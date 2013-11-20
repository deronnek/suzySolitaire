//
//  ssViewController.h
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 6/2/13.
//  Copyright (c) 2013 Kevin DeRonne. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ssViewController : UIViewController
@property bool do_init_table;
@property(nonatomic, copy) NSString *restorationIdentifier;

- (void)update_bucks;
- (void)update_wins;
- (void)enable_undo;
- (void)disable_undo;

@end
