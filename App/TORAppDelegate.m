//
//  TORAppDelegate.m
//  Tor
//
//  Created by Conrad Kramer on 5/1/14.
//  Copyright (c) 2014 Kramer Software Productions, LLC. All rights reserved.
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
