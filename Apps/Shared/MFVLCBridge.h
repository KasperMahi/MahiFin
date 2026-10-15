#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
/// Original adapter for the pinned VLCKit 4 API. No framework URLs/logs are exported.
@interface MFVLCBridge : NSObject
@property(nonatomic, readonly) UIView *surface;
@property(nonatomic, copy, nullable) void (^onEvent)(NSString *event, double seconds, double duration, BOOL paused);
@property(nonatomic, readonly) double seconds;
@property(nonatomic, readonly) double duration;
@property(nonatomic, readonly) BOOL paused;
@property(nonatomic, readonly) BOOL seekable;
@property(nonatomic, readonly) NSArray<NSDictionary *> *audioTracks;
@property(nonatomic, readonly) NSArray<NSDictionary *> *subtitleTracks;
- (void)openURL:(NSURL *)url resume:(double)seconds NS_SWIFT_NAME(open(url:resume:));
- (void)play;
- (void)pause;
- (void)seekSeconds:(double)seconds NS_SWIFT_NAME(seek(seconds:));
- (void)selectAudio:(NSInteger)index NS_SWIFT_NAME(selectAudio(index:));
- (void)selectSubtitle:(NSInteger)index NS_SWIFT_NAME(selectSubtitle(index:));
- (void)stop;
@end
NS_ASSUME_NONNULL_END
