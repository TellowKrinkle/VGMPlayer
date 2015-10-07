//
//  VGMStream.m
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 4/6/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import "VGMStream.h"
#include "VGMStream/VGMStream/vgmstream.h"

static void makeNSError(NSError **error, NSString *domain, int code, NSString *localizedDescription) {
	if (error) {
		NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
		[errorDetail setValue:localizedDescription forKey:NSLocalizedDescriptionKey];
		*error = [NSError errorWithDomain:domain code:code userInfo:errorDetail];
	}
}

@interface VGMStream () {
	VGMSTREAM *_stream;
}

@end

@implementation VGMStream

- (instancetype)init {
	self = [super init];
	
	if (self) {
		_channels = 2;
		_sampleRate = 44100;
	}
	
	return self;
}

- (void)openFile:(NSURL *)file error:(NSError *__autoreleasing *)e {
	_stream = init_vgmstream(file.fileSystemRepresentation);
	if (_stream == NULL) {
		makeNSError(e, @"VGMStream", 100, [NSString stringWithFormat:@"File %@ is of an unsupported type.", file]);
		return;
	}
	_sampleRate = _stream->sample_rate;
	_channels = _stream->channels;
}

- (void)playIntoBuffer:(short *)buffer size:(int)size {
	if (_stream) {
		if (_stream->loop_flag) {
			render_vgmstream(buffer, size / self.channels, _stream);
		}
		else {
			int sample_count = size / self.channels;
			if (sample_count + _stream->current_sample > _stream->num_samples) {
				sample_count = _stream->num_samples - _stream->current_sample;
				if (sample_count < 0) {
					sample_count = 0;
				}
				memset(buffer, 0, size * sizeof(short));
			}
			render_vgmstream(buffer, sample_count, _stream);
		}
	}
}

- (bool)trackHasEnded {
	if (_stream) {
		return !_stream->loop_flag && _stream->current_sample >= _stream->num_samples;
	}
	return true;
}

- (long)position {
	return _stream->current_sample;
}

- (void)setPosition:(long)position {
	if (position < self.position) {
		reset_vgmstream(_stream);
	}
	if (position > self.trackLength) {
		position = self.trackLength;
	}
	long samplesToSeek = position - self.position;
	int bufferSize = _sampleRate / 2;
	short *buffer = malloc(sizeof(short) * bufferSize * self.channels);
	while (samplesToSeek > 0) {
		if (samplesToSeek > bufferSize) {
			samplesToSeek -= bufferSize;
			render_vgmstream(buffer, bufferSize, _stream);
		}
		else {
			render_vgmstream(buffer, (int)samplesToSeek, _stream);
			samplesToSeek = 0;
		}
	}
	free(buffer);
}

- (long)trackLength {
	return _stream->num_samples;
}

+ (bool)canPlay:(NSURL *)file {
	VGMSTREAM *stream = init_vgmstream(file.fileSystemRepresentation);
	if (stream == NULL) {
		return false;
	}
	else {
		close_vgmstream(stream);
		return true;
	}
}

- (void)dealloc {
	close_vgmstream(_stream);
}

@end
