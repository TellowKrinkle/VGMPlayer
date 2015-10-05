//
//  AOPSF.m
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 9/25/15.
//  Copyright © 2015 TellowKrinkle. All rights reserved.
//

#import "AOPSF.h"
#include "PSFLib/PSFLib/psflib.h"
#include "PSFLib/PSFLib/psf2fs.h"
#include "AOPSF/AOPSF/psx_external.h"
#include <zlib.h>

struct psf_loader_state {
	void *emu;
	bool first;
	unsigned refresh;
	int psf_version;
	
	double length;
	double fade;
	void *tags;
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

static int psfInfo(void *context, const char *name, const char *value) {
	struct psf_loader_state *state = (struct psf_loader_state *)context;
	char *end;
	
	if (strcasecmp(name, "_refresh") == 0) {
		state->refresh = (int)strtol(value, &end, 10);
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

static int psf1Loader(void *context, const uint8_t *exe, size_t exe_size, const uint8_t *reserved, size_t reserved_size) {
	struct psf_loader_state *state = (struct psf_loader_state *)context;
	if (reserved && reserved_size) {
		return -1;
	}
	if (psf_load_section((PSX_STATE *)state->emu, exe, (unsigned)exe_size, state->first)) {
		NSLog(@"Meow!");
		return -1;
	}
	state->first = false;
	
	return 0;
}

@interface AOPSF () {
	struct psf_loader_state _state;
	void *_psf2fs;
	bool _started;
	int32 (*_autoPSFStart)(PSX_STATE *);
	int32 (*_autoPSFStop)(PSX_STATE *);
	int32 (*_autoPSFGen)(PSX_STATE *, int16 *, uint32);
	NSURL *_file;
}

@end

@implementation AOPSF

- (instancetype)init {
	self = [super init];
	
	if (self) {
		_state.tags = (void *)CFBridgingRetain([NSMutableDictionary dictionary]);
		_sampleRate = 44100;
		_channels = 2;
		_started = false;
	}
	
	return self;
}

- (void)openFile:(NSURL *)file error:(NSError *__autoreleasing *)err {
	_file = file;
	_state.psf_version = psf_load(file.fileSystemRepresentation, &psfFileSystem, 0, 0, 0, 0, 0, 0);
	if (_state.psf_version != 1 && _state.psf_version != 2) {
		makeNSError(err, @"AOPSF", 100, [NSString stringWithFormat:@"File %@ is of an unsupported type.", file]);
		return;
	}
	
	[self stop];
	
	_state.emu = malloc(psx_get_state_size(_state.psf_version));
	
	if (_state.psf_version == 1) {
		
		_state.first = true;
		_state.refresh = 0;
		
		if (psf_load(file.fileSystemRepresentation, &psfFileSystem, 1, &psf1Loader, &_state, &psfInfo, &_state, 1) < 0) {
			makeNSError(err, @"AOPSF", 100, [NSString stringWithFormat:@"File %@ is of an unsupported type.", file]);
			return;
		}
		
		if (_state.refresh) {
			psx_set_refresh((PSX_STATE *)_state.emu, _state.refresh);
		}
		
		_autoPSFStart = &psf_start;
		_autoPSFStop = &psf_stop;
		_autoPSFGen = &psf_gen;
	}
	else {
		if (_psf2fs) {
			psf2fs_delete(_psf2fs);
		}
		_psf2fs = psf2fs_create();
		
		_state.refresh = 0;
		if (psf_load(file.fileSystemRepresentation, &psfFileSystem, 2, psf2fs_load_callback, _psf2fs, &psfInfo, &_state, 1) < 0) {
			makeNSError(err, @"AOPSF", 100, [NSString stringWithFormat:@"File %@ is of an unsupported type.", file]);
			return;
		}
		
		if (_state.refresh) {
			psx_set_refresh((PSX_STATE *)_state.emu, _state.refresh);
		}
		
		psf2_register_readfile( (PSX_STATE *) _state.emu, psf2fs_virtual_readfile, _psf2fs );
		
		_autoPSFStart = &psf2_start;
		_autoPSFStop = &psf2_stop;
		_autoPSFGen = &psf2_gen;
	}
	
	_autoPSFStart((PSX_STATE *)_state.emu);
	
	_sampleRate = _state.psf_version == 2 ? 48000 : 44100;
	_started = true;
}

- (void)playIntoBuffer:(short *)buffer size:(int)size {
	if (_started) {
		_position += size / self.channels;
		_autoPSFGen(_state.emu, buffer, size / self.channels);
	}
}

- (void)stop {
	if (_started) {
		_autoPSFStop(_state.emu);
		free(_state.emu);
		_started = false;
	}
}

- (void)setPosition:(long)position {
	long seekSamples;
	if (position > _position) {
		seekSamples = (position - _position) * self.channels;
	}
	else {
		seekSamples = position * self.channels;
		_autoPSFStop(_state.emu);
		if (_state.psf_version == 1) {
			
			_state.first = true;
			
			psf_load(_file.fileSystemRepresentation, &psfFileSystem, 1, &psf1Loader, &_state, NULL, NULL, 1);
		}
		else {
			if (_psf2fs) {
				psf2fs_delete(_psf2fs);
			}
			_psf2fs = psf2fs_create();
			
			psf_load(_file.fileSystemRepresentation, &psfFileSystem, 2, psf2fs_load_callback, _psf2fs, &psfInfo, &_state, 1);
			
			psf2_register_readfile( (PSX_STATE *) _state.emu, psf2fs_virtual_readfile, _psf2fs );
		}
		_autoPSFStart(_state.emu);
	}
	_position = position;
	int bufferSize = _sampleRate / 2;
	short *buffer = malloc(sizeof(short) * bufferSize * 2);
	while (seekSamples > 0) {
		if (seekSamples > bufferSize) {
			seekSamples -= bufferSize;
			_autoPSFGen(_state.emu, buffer, bufferSize);
		}
		else {
			_autoPSFGen(_state.emu, buffer, (int)seekSamples);
			seekSamples = 0;
		}
	}
	free(buffer);
}

- (long)trackLength {
	return (_state.length + _state.fade) * self.sampleRate;
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
	if (bytes[0] == 'P' && bytes[1] == 'S' && bytes[2] == 'F' && (bytes[3] == 0x01 || bytes[3] == 0x02)) {
		return true;
	}
	return false;
}

- (void)dealloc {
	CFBridgingRelease(_state.tags);
	if (_psf2fs) {
		psf2fs_delete(_psf2fs);
	}
	[self stop];
}

@end
