//
//  ssTest.m
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 3/25/14.
//  Copyright (c) 2014 Kevin DeRonne. All rights reserved.
//

#import "ssTest.h"

@implementation ssTest

- (id)init {
    _simple = 7;
    _myview = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"spade1.png"]];
    return self;
}

- (id)initWithCoder:aDecoder {
    self  = [super init];
    
    //self.myview = [[UIImageView alloc] initWithCoder:aDecoder];
    self.myview = [[UIImageView alloc] init];
    [self.myview decodeRestorableStateWithCoder:aDecoder];
    [self.myview setImage:[UIImage imageNamed:@"spade1.png"]];
    self.simple = [aDecoder decodeIntForKey:@"simple"];
    
    return self;
}

// I don't think this was ever called
- (void)decodeWithCoder:(NSCoder *)aDecoder
{
    NSLog(@"ssTest decodeWithCoder");

    self.myview = [[UIImageView alloc] initWithCoder:aDecoder];
    self.simple = [aDecoder decodeIntForKey:@"simple"];
}

// we are asked to be archived, encode all our data
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    NSLog(@"ssTest ENcodeWithCoder");
    [aCoder encodeInt:self.simple forKey:@"simple"];
    [self.myview encodeRestorableStateWithCoder:aCoder];
}

@end
