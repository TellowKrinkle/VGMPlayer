//
//  SSEQPlayer.m
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 9/18/15.
//  Copyright © 2015 TellowKrinkle. All rights reserved.
//

#import "SSEQPlayer.h"
#include "PSFLib/PSFLib/psflib.h"
#include "SSEQPlayer/SSEQPlayer/SDAT.h"
#include "SSEQPlayer/SSEQPlayer/Player.h"
#include <zlib.h>

struct ncsf_loader_state {
	uint32_t sseq;
	std::vector<uint8_t> sdatData;
	std::unique_ptr<SDAT> sdat;
	
	double length;
	double fade;
	void *tags;
	
	ncsf_loader_state() : sseq(0), length(0), fade(0), tags(0) {}
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

static int ncsf_loader(void * context, const uint8_t *exe, size_t exe_size,
				const uint8_t *reserved, size_t reserved_size)
{
	struct ncsf_loader_state *state = (struct ncsf_loader_state *) context;
	
	if (reserved_size >= 4)
	{
		state->sseq = get_le32(reserved);
	}
	
	if (exe_size >= 12)
	{
		uint32_t sdat_size = get_le32(exe + 8);
		if (sdat_size > exe_size) return -1;
		
		if (state->sdatData.empty())
			state->sdatData.resize(sdat_size, 0);
		else if (state->sdatData.size() < sdat_size)
			state->sdatData.resize(sdat_size);
		memcpy(&state->sdatData[0], exe, sdat_size);
	}
	
	return 0;
}

static int ncsfInfo(void *context, const char *name, const char *value) {
	struct ncsf_loader_state *state = (struct ncsf_loader_state *)context;
	if (strcasecmp(name, "length") == 0) {
		state->length = parseTime(value);
	}
	else if (strcasecmp(name, "fade") == 0) {
		state->fade = parseTime(value);
	}
	[(__bridge NSMutableDictionary *)state->tags setObject:[NSString stringWithCString:value encoding:NSUTF8StringEncoding] forKey:[NSString stringWithCString:name encoding:NSUTF8StringEncoding]];
	
	return 0;
}

#pragma mark - Main Class

@interface SSEQPlayer() {
	struct ncsf_loader_state _state;
	Player _emu;
	std::vector<uint8_t> _sampleBuffer;
}

@end

@implementation SSEQPlayer

- (instancetype)initWithSampleRate:(int)sampleRate {
	self = [super init];
	
	if (self) {
		_state.tags = (void *)CFBridgingRetain([NSMutableDictionary dictionary]);
		_emu.sampleRate = sampleRate;
		_emu.interpolation = INTERPOLATION_SINC;
	}
	
	return self;
}

- (instancetype)init {
	return [self initWithSampleRate:DEFAULT_SAMPLE_RATE];
}

- (void)openFile:(NSURL *)file error:(NSError *__autoreleasing *)err {
	if (psf_load(file.fileSystemRepresentation, &psfFileSystem, 0x25, ncsf_loader, &_state, ncsfInfo, &_state, 1) < 0) {
		makeNSError(err, @"SSEQPlayer", 100, [NSString stringWithFormat:@"File %@ is of an unsupported type.", file]);
	}
	
	PseudoFile pseudoFile;
	pseudoFile.data = &_state.sdatData;
	
	_state.sdat.reset(new SDAT(pseudoFile, _state.sseq));
	
	auto *sseqToPlay = _state.sdat->sseq.get();
	
	_emu.sseqVol = Cnv_Scale(sseqToPlay->info.vol);
	_emu.Setup(sseqToPlay);
	_emu.Timer();
}

- (void)playIntoBuffer:(short *)buffer size:(int)size {
	if (_sampleBuffer.size() < size * sizeof(short)) {
		_sampleBuffer.resize(size * sizeof(short));
	}
	_position += size / self.channels;
	_emu.GenerateSamples(_sampleBuffer, 0, size / self.channels);
	memcpy(buffer, &_sampleBuffer[0], size * sizeof(short));
}

- (void)setPosition:(long)position {
	long seekSamples;
	if (position > _position) {
		seekSamples = position - _position;
	}
	else {
		seekSamples = position;
		_emu.Stop(true);
		PseudoFile pseudoFile;
		pseudoFile.data = &_state.sdatData;
		
		_state.sdat.reset(new SDAT(pseudoFile, _state.sseq));
		
		auto *sseqToPlay = _state.sdat->sseq.get();
		
		_emu.sseqVol = Cnv_Scale(sseqToPlay->info.vol);
		_emu.Setup(sseqToPlay);
		_emu.Timer();
	}
	_position = position;
	int bufferSize = self.sampleRate / 2;
	if (_sampleBuffer.size() < bufferSize * sizeof(short) * self.channels) {
		_sampleBuffer.resize(bufferSize * sizeof(short) * self.channels);
	}
	while (seekSamples > 0) {
		if (seekSamples > bufferSize) {
			seekSamples -= bufferSize;
			_emu.GenerateSamples(_sampleBuffer, 0, bufferSize);
		}
		else {
			_emu.GenerateSamples(_sampleBuffer, 0, (int)seekSamples);
			seekSamples = 0;
		}
	}
}

- (int)sampleRate {
	return _emu.sampleRate;
}

- (int)numTracks {
	return 1;
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
	if (bytes[0] == 'P' && bytes[1] == 'S' && bytes[2] == 'F' && bytes[3] == 0x25) {
		return true;
	}
	return false;
}

- (void)dealloc {
	CFBridgingRelease(_state.tags);
}

@end
