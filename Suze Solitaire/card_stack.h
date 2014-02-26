//
//  card_stack.h
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 6/3/13.
//  Copyright (c) 2013 Kevin DeRonne. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "card.h"  

typedef enum {
    fub,
    suitstack,
    cardstack,
    deck,
    deal
} card_stack_type;



@interface card_stack : UIView

@property NSMutableArray *cards;
//@property CGRect rect;
@property card_stack_type stack_type;
@property int card_slice_height;
@property int stack_z;
@property (nonatomic, strong) NSString *identifier;

- (id)initWithData:(int)x :(int)y :(int)width :(int)height :(card_stack_type)type;
- (void)resize:(int)x :(int)y :(int)width :(int)height;
- (void)set_pos:(int)x :(int)y;
- (void)add_card:(card *)toadd;
- (void)remove_card:(card *)card;
- (void)display_card_stack:(CGRect)rect;
- (void)makeSubViewsOfCards;

- (card *)get_card_at_pos:(CGPoint)point;
- (card *)get_top_card;

@end
