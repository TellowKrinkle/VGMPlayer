//
//  Vio2SF.h
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 3/25/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GameMusicDataSource.h"

@interface Vio2SF : NSObject <GameMusicDataSource>

@property (nonatomic, readonly) int sampleRate;
@property (nonatomic, readonly) int channels;
@property (nonatomic) long position;
@property (nonatomic, readonly) int numTracks;
@property (nonatomic, readonly) long trackLength;
@property (nonatomic, readonly) NSDictionary *tags;

@end
