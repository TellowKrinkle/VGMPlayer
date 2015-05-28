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

@property (nonatomic) int sampleRate;
@property (nonatomic, readonly) int channels;
@property (nonatomic, readonly) bool isPlaying;
@property (nonatomic) float volume;
@property (nonatomic) long position;
@property (nonatomic, readonly) long trackLength;

- (instancetype)initWithSampleRate:(int)sampleRate;

- (void)openFile:(NSURL *)file withTrackNo:(int)trackNo error:(NSError **)e;
- (void)openFile:(NSURL *)file error:(NSError **)e;
- (bool)play;
- (void)pause;
- (void)stop;
- (bool)isStopped;

+ (bool)canPlay:(NSURL *)file;

@end
