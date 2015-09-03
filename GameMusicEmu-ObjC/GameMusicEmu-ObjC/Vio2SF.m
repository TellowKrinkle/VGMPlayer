//
//  Vio2SF.m
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 3/25/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import "Vio2SF.h"
#include "PSFLib/psflib.h"
#include "Vio2SF/desmume/state.h"
#include <zlib.h>

struct twosf_loader_state {
	uint8_t *rom;
	uint8_t *state;
	size_t rom_size;
	size_t state_size;
	
	int initial_frames;
	int sync_type;
	int clockdown;
	int arm9_clockdown_level;
	int arm7_clockdown_level;
	
	double length;
	double fade;
};

static void makeNSError(NSError **error, NSString *domain, int code, NSString *localizedDescription) {
	if (error) {
		NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
		[errorDetail setValue:localizedDescription forKey:NSLocalizedDescriptionKey];
		*error = [NSError errorWithDomain:domain code:code userInfo:errorDetail];
	}
}

static double parseTime(const char * time) {
	double seconds = 0;
	NSString *timeString = [NSString stringWithCString:time encoding:NSUTF8StringEncoding];
	NSArray *parts = [timeString componentsSeparatedByString:@":"];
	if (parts.count > 2) {
		seconds = [(NSString *)parts[0] doubleValue] * 3600;
		seconds += [(NSString *)parts[1] doubleValue] * 60;
		seconds += [(NSString *)parts[2] doubleValue];
	}
	else if (parts.count == 2) {
		seconds = [(NSString *)parts[0] doubleValue] * 60;
		seconds += [(NSString *)parts[1] doubleValue];
	}
	else if (parts.count == 1) {
		seconds = [(NSString *)parts[0] doubleValue];
	}
	return seconds;
}

#pragma mark PSFLib callbacks

static void * psf_file_fopen(const char *url) {
	return fopen(url, "r");
}

static size_t psf_file_fread(void *buffer, size_t size, size_t count, void *handle) {
	return fread(buffer, size, count, handle);
}

static int psf_file_fseek(void *handle, int64_t offset, int whence) {
	return fseek(handle, offset, whence);
}

static int psf_file_fclose(void *handle) {
	return fclose(handle);
}

static long psf_file_ftell(void *handle) {
	return ftell(handle);
}

static psf_file_callbacks psfFileSystem = {
	"/:",
	psf_file_fopen,
	psf_file_fread,
	psf_file_fseek,
	psf_file_fclose,
	psf_file_ftell
};

static unsigned get_le32( void const* p )
{
	return  (unsigned) ((unsigned char const*) p) [3] << 24 |
	(unsigned) ((unsigned char const*) p) [2] << 16 |
	(unsigned) ((unsigned char const*) p) [1] <<  8 |
	(unsigned) ((unsigned char const*) p) [0];
}

static int load_twosf_map(struct twosf_loader_state *state, int issave, const unsigned char *udata, unsigned usize)
{
	if (usize < 8) return -1;
	
	unsigned char *iptr;
	size_t isize;
	unsigned char *xptr;
	unsigned xsize = get_le32(udata + 4);
	unsigned xofs = get_le32(udata + 0);
	if (issave)
	{
		iptr = state->state;
		isize = state->state_size;
		state->state = 0;
		state->state_size = 0;
	}
	else
	{
		iptr = state->rom;
		isize = state->rom_size;
		state->rom = 0;
		state->rom_size = 0;
	}
	if (!iptr)
	{
		size_t rsize = xofs + xsize;
		if (!issave)
		{
			rsize -= 1;
			rsize |= rsize >> 1;
			rsize |= rsize >> 2;
			rsize |= rsize >> 4;
			rsize |= rsize >> 8;
			rsize |= rsize >> 16;
			rsize += 1;
		}
		iptr = (unsigned char *) malloc(rsize + 10);
		if (!iptr)
			return -1;
		memset(iptr, 0, rsize + 10);
		isize = rsize;
	}
	else if (isize < xofs + xsize)
	{
		size_t rsize = xofs + xsize;
		if (!issave)
		{
			rsize -= 1;
			rsize |= rsize >> 1;
			rsize |= rsize >> 2;
			rsize |= rsize >> 4;
			rsize |= rsize >> 8;
			rsize |= rsize >> 16;
			rsize += 1;
		}
		xptr = (unsigned char *) realloc(iptr, xofs + rsize + 10);
		if (!xptr)
		{
			free(iptr);
			return -1;
		}
		iptr = xptr;
		isize = rsize;
	}
	memcpy(iptr + xofs, udata + 8, xsize);
	if (issave)
	{
		state->state = iptr;
		state->state_size = isize;
	}
	else
	{
		state->rom = iptr;
		state->rom_size = isize;
	}
	return 0;
}

static int load_twosf_mapz(struct twosf_loader_state *state, int issave, const unsigned char *zdata, unsigned zsize, unsigned zcrc)
{
	int ret;
	int zerr;
	uLongf usize = 8;
	uLongf rsize = usize;
	unsigned char *udata;
	unsigned char *rdata;
	
	udata = (unsigned char *) malloc(usize);
	if (!udata)
		return -1;
	
	while (Z_OK != (zerr = uncompress(udata, &usize, zdata, zsize)))
	{
		if (Z_MEM_ERROR != zerr && Z_BUF_ERROR != zerr)
		{
			free(udata);
			return -1;
		}
		if (usize >= 8)
		{
			usize = get_le32(udata + 4) + 8;
			if (usize < rsize)
			{
				rsize += rsize;
				usize = rsize;
			}
			else
				rsize = usize;
		}
		else
		{
			rsize += rsize;
			usize = rsize;
		}
		rdata = (unsigned char *) realloc(udata, usize);
		if (!rdata)
		{
			free(udata);
			return -1;
		}
		udata = rdata;
	}
	
	rdata = (unsigned char *) realloc(udata, usize);
	if (!rdata)
	{
		free(udata);
		return -1;
	}
	
	/*if (0)
	{
		uLong ccrc = crc32(crc32(0L, Z_NULL, 0), rdata, (uInt) usize);
		if (ccrc != zcrc)
			return -1;
	}*/
	
	ret = load_twosf_map(state, issave, rdata, (unsigned) usize);
	free(rdata);
	return ret;
}

static int twosfLoader(void *context, const uint8 *exe, size_t exe_size, const uint8_t *reserved, size_t reserved_size) {
	struct twosf_loader_state *state = (struct twosf_loader_state *)context;
	
	if (exe_size >= 8) {
		if (load_twosf_map(state, 0, exe, (unsigned)exe_size)) {
			return -1;
		}
	}
	
	if (reserved_size) {
		size_t resvPos = 0;
		if (reserved_size < 16) {
			return -1;
		}
		while (resvPos + 12 < reserved_size) {
			unsigned save_size = get_le32(reserved + resvPos + 4);
			unsigned save_crc = get_le32(reserved + resvPos + 8);
			if (get_le32(reserved + resvPos + 0) == 0x45564153) {
				if (resvPos + 12 + save_size > reserved_size) {
					return -1;
				}
				if (load_twosf_mapz(state, 1, reserved + resvPos + 12, save_size, save_crc)) {
					return -1;
				}
			}
			resvPos += 12 + save_size;
		}
 	}
	
	return 0;
}

static int twosfInfo(void *context, const char *name, const char *value) {
	struct twosf_loader_state *state = (struct twosf_loader_state *)context;
	char *end;
	
	if (!strcasecmp(name, "_frames")) {
		state->initial_frames = (int)strtol(value, &end, 10);
	}
	else if (!strcasecmp(name, "_clockdown")) {
		state->clockdown = (int)strtol(value, &end, 10);
	}
	else if (!strcasecmp(name, "_vio2sf_sync_type")) {
		state->sync_type = (int)strtol(value, &end, 10);
	}
	else if (!strcasecmp(name, "_vio2sf_arm9_clockdown_level")) {
		state->arm9_clockdown_level = (int)strtol(value, &end, 10);
	}
	else if (!strcasecmp(name, "_vio2sf_arm7_clockdown_level")) {
		state->arm7_clockdown_level = (int)strtol(value, &end, 10);
	}
	else if (strcasecmp(name, "length") == 0) {
		state->length = parseTime(value);
	}
	else if (strcasecmp(name, "fade") == 0) {
		state->fade = parseTime(value);
	}
	
	return 0;
}

#pragma mark - Main Class

@interface Vio2SF() {
	struct twosf_loader_state _state;
	NDS_state *_emu;
}

@end

@implementation Vio2SF

- (instancetype)init {
	self = [super init];
	
	if (self) {
		_emu = (NDS_state *)calloc(1, sizeof(NDS_state));
		state_init(_emu);
		_sampleRate = 44100;
	}
	
	return self;
}

- (int)channels {
	return 2;
}

- (void)openFile:(NSURL *)file error:(NSError *__autoreleasing *)e {
	if (psf_load(file.fileSystemRepresentation, &psfFileSystem, 0x24, twosfLoader, &_state, twosfInfo, &_state, 1) < 0) {
		makeNSError(e, @"Vio2SF", 100, [NSString stringWithFormat:@"File %@ is of an unsupported type.", file]);
	}
	if (!_state.arm7_clockdown_level) {
		_state.arm7_clockdown_level = _state.clockdown;
	}
	if (!_state.arm9_clockdown_level) {
		_state.arm9_clockdown_level = _state.clockdown;
	}
	
	_emu->dwInterpolation = 4;
	_emu->dwChannelMute = 0;
	_emu->initial_frames = _state.initial_frames;
	_emu->sync_type = _state.sync_type;
	_emu->arm7_clockdown_level = _state.arm7_clockdown_level;
	_emu->arm9_clockdown_level = _state.arm9_clockdown_level;
	
	if (_state.rom) {
		state_setrom(_emu, _state.rom, (uint32)_state.rom_size, 0);
	}
	state_loadstate(_emu, _state.state, (uint32)_state.state_size);
}

- (void)play:(int)size withBuffer:(short *)buffer {
	if (_emu) {
		_position += size / self.channels;
		state_render(_emu, buffer, size/2);
	}
}

- (void)setPosition:(long)position {
	long seekSamples;
	if (position > _position) {
		seekSamples = position - _position;
	}
	else {
		seekSamples = position;
		state_setrom(_emu, _state.rom, (uint32)_state.rom_size, 0);
		state_loadstate(_emu, _state.state, (uint32)_state.state_size);
	}
	_position = position;
	int bufferSize = _sampleRate / 2;
	short *buffer = malloc(sizeof(short) * bufferSize * 2);
	while (seekSamples > 0) {
		if (seekSamples > bufferSize) {
			seekSamples -= bufferSize;
			state_render(_emu, buffer, bufferSize);
		}
		else {
			seekSamples = 0;
			state_render(_emu, buffer, (int)seekSamples);
		}
	}
	free(buffer);
}

- (long)trackLength {
	return (_state.length + _state.fade) * self.sampleRate;
}

+ (bool)canPlay:(NSURL *)file {
	NSError *error = nil;
	NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL:file error:&error];
	if (error) {
		return false;
	}
	NSData *header = [handle readDataOfLength:4];
	if (header.length < 4) {
		return false;
	}
	[handle closeFile];
	uint8 *bytes = (uint8 *)header.bytes;
	if (bytes[0] == 'P' && bytes[1] == 'S' && bytes[2] == 'F' && bytes[3] == 0x24) {
		return true;
	}
	return false;
}

- (void)dealloc {
	state_deinit(_emu);
	free(_emu);
	free(_state.rom);
	free(_state.state);
}

@end
