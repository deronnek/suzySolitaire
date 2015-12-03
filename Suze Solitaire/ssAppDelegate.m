//
//  ssAppDelegate.m
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 6/2/13.
//  Copyright (c) 2013 Kevin DeRonne. All rights reserved.
//

#import "ssAppDelegate.h"
#import "ssViewController.h"

@implementation ssAppDelegate

NSString * const AppDelegateRootVCKey = @"AppDelegateRootVCKey";


/*
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    //NSLog(@"KDR didFinishLaunching called");
	// Set the view controller as the window's root view controller and display.
    //self.window.rootViewController = self.viewController;
    //[self.window makeKeyAndVisible];
     
    //NSLog(@"KDR didFinishLaunching finished");
    
    if (!self.window) {
        
        UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        
        // The blue color is just to make it obvious if our view didn't load properly.
        // It can be removed when you are finished debugging.
        window.backgroundColor = [UIColor blueColor];
        window.rootViewController = [[ssViewController alloc] initWithNibName:@"ViewController" bundle:nil];
        window.restorationIdentifier = NSStringFromClass([window class]);
        
        self.window = window;
    }
    else {
        NSLog(@"vc init doesn't get called");
    }
    
    //[self commonInitWithOptions:launchOptions];
    [self.window makeKeyAndVisible];

    return YES;
}
*/
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
    return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
    return YES;
}

- (void)application:(UIApplication *)application willEncodeRestorableStateWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.window.rootViewController forKey:AppDelegateRootVCKey];
}


- (void)application:(UIApplication *)application didDecodeRestorableStateWithCoder:(NSCoder *)coder {
    
    NSLog(@"didDecodeRestorableStateWithCoder");
    // Grabs the preserved root view controller.
    UIViewController * vc = [coder decodeObjectForKey:AppDelegateRootVCKey];
    
    if (vc) {
        UIWindow * window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        window.rootViewController = vc;
        window.restorationIdentifier = NSStringFromClass([window class]);
        //[vc decodeRestorableStateWithCoder:coder];
        // The green color is just to make it obvious if our view didn't load properly.
        // It can be removed when you are finished debugging.
        window.backgroundColor = [UIColor greenColor];
        
        self.window = window;
        [self.window makeKeyAndVisible];
    }
    else {
        NSLog(@"Didn't get a view controller?");
    }
}

@end
