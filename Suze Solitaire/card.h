//
//  card.h
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 6/2/13.
//  Copyright (c) 2013 Kevin DeRonne. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    Black,
    Red
} card_color;

typedef enum {
    Clubs,
    Diamonds,
    Hearts,
    Spades
} card_suit;

@class card_stack;

@interface card : NSObject

@property card_color color;
@property int rank;
@property card_suit suit;
@property BOOL face_up;
@property NSString *card_name;
@property UIImage *face_image;
@property UIImage *back_image;
@property UIImage *cap_image;
//@property CGLayerRef card_layer;
@property CGRect rect;
@property CGPoint xy_loc;
@property int z_loc;
@property CGPoint saved_pos;
@property int saved_cap;
@property BOOL loaded;
@property card *card_parent;
@property (nonatomic, strong) NSString *identifier;

-(id)initWithData :(card_suit)suit :(int)rank :(NSString*)face_image_file :(NSString*)back_image_file :(NSString*)cap_image_file :(int)x :(int)y :(int)z :(int)width :(int)height;
-(void)set_pos :(int)x :(int)y;
-(void)cancel_move;
-(void)save_pos;
-(void)draw_card;
-(void)draw_cap;
-(void)draw_self_and_parent;
- (void)resize:(int)width :(int)height;
-(BOOL)change_stack:(card_stack *)from_stack :(card_stack *)to_stack;

@end

