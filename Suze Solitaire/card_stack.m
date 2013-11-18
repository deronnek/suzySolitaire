//
//  card_stack.m
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 6/3/13.
//  Copyright (c) 2013 Kevin DeRonne. All rights reserved.
//

#import "card_stack.h"

@implementation card_stack

- (NSArray *)keysForEncoding;
{
    return [NSArray arrayWithObjects:@"cards",
            @"rect",
            @"stack_type",
            @"card_slice_height",
            @"stack_z",
            @"identifier", nil];
}


-(id)initWithData:(int)x :(int)y :(int)width :(int)height :(card_stack_type)type
{
    //self = [super init];
    int capacity=52;
    if(type == fub || type == suitstack) {
        capacity = 13;
    }
    else if(type == deck || type == deal) {
        capacity = 34;
    }
    
    // Set card overlap here
    self.card_slice_height = 30;
    
    self.cards = [[NSMutableArray alloc] initWithCapacity:capacity];
    self.stack_type = type;
    
    CGPoint point;
    point.x = x;
    point.y = y;
    
    CGRect rect;
    rect.origin      = point;
    rect.size.width  = width;
    rect.size.height = height;
    self.rect        = rect;
    
    return self;
}

- (void)resize:(int)x :(int)y :(int)width :(int)height
{
    // Set the bounds of the box for the stack
    CGPoint point;
    point.x = x;
    point.y = y;
    
    CGRect rect;
    rect.origin      = point;
    rect.size.width  = width;
    rect.size.height = height;
    self.rect        = rect;
    
    // Set card sizes by copying, removing everything then
    // resizing and adding back
    NSMutableArray *cards_old = [_cards copy];
    [_cards removeAllObjects];
    for(int i=0; i<[cards_old count]; i++) {
        [cards_old[i] resize:width:height];
        [self add_card:cards_old[i]];
    }
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

- (void)set_pos:(int)x :(int)y
{
    _rect.origin.x = x;
    _rect.origin.y = y;
}

- (void)add_card:(card *)toadd
{
    // Set card new position
    CGPoint pos;
    pos.x = self.rect.origin.x;
    
    //NSLog(@"Adding card to stack with %d",[self.cards count]);
    // Handle visual stacking here by adjusting y value
    if (self.stack_type == cardstack && [self.cards count] > 0) {
        pos.y = self.rect.origin.y + (self.card_slice_height*[self.cards count]-1);
        //NSLog(@"KDR adjusting y value");
    }
    else {
        pos.y = self.rect.origin.y;
    }
    
    
    if(self.stack_type == suitstack && [self.cards count] == 1) {
        [self set_pos:self.rect.origin.x:self.rect.origin.y+self.card_slice_height];
    
        [toadd set_pos:pos.x:pos.y+self.card_slice_height];
    
    }
    else {
        [toadd set_pos:pos.x:pos.y];
    }
    
    // If the stack is to be shown, make rect larger
    if((self.stack_type == cardstack && [self.cards count] > 0) || (self.stack_type == suitstack && [self.cards count] == 1)) {
        CGRect rec = [self rect];
        rec.size = CGSizeMake(rec.size.width, rec.size.height + self.card_slice_height);
        [self setRect:rec];
    }
    
    // Set deck info to card
    //[card setDeck:self];
    
    // Keep track of internal z order so we know how high the card should be
    [self setStack_z:self.stack_z+1];
    [toadd setZ_loc:self.stack_z];
    
    // Parent card
    if(self.stack_type != deal && self.stack_type != deck && self.stack_type != fub && [self.cards count]>0 ) {
        card *child_card = [self.cards lastObject];
        child_card.card_parent = toadd;
    }
    
    // Card ownership is transfered to array
    [self.cards addObject:toadd];
    
    //NSLog(@"Stack now has %d",[self.cards count]);
}

- (void)remove_card:(card *)card
{
    
    
    // make rect smaller
    
    if((self.stack_type == cardstack) && [self.cards count] > 1) {
        CGRect rec = [self rect];
        rec.size = CGSizeMake(rec.size.width, rec.size.height - self.card_slice_height);
        [self setRect:rec];
    }
    
    [self.cards removeObject:card];
}

// KDR this may *still* need attention
-(void)display_card_stack:(CGRect)rect
{
    // Do not draw deck if not really needed
    if(!CGRectIntersectsRect(rect,self.rect)) {
        return;
    }
    
    if([self.cards count] == 0) {
        [[UIColor whiteColor] set];
        UIRectFrame([self rect]);
    }
    else {
        if(self.stack_type == cardstack || self.stack_type == suitstack) {
            for(card *card in self.cards) {
                [card display_card];
            }
        }
        else {
            // Draw only top 2 cards in other decks
            if([self.cards count]>2) {
                card *card = [self.cards objectAtIndex:[self.cards count]-2];
                [card display_card];
                card = [self.cards objectAtIndex:[self.cards count]-1];
                [card display_card];
            } else {
                for(card* card in self.cards) {
                    [card display_card];
                }
            }
        }

    }
}

- (card *)get_top_card
{
    card* top = nil;
    top = [self.cards lastObject];
    [self.cards removeObject:top];
    return top;
}


- (card *)get_card_at_pos:(CGPoint)point
{
    // Try to find card under (touch) point
    card *activeCard = nil;
    // Don't bother checking all rectangles in a stack when only the top card is visible
    if(self.stack_type == deck || self.stack_type == deal || self.stack_type == fub) {
        card *card = [self.cards lastObject];
        if (CGRectContainsPoint(card.rect,point)) {
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
            if (CGRectContainsPoint(card.rect,point)) {
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
