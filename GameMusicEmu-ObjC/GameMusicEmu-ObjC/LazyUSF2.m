//
//  LazyUSFWrapper.m
//  GameMusicEmu-ObjCTest
//
//  Created by Evan Tang on 3/22/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import "LazyUSF2.h"
#include "LazyUSF2/LazyUSF2/usf/usf.h"
#include "PSFLib/PSFLib/psflib.h"

#define DEFAULT_SAMPLE_RATE 44100

struct usfLoaderState {
	uint32_t enableCompare;
	uint32_t enableFifoFull;
	double	 length;
	double	 fade;
	void *tags;
	void	 *emuState;
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

static int usfLoader(void *context, const uint8_t *exe, size_t exe_size, const uint8_t *reserved, size_t reserved_size) {
	struct usfLoaderState *state = (struct usfLoaderState *)context;
	if (exe_size > 0) {
		return -1;
	}
	return usf_upload_section(state->emuState, reserved, reserved_size);
}

static int usfInfo(void *context, const char *name, const char *value) {
	struct usfLoaderState *state = (struct usfLoaderState *)context;
//	NSLog(@"%s", name);
	if (strcasecmp(name, "_enablecompare") == 0 && strlen(value)) {
		state->enableCompare = 1;
	}
	else if (strcasecmp(name, "_enablefifofull") == 0 && strlen(value)) {
		state->enableFifoFull = 1;
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


# pragma mark - Main Class

@interface LazyUSF2() {
	struct usfLoaderState _usfState;
}

@end

@implementation LazyUSF2

- (instancetype)initWithSampleRate:(int)sampleRate {
	self = [super init];
	if (self) {
		_position = 0;
		_sampleRate = sampleRate;
		_usfState.emuState = malloc(usf_get_state_size());
		_usfState.tags = (void *)CFBridgingRetain([NSMutableDictionary dictionary]);
		usf_clear(_usfState.emuState);
		usf_set_hle_audio(_usfState.emuState, 1);
	}
	return self;
}

- (instancetype)init {
	return [self initWithSampleRate:DEFAULT_SAMPLE_RATE];
}

- (int)channels {
	return 2;
}

- (void)openFile:(NSURL *)file error:(NSError **)e {
	if (psf_load(file.fileSystemRepresentation, &psfFileSystem, 0x21, usfLoader, &_usfState, usfInfo, &_usfState, 1) < 0) {
		makeNSError(e, @"LazyUSF2", 100, [NSString stringWithFormat:@"File %@ is of an unsupported type.", file]);
		return;
	}
	usf_set_compare(_usfState.emuState, _usfState.enableCompare);
	usf_set_fifo_full(_usfState.emuState, _usfState.enableFifoFull);
}

- (void)play:(int)size withBuffer:(short *)buffer {
	if (_usfState.emuState) {
		usf_render_resampled(_usfState.emuState, buffer, size/2, _sampleRate);
		_position += size / self.channels;
	}
}

- (void)setPosition:(long)position {
	long seekSamples;
	if (position > _position) {
		seekSamples = position - _position;
	}
	else {
		seekSamples = position;
		usf_restart(_usfState.emuState);
	}
	_position = position;
	int bufferSize = _sampleRate / 2;
	short *buffer = malloc(sizeof(short) * bufferSize * 2);
	while (seekSamples > 0) {
		if (seekSamples > bufferSize) {
			seekSamples -= bufferSize;
			usf_render_resampled(_usfState.emuState, buffer, bufferSize, _sampleRate);
		}
		else {
			seekSamples = 0;
			usf_render_resampled(_usfState.emuState, buffer, seekSamples, _sampleRate);
		}
	}
	free(buffer);
}

- (long)trackLength {
	return (_usfState.length + _usfState.fade) * self.sampleRate;
}

- (NSDictionary *)tags {
	return [(__bridge NSMutableDictionary *)_usfState.tags copy];
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
	if (bytes[0] == 'P' && bytes[1] == 'S' && bytes[2] == 'F' && bytes[3] == 0x21) {
		return true;
	}
	return false;
}

- (void)dealloc {
	usf_shutdown(_usfState.emuState);
	free(_usfState.emuState);
	CFBridgingRelease(_usfState.tags);
}

@end
