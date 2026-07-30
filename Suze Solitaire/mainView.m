//
//  mainView.m
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 6/5/13.
//  Copyright (c) 2013 Kevin DeRonne. All rights reserved.
//

#import "mainView.h"
#import "ssViewController.h"
#import "UIKitCategories.h"


@implementation mainView


- (id)initWithFrame:(CGRect)frame
{
    NSLog(@"KDR initWithFrame called");
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        //[self init_table];
    }
    return self;
}

- (NSArray *)keysForEncoding;
{
    return [NSArray arrayWithObjects:
            @"backgroundImage",
            @"score",
            @"wins",
            @"losses",
            @"cards",
            @"suitstacks",
            @"cardstacks",
            @"fub",
            @"deck",
            @"deal",
            @"suit_stack_starter",
            @"identifier", nil];
}


// we are being created based on what was archived earlier
- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        for (NSString *key in self.keysForEncoding)
        {
            if([aDecoder decodeObjectForKey:key] != nil) {
                [self setValue:[aDecoder decodeObjectForKey:key] forKey:key];
            }
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


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
