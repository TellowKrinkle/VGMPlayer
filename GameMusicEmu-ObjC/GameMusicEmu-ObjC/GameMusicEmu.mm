//
//  MusicEmuWrapper.m
//  test2
//
//  Created by Evan Tang on 3/9/15.
//
//

#import "GameMusicEmu.h"
#import "GME/GME/Music_Emu.h"
#define DEFAULT_SAMPLE_RATE 44100

static void makeNSError(NSError **error, NSString *domain, int code, NSString *localizedDescription) {
	if (error) {
		NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
		[errorDetail setValue:localizedDescription forKey:NSLocalizedDescriptionKey];
		*error = [NSError errorWithDomain:domain code:code userInfo:errorDetail];
	}
}

void handle_error( const char* str )
{
	if ( str )
	{
		[NSException raise:[NSString stringWithCString:str encoding:NSUTF8StringEncoding] format:@"%s", str];
	}
}

@interface GameMusicEmu() {
	Music_Emu *_emu;
	track_info_t *_info;
}

@end

@implementation GameMusicEmu

+ (bool)canPlay:(NSURL *)file {
	gme_type_t file_type;
	handle_error(gme_identify_file(file.fileSystemRepresentation, &file_type));
	if (!file_type) {
		return false;
	}
	else {
		return true;
	}
}

- (instancetype)initWithSampleRate:(int)sampleRate {
	self = [super init];
	if (self) {
		_info = (track_info_t *)malloc(sizeof(track_info_t));
		_sampleRate = sampleRate;
		_position = 0;
	}
	return self;
}

- (instancetype)init {
	return [self initWithSampleRate:DEFAULT_SAMPLE_RATE];
}

- (int)channels {
	return 2;
}

- (void)openFile:(NSURL *)file track:(int)trackNo error:(NSError *__autoreleasing *)e{
	_trackNo = trackNo;
	gme_type_t fileType;
	handle_error(gme_identify_file(file.fileSystemRepresentation, &fileType));
	if (!fileType) {
		makeNSError(e, @"GameMusicEmu", 100, [NSString stringWithFormat:@"File %@ is of an unsupported type.", file]);
		return;
	}
	if (_emu) {
		if (strcmp(_emu->type()->system, fileType->system) != 0 || _emu->type()->track_count != fileType->track_count) {
			delete _emu;
			_emu = fileType->new_emu();
			handle_error(_emu->set_sample_rate(self.sampleRate));
		}
	}
	else {
		_emu = fileType->new_emu();
		handle_error(_emu->set_sample_rate(self.sampleRate));
	}
	if (!_emu) { handle_error("Out of memory"); }
	handle_error(_emu->load_file(file.fileSystemRepresentation));
	handle_error(_emu->track_info(_info, trackNo));
	handle_error(_emu->start_track(trackNo));
}

- (void)openFile:(NSURL *)file error:(NSError *__autoreleasing *)e{
	[self openFile:file atTrack:0 error:e];
}

- (void)playIntoBuffer:(short *)buffer size:(int)size {
	if (_emu && !_emu->track_ended()) {
		handle_error(_emu->play(size, buffer));
		_position += size / self.channels;
	}
}

- (void)setPosition:(long)newPosition {
	_position = newPosition;
	_emu->seek((int)(newPosition * 1000 / self.sampleRate));
}

- (void)setTrackNo:(int)trackNo {
	handle_error(_emu->start_track(trackNo));
	handle_error(_emu->track_info(_info, trackNo));
}

- (long)trackLength {
	return (long)_info->play_length * self.sampleRate / 1000;
}

- (bool)trackHasEnded {
	return _emu->track_ended();
}

- (void)dealloc {
	delete _emu;
}

@end
