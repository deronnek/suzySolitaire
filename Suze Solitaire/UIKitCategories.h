//
//  UIKitCategories.h
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 6/15/13.
//  Copyright (c) 2013 Kevin DeRonne. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (FindUIViewController)
- (UIViewController *) firstAvailableUIViewController;
- (id) traverseResponderChainForUIViewController;
@end
