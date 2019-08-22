 //
//  Document.m
//  VGMPlayer
//
//  Created by Evan Tang on 3/26/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import "Document.h"
#import "../../TKRPlayer/TKRPlayer/TKRPlayer.h"

static NSComparisonResult urlCompare(NSURL * _Nonnull url1, NSURL * _Nonnull url2, void *context) {
	NSString *a = [url1 lastPathComponent];
	NSString *b = [url2 lastPathComponent];
	return [a compare:b];
}

static inline NSURL * getPreviousFile(NSURL *file) {
	NSURL *directory = [file URLByDeletingLastPathComponent];
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directory includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
	files = [files sortedArrayUsingFunction:urlCompare context:NULL];
	int fileID = (int)[files indexOfObject:[file filePathURL]];
	do {
		fileID--;
	} while (fileID >= 0 && ![TKRPlayer canPlay:[files objectAtIndex:fileID]]);
	return fileID < 0 ? nil : [files objectAtIndex:fileID];
}

static inline NSURL * getNextFile(NSURL *file) {
	NSURL *directory = [file URLByDeletingLastPathComponent];
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directory includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
	files = [files sortedArrayUsingFunction:urlCompare context:NULL];
	int fileID = (int)[files indexOfObject:[file filePathURL]];
	do {
		fileID++;
	} while (fileID < files.count && ![TKRPlayer canPlay:[files objectAtIndex:fileID]]);
	return fileID >= files.count ? nil : [files objectAtIndex:fileID];
}

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
		self.rightTimeIndicator.stringValue = [self formatTime:_player.trackLength];
	}
	else {
		self.rightTimeIndicator.stringValue = @"0:00";
	}
	self.leftTimeIndicator.stringValue = @"0:00";
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vgmStartedPlaying:) name:@"VGMStartedPlaying" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vgmPaused:) name:@"VGMPaused" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vgmStoppedPlaying:) name:@"VGMStoppedPlaying" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vgmStartedSeeking:) name:@"VGMStartedSeeking" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vgmFinishedSeeking:) name:@"VGMFinishedSeeking" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkPlayheadUpdateTimer) name:@"NSWindowDidChangeOcclusionStateNotification" object:nil];
	[self updatePrevNext];
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
	return [NSData dataWithContentsOfURL:self.fileURL];
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
	bool oldPlayer = false;
	bool wasPlaying = false;
	if (!_player) {
		_player = [[TKRPlayer alloc] init];
	}
	else {
		oldPlayer = true;
		if (_player.isPlaying) {
			wasPlaying = true;
		}
		[_player stop];
	}
	[_player openFile:url error:outError];
	if (!outError || !*outError) {
		if (self.rightTimeIndicator) {
			self.rightTimeIndicator.stringValue = [self formatTime:_player.trackLength];
		}
		self.fileURL = url;
		
		if (oldPlayer) {
			[self updatePlayhead];
			if (wasPlaying) {
				[_player play];
			}
		}
		
		return true;
	}
	
	return false;
}

- (void)setFileURL:(NSURL *)file {
	_prevFile = getPreviousFile(file);
	_nextFile = getNextFile(file);
	[super setFileURL:file];
	[self updatePrevNext];
}

- (void)updatePrevNext {
	if ((_player.numTracks == 1 && _prevFile) || (_player.numTracks > 1 && _player.currentTrack > 0)) {
		self.prevButton.enabled = true;
	}
	else {
		self.prevButton.enabled = false;
	}
	if ((_player.numTracks == 1 && _nextFile) || (_player.numTracks > 1 && _player.currentTrack < _player.numTracks - 1)) {
		self.nextButton.enabled = true;
	}
	else {
		self.nextButton.enabled = false;
	}
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
	if (!_player.isPlaying) {
		return [_player play];
	}
	return false;
}

- (bool)pause {
	if (_player.isPlaying) {
		[_player pause];
		return true;
	}
	return false;
}

- (void)setSpeed:(float)speed {
	_player.speed = speed;
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

# pragma mark Notifications

- (void)vgmStartedPlaying:(NSNotification *)notification {
	if (notification.object == _player) {
		[_playheadUpdateTimer invalidate];
		[self.playPauseButton setImage:[NSImage imageNamed:@"pause"]];
		[self checkPlayheadUpdateTimer];
	}
}

- (void)vgmPaused:(NSNotification *)notification {
	if (notification.object == _player) {
		[self.playPauseButton setImage:[NSImage imageNamed:@"play"]];
		[self updatePlayhead];
		[self checkPlayheadUpdateTimer];
	}
}

- (void)vgmStoppedPlaying:(NSNotification *)notification {
	// Should act the same as if we paused
	[self vgmPaused:notification];
}

- (void)vgmStartedSeeking:(NSNotification *)notification {
	if (notification.object == _player) {
		self.playPauseButton.enabled = false;
	}
}

- (void)vgmFinishedSeeking:(NSNotification *)notification {
	if (notification.object == _player) {
		self.playPauseButton.enabled = true;
		[self updatePlayhead];
	}
}

- (void)checkPlayheadUpdateTimer {
	[_playheadUpdateTimer invalidate];
	if ([self isPlaying] && [self.playerWindow
							 occlusionState] & NSWindowOcclusionStateVisible) {
		[self updatePlayhead];
		_playheadUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(updatePlayhead) userInfo:nil repeats:YES];
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

- (IBAction)goPrevious:(id)sender {
	if (_player.numTracks > 1 && _player.currentTrack > 0) {
		_player.currentTrack--;
		if (self.rightTimeIndicator) {
			self.rightTimeIndicator.stringValue = [self formatTime:_player.trackLength];
		}
		[self updatePrevNext];
	}
	else {
		[self readFromURL:getPreviousFile(self.fileURL) ofType:@"VGM File" error:nil];
	}
}

- (IBAction)goNext:(id)sender {
	if (_player.numTracks > 1 && _player.currentTrack < _player.numTracks - 1) {
		_player.currentTrack++;
		if (self.rightTimeIndicator) {
			self.rightTimeIndicator.stringValue = [self formatTime:_player.trackLength];
		}
		[self updatePrevNext];
	}
	else {
		[self readFromURL:getNextFile(self.fileURL) ofType:@"VGM File" error:nil];
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
	self.leftTimeIndicator.stringValue = [self formatTime:_player.position];
}

- (IBAction)changeVolume:(id)sender {
	_player.volume = [sender floatValue];
}

@end
