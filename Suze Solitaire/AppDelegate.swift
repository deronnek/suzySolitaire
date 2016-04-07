//
//  AppDelegate.swift
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 4/7/16.
//  Copyright © 2016 Kevin DeRonne. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return true
    }
    
    func application(application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        return true
    }
    
    func application(application: UIApplication, willEncodeRestorableStateWithCoder coder: NSCoder) {
        coder.encodeObject(self.window?.rootViewController, forKey:"AppDelegateRootVCKey")
    }
    
    func application(application: UIApplication, didDecodeRestorableStateWithCoder coder: NSCoder) {
        print("didDecodeRestorableStateWithCoder")
        // Grabs the preserved root view controller.
        if let vc = coder.decodeObjectForKey("AppDelegateRootVCKey") {
            let window = UIWindow(frame: UIScreen().applicationFrame)
            window.rootViewController    = vc as? UIViewController
            window.restorationIdentifier = NSStringFromClass(UIWindow)

            // The green color is just to make it obvious if our view didn't load properly.
            // It can be removed when you are finished debugging.
            window.backgroundColor = UIColor.greenColor()
            
            self.window = window;
            self.window?.makeKeyAndVisible()
        }
        else {
            print("Didn't get a view controller?")
        }
    }
}
