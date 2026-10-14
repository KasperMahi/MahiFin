#import "MFVLCBridge.h"
#import <VLCKit/VLCKit.h>
#include <math.h>

@interface MFVLCBridge () <VLCMediaPlayerDelegate>
@property(nonatomic) VLCMediaPlayer *engine;
@property(nonatomic, readwrite) UIView *surface;
@property(nonatomic, readwrite) double duration;
@property(nonatomic) double lastSeconds;
@property(nonatomic) double pendingResume;
@property(nonatomic) BOOL userStopped;
@property(nonatomic) BOOL started;
@property(nonatomic) BOOL errored;
@end

@implementation MFVLCBridge
- (instancetype)init {
    self = [super init];
    if (self) {
        _surface = [[UIView alloc] init];
        _surface.backgroundColor = UIColor.blackColor;
        // libVLC can include source URLs in ordinary logs. Quiet mode is mandatory.
        _engine = [[VLCMediaPlayer alloc] initWithOptions:@[@"--quiet", @"--no-video-title-show"]];
        _engine.drawable = _surface;
        _engine.delegate = self;
    }
    return self;
}
- (void)openURL:(NSURL *)url resume:(double)seconds {
    self.userStopped = NO; self.started = NO; self.errored = NO;
    self.pendingResume = isfinite(seconds) ? MAX(0, seconds) : 0;
    self.engine.media = [[VLCMedia alloc] initWithURL:url];
    [self.engine play];
}
- (double)seconds { return MAX(self.lastSeconds, 0); }
- (BOOL)paused { return !self.engine.isPlaying; }
- (BOOL)seekable { return self.engine.isSeekable; }
- (void)play { [self.engine play]; }
- (void)pause { [self.engine pause]; }
- (void)seekSeconds:(double)seconds {
    if (!isfinite(seconds) || !self.seekable) return;
    double bounded = MAX(0, seconds);
    if (self.duration > 0) bounded = MIN(bounded, self.duration);
    self.engine.time = [[VLCTime alloc] initWithNumber:@(bounded * 1000)];
}
- (NSArray<NSDictionary *> *)tracks:(NSArray<VLCMediaPlayerTrack *> *)tracks {
    NSMutableArray *result = [NSMutableArray array];
    [tracks enumerateObjectsUsingBlock:^(VLCMediaPlayerTrack *track, NSUInteger index, BOOL *stop) {
        [result addObject:@{@"index": @(index), @"name": track.trackName ?: @"", @"selected": @(track.isSelected)}];
    }];
    return result;
}
- (NSArray<NSDictionary *> *)audioTracks { return [self tracks:self.engine.audioTracks]; }
- (NSArray<NSDictionary *> *)subtitleTracks { return [self tracks:self.engine.textTracks]; }
- (void)selectAudio:(NSInteger)index {
    if (index >= 0 && index < self.engine.audioTracks.count) self.engine.audioTracks[index].selectedExclusively = YES;
}
- (void)selectSubtitle:(NSInteger)index {
    if (index < 0) [self.engine deselectAllTextTracks];
    else if (index < self.engine.textTracks.count) self.engine.textTracks[index].selectedExclusively = YES;
}
- (void)emit:(NSString *)event {
    if (self.onEvent && !self.userStopped) self.onEvent(event, self.seconds, self.duration, self.paused);
}
- (void)mediaPlayerLengthChanged:(int64_t)length {
    dispatch_async(dispatch_get_main_queue(), ^{ self.duration = MAX(0, (double)length / 1000); });
}
- (void)mediaPlayerTimeChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.userStopped) return;
        self.lastSeconds = self.engine.time.value.doubleValue / 1000;
        if (self.pendingResume > 0 && self.seekable) {
            double resume = self.pendingResume; self.pendingResume = 0;
            [self seekSeconds:resume];
        }
        [self emit:@"time"];
    });
}
- (void)mediaPlayerStateChanged:(VLCMediaPlayerState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.userStopped) return;
        if (state == VLCMediaPlayerStatePlaying) { self.started = YES; [self emit:@"playing"]; }
        else if (state == VLCMediaPlayerStatePaused) [self emit:@"paused"];
        else if (state == VLCMediaPlayerStateError) { self.errored = YES; [self emit:@"error"]; }
        else if (state == VLCMediaPlayerStateStopped && self.started && !self.errored) {
            // VLCKit 4 exposes Stopped rather than a distinct EOF delegate. Unknown/early stops never mark watched.
            if (self.duration > 0 && self.lastSeconds >= MAX(0, self.duration - 1.5)) [self emit:@"ended"];
            else [self emit:@"error"];
        }
    });
}
- (void)stop {
    self.userStopped = YES; self.onEvent = nil; self.engine.delegate = nil;
    [self.engine stop]; self.engine.drawable = nil;
}
@end
