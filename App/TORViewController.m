//
//  TORViewController.m
//  Tor
//
//  Created by Conrad Kramer on 5/13/14.
//  Copyright (c) 2014 Kramer Software Productions, LLC. All rights reserved.
//

#import "TORViewController.h"

@implementation TORViewController

- (void)loadView {
    [super loadView];

    self.view.backgroundColor = [UIColor whiteColor];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:button];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(button);
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[button]|" options:0 metrics:nil views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[button]|" options:0 metrics:nil views:views]];
}

- (void)toggle {
    
}

@end
