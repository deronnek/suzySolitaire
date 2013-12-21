//
//  card.m
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 6/2/13.
//  Copyright (c) 2013 Kevin DeRonne. All rights reserved.
//

#import "card.h"
#import "card_stack.h"

@implementation card

- (NSArray *)keysForEncoding;
{
    return [NSArray arrayWithObjects:@"color",
                                     @"rank",
                                     @"suit",
                                     @"face_up",
                                     @"card_name",
                                     @"face_image",
                                     @"back_image",
                                     @"cap_image",
                                     @"rect",
                                     @"xy_loc",
                                     @"z_loc",
                                     @"saved_pos",
                                     @"card_parent",
                                     @"identifier", nil];
}

-(id)initWithData:(card_suit)suit :(int)rank :(NSString *)face_image_file :(NSString *)back_image_file :(NSString *)cap_image_file :(int)x :(int)y :(int)z :(int)width :(int)height
{
    self = [super init];
    if(self) {
        
        self.face_image = [UIImage imageNamed:face_image_file];
        self.back_image = [UIImage imageNamed:back_image_file];
        self.cap_image  = [UIImage imageNamed:cap_image_file];
        
        //NSLog(@"height: %d width: %d",height,width);
        
        if(suit == Spades || suit == Clubs) {
            self.color = Black;
        }
        else {
            self.color = Red;
        }
        
        self.suit       = suit;
        self.rank       = rank;
        self.z_loc      = z;
        self.face_up    = false;
        
        CGPoint point;
        point.x = x;
        point.y = y;
        
        CGRect rect;
        rect.origin      = point;
        rect.size.width  = width;
        rect.size.height = height;

        self.rect        = rect;
        self.card_parent = nil;
        
        //CGContextRef context  = UIGraphicsGetCurrentContext();
        //CGSize size           = CGSizeMake((CGFloat)width, (CGFloat)height);
        //self.card_layer       = CGLayerCreateWithContext(context, size, NULL);
        //CGContextRef layerCtx = CGLayerGetContext(self.card_layer);
        
        // this just draws the image into the layer, not onto the screen (I think)
        //CGContextDrawImage(context, (CGRect){ point, self.face_image.size }, self.face_image.CGImage);
        
        // create a unique identifier for this object, helps with state restoration
        NSUUID *uuid    = [[NSUUID alloc] init];
        self.identifier = [uuid UUIDString];
    }
    return self;
}

- (void)draw_self_and_parent
{
    [self draw_card];
    [self.card_parent draw_self_and_parent];
}

- (void)resize:(int)width :(int)height
{
    _rect.size.width  = width;
    _rect.size.height = height;
}

// we are being created based on what was archived earlier
- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        for (NSString *key in self.keysForEncoding)
        {
            [self setValue:[aDecoder decodeObjectForKey:key] forKey:key];
        }
    }
    return self;
}

// we are asked to be archived, encode all our data
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	for (NSString *key in self.keysForEncoding)
    {
        [aCoder encodeObject:[self valueForKey:key] forKey:key];
    }
}


-(void)cancel_move
{
    [self set_pos:self.saved_pos.x:self.saved_pos.y];
    [self.card_parent cancel_move];
}

-(void)draw_card
{
    NSLog(@"Called draw_card");

    
    if(self.face_up) {
        //CGContextRef layerCtx = CGLayerGetContext(self.card_layer);
        //CGContextDrawLayerInRect(layerCtx, self.rect, self.card_layer);
        
        [self.face_image drawInRect:self.rect];
        //CGContextDrawLayerAtPoint(CGLayerGetContext(self.card_layer), self.rect.origin, self.card_layer);
    }
    else {
        [self.back_image drawInRect:self.rect];
    }
}
-(void)draw_cap
{
    CGRect caprect;
    caprect.origin      = self.rect.origin;
    caprect.size.width  = self.rect.size.width;
    caprect.size.height = self.saved_cap*2;
    [self.cap_image drawInRect:caprect];
}

-(void)set_pos:(int)x :(int)y
{
    CGRect rect = self.rect;
	CGPoint point;
	point.x = x;
	point.y = y;
    rect.origin = point;
	self.rect   = rect;
    
    [self.card_parent set_pos:x:y+self.saved_cap];
}

- (void)save_pos
{
    self.saved_pos = self.rect.origin;
    [self.card_parent save_pos];
}


-(BOOL)change_stack:(card_stack *)from_stack :(card_stack *)to_stack
{
    if (from_stack != to_stack){
        
        [to_stack add_card:self];
        [from_stack remove_card:self];
        
        // Clean parent card reference
        card* last = [from_stack.cards lastObject];
        [last setCard_parent:nil];
        
        [self.card_parent change_stack:from_stack:to_stack];
        
        return TRUE;
    }
    return FALSE;
}

@end
