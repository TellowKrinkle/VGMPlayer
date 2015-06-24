//
//  VGMPlayer.m
//  GameMusicEmu-ObjCTest
//
//  Created by Evan Tang on 3/10/15.
//  Copyright (c) 2015 TellowKrinkle. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import "TKRPlayer.h"
#import "GameMusicDataSource.h"
#import "GameMusicEmu.h"
#import "LazyUSF2.h"
#import "Vio2SF.h"
#import "VGMStream.h"

#define NUM_PLAYBACK_BUFFERS 3
#define FORMAT_BYTES_PER_CHANNEL 2
//#define FORMAT_CHANNELS_PER_FRAME 2
#define FORMAT_FRAMES_PER_PACKET 1
#define BUFFER_SIZE_SECONDS 0.1

#pragma mark User Data Struct
typedef struct MyPlayer {
	AudioStreamBasicDescription format;
//	AudioUnit	outputUnit;
//	AUGraph		graph;
	short *		extraBuffer;
	int			extraBufferSize;
	void		**emu;
	Boolean		isStopped;
	UInt32		bufferSize;
	int			channels;
} MyPlayer;

#pragma mark C Helper Functions
static void CheckError(OSStatus error, const char *operation) {
	if (error == noErr) return;
	char errorString[20];
	// See if it appears to be a 4-char code
	*(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
	if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
		errorString[0] = errorString[5] = '\'';
		errorString[6] = '\0';
	}
	else {
		// If not, format it as an integer
		sprintf(errorString, "%d", (int)error);
	}
	fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
}

static void makeNSError(NSError **error, NSString *domain, int code, NSString *localizedDescription) {
	if (error) {
		NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
		[errorDetail setValue:localizedDescription forKey:NSLocalizedDescriptionKey];
		*error = [NSError errorWithDomain:domain code:code userInfo:errorDetail];
	}
}

// Code for using Audio units, not currently working
/*
OSStatus VGMRenderProc(void *inUserData, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

void setupAUGraph(MyPlayer *player) {
	CheckError(NewAUGraph(&player->graph), "NewAUGraph Failed");
	
	// Make a description that matches output device (speakers)
	AudioComponentDescription outputcd = {0};
	outputcd.componentType = kAudioUnitType_Output;
	outputcd.componentSubType = kAudioUnitSubType_DefaultOutput;
	outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
	// Add a node with the above description to the graph
	AUNode outputNode;
	CheckError(AUGraphAddNode(player->graph, &outputcd, &outputNode), "AUGraphAddNode[kAudioUnitSubType_DefaultOutput] failed");
	
	// Open the graph
	CheckError(AUGraphOpen(player->graph), "AUGraphOpen failed");
	
	// Get the output audio unit
	CheckError(AUGraphNodeInfo(player->graph, outputNode, NULL, &player->outputUnit), "AUGraphNodeInfo failed");
	
	// Initialize the AUGraph
	CheckError(AUGraphInitialize(player->graph), "AUGraphInitialize failed");
	
	// Setup the render callback
	AURenderCallbackStruct input;
	input.inputProc = VGMRenderProc;
	input.inputProcRefCon = player;
	CheckError(AudioUnitSetProperty(player->outputUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &input, sizeof(input)), "AudioUnitSetProperty failed");
}
*/

#pragma mark Playback Callback Function
/*
OSStatus VGMRenderProc(void *inUserData, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
	MyPlayer *player = (MyPlayer *)inUserData;
	id<GameMusicDataSource> emu = (__bridge id<GameMusicDataSource>)*(player->emu);
	if (player->isStopped) {
		for (int i = 0; i < ioData->mNumberBuffers; i++) {
			memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
		}
		return noErr;
	}
	if ([emu respondsToSelector:@selector(trackHasEnded)] && [emu trackHasEnded]) {
		player->isStopped = true;
		for (int i = 0; i < ioData->mNumberBuffers; i++) {
			memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
		}
		return noErr;
	}
	for (int i = 0; i < ioData->mNumberBuffers; i++) {
		int numSamples = ioData->mBuffers[i].mDataByteSize / FORMAT_BYTES_PER_CHANNEL;
		[emu play:numSamples withBuffer:ioData->mBuffers[i].mData];
	}
//	printf("Buffers: %d\n", ioData->mNumberBuffers);
	return noErr;
}
*/

void AQCallbackFunction(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inCompleteAQBuffer) {
	MyPlayer *player = (MyPlayer *)inUserData;
	id<GameMusicDataSource> emu = (__bridge id<GameMusicDataSource>)*(player->emu);
	if (player->isStopped) return;
	if ([emu respondsToSelector:@selector(trackHasEnded)] && [emu trackHasEnded]) {
		player->isStopped = true;
		CheckError(AudioQueueStop(inAQ, false), "AudioQueueStop failed");
		return;
	}
	int numSamples = player->bufferSize / FORMAT_BYTES_PER_CHANNEL;
	[emu play:numSamples withBuffer:inCompleteAQBuffer->mAudioData];
	/*
	if (player->channels == FORMAT_CHANNELS_PER_FRAME) {
		int numSamples = player->bufferSize / FORMAT_BYTES_PER_CHANNEL;
		[emu play:numSamples withBuffer:inCompleteAQBuffer->mAudioData];
	}
	else {
		int numChannels = player->channels;
		if (player->extraBufferSize != player->bufferSize / FORMAT_CHANNELS_PER_FRAME * numChannels) {
			player->extraBufferSize = player->bufferSize / FORMAT_CHANNELS_PER_FRAME * numChannels;
			free(player->extraBuffer);
			player->extraBuffer = malloc(player->extraBufferSize);
		}
		int numSamples = player->extraBufferSize / FORMAT_BYTES_PER_CHANNEL;
		[emu play:numSamples withBuffer:player->extraBuffer];
		short *outBuffer = (short *)inCompleteAQBuffer->mAudioData;
		short *extraBuffer = player->extraBuffer;
		if (numChannels % 2 == 0) {
			int i = 0;
			int obufslot = 0;
			int divisor = numChannels / 2;
			int nextI, leftsum, rightsum;
			while (i < numSamples) {
				nextI = i + numChannels;
				leftsum = 0;
				rightsum = 0;
				for (int j = i; j < nextI; j++) {
					leftsum += extraBuffer[j];
					j++;
					rightsum += extraBuffer[j];
				}
				outBuffer[obufslot] = leftsum / divisor;
				obufslot++;
				outBuffer[obufslot] = rightsum / divisor;
				obufslot++;
				i = nextI;
			}
		}
		else {
			int i = 0;
			int obufslot = 0;
			int nextI, sum, average;
			while (i < numSamples) {
				nextI = i + numChannels;
				sum = 0;
				for (int j = i; j < nextI; j++) {
					sum += extraBuffer[j];
				}
				average = sum / numChannels;
				outBuffer[obufslot] = average;
				obufslot++;
				outBuffer[obufslot] = average;
				obufslot++;
				i = nextI;
			}
		}
	}
	*/
	inCompleteAQBuffer->mAudioDataByteSize = player->bufferSize;
	AudioQueueEnqueueBuffer(inAQ, inCompleteAQBuffer, 0, NULL);
}

#pragma mark - Main Class
@interface TKRPlayer() {
	id<GameMusicDataSource> _emu;
	MyPlayer _player;
	AudioQueueRef _queue;
	AudioQueueBufferRef _buffers[NUM_PLAYBACK_BUFFERS];
	bool _isPlaying;
}

@end

@implementation TKRPlayer

- (instancetype)initWithSampleRate:(int)sampleRate {
	self = [super init];
	
	if (self) {
		_sampleRate = sampleRate;
		_player.channels = 2;
		_player.isStopped = true;
		_isPlaying = false;
	}
	return self;
}

- (instancetype)init {
	return [self initWithSampleRate:44100];
}

- (void)openFile:(NSURL *)file withTrackNo:(int)trackNo error:(NSError **)e {
	[self stop];
	if (!_emu || ![[_emu class] canPlay:file]) {
		if ([GameMusicEmu canPlay:file]) {
			_emu = [[GameMusicEmu alloc] initWithSampleRate:self.sampleRate];
		}
		else if ([LazyUSF2 canPlay:file]) {
			_emu = [[LazyUSF2 alloc] initWithSampleRate:self.sampleRate];
		}
		else if ([Vio2SF canPlay:file]) {
			_emu = [[Vio2SF alloc] init];
		}
		else if ([VGMStream canPlay:file]) {
			_emu = [[VGMStream alloc] init];
		}
		else {
			makeNSError(e, @"GameMusicEmu", 100, [NSString stringWithFormat:@"File %@ is of an unsupported type.", file]);
			return;
		}
	}
	if ([_emu respondsToSelector:@selector(openFile:atTrack:error:)]) {
		[_emu openFile:file atTrack:trackNo error:e];
	}
	else {
		[_emu openFile:file error:e];
	}
	if (![_emu respondsToSelector:@selector(initWithSampleRate:)]) {
		if (self.sampleRate != _emu.sampleRate) {
			_sampleRate = _emu.sampleRate;
		}
	}
	if (self.channels != _emu.channels) {
		_player.channels = _emu.channels;
	}
	_player.emu = (void *)&_emu;
	_player.format = [self GetAudioStreamBasicDescription];
	//setupAUGraph(&_player);
	CheckError(AudioQueueNewOutput(&_player.format, AQCallbackFunction, &_player, NULL, NULL, 0, &_queue), "AudioQueueNewOutput failed");
}

- (void)openFile:(NSURL *)file error:(NSError **)e {
	[self openFile:file withTrackNo:0 error:e];
}

- (void)fillBuffers {
	if (!_buffers[0]) {
		UInt32 bufferByteSize = BUFFER_SIZE_SECONDS * FORMAT_BYTES_PER_CHANNEL * self.channels * self.sampleRate;
		_player.bufferSize = bufferByteSize;
		for (int i = 0; i < NUM_PLAYBACK_BUFFERS; ++i) {
			CheckError(AudioQueueAllocateBuffer(_queue, bufferByteSize, &_buffers[i]), "AudioQueueAllocateBuffer failed");
		}
	}
	for (int i = 0; i < NUM_PLAYBACK_BUFFERS; ++i) {
		AQCallbackFunction(&_player, _queue, _buffers[i]);
		if (_player.isStopped) {
			break;
		}
	}
}

- (bool)play {
	if (_emu != nil) {
		_isPlaying = true;
		if (_player.isStopped) {
			_player.isStopped = false;
			[self fillBuffers];
		}
//		AUGraphStart(_player.graph);
		CheckError(AudioQueueStart(_queue, NULL), "AudioStartQueue failed");
		return true;
	}
	return false;
}

- (void)pause {
	_isPlaying = false;
	if (!_player.isStopped) {
//		AUGraphStop(_player.graph);
		CheckError(AudioQueuePause(_queue), "AudioQueuePause failed");
	}
}

- (void)stop {
	_isPlaying = false;
	if (!_player.isStopped) {
//		AUGraphStop(_player.graph);
		_player.isStopped = true;
		CheckError(AudioQueueStop(_queue, TRUE), "AudioQueueStop failed");
	}
}

- (void)close {
	[self stop];
	_emu = nil;
}

- (bool)isStopped {
	return _player.isStopped;
}

+ (bool)canPlay:(NSURL *)file {
	return [GameMusicEmu canPlay:file] || [LazyUSF2 canPlay:file] || [Vio2SF canPlay:file];
}

- (void)dealloc {
	AudioQueueDispose(_queue, true);
}

#pragma mark getters and setters

- (bool)isPlaying {
	if (_isPlaying && _player.isStopped) {
		_isPlaying = false;
	}
	return _isPlaying;
}

- (void)setSampleRate:(int)sampleRate {
	_sampleRate = sampleRate;
	[self close];
}

- (int)channels {
	return _player.channels;
}

- (void)setChannels:(int)channels {
	_player.channels = channels;
	[self close];
}

- (void)setVolume:(float)volume {
	_volume = volume;
	AudioQueueSetParameter(_queue, kAudioQueueParam_Volume, volume);
}

- (long)position {
	return [_emu position];
}

- (void)setPosition:(long)position {
	if (_isPlaying) {
		[self stop];
		[_emu setPosition:position];
		[self play];
	}
	else {
		[self stop];
		[_emu setPosition:position];
	}
}

- (long)trackLength {
	if ([_emu respondsToSelector:@selector(trackLength)]) {
		return _emu.trackLength;
	}
	else {
		return 150 * self.sampleRate;
	}
}

#pragma mark Obj-C Helper Functions
- (AudioStreamBasicDescription)GetAudioStreamBasicDescription {
	AudioStreamBasicDescription format;
	memset(&format, 0, sizeof(format));
	format.mSampleRate = self.sampleRate;
	format.mFormatID = kAudioFormatLinearPCM;
	format.mFormatFlags = kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	format.mBitsPerChannel = 8 * FORMAT_BYTES_PER_CHANNEL;
	format.mChannelsPerFrame = self.channels;
//	format.mChannelsPerFrame = FORMAT_CHANNELS_PER_FRAME;
	format.mFramesPerPacket = FORMAT_FRAMES_PER_PACKET;
	format.mBytesPerFrame = FORMAT_BYTES_PER_CHANNEL * self.channels;
	format.mBytesPerPacket = FORMAT_BYTES_PER_CHANNEL * self.channels * FORMAT_FRAMES_PER_PACKET;
	return format;
}

@end