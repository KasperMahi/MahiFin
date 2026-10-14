#import "MFCastBridge.h"
#import <GoogleCast/GoogleCast.h>
#include <math.h>

@interface MFCastBridge () <GCKSessionManagerListener, GCKRemoteMediaClientListener, GCKLoggerDelegate>
@property(nonatomic, copy) NSString *receiver;
@end
@implementation MFCastBridge
- (BOOL)configureReceiver:(NSString *)identifier {
    if (self.receiver) {
        if (![self.receiver isEqualToString:identifier]) return NO;
        [[GCKCastContext sharedInstance].discoveryManager startDiscovery]; return YES;
    }
    [GCKLogger sharedInstance].delegate = self;
    GCKDiscoveryCriteria *criteria = [[GCKDiscoveryCriteria alloc] initWithApplicationID:identifier];
    GCKCastOptions *options = [[GCKCastOptions alloc] initWithDiscoveryCriteria:criteria];
    options.disableDiscoveryAutostart = YES;
    options.startDiscoveryAfterFirstTapOnCastButton = YES;
    [GCKCastContext setSharedInstanceWithOptions:options];
    [[GCKCastContext sharedInstance].sessionManager addListener:self];
    [[GCKCastContext sharedInstance].discoveryManager startDiscovery]; // Called only by explicit Find action.
    self.receiver = identifier;
    GCKCastSession *session = [GCKCastContext sharedInstance].sessionManager.currentCastSession;
    if (session) [self attach:session];
    return YES;
}
- (UIView *)makeButton { return [[GCKUICastButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)]; }
- (GCKRemoteMediaClient *)client { return [GCKCastContext sharedInstance].sessionManager.currentCastSession.remoteMediaClient; }
- (NSString *)mediaIdentity {
    if (!self.receiver) return @"";
    GCKCastSession *session = [GCKCastContext sharedInstance].sessionManager.currentCastSession;
    GCKMediaStatus *status = session.remoteMediaClient.mediaStatus;
    if (!session || !status) return @"";
    return [NSString stringWithFormat:@"%@:%lld", session.sessionID, (long long)status.mediaSessionID];
}
- (void)attach:(GCKCastSession *)session {
    [session.remoteMediaClient addListener:self];
    [self update:session.remoteMediaClient.mediaStatus];
}
- (void)update:(GCKMediaStatus *)status {
    BOOL paused = status.playerState != GCKMediaPlayerStatePlaying;
    if (self.onStatus) self.onStatus(@"receiver", status ? status.streamPosition : 0, paused, status != nil);
}
- (void)pause { [[self client] pause]; }
- (void)play { [[self client] play]; }
- (void)seekSeconds:(double)seconds {
    if (!isfinite(seconds) || seconds < 0) return;
    GCKMediaSeekOptions *options = [[GCKMediaSeekOptions alloc] init]; options.interval = seconds;
    [[self client] seekWithOptions:options];
}
- (void)disconnect {
    if (!self.receiver) return;
    [[GCKCastContext sharedInstance].sessionManager endSessionAndStopCasting:YES];
    [[GCKCastContext sharedInstance].discoveryManager stopDiscovery];
    if (self.onStatus) self.onStatus(@"disconnected", 0, YES, NO);
}
- (void)sessionManager:(GCKSessionManager *)manager didStartCastSession:(GCKCastSession *)session { [self attach:session]; }
- (void)sessionManager:(GCKSessionManager *)manager didResumeCastSession:(GCKCastSession *)session { [self attach:session]; }
- (void)sessionManager:(GCKSessionManager *)manager didEndCastSession:(GCKCastSession *)session withError:(NSError *)error {
    if (self.onStatus) self.onStatus(@"disconnected", 0, YES, NO);
}
- (void)sessionManager:(GCKSessionManager *)manager didFailToStartCastSession:(GCKCastSession *)session withError:(NSError *)error {
    if (self.onStatus) self.onStatus(@"failed", 0, YES, NO);
}
- (void)sessionManager:(GCKSessionManager *)manager didSuspendCastSession:(GCKCastSession *)session withReason:(GCKConnectionSuspendReason)reason {
    if (self.onStatus) self.onStatus(@"disconnected", 0, YES, NO);
}
- (void)remoteMediaClient:(GCKRemoteMediaClient *)client didUpdateMediaStatus:(GCKMediaStatus *)status { [self update:status]; }
// Raw SDK log strings may contain media URLs, receiver names or authorization context. Drop them entirely.
- (void)logMessage:(NSString *)message atLevel:(GCKLoggerLevel)level fromFunction:(NSString *)function location:(NSString *)location {}
- (void)logMessage:(NSString *)message fromFunction:(NSString *)function {}
@end
