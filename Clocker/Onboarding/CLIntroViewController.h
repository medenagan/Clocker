//
//  CLIntroViewController.h
//  Clocker
//
//  Created by Abhishek Banthia on 1/19/16.
//
//

#import <Cocoa/Cocoa.h>
#import "CLParentViewController.h"

typedef NS_ENUM(NSUInteger, CLFeature) {
    CLFloatingViewFeature,
    CLKeyboardShortcutFeature,
    CLFavouriteFeature
};

@interface CLIntroViewController : CLParentViewController

@end
