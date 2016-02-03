//
//  AOPSF.h
//  GameMusicEmu-ObjC
//
//  Created by Evan Tang on 9/25/15.
//  Copyright © 2015 TellowKrinkle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GameMusicDataSource.h"

@interface AOPSF : NSObject <GameMusicDataSource>

@property (nonatomic, readonly) int sampleRate;
@property (nonatomic, readonly) int channels;
@property (nonatomic) long position;
@property (nonatomic, readonly) int numTracks;
@property (nonatomic, readonly) long trackLength;
@property (nonatomic, readonly) NSDictionary *tags;

@end
