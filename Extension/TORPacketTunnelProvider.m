//
//  TORPacketTunnelProvider.m
//  Tor
//
//  Created by Conrad Kramer on 7/19/15.
//
//

#import <Tor/Tor.h>

#import "TORPacketTunnelProvider.h"
#import "TORSharedConstants.h"

@implementation TORPacketTunnelProvider

- (void)startTunnelWithOptions:(nullable NSDictionary<NSString *,NSObject *> *)options completionHandler:(void (^)(NSError * __nullable error))completionHandler {
    NSString *dataDirectory = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:TORAppGroupIdentifier] path];
    NSString *socksSocketPath = [dataDirectory stringByAppendingPathComponent:@"socks"];
    NSString *controlSocketPath = [dataDirectory stringByAppendingPathComponent:@"control"];
    TORThread *thread = [[TORThread alloc] initWithDataDirectory:dataDirectory socksSocketPath:socksSocketPath controlSocketPath:controlSocketPath arguments:@[@"--CookieAuthentication", @"1"]];
    
    [thread start];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        completionHandler(nil);
        
        [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> *packets, NSArray<NSNumber *> *protocols) {
            
        }];
    });
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    completionHandler();
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    
}

- (void)wake {
    
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(nullable void (^)(NSData * __nullable responseData))completionHandler {
    
}

@end
