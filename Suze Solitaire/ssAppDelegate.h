//
//  ssAppDelegate.h
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 6/2/13.
//  Copyright (c) 2013 Kevin DeRonne. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ssViewController;

@interface ssAppDelegate : UIResponder <UIApplicationDelegate>
//@interface ssAppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet ssViewController *viewController;

@end
