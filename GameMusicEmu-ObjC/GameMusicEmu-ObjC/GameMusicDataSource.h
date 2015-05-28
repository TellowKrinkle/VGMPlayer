//
//  GameMusicDataSource.h
//  GameMusicEmu-ObjCTest
//
//  Created by Evan Tang on 3/25/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol GameMusicDataSource <NSObject>
@required
@property (nonatomic, readonly) int sampleRate;
@property (nonatomic, readonly) int channels;
@property (nonatomic) long position; // Position in samples

- (void)openFile:(NSURL *)file error:(NSError **)e;
- (void)play:(int)size withBuffer:(short *)buffer; // Size is in total samples between all channels
+ (bool)canPlay:(NSURL *)file;

@optional
@property (nonatomic, readonly) long trackLength; // Track length in samples
@property (nonatomic) int trackNo;
- (instancetype)initWithSampleRate:(int)sampleRate;
- (long)tell;
- (void)openFile:(NSURL *)file atTrack:(int)trackNo error:(NSError **)e;
- (bool)trackHasEnded;

@end
