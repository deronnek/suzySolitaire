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
                                     @"face_image_filename",
                                     @"z_loc",
                                     @"saved_pos",
                                     @"card_parent",
                                     nil];
}

-(id)initWithData:(card_suit)suit :(int)rank :(NSString *)face_image_file :(NSString *)back_image_file :(int)x :(int)y :(int)z :(int)width :(int)height :(int)tag
{
    self = [super init];
    if(self) {
        self.view = [[UIImageView alloc] initWithImage:[UIImage imageNamed:face_image_file]];
        self.view.tag = tag;

        self.face_image_filename = face_image_file;
        self.back_image_filename = back_image_file;
        
        self.face_image = [UIImage imageNamed:face_image_file];
        self.back_image = [UIImage imageNamed:back_image_file];
        
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
        self.view.frame  = rect;

        [self.view setCenter: point];
        [self.view setUserInteractionEnabled:true];

        self.card_parent = nil;
        
        // create a unique identifier for this object, used in state restoration
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

- (void)resize:(int)x :(int)y :(int)width :(int)height {
    CGPoint point;
    point.x = x;
    point.y = y;
    
    CGRect rect;
    rect.origin      = point;
    rect.size.width  = width;
    rect.size.height = height;
    self.view.frame  = rect;

}

// we are being created based on what was archived earlier
- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSLog(@"Card initWithCoder called");
    self = [super init];
    if (self)
    {
        // Need to get the image filename out of the decoder first
        self.face_image_filename = [aDecoder decodeObjectForKey:@"face_image_filename"];
        self.back_image_filename = [aDecoder decodeObjectForKey:@"back_image_filename"];
        self.back_image = [UIImage imageNamed:self.back_image_filename];
        self.face_image = [UIImage imageNamed:self.face_image_filename];
        self.view = [[UIImageView alloc] init];
        [self.view decodeRestorableStateWithCoder:aDecoder];
        [self.view setImage:self.face_image];
        
        self.rank  = [aDecoder decodeIntForKey:@"rank"];
        self.suit  = [aDecoder decodeIntForKey:@"suit"];
        self.z_loc = [aDecoder decodeIntForKey:@"z_loc"];
        self.color = [aDecoder decodeIntForKey:@"color"];
        self.face_up = [aDecoder decodeBoolForKey:@"face_up"];
        self.saved_pos = [aDecoder decodeCGPointForKey:@"saved_pos"];
        self.card_parent = [aDecoder decodeObjectForKey:@"card_parent"];
        [self.view setUserInteractionEnabled:true];
        
    }
    return self;
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)aDecoder {
    NSLog(@"Card being DECODED under stack %u",((card_stack *)[self.view superview]).stack_type);
    NSArray *syms = [NSThread  callStackSymbols];
    if ([syms count] > 1) {
        NSLog(@"<%@ %p> %@ - caller: %@ ", [self class], self, NSStringFromSelector(_cmd),[syms objectAtIndex:1]);
    } else {
        NSLog(@"<%@ %p> %@", [self class], self, NSStringFromSelector(_cmd));
    }
    //[super decodeRestorableStateWithCoder:aDecoder];
    for (NSString *key in self.keysForEncoding)
    {
        [self setValue:[aDecoder decodeObjectForKey:key] forKey:key];
    }
}

- (void)decodeWithCoder:(NSCoder *)aDecoder {
    NSLog(@"CArd decodeWithCoder called");
    for (NSString *key in self.keysForEncoding)
    {
        [self setValue:[aDecoder decodeObjectForKey:key] forKey:key];
    }
    
}

// we are asked to be archived, encode all our data
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [self.view encodeRestorableStateWithCoder:aCoder];
    
    [aCoder encodeInt:self.rank forKey:@"rank"];
    [aCoder encodeInt:self.suit forKey:@"suit"];
    [aCoder encodeInt:self.z_loc forKey:@"z_loc"];
    [aCoder encodeInt:self.color forKey:@"color"];
    [aCoder encodeBool:self.face_up forKey:@"face_up"];
    [aCoder encodeCGPoint:self.saved_pos forKey:@"saved_pos"];
    [aCoder encodeObject:self.card_parent forKey:@"card_parent"];
    [aCoder encodeObject:self.face_image_filename forKey:@"face_image_filename"];
    [aCoder encodeObject:self.back_image_filename forKey:@"back_image_filename"];
    

}

- (void)encodeRestorableStateWithCoder:(NSCoder *)aCoder
{
    NSArray *syms = [NSThread  callStackSymbols];
    if ([syms count] > 1) {
        NSLog(@"<%@ %p> %@ - caller: %@ ", [self class], self, NSStringFromSelector(_cmd),[syms objectAtIndex:1]);
    } else {
        NSLog(@"<%@ %p> %@", [self class], self, NSStringFromSelector(_cmd));
    }
    NSLog(@"Card being encoded under stack %u",((card_stack *)[self.view superview]).stack_type);
    

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

-(void)draw_card {
    NSLog(@"Called draw_card");

    
    if(self.face_up) {
        [self.view setHidden:false];
        
        
    }
    else {
    
    }
}


-(void)set_pos:(int)x :(int)y
{
    CGRect rect = self.view.frame;
	CGPoint point;
	point.x = x;
	point.y = y;
    rect.origin = point;
    self.view.frame  = rect;
    [self.view setFrame:rect];
    
    
    [self.card_parent set_pos:x:y+self.saved_cap];
}

- (void)save_pos
{
    self.saved_pos = self.view.frame.origin;
    [self.card_parent save_pos];
}




@end
