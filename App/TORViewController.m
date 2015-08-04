//
//  TORViewController.m
//  Tor
//
//  Created by Conrad Kramer on 5/13/14.
//
//

#import <Tor/Tor.h>

#import "TORViewController.h"

@interface TORViewController ()

@property (nonatomic, readonly) TORController *controller;

@end

@implementation TORViewController

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        NSString *dataDirectory = NSTemporaryDirectory();
        NSString *socksSocketPath = [dataDirectory stringByAppendingPathComponent:@"socks"];
        NSString *controlSocketPath = [dataDirectory stringByAppendingPathComponent:@"control"];
        TORThread *thread = [[TORThread alloc] initWithDataDirectory:dataDirectory socksSocketPath:socksSocketPath controlSocketPath:controlSocketPath arguments:@[@"--CookieAuthentication", @"1"]];
        
        [thread start];
        
        _controller = [[TORController alloc] initWithControlSocketPath:controlSocketPath];
        
        [_controller addObserverForCircuitEstablished:^(BOOL established) {
            NSLog(@"Circuit was %@.", (established ? @"connected" : @"disconnected"));
        }];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [_controller connect];
            
            NSData *cookie = [NSData dataWithContentsOfFile:[dataDirectory stringByAppendingPathComponent:@"control_auth_cookie"]];
            [_controller authenticateWithData:cookie completion:^(BOOL success, NSString *message) {
                NSLog(@"Authentication %@.", (success ? @"succeeded" : @"failed"));
            }];
        });
    }
    return self;
}

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
