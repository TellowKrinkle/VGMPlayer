//
//  VGMPlayer.h
//  GameMusicEmu-ObjCTest
//
//  Created by Evan Tang on 3/10/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GameMusicEmu.h"

@interface TKRPlayer : NSObject

/// The current playback sample rate, changing this will stop playback and close the current file
@property (nonatomic) int sampleRate;

/// The current number of channels
@property (nonatomic, readonly) int channels;

/// Whether or not the player is currently playing audio to the speakers
@property (nonatomic, readonly) bool isPlaying;

/// Whether or not the player is stopped (rather than just paused)
@property (nonatomic, readonly) bool isStopped;

/// The current playback volume
@property (nonatomic) float volume;

/// The current playback speed
@property (nonatomic) float speed;

/// The current playback position in samples
@property (nonatomic) long position;

/// The length of the track in samples.  Will be 150 seconds if the audio file doesn't support track length.
@property (nonatomic, readonly) long trackLength;

/// Number of tracks in file.  If trackNo is not supported, this should be 1.
@property (nonatomic, readonly) int numTracks;

/// Current playing track.  If trackNo is not supported, this should be 0.
@property (nonatomic) int currentTrack;

/**
 * Initialize with the default sample rate of 44.1 khz
 */
- (instancetype)init;

/**
 * Initialize with a starting sample rate
 * @param sampleRate starting sample rate
 */
- (instancetype)initWithSampleRate:(int)sampleRate;

/**
 * Open an audio file and advance to the specified track, if the file type doesn't have multiple tracks, the track will be ignored.
 * @param file The file to be opened
 * @param trackNo The track to advance to
 * @param error NSError in case something goes wrong
 */
- (void)openFile:(NSURL *)file trackNo:(int)trackNo error:(NSError **)e;

/**
 * Open an audio file for playing
 * @param file The file to be opened
 * @param error NSError in case something goes wrong
 */
- (void)openFile:(NSURL *)file error:(NSError **)e;

/**
 * Start playing audio
 * @return whether or not it started playing successfully
 */
- (bool)play;

/**
 * Pause audio (position is kept)
 */
- (void)pause;

/**
 * Stop playing audio (position is set back to beginning)
 */
- (void)stop;

/**
 * Check whether or not a file is playable
 * @param file the file to check
 * @return whether or not the file is playable
 */
+ (bool)canPlay:(NSURL *)file;

@end