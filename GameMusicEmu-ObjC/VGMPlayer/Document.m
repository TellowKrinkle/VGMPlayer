//
//  Document.m
//  VGMPlayer
//
//  Created by Evan Tang on 3/26/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import "Document.h"
#import "TKRPlayer.h"

@interface Document () {
	TKRPlayer *_player;
	NSTimer *_playheadUpdateTimer;
}

@end

@implementation Document

- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
	if (_player) {
		self.leftTimeIndicator.stringValue = [self formatTime:_player.trackLength];
	}
	else {
		self.leftTimeIndicator.stringValue = @"0:00";
	}
	self.rightTimeIndicator.stringValue = @"0:00";
	[super windowControllerDidLoadNib:aController];
}

+ (BOOL)autosavesInPlace {
	return YES;
}

- (NSString *)windowNibName {
	// Override returning the nib file name of the document
	// If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
	return @"Document";
}


- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
	// Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
	// You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
	return [NSData dataWithContentsOfURL:self.file];
}

/*
	- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	// Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
	// You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
	// If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
	[NSException raise:@"UnimplementedMethod" format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
	return YES;
}
*/

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
	if (!_player) {
		_player = [[TKRPlayer alloc] init];
	}
	[_player openFile:url error:outError];
	if (!*outError) {
		if (self.leftTimeIndicator) {
			self.leftTimeIndicator.stringValue = [self formatTime:_player.trackLength];
		}
		self.file = url;
		return true;
	}
	return false;
}

- (BOOL)isEntireFileLoaded {
	return false;
}

- (void)close {
	[_player stop];
	[super close];
}

- (bool)isPlaying {
	return [_player isPlaying];
}

- (bool)play {
	[_playheadUpdateTimer invalidate];
	if (!_player.isPlaying) {
		if ([_player play]) {
			[self.playPauseButton setImage:[NSImage imageNamed:@"pause"]];
			_playheadUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updatePlayhead) userInfo:nil repeats:YES];
			return true;
		}
	}
	return false;
}

- (bool)pause {
	[_playheadUpdateTimer invalidate];
	[self.playPauseButton setImage:[NSImage imageNamed:@"play"]];
	if (_player.isPlaying) {
		[_player pause];
		return true;
	}
	return false;
}

- (NSString *)formatTime:(long)samples {
	int seconds = (int)(samples / _player.sampleRate);
	int hours = seconds / 3600;
	int minutes = (seconds % 3600) / 60;
	seconds %= 60;
	if (hours > 0) {
		return [NSString stringWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
	}
	else {
		return [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
	}
}

# pragma mark Actions

- (IBAction)playPause:(id)sender {
	if (_player.isPlaying) {
		[self pause];
	}
	else {
		[self play];
	}
}

- (IBAction)movedPlayhead:(id)sender {
	_player.position = self.playhead.doubleValue * _player.trackLength;
}

- (void)updatePlayhead {
	if (!_player.isPlaying) {
		[self pause];
	}
	if (_player.position < _player.trackLength) {
		self.playhead.doubleValue = (double)_player.position / _player.trackLength;
	}
	else {
		self.playhead.doubleValue = 1.0;
	}
	self.rightTimeIndicator.stringValue = [self formatTime:_player.position];
}

- (IBAction)changeVolume:(id)sender {
	_player.volume = [sender floatValue];
}

@end