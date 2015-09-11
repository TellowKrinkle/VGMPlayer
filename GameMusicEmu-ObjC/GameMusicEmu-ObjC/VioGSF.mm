//
//  VioGSF.m
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 9/3/15.
//  Copyright © 2015 TellowKrinkle. All rights reserved.
//

#import "VioGSF.h"
#include "PSFLib/PSFLib/psflib.h"
#include "VioGSF/VioGSF/gba/GBA.h"
#include "VioGSF/VioGSF/gba/Sound.h"
#define BUFFER_SIZE 65536

struct gsf_loader_state {
	int entry_set;
	uint32_t entry;
	uint8_t *data;
	uint32_t data_size;
	
	int initial_frames;
	
	double length;
	double fade;
	void *tags;
};

struct gsf_sound_out : public GBASoundOut {
	unsigned long bytesInBuffer;
	unsigned writeOffset;
	unsigned readOffset;
	uint8_t *buffer;
	
	gsf_sound_out() {
		buffer = (uint8_t *)malloc(sizeof(uint8_t) * BUFFER_SIZE);
		writeOffset = 0;
		readOffset = 0;
	}
	~gsf_sound_out() {}
	virtual void write(const void *samples, unsigned long bytes) {
		if (bytes + bytesInBuffer > BUFFER_SIZE) {
			printf("GSF Sound Out buffer overflowed by %lu bytes!", BUFFER_SIZE - (bytes + bytesInBuffer));
			bytes = BUFFER_SIZE - bytesInBuffer;
		}
		// Are we about to write off the end of the buffer?
		if (writeOffset + bytes > BUFFER_SIZE) {
			unsigned firstChunk = BUFFER_SIZE - writeOffset;
			memcpy(buffer + writeOffset, samples, firstChunk);
			memcpy(buffer, (uint8_t *)samples + firstChunk, bytes - firstChunk);
			writeOffset = (unsigned)(bytes - firstChunk);
		}
		else {
			memcpy(buffer + writeOffset, samples, bytes);
			writeOffset += bytes;
		}
		bytesInBuffer += bytes;
	}
	
	virtual void read(uint8_t *samples, unsigned long numBytes) {
		if (numBytes > bytesInBuffer) {
			printf("GSF Sound Out buffer underflowed by %lu bytes!", bytesInBuffer - numBytes);
			numBytes = bytesInBuffer;
		}
		// Are we about to read off the end of the buffer?
		if (readOffset + numBytes > BUFFER_SIZE) {
			unsigned firstChunk = BUFFER_SIZE - readOffset;
			memcpy(samples, buffer + readOffset, firstChunk);
			memcpy(samples + firstChunk, buffer, numBytes - firstChunk);
			readOffset = (unsigned)(numBytes - firstChunk);
		}
		else {
			memcpy(samples, buffer + readOffset, numBytes);
			readOffset += numBytes;
		}
		bytesInBuffer -= numBytes;
	}
	
	virtual void clear(unsigned long numBytes) {
		if (numBytes > bytesInBuffer) {
			printf("GSF Sound Out buffer underflowed by %lu bytes!", bytesInBuffer - numBytes);
			numBytes = bytesInBuffer;
		}
		if (readOffset + numBytes > BUFFER_SIZE) {
			readOffset = (unsigned)(numBytes - (BUFFER_SIZE - readOffset));
		}
		else {
			readOffset += numBytes;
		}
		bytesInBuffer -= numBytes;
	}
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
	return fread(buffer, size, count, (FILE *)handle);
}

static int psf_file_fseek(void *handle, int64_t offset, int whence) {
	return fseek((FILE *)handle, offset, whence);
}

static int psf_file_fclose(void *handle) {
	return fclose((FILE *)handle);
}

static long psf_file_ftell(void *handle) {
	return ftell((FILE *)handle);
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

static int gsfLoader(void *context, const uint8_t *exe, size_t exe_size, const uint8_t *reserved, size_t reserved_size) {
	struct gsf_loader_state *state = (struct gsf_loader_state *)context;
	if (exe_size < 12) {
		return -1;
	}
	unsigned char *iptr;
	unsigned isize;
	unsigned char *xptr;
	unsigned xentry = get_le32(exe + 0);
	unsigned xsize = get_le32(exe + 8);
	unsigned xofs = get_le32(exe + 4) & 0x1ffffff;
	if ( xsize < exe_size - 12 ) return -1;
	if (!state->entry_set)
	{
		state->entry = xentry;
		state->entry_set = 1;
	}
	{
		iptr = state->data;
		isize = state->data_size;
		state->data = 0;
		state->data_size = 0;
	}
	if (!iptr)
	{
		unsigned rsize = xofs + xsize;
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
		unsigned rsize = xofs + xsize;
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
	memcpy(iptr + xofs, exe + 12, xsize);
	{
		state->data = iptr;
		state->data_size = isize;
	}
	return 0;
	
}

static int gsfInfo(void *context, const char *name, const char *value) {
	struct gsf_loader_state *state = (struct gsf_loader_state *)context;
	char *end;
	
	if (!strcasecmp(name, "_frames")) {
		state->initial_frames = (int)strtol(value, &end, 10);
	}
	else if (strcasecmp(name, "length") == 0) {
		state->length = parseTime(value);
	}
	else if (strcasecmp(name, "fade") == 0) {
		state->fade = parseTime(value);
	}
	[(__bridge NSMutableDictionary *)state->tags setObject:[NSString stringWithCString:value encoding:NSUTF8StringEncoding] forKey:[NSString stringWithCString:name encoding:NSUTF8StringEncoding]];
	
	return 0;
}

@interface VioGSF() {
	gsf_loader_state _state;
	GBASystem *_emu;
	gsf_sound_out *_sound;
}

@end

@implementation VioGSF

- (instancetype) init {
	self = [super init];
	
	if (self) {
		_emu = new GBASystem();
		_sound = new gsf_sound_out();
		_sampleRate = 44100;
	}
	
	return self;
}

- (void)openFile:(NSURL *)file error:(NSError *__autoreleasing *)err {
	if (psf_load(file.fileSystemRepresentation, &psfFileSystem, 0x22, gsfLoader, &_state, gsfInfo, &_state, 0) < 0) {
		makeNSError(err, @"Vio2SF", 100, [NSString stringWithFormat:@"File %@ is of an unsupported type.", file]);
	}
	_emu->cpuIsMultiBoot = ((_state.entry >> 24) == 2);
	_emu->soundDeclicking = 1;
	_emu->soundInterpolation = 1;
	CPULoadRom(_emu, _state.data, _state.data_size);
	soundInit(_emu, _sound);
	soundReset(_emu);
	CPUInit(_emu);
	CPUReset(_emu);
	
}

- (void)playIntoBuffer:(short *)buffer size:(int)size {
	if (_emu) {
		_position += size / self.channels;
		while (_sound->bytesInBuffer < size * 2) {
			CPULoop(_emu, 250000);
		}
		_sound->read((uint8_t *)buffer, size * 2);
	}
}

- (void)setPosition:(long)position {
	long seekSamples;
	if (position > _position) {
		seekSamples = (position - _position) * self.channels;
	}
	else {
		seekSamples = position * self.channels;
		soundReset(_emu);
		CPUReset(_emu);
	}
	_position = position;
	while (seekSamples > BUFFER_SIZE/4) {
		// Fill the buffer a quarter of the way, then dump it.
		while (_sound->bytesInBuffer < BUFFER_SIZE/4) {
			CPULoop(_emu, 250000);
		}
		_sound->clear(BUFFER_SIZE/4);
		seekSamples -= BUFFER_SIZE/4;
	}
	unsigned long bytesLeft = _sound->bytesInBuffer + seekSamples;
	while (_sound->bytesInBuffer < bytesLeft) {
		CPULoop(_emu, 250000);
	}
	_sound->clear(bytesLeft);
}

- (long)trackLength {
	return (_state.length + _state.fade) * self.sampleRate;
}

- (int)channels {
	return 2;
}

- (NSDictionary *)tags {
	return [(__bridge NSMutableDictionary *)_state.tags copy];
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
	if (bytes[0] == 'P' && bytes[1] == 'S' && bytes[2] == 'F' && bytes[3] == 0x22) {
		return true;
	}
	return false;
}

- (void)dealloc {
	free(_state.data);
	CFBridgingRelease(_state.tags);
	delete _emu;
	delete _sound;
}

@end
