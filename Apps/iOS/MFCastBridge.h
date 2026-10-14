#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface MFCastBridge : NSObject
@property(nonatomic, copy, nullable) void (^onStatus)(NSString *state, double seconds, BOOL paused, BOOL hasMedia);
@property(nonatomic, readonly) NSString *mediaIdentity;
- (BOOL)configureReceiver:(NSString *)identifier NS_SWIFT_NAME(configure(receiver:));
- (UIView *)makeButton;
- (void)pause;
- (void)play;
- (void)seekSeconds:(double)seconds NS_SWIFT_NAME(seek(seconds:));
- (void)disconnect;
@end
NS_ASSUME_NONNULL_END
