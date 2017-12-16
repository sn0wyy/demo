//
//  SaigonViewController.m
//  Saigon
//
//  Created by Abraham Masri on 11/29/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


#include "sploit.h"
#include "Utilities.h"
#include "ziva_main.h"
#include "unjail.h"
#include "kppless.h"

@interface SaigonViewController : UIViewController
@property (retain, nonatomic) IBOutlet UIButton *helpButton;

@property (retain, nonatomic) IBOutlet UIButton *jailbreakButton;
@property (retain, nonatomic) IBOutlet NSLayoutConstraint *jailbreakButtonWidth;

@property (retain, nonatomic) IBOutlet UILabel *warningLabel;

@property (retain, nonatomic) IBOutlet UILabel *deviceInfoLabel;

@property (retain, nonatomic) IBOutlet UIProgressView *progressView;

@property (assign) mach_port_t mach_port;
@end

@interface SaigonViewController ()

@end

@implementation SaigonViewController

bool autoRespring = false;
int reinstallCydia = 1; // false by default

NSString *error_message;

- (void)addGradient {
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    CAGradientLayer *gradient = [CAGradientLayer layer];
    
    gradient.frame = view.bounds;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
    [formatter setDateFormat:@"HH"];
    
    if([[formatter stringFromDate:[NSDate date]] intValue] >= 18) {
        gradient.colors = @[(id)[UIColor colorWithRed:0.0941 green:0.5882 blue:0.7765 alpha:1.0].CGColor, (id)[UIColor colorWithRed:0.1686 green:0.1255 blue:0.3216 alpha:1.0].CGColor];
        [self.jailbreakButton setBackgroundColor:[UIColor colorWithRed:0.0941 green:0.5882 blue:0.7765 alpha:1.0]];
        [self.helpButton setBackgroundColor:[UIColor colorWithRed:0.1686 green:0.1255 blue:0.3216 alpha:0.5]];
        [self.progressView setTintColor:[UIColor colorWithRed:0.0941 green:0.5882 blue:0.7765 alpha:1.0]];
        
    } else {
        gradient.colors = @[(id)[UIColor colorWithRed:0.77 green:0.00 blue:0.34 alpha:1.0].CGColor, (id)[UIColor colorWithRed:0.24 green:0.04 blue:0.29 alpha:1.0].CGColor];
    }
    
    [view.layer insertSublayer:gradient atIndex:0];
    [self.view insertSubview:view atIndex:0];
    
}


- (void)viewDidLoad {
    [super viewDidLoad];
    [self addGradient];

    self.mach_port = MACH_PORT_NULL;

    
    // get device info
    [self.deviceInfoLabel setText:[NSString stringWithFormat:@"%s - %@", get_internal_model_name(), [[UIDevice currentDevice] systemVersion]]];
    
    if (ami_jailbroken() == 1) {
        
        [self.jailbreakButton setEnabled:NO];
        [self.jailbreakButtonWidth setConstant:[self.jailbreakButtonWidth constant] + 100];
        [self.jailbreakButton setFrame:CGRectMake(self.jailbreakButton.frame.origin.x, self.jailbreakButton.frame.origin.y, self.jailbreakButton.frame.size.width + 60, self.jailbreakButton.frame.size.height)];
        [self.jailbreakButton setTitle:@"you're already jailbroken" forState:UIControlStateDisabled];
        [self.jailbreakButton setAlpha:0.4];
        [self.jailbreakButton setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.0]];
        return;
    }
    
    if (offsets_init() != KERN_SUCCESS) {
        
        [self.jailbreakButton setEnabled:NO];
        [self.jailbreakButtonWidth setConstant:[self.jailbreakButtonWidth constant] + 100];
        [self.jailbreakButton setFrame:CGRectMake(self.jailbreakButton.frame.origin.x, self.jailbreakButton.frame.origin.y, self.jailbreakButton.frame.size.width + 60, self.jailbreakButton.frame.size.height)];
        [self.jailbreakButton setTitle:@"device not supported" forState:UIControlStateDisabled];
        [self.jailbreakButton setAlpha:0.4];
        [self.jailbreakButton setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.0]];
        return;
    }

}

- (IBAction)helpTapped:(id)sender {
    
    UIViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"InfoViewController"];
    viewController.providesPresentationContextTransitionStyle = YES;
    viewController.definesPresentationContext = YES;
    [viewController setModalPresentationStyle:UIModalPresentationOverCurrentContext];
    [self presentViewController:viewController animated:YES completion:nil];
}


- (IBAction)jailbreakTapped:(id)sender {
    
    [UIView animateWithDuration:0.2 animations:^{
        self.jailbreakButton.transform = CGAffineTransformMakeScale(0.90, 0.90);
    } completion:nil];
}

- (IBAction)jailbreakHold:(id)sender {
    
    if(reinstallCydia == 1 && is_cydia_installed() == 1) {
        
        printf("[INFO]: will reinstall Cydia\n");
        reinstallCydia = 0;
        
        [self.warningLabel setText:@"tap again to reinstall Cydia"];
        [self.warningLabel setHidden:NO];
        
        [UIView animateWithDuration:0.9 animations:^{
            [self.warningLabel setAlpha:0.30];
        } completion:^(BOOL finished){
            [self.warningLabel setAlpha:0];
        }];
        
    }
    
}


- (IBAction)jailbreakReleased:(id)sender {

    [UIView animateWithDuration:0.2 animations:^{
        self.jailbreakButton.transform = CGAffineTransformMakeScale(1, 1);
    } completion:nil];
    
    [self.helpButton setEnabled:NO];
    [self.jailbreakButton setEnabled:NO];
    [self.jailbreakButtonWidth setConstant:[self.jailbreakButtonWidth constant] + 100];
    [self.jailbreakButton setFrame:CGRectMake(self.jailbreakButton.frame.origin.x, self.jailbreakButton.frame.origin.y, self.jailbreakButton.frame.size.width + 60, self.jailbreakButton.frame.size.height)];
    [self.jailbreakButton setTitle:@"escaping sandbox" forState:UIControlStateNormal];
    [self.jailbreakButton setAlpha:0.4];
    [self.jailbreakButton setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.0]];
    
    [self.progressView setHidden:NO];
    [self.progressView setProgress:0.1 animated:YES];
    
    // escape sandbox
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
        
        self.mach_port = do_exploit();
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if(self.mach_port == MACH_PORT_NULL) {
                // show failure (escaping sandbox)
                error_message = @"escaping sandbox";
                [self show_failure];
                
            } else {
                // show priv escalation
                [self priv_escalation];
            }
            
        });
        
    });
    
    
}


- (void) priv_escalation {
    

    
    [self.progressView setProgress:0.3 animated:YES];
    [self.jailbreakButton setTitle:@"setting ports.." forState:UIControlStateNormal];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

        if (set_ports(self.mach_port) == KERN_SUCCESS) {
            
            [self.progressView setProgress:0.5 animated:YES];
            [self.jailbreakButton setTitle:@"privilege escalation.." forState:UIControlStateNormal];
            [self.warningLabel setHidden:NO];
            [self.warningLabel setText:@"if your device reboots, please try again"];
            
            // call ziVA
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

                // run ziVA
                if (ziva_go(self.mach_port) == KERN_SUCCESS) {
                    [self show_kpp_bypass];
                    // [self show_kppless];
                    
                } else {
                    // show failure (privilege escalation)
                    error_message = @"privilege escalation";
                    [self show_failure];
                }
                
            });
            

        } else {
            // show failure (setting ports)
            error_message = @"setting ports";
            [self show_failure];
        }
        
    });
}


- (void) show_kpp_bypass {
    
    [self.progressView setProgress:0.7 animated:YES];
    [self.jailbreakButton setTitle:@"bypassing kpp" forState:UIControlStateNormal];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        if (go_extra_recipe() == KERN_SUCCESS) {
            [self show_install_cydia];
        } else {
            // show failure (bypassing KPP)
//            error_message = @"bypassing KPP";
//            [self show_failure];

            // try going kppless then
            printf("[ERROR]: kpp bypass failed!\n");
            printf("[INFO]: trying to use kppless method..\n");
            [self show_kpp_bypass];
        }
        
    });
}

- (void) show_kppless {
    
    [self.progressView setProgress:0.9 animated:YES];
    [self.jailbreakButton setTitle:@"going kppless" forState:UIControlStateNormal];
    [self.warningLabel setHidden:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

        if (go_kppless() == KERN_SUCCESS) {
            
            [self.progressView setProgress:1.0 animated:YES];
            [self respring];
            
        } else {
            // show failure (going kppless)
            error_message = @"going kppless";
            [self show_failure];
        }
        
    });
    
}

- (void) show_install_cydia {
    
    int cydia_installed = is_cydia_installed();
    
    if (cydia_installed == 0 || reinstallCydia == 0) {
        [self.jailbreakButton setTitle:@"installing Cydia" forState:UIControlStateNormal];
        reinstallCydia = 0; // install Cydia
    } else {
        [self.jailbreakButton setTitle:@"respringing" forState:UIControlStateNormal];
    }
    
    [self.progressView setProgress:0.9 animated:YES];
    [self.warningLabel setHidden:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

        // Untar bootstrap & install Cydia (final step)
        if (install_cydia(reinstallCydia) == KERN_SUCCESS) {
            
            [self.progressView setProgress:1.0 animated:YES];
            [self respring];
            

        } else {
            // show failure (installing Cydia)
            error_message = @"installing Cydia";
            [self show_failure];
        }
        
        
        
    });
}

- (void) respring {
    
    [self.jailbreakButton setTitle:@"respringing" forState:UIControlStateDisabled];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        [UIView animateWithDuration:1.5 animations:^{
            [self.view setAlpha:0];
        } completion:^(BOOL finished){
            kill_backboardd();
        }];
    });
    
}

- (void) show_failure {
    
    // hide other elements
    [self.jailbreakButton setHidden:YES];
    [self.progressView setHidden:YES];
    [self.view setAlpha:0.7];
    
    // we failed badly :(
    UIViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"AlertViewController"];
    viewController.providesPresentationContextTransitionStyle = YES;
    viewController.definesPresentationContext = YES;
    [viewController setModalPresentationStyle:UIModalPresentationOverCurrentContext];
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)dealloc {
    [_jailbreakButton release];
    [_progressView release];
    [_jailbreakButtonWidth release];
    [_warningLabel release];
    [_deviceInfoLabel release];
    [_helpButton release];
    [super dealloc];
}
@end
