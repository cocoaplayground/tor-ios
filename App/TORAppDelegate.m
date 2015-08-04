//
//  TORAppDelegate.m
//  Tor
//
//  Created by Conrad Kramer on 5/1/14.
//
//

#import "TORAppDelegate.h"
#import "TORViewController.h"

@implementation TORAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[TORViewController alloc] init];
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
