//
//  GameMusicDataSource.h
//  GameMusicEmu-ObjCTest
//
//  Created by Evan Tang on 3/25/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DEFAULT_SAMPLE_RATE 44100

@protocol GameMusicDataSource <NSObject>

@required

/**
 * The sample rate of the player
 */
@property (nonatomic, readonly) int sampleRate;

/**
 * The number of audio channels
 */
@property (nonatomic, readonly) int channels;

/**
 * The current playing position in samples
 */
@property (nonatomic) long position;

/**
 * Open an audio file for playing
 * @param file The file to be opened
 * @param error NSError in case something goes wrong
 */
- (void)openFile:(NSURL *)file error:(NSError **)err;

/**
 * Play the opened audio file to a buffer
 * @param buffer the buffer to play into
 * @param size the number of samples to play (total samples between all channels)
 */
- (void)playIntoBuffer:(short *)buffer size:(int)size;

/**
 * Check whether the player can play a given file
 * @param file The file to check
 * @return whether or not the player can play the file
 */
+ (bool)canPlay:(NSURL *)file;

@optional

/**
 * The length of the audio file in samples
 */
@property (nonatomic, readonly) long trackLength;

/**
 * The current track number, available only if the file type supports multiple tracks in one file
 */
@property (nonatomic) int trackNo;

/**
 * The metadata tags of the file
 */
@property (nonatomic, readonly) NSDictionary *tags;

/**
 * Initializer that also sets the sample rate, available only if the player supports multiple sample rates.
 */
- (instancetype)initWithSampleRate:(int)sampleRate;

/**
 * Open a file and advance to a certain track, available only if the file type supports multiple tracks in one file
 * @param file The file to be opened
 * @param trackNo The track to advance to
 * @param error NSError in case something goes wrong
 */
- (void)openFile:(NSURL *)file track:(int)trackNo error:(NSError **)e;

/**
 * Check whether or not a track has ended.  If the track loops, this will always be false.
 * @return whether or not the track has ended
 */
- (bool)trackHasEnded;

@end
