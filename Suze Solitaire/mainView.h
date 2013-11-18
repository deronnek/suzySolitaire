//
//  mainView.h
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 6/5/13.
//  Copyright (c) 2013 Kevin DeRonne. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "card.h"
#import "card_stack.h"
#import "stdlib.h"

@interface mainView : UIView

@property(nonatomic, copy) NSString *restorationIdentifier;

// These next two keep the card under the cursor where it's grabbed instead
// of always at the upper left corner
@property    int xCap;
@property    int yCap;

@property    (nonatomic, retain) UIImage* backgroundImage;

// Active card under user touch
@property    card *active_card;
@property    card_stack *active_card_source_stack;
@property    card_stack *active_card_dest_stack;

@property int score;
@property int wins;
@property int losses;
@property bool autocomplete;
@property int just_won;

@property    (nonatomic, retain) NSMutableArray *cards; // Initial deck to pull from when setting up a game
@property    (nonatomic, retain) NSMutableArray *suitstacks;
@property    (nonatomic, retain) NSMutableArray *cardstacks;
@property    (nonatomic, retain) card_stack     *fub;
@property    (nonatomic, retain) card_stack     *deck;
@property    (nonatomic, retain) card_stack     *deal;
@property    int suit_stack_starter;
@property    CGPoint prev_point;

-(void)init_table;
-(void)redraw_table;
-(void)init_table_trivial;
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
-(card *)find_tapped_card:(CGPoint)point;
-(void)tryToPutUpCardAtPoint:(CGPoint)point;
-(card_stack *)find_active_stack:(CGPoint)point;
-(void)create_cards:(int)width :(int)height;
-(card *)get_random_card;
-(BOOL)accept_card_move:(card_stack *)from :(card_stack *)to :(card *)onTopOfCard;
-(BOOL)find_card_for_suitstack;


@end
