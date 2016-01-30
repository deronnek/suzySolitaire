//
//  card_stack.m
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 6/3/13.
//  Copyright (c) 2013 Kevin DeRonne. All rights reserved.
//

#import "card_stack.h"
#import "QuartzCore/QuartzCore.h"

@implementation card_stack

- (NSArray *)keysForEncoding;
{
    return [NSArray arrayWithObjects:@"cards",
            @"stack_type",
            @"card_slice_height",
            @"stack_z",
            nil];
}


-(id)initWithData:(int)x :(int)y :(int)width :(int)height :(card_stack_type)type {

    CGPoint point;
    point.x = x;
    point.y = y;
    
    CGRect rect;
    rect.origin      = point;
    rect.size.width  = width;
    rect.size.height = height;
    self.view.frame        = rect;
    
    point.x += width/2;
    point.y += height/2;
    //rect.origin = point;
    self.view = [[UIView alloc] initWithFrame:rect];
    [self.view setCenter:point];
    [self.view setUserInteractionEnabled:true];
    
    NSUUID *uuid    = [[NSUUID alloc] init];
    self.identifier = [uuid UUIDString];

    int capacity=52;
    if(type == fub || type == suitstack) {
        capacity = 13;
    }
    else if(type == deck || type == deal) {
        capacity = 34;
    }
    
    // Set card overlap here
    self.card_slice_height = 30;
    
    if(type == fub) {
        self.card_slice_height = 2;
    }
    if(type == deal) {
        self.card_slice_height = 2;
    }
    
    self.cards = [[NSMutableArray alloc] initWithCapacity:capacity];
    self.stack_type = type;
    
    return self;
}

- (void)resize:(int)x :(int)y :(int)width :(int)height {
    // Set the bounds of the box for the stack
    CGPoint point;
    point.x = x;
    point.y = y;
    
    CGRect rect;
    rect.origin      = point;
    rect.size.width  = width;
    if(self.stack_type == deck) {
        rect.size.height = height;
    }
    else if(self.stack_type == deal || self.stack_type == fub || self.stack_type == cardstack) {
        rect.size.height = height + ([_cards count]-1)*self.card_slice_height;
    }
    else if(self.stack_type == suitstack) {
        if([_cards count] > 1) {
            rect.size.height = height + self.card_slice_height;
        }
        else {
            rect.size.height = height;
        }
    }
    self.view.frame  = rect;
    
    //self.view.layer.borderWidth = 2;
    //self.view.layer.borderColor = [[UIColor blackColor] CGColor];
    
    // Set card sizes by copying, removing everything then
    // resizing and adding back (preserves stacking)  **but not the image now that the view is nested
    for(int i=0; i<[_cards count]; i++) {
        if(self.stack_type == cardstack || self.stack_type == fub || self.stack_type == deal) {
            y = i*self.card_slice_height;
        }
        else if(self.stack_type == suitstack && i > 0){
            y = self.card_slice_height;
        }
        else {
            y = 0;
        }
        [self.cards[i] resize:0:y:width:height];
        //NSLog(@"cardimage: %@",[((card *)_cards[i]).view image]);
    }
}

// we are being created based on what was archived earlier
- (id)initWithCoder:(NSCoder *)aDecoder {
    NSLog(@"card_stack initWithCoder called");
    self = [super init];
    if (self)
    {
        // Restore the view so we know where this stack is
        self.view = [[UIView alloc] init];
        [self.view decodeRestorableStateWithCoder:aDecoder];
        
        self.stack_type        = [aDecoder decodeIntForKey:@"stack_type"];
        self.card_slice_height = [aDecoder decodeIntForKey:@"csh"];
        self.stack_z           = [aDecoder decodeIntForKey:@"stack_z"];
        self.cards             = [aDecoder decodeObjectForKey:@"cards"];
        
        for(int i=0; i<[self.cards count]; i++) {
            //NSLog(@"adding subview: %@",((card *)self.cards[i]).view);
            [self.view addSubview:((card *)self.cards[i]).view];
            if(self.stack_type == deck) {
                [((card *)self.cards[i]).view setImage:[UIImage imageNamed:((card *)self.cards[i]).back_image_filename]];
            }
        }
    }
    return self;
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)aDecoder {
    NSLog(@"card_stack decodeRestorableStateWithCoder called!");
    //[super decodeRestorableStateWithCoder:aDecoder];
    for (NSString *key in self.keysForEncoding)
    {
        [self setValue:[aDecoder decodeObjectForKey:key] forKey:key];
    }
    NSLog(@"card_stack superview: %@",[self.view superview]);
    //NSLog(@"card_stack card[0]: %@",self.cards[0]);
}

- (void)decodeWithCoder:(NSCoder *)aDecoder {

    for (NSString *key in self.keysForEncoding)
    {
        [self setValue:[aDecoder decodeObjectForKey:key] forKey:key];
    }

}

// we are asked to be archived; encode all our data
- (void)encodeWithCoder:(NSCoder *)aCoder {
    [self.view encodeRestorableStateWithCoder:aCoder];
    [aCoder encodeInt:self.stack_type forKey:@"stack_type"];
    [aCoder encodeInt:self.card_slice_height forKey:@"csh"];
    [aCoder encodeInt:self.stack_z  forKey:@"stack_z"];
    [aCoder encodeObject:self.cards forKey:@"cards"];
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)aCoder
{
    NSLog(@"card_stack encodeRestorableStateWithCoder called for type %u",self.stack_type);
    //[super encodeRestorableStateWithCoder:aCoder];
    
    for (NSString *key in self.keysForEncoding)
    {
        [aCoder encodeObject:[self valueForKey:key] forKey:key];
    }
}

- (void)set_pos:(int)x :(int)y
{
    
    CGRect rect = self.view.frame;
	CGPoint point;
	point.x = x;
	point.y = y;
    rect.origin = point;
    self.view.frame  = rect;
    
    //point.x += self.rect.size.width/2;
    //point.y += self.rect.size.height/2;
    
    //[self setCenter:point];
}

- (void)add_card:(card *)toadd
{
    // Set card new position.  Remember: the position of a subview is relative to its super view
    CGPoint pos;
    pos.x = 0;
    
    if(self.stack_type == deck) {
        [toadd.view setImage:toadd.back_image];
    }
    else {
        [toadd.view setImage:toadd.face_image];
    }
    
    //NSLog(@"\n\n\nAdding card to stack with %d\n\n\n",[self.cards count]);
    // Handle visual stacking here by adjusting y value
    if ((self.stack_type == cardstack || self.stack_type == fub || self.stack_type == deal) && [self.cards count] > 0) {
        pos.y = (self.card_slice_height*[self.cards count]-1);
        //NSLog(@"KDR adjusting y value");
    }
    else {
        pos.y = 0;
    }
    
    
    //if(self.stack_type == suitstack && [self.cards count] == 1) {
    if(self.stack_type == suitstack && [self.cards count] > 0) {
        //[self set_pos:self.frame.origin.x:self.frame.origin.y+self.card_slice_height];
        //[toadd set_pos:pos.x:pos.y+self.card_slice_height];
        pos.y = pos.y + self.card_slice_height;
    }
    
    [toadd setSaved_cap:self.card_slice_height];
    [toadd set_pos:pos.x:pos.y];
    
    // If the stack is to be shown, make rect larger
    if(((self.stack_type == cardstack || self.stack_type == fub || self.stack_type==deal) && [self.cards count] > 0) || (self.stack_type == suitstack && [self.cards count] == 1)) {
        CGRect rec = self.view.frame;
        rec.size = CGSizeMake(rec.size.width, rec.size.height + self.card_slice_height);
        [self.view setFrame:rec];
    }
    //NSLog(@"\n\n\n KDR KDR TEST KDR KDR KDR\n\n\n");
    // Set deck info to card
    //[card setDeck:self];
    
    // Keep track of internal z order so we know how high the card should be
    [self setStack_z:self.stack_z+1];
    [toadd setZ_loc:self.stack_z];
    
    // Parent card
    //if(self.stack_type != deal && self.stack_type != deck && self.stack_type != fub && [self.cards count] > 0 ) {
    // We actually need to set parents for deal and fub so you can't grab cards willy-nilly.  l
    // deck cards are perfectly aligned so there's no risk for that stack.
    if(self.stack_type != deck && [self.cards count] > 0) {
        card *child_card = [self.cards lastObject];
        child_card.card_parent = toadd;
    }
    if(self.stack_type == deck) {
        toadd.card_parent = nil;
    }
    
    // If we're adding a card, we have at least one and don't want the border
    self.view.layer.borderWidth = 0;

    // Card ownership is transfered to array
    [self.cards addObject:toadd];
    [toadd.view setExclusiveTouch:true];
    
    // Update restoration identifier to be mainview/cardstack/card
    //[toadd.view setRestorationIdentifier:[NSString stringWithFormat:@"%@/%@", self.restorationIdentifier, toadd.identifier]];
    //NSLog(@"Setting card restoration identifier: %@",toadd.restorationIdentifier);
    [self.view addSubview:toadd.view];
    
    //NSLog(@"Stack now has %d",[self.cards count]);
}

- (void)makeSubViewsOfCards
{
    for(card *c in self.cards) {
        //NSLog(@"KDR adding card view as subview to stack type %u",self.stack_type);
        [self.view addSubview:c.view];
    }
}

- (void)remove_card:(card *)card {
    // make rect smaller -- wait do I really need to do this?
    if((self.stack_type == cardstack) && [self.cards count] > 1) {
        CGRect rec = self.view.frame;
        rec.size = CGSizeMake(rec.size.width, rec.size.height - self.card_slice_height);
        //[self.view setFrame:rec];
    }

    [self.cards removeObject:card];
    
    if([self.cards count] == 0) {
        self.view.layer.borderWidth = 1;
        self.view.layer.borderColor = [[UIColor whiteColor] CGColor];
    }
    // KDR a little awkward that I send a message to the card to remove itself from us, effectively
    [card.view removeFromSuperview];
}


- (card *)get_top_card
{
    card* top = nil;
    top = [self.cards lastObject];
    [self remove_card:top];
    return top;
}


- (card *)get_card_at_pos:(CGPoint)point {
    // Try to find card under (touch) point
    card *activeCard = nil;
    // Don't bother checking all rectangles in a stack when only the top card is visible
    if(self.stack_type == deck || self.stack_type == deal || self.stack_type == fub) {
        card *card = [self.cards lastObject];
        if (CGRectContainsPoint(card.view.frame,point)) {
            if (activeCard==nil) {
                activeCard = card;
            }
            else {
                if (card.z_loc > activeCard.z_loc)
                    activeCard = card;
            }
        }
    }
    else {
        for(card *card in self.cards) {
            
            if (CGRectContainsPoint(card.view.frame,point)) {
                if (activeCard==nil) {
                    activeCard = card;
                }
                else {
                    if (card.z_loc > activeCard.z_loc)
                        activeCard = card;
                }
            }
        }
    }
    // Return fourd card
	return activeCard;
}


@end
