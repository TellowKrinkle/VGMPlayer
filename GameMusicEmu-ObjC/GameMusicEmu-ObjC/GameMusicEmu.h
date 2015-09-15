//
//  MusicEmuWrapper.h
//  test2
//
//  Created by Evan Tang on 3/9/15.
//
//

#import <Foundation/Foundation.h>
#import "GameMusicDataSource.h"

@interface GameMusicEmu : NSObject <GameMusicDataSource>

@property (nonatomic, readonly) int sampleRate;
@property (nonatomic) long position;
@property (nonatomic) int trackNo;
@property (nonatomic, readonly) long trackLength;

- (instancetype)initWithSampleRate:(int)sampleRate NS_DESIGNATED_INITIALIZER;
- (void)openFile:(NSURL *)file track:(int)trackNo error:(NSError **)e;
- (bool)trackHasEnded;

@end
