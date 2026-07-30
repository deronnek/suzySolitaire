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

@interface card: NSObject

@property card_color color;
@property int rank;
@property card_suit suit;
@property BOOL face_up;
@property NSString *face_image_filename;
@property NSString *back_image_filename;
@property UIImage *face_image;
@property UIImage *back_image;
@property UIImage *cap_image;
@property int z_loc;
@property CGPoint saved_pos;
@property int saved_cap;

@property card *card_parent;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, retain) UIImageView *view;

-(id)initWithData :(card_suit)suit :(int)rank :(NSString*)face_image_file :(NSString*)back_image_file
                  :(int)x :(int)y :(int)z :(int)width :(int)height :(int)tag;
-(void)set_pos :(int)x :(int)y;
-(void)cancel_move;
-(void)save_pos;
-(void)draw_card;
-(void)draw_self_and_parent;
-(void)resize:(int)x :(int)y :(int)width :(int)height;

@end

