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
#import "NSMutableArray+Shuffling.h"

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
/*
-(void)drawRect:(CGRect)rect
{
    //NSLog(@"KDR drawRect called deck has %d score: %d",[self.deck.cards count],self.score);
    //CGContextRef    context = UIGraphicsGetCurrentContext();
    
    // Disable antialias
    //CGContextSetShouldAntialias(context,false);

    // Draw background green color
    //[RGB(0, 100, 0) set];
	//UIRectFill(rect);

    // Draw background image
    //[self.backgroundImage drawInRect:self.bounds];
    //[self.backgroundImage drawInRect:rect];
    if(self.just_won) {
        for(card_stack* cs in self.suitstacks)
        {
            for(card *card in cs.cards) {
                [card draw_card];
            }
        }
    }
    else {
    // Draw initial card stacks
    for(card_stack* cs in self.cardstacks)
    {
        [cs display_card_stack:rect];
    }
    
    for(card_stack* cs in self.suitstacks)
    {
        [cs display_card_stack:rect];
    }
    
    [self.fub display_card_stack:rect];
    [self.deck display_card_stack:rect];
    [self.deal display_card_stack:rect];
    
    
    // Draw active card on top of all others
    
	if (self.active_card)
	{
        // Make Shadow
        //CGSize myShadowOffset = CGSizeMake(-10,10);
        //CGContextSaveGState(context);
        //CGContextSetShadow(context, myShadowOffset,5);
        
        
        // Draw the card(s)
        [self.active_card draw_self_and_parent];
		
        //CGContextRestoreGState(context);
        
	}
    }
    NSLog(@"Called drawRect");

}
 */

- (void)init_table
{
    /*
    
    NSURL *dataFileURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"SavedData"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[dataFileURL path]])
    {
        // saved file exists, load it's content from that path
        // note: unarchiveObjectWithFile returns an immutable array, we need to make it mutable
        //
        _dataArray = [[NSKeyedUnarchiver unarchiveObjectWithFile:[dataFileURL path]] mutableCopy];
    }
    else
    {
        _dataArray = [[NSMutableArray alloc] init];
    }
*/
    //NSLog(@"KDR init_table called");
    //int screen_width = self.bounds.size.width;
    ssViewController *myController = (ssViewController *)[self firstAvailableUIViewController];
    [myController disable_undo];
    
    int screen_width = CGRectGetWidth(self.bounds);
    //int screenHeight = self.bounds.size.height;
    NSLog(@"KDR screen width: %d",screen_width);
    
    self.restorationIdentifier = @"mainView";
    
    if (self.cards != nil)
        return;
    
    int card_width = screen_width / 10;
    int card_height = card_width * 1.55;
    //int cap = (screen_width - card_width*7) / 8;
    
    int toprow_spacer = card_height/1.4;
    int second_spacer = card_height*2.1;
    
    NSLog(@"Card width: %d %d %d",screen_width,card_width,card_height);
    
    self.backgroundImage = [UIImage imageNamed:@"background.png"];
    
    // Create cards
    self.cards =  [[NSMutableArray alloc] init];
    [self create_cards:card_width:card_height];
    [self.cards shuffle];
    
    // Array for the suit stacks
    self.suitstacks = [[NSMutableArray alloc] initWithCapacity:4];
    self.cardstacks = [[NSMutableArray alloc] initWithCapacity:4];
    
    /* The creation of the various stacks is organized from the top of the window to the bottom, then left to right. */
    
    // Create the face up blind
    self.fub = [[card_stack alloc] initWithData:card_width/5:toprow_spacer:card_width:card_height:fub];
    for(int i=0; i<13; i++) {
        card* card = [self get_random_card];
        [card setFace_up:true];
        [self.fub add_card:card];
        card = nil;
    }

    // Create four suit stacks
    for(int i=0; i<4; i++) {
        card_stack *asuitstack = [[card_stack alloc] initWithData:card_width*4+(i*card_width+(i*50)):toprow_spacer:card_width:card_height:suitstack];
        if(i==0) {
            card* card = [self get_random_card];
            [card setFace_up:true];
            [asuitstack add_card:card];
            self.suit_stack_starter = card.rank;
            card = nil;
        }
        [self.suitstacks addObject:asuitstack];
        asuitstack = nil;
    }
    
    // Create the deck
    self.deck = [[card_stack alloc] initWithData:card_width/5:second_spacer:card_width:card_height:deck];
    for(int i=0; i<34; i++) {
        card* card = [self get_random_card];
        [self.deck add_card:card];
        card = nil;
    }
    
    // Create the deal
    self.deal = [[card_stack alloc] initWithData:card_width+(card_width/5)+20:second_spacer:card_width:card_height:deal];

    // Create four card stacks
    for(int i=0; i<4; i++) {
        card_stack *acardstack = [[card_stack alloc] initWithData:card_width*4+(i*card_width+(i*50)):second_spacer:card_width:card_height:cardstack];
        
        card* card = [self get_random_card];
        [card setFace_up:true];
        [acardstack add_card:card];
        card = nil;
        
        [self.cardstacks addObject:acardstack];
        acardstack = nil;
    }
}

- (void)redraw_table
{

    //int screen_width = self.bounds.size.width;
    int screen_width = CGRectGetWidth(self.bounds);
    //int screenHeight = self.bounds.size.height;
    NSLog(@"KDR screen width: %d",screen_width);
    
    int card_width = screen_width / 10;
    int card_height = card_width * 1.55;
    int toprow_spacer = card_height/1.4;
    int second_spacer = card_height*2.1;

    //int cap = (screen_width - card_width*7) / 8;
    
    //NSLog(@"Card width: %d %d %d",screen_width,card_width,card_height);
    
    /* The creation of the various stacks is organized from the top of the window to the bottom, then left to right. */
    
    // Create the face up blind
    /*
    self.fub = [[card_stack alloc] initWithData:card_width/5:card_height:card_width:card_height:fub];
    for(int i=0; i<13; i++) {
        card* card = [self get_random_card];
        [card setFace_up:true];
        [self.fub add_card:card];
        card = nil;
    }
     */
    
    [_fub resize:card_width/5:toprow_spacer:card_width:card_height];
    
    // Resize the four suit stacks
    for(int i=0; i<4; i++) {
        [_suitstacks[i] resize:card_width*4+(i*card_width+(i*50)):toprow_spacer:card_width:card_height];
        
     }
    
    [_deck resize:card_width/5:second_spacer:card_width:card_height];
    
    [_deal resize:card_width+(card_width/5)+20:second_spacer:card_width:card_height];
    
    for(int i=0; i<4; i++) {
        [_cardstacks[i] resize:card_width*4+(i*card_width+(i*50)):second_spacer:card_width:card_height];
    }
    
    
    /*
    // Create the deck
    self.deck = [[card_stack alloc] initWithData:card_width/5:card_height*2.5:card_width:card_height:deck];
    for(int i=0; i<34; i++) {
        card* card = [self get_random_card];
        [self.deck add_card:card];
        card = nil;
    }
    
    // Create the deal
    self.deal = [[card_stack alloc] initWithData:card_width+(card_width/5)+20:card_height*2.5:card_width:card_height:deal];
    
    // Create four card stacks
    for(int i=0; i<4; i++) {
        card_stack *acardstack = [[card_stack alloc] initWithData:card_width*4+(i*card_width+(i*50)):card_height*2.5:card_width:card_height:cardstack];
        
        card* card = [self get_random_card];
        [card setFace_up:true];
        [acardstack add_card:card];
        card = nil;
        
        [self.cardstacks addObject:acardstack];
        acardstack = nil;
    }
     */
    [self setNeedsDisplay];
}

- (void)init_table_trivial
{

    int screen_width = CGRectGetWidth(self.bounds);
    self.restorationIdentifier = @"mainView";
    
    if (self.cards != nil)
        return;
    
    int card_width = screen_width / 10;
    int card_height = card_width * 1.55;
    
    self.backgroundImage = [UIImage imageNamed:@"background.png"];
    
    // Create cards
    self.cards =  [[NSMutableArray alloc] init];
    [self create_cards:card_width:card_height];
    //[self.cards shuffle];
    
    // Array for the suit stacks
    self.suitstacks = [[NSMutableArray alloc] initWithCapacity:4];
    self.cardstacks = [[NSMutableArray alloc] initWithCapacity:4];
    
    /* The creation of the various stacks is organized from the top of the window to the bottom, then left to right. */
    
    // Create the face up blind
    
    self.fub = [[card_stack alloc] initWithData:card_width/5:card_height:card_width:card_height:fub];
     /*
    for(int i=0; i<13; i++) {
        card* card = [self get_random_card];
        [card setFace_up:true];
        [self.fub add_card:card];
        card = nil;
    }
     */
    
    // Create the deck
    self.deck = [[card_stack alloc] initWithData:card_width/5:card_height*2.5:card_width:card_height:deck];
    
    // Create the deal
    self.deal = [[card_stack alloc] initWithData:card_width+(card_width/5)+20:card_height*2.5:card_width:card_height:deal];
    
    // Create four suit stacks and cardstacks
    for(int i=0; i<4; i++) {
        card_stack *asuitstack = [[card_stack alloc] initWithData:card_width*4+(i*card_width+(i*50)):card_height:card_width:card_height:suitstack];
        for(int j=0; j<10; j++) {
            card* card = [self get_next_card];

            [card setFace_up:true];
            [asuitstack add_card:card];
            self.suit_stack_starter = card.rank;
            card = nil;
        }
        [self.suitstacks addObject:asuitstack];
        asuitstack = nil;
        
        card_stack *acardstack = [[card_stack alloc] initWithData:card_width*4+(i*card_width+(i*50)):card_height*2.5:card_width:card_height:cardstack];
        
      
        card* topcard    = [self get_next_card];
        card* middlecard = [self get_next_card];
        card* bottomcard = [self get_next_card];
            
        [topcard setFace_up:true];
        [middlecard setFace_up:true];
        [bottomcard setFace_up:true];
        if(i==2) {
            [self.fub add_card:topcard];
            [acardstack add_card:bottomcard];
            [acardstack add_card:middlecard];
        }
        else if(i==3) {
            [self.deal add_card:topcard];
            [acardstack add_card:bottomcard];
            [acardstack add_card:middlecard];
        }
        else {
            [acardstack add_card:bottomcard];
            [acardstack add_card:middlecard];
            [acardstack add_card:topcard];
        }

        [self.cardstacks addObject:acardstack];
        acardstack = nil;
    }
    
    
    
    
    /*
    for(int i=0; i<34; i++) {
        card* card = [self get_random_card];
        [self.deck add_card:card];
        card = nil;
    }
     */
    
    
    
}

- (void)init_table_debug
{
    
    int screen_width = CGRectGetWidth(self.bounds);
    self.restorationIdentifier = @"mainView";
    
    if (self.cards != nil)
        return;
    
    int card_width = screen_width / 10;
    int card_height = card_width * 1.55;
    
    self.backgroundImage = [UIImage imageNamed:@"background.png"];
    
    // Create cards
    self.cards =  [[NSMutableArray alloc] init];
    [self create_cards:card_width:card_height];
    //[self.cards shuffle];
    
    // Array for the suit stacks
    self.suitstacks = [[NSMutableArray alloc] initWithCapacity:4];
    self.cardstacks = [[NSMutableArray alloc] initWithCapacity:4];
    
    /* The creation of the various stacks is organized from the top of the window to the bottom, then left to right. */
    
    // Create the face up blind
    
    self.fub = [[card_stack alloc] initWithData:card_width/5:card_height:card_width:card_height:fub];
    /*
     for(int i=0; i<13; i++) {
     card* card = [self get_random_card];
     [card setFace_up:true];
     [self.fub add_card:card];
     card = nil;
     }
     */
    
    // Create the deck
    self.deck = [[card_stack alloc] initWithData:card_width/5:card_height*2.5:card_width:card_height:deck];
    
    // Create the deal
    self.deal = [[card_stack alloc] initWithData:card_width+(card_width/5)+20:card_height*2.5:card_width:card_height:deal];
    
    // Create four suit stacks and cardstacks
    for(int i=0; i<4; i++) {
        card_stack *asuitstack = [[card_stack alloc] initWithData:card_width*4+(i*card_width+(i*50)):card_height:card_width:card_height:suitstack];
        for(int j=0; j<10; j++) {
            card* card = [self get_next_card];
            
            [card setFace_up:true];
            [asuitstack add_card:card];
            self.suit_stack_starter = card.rank;
            card = nil;
        }
        [self.suitstacks addObject:asuitstack];
        asuitstack = nil;
        
        card_stack *acardstack = [[card_stack alloc] initWithData:card_width*4+(i*card_width+(i*50)):card_height*2.5:card_width:card_height:cardstack];
        
        
        card* topcard    = [self get_next_card];
        card* middlecard = [self get_next_card];
        card* bottomcard = [self get_next_card];
        
        [topcard setFace_up:true];
        [middlecard setFace_up:true];
        [bottomcard setFace_up:true];
        if(i==2) {
            [self.fub add_card:topcard];
            [acardstack add_card:bottomcard];
            [acardstack add_card:middlecard];
        }
        else if(i==3) {
            [self.deal add_card:topcard];
            [acardstack add_card:bottomcard];
            [acardstack add_card:middlecard];
        }
        else {
            [acardstack add_card:bottomcard];
            [acardstack add_card:middlecard];
            [acardstack add_card:topcard];
        }
        
        [self.cardstacks addObject:acardstack];
        acardstack = nil;
    }
}

-(void)create_cards:(int)width :(int)height
{
    NSString *back_img = @"cardback.png";
    
    for (int i=1; i<=13; i++) {
        NSString* face_img = [NSString stringWithFormat:@"s.club%d.png",i];
        NSString* cap_img = [NSString stringWithFormat:@"c.club%d.png",i];
        card *acard = [[card alloc] initWithData:Clubs:i:face_img:back_img:cap_img:0:0:i:width:height];
         [acard setColor:Black];
        [self.cards addObject:acard];
        acard = nil;
    }
    
    for (int i=1; i<=13; i++) {
        NSString* face_img = [NSString stringWithFormat:@"s.diamond%d.png",i];
        NSString* cap_img = [NSString stringWithFormat:@"c.diamond%d.png",i];
        card *acard = [[card alloc] initWithData:Diamonds:i:face_img:back_img:cap_img:0:0:i:width:height];
        [acard setColor:Red];
        [self.cards addObject:acard];
        acard = nil;
    }

    for (int i=1; i<=13; i++) {
        NSString* face_img = [NSString stringWithFormat:@"s.heart%d.png",i];
        NSString* cap_img = [NSString stringWithFormat:@"c.heart%d.png",i];
        card *acard = [[card alloc] initWithData:Hearts:i:face_img:back_img:cap_img:0:0:i:width:height];
        [acard setColor:Red];
        [self.cards addObject:acard];
        acard = nil;
    }

    for (int i=1; i<=13; i++) {
        NSString* face_img = [NSString stringWithFormat:@"s.spade%d.png",i];
        NSString* cap_img = [NSString stringWithFormat:@"c.spade%d.png",i];
        card *acard = [[card alloc] initWithData:Spades:i:face_img:back_img:cap_img:0:0:i:width:height];
        [acard setColor:Black];
        [self.cards addObject:acard];
        acard = nil;
    }

    
}

-(card*)get_random_card
{
    card* ret = nil;
    int r = 0;
    
    int max = ([self.cards count]-1);
    if (max>0)
        r = arc4random() % max;
    
    //NSLog(@"r = %d, max = %d", r, max);
    
    ret = [self.cards objectAtIndex:r];
    [self.cards removeObject:ret];
    
    return ret;
}

-(card*)get_next_card
{
    card* ret = nil;
    int r = 0;
    
    ret = [self.cards objectAtIndex:r];
    [self.cards removeObject:ret];
    
    return ret;
}

-(card *)find_tapped_card:(CGPoint)point
{
    card* card = nil;
    // Deck
    card = [self.deck get_card_at_pos:point];
    if(card) {
        self.active_card_source_stack = self.deck;
        return card;
    }
    card = nil;
    
    // Deal
    card = [self.deal get_card_at_pos:point];
    if(card) {
        self.active_card_source_stack = self.deal;
        return card;
    }
    card = nil;
    
    // Cardstacks
    for(card_stack *cs in self.cardstacks)
    {
        card = [cs get_card_at_pos:point];
        if (card) {

            self.active_card_source_stack = cs;
            return card;
        }
        card = nil;
    }
 
    // Fub
    card = [self.fub get_card_at_pos:point];
    if(card) {

        self.active_card_source_stack = self.fub;
        return card;
    }
    card = nil;
    

    
    // Suitstacks
    for(card_stack *cs in self.suitstacks)
    {
        card = [cs get_card_at_pos:point];
        if (card) {
           
            self.active_card_source_stack = cs;
            return card;
        }
        card = nil;
    }

    return nil;
}

-(card_stack *)find_active_stack:(CGPoint)point
{
   
    
    for(card_stack *cs in self.cardstacks)
    {
        if(CGRectContainsPoint(cs.rect,point))
        {
            return cs;
        }
    }
    
    for(card_stack *cs in self.suitstacks)
    {
        if(CGRectContainsPoint(cs.rect,point))
        {
            return cs;
        }
    }
    
    if(CGRectContainsPoint(self.deck.rect,point))
    {
        return self.deck;
    }

    if(CGRectContainsPoint(self.deal.rect,point))
    {
        return self.deal;
    }

    if(CGRectContainsPoint(self.fub.rect,point))
    {
        return self.fub;
    }

    return nil;
}

-(card_stack *)find_active_stack_rect:(CGRect)rect
{
    
    
    for(card_stack *cs in self.cardstacks)
    {
        if(CGRectIntersectsRect(cs.rect, rect))
        {
            return cs;
        }
    }
    
    for(card_stack *cs in self.suitstacks)
    {
        if(CGRectIntersectsRect(cs.rect, rect))
        {
            return cs;
        }
    }
    if(CGRectIntersectsRect(self.deck.rect,rect)) 
    {
        return self.deck;
    }
    if(CGRectIntersectsRect(self.deal.rect,rect))
    {
        return self.deal;
    }
    
    if(CGRectIntersectsRect(self.fub.rect,rect))
    {
        return self.fub;
    }
    
    return nil;
}

-(void)run_victory
{
    if(!self.just_won) {
        self.active_card = nil;
        self.score += 250;
        self.wins++;
        ssViewController * myController = (ssViewController *)[self firstAvailableUIViewController];
        if(myController != nil) {
            //NSLog(@"KDR controller obtained successfully");
            [myController update_bucks];
            [myController update_wins];
        }
        else {
            NSLog(@"KDR COULD NOT OBTAIN CONTROLLER");
        }
        // Visual "reward" for winning
        
        int offset = 75;
        int stacknum = 0;
        for(card_stack *cs in self.suitstacks) {
            int cardnum  = 0;
            for(card *card in cs.cards) {
                float x = (cardnum*card.rect.size.width*0.735)+10;
                float y = offset+(stacknum*card.rect.size.height);
                CGRect rect = card.rect;
                CGPoint point;
                point.x = x;
                point.y = y;
                rect.origin = point;
                
                card.rect   = rect;
                card.card_parent  = nil;
                
                int screen_width  = CGRectGetWidth(self.bounds);
                int screen_height = CGRectGetHeight(self.bounds);
                if(x> screen_width || y>screen_height) {
                    NSLog(@"KDR OUT OF BOUNDS!!!!!!!!!!!!!");
                }
                NSLog(@"x: %f y %f height: %f stacknum: %d",x, y,card.rect.size.height,stacknum);
                

                [self setNeedsDisplayInRect:rect];
                
//                sleep(1);
                
                cardnum++;
            }
            stacknum++;
        }
        
    }
    self.just_won = 1;
}

-(void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    UITouch* touchPoint = [touches anyObject];
    CGPoint point       = [touchPoint locationInView:self];
	
    _prev_point = point;
    
    self.active_card  = [self find_tapped_card:point];
    [self.active_card save_pos];
    
    if(self.active_card) {
        NSLog(@"Tapped: rank: %d suit: %u",self.active_card.rank,self.active_card.suit);
        self.xCap = point.x - self.active_card.rect.origin.x;
        self.yCap = point.y - self.active_card.rect.origin.y;
    }
    
    /*
    // Handle source deck and waste2 touch
    if (_activeCard && ([[_activeCard ownerDeck]deckType] == ESource ||
                        [[_activeCard ownerDeck]deckType] == EWaste2)) {
        if (_activeCard.cardParent == nil ||
            (_activeCard.cardParent && _activeCard.cardParent.turned && _activeCard.turned)) {
            xCap = point.x - _activeCard.cardRect.origin.x;
            yCap = point.y - _activeCard.cardRect.origin.y;
            [_activeCard setTurned: true];
            [_activeCard storeCurrentPos];
        } else {
            _activeCard = nil;
        }
        
	}
    // Handle waste1 deck touch
    else if (_activeCard && [[_activeCard ownerDeck]deckType] == EWaste1) {
        [_activeCard setTurned: true];
        [_activeCard changeDeckTo:_activeCard.ownerDeck:_wasteDeck2];
        _activeCard = nil;
        [self setNeedsDisplay];
    }
    // Empty waste1 deck touch
    else if(!_activeCard && CGRectContainsPoint(self.wasteDeck1.deckRect,point)) {
        // Copy all cards from wast2 back to waste1
        if ([self.wasteDeck2.cardArray count]>0) {
            
            Card* c = [self.wasteDeck2.cardArray objectAtIndex:0];
            // That handles all copying
            [c changeDeckTo:self.wasteDeck2 :self.wasteDeck1];
            c = nil;
        }
        [self setNeedsDisplay];
        
    }
    */
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (self.active_card && self.active_card_source_stack.stack_type != deck)
	{
        UITouch* touch = [touches anyObject];
        CGPoint point  = [touch locationInView:self];
		[self.active_card set_pos:point.x - self.xCap:point.y - self.yCap];
		
        //[self setNeedsDisplay];
        
        // Optimize drawing with clipping when user moves cards
        
        int x = ABS(_prev_point.x - point.x) + 45;
        int y = ABS(_prev_point.y - point.y) + 45;
        _prev_point = point;
        
        
         //  Slower, though possibly smoother, animation
        /*
        int x = point.x;
        int y = point.y;
         */
        
        CGRect rect;
        rect = self.active_card.rect;
        rect.origin.x -= x;
        rect.origin.y -= y;
        rect.size.width += x*2;
        rect.size.height = self.bounds.size.height-self.active_card.rect.origin.y+45;
        
        [self setNeedsDisplayInRect:rect];
        //[self setNeedsDisplay];
	}
}
- (void)undo_deck_tap
{
    NSLog(@"KDR Undoing deck tap");
    if([self.deal.cards count] == 0) {
        /* Move everything from the deck back to the deal */
        int deck_count =[self.deck.cards count];
        for(int i=0; i<deck_count; i++) {
            [self.deal add_card:[self.deck get_top_card]];
            [[self.deal.cards lastObject] setFace_up:true];
        }
        [self setNeedsDisplayInRect:self.deal.rect];
    }
    else {
        /* Take the top 3 cards from the deal and move them to the deck */
        int deal_count = [self.deal.cards count];
        for(int i=0; i<self.deck_just_tapped && i<deal_count; i++) {
            [self.deck add_card:[self.deal get_top_card]];
            [[self.deck.cards lastObject] setFace_up:false];
        }
    }
    //[myController disable_undo];
    self.active_card = NULL;
    // Refresh the appropriate rectangles
    
    [self setNeedsDisplayInRect:self.deck.rect];
    
    if([self.deal.cards count] == 0) {
        [self setNeedsDisplayInRect:self.deal.rect];
    }
    /*
    if([self.deck.cards count] == 0) {
        // Reset the size of the rectangle for the deal
        CGRect rec = [self.deal rect];
        rec.size = CGSizeMake(rec.size.width, self.deck.rect.size.height);
        [self.deal setRect:rec];
        [self setNeedsDisplayInRect:self.deal.rect];
    }
    */
    //[self setNeedsDisplay];
    NSLog(@"Deck has %d cards",[self.deck.cards count]);
    NSLog(@"Deal has %d cards",[self.deal.cards count]);

}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(self.just_won)
        return;
    
    //NSLog(@"Called touchesEnded");
        //CGPoint point  = [touch locationInView:self];
    //card_stack *cs = [self find_active_stack:point];
    
    card_stack *cs = [self find_active_stack_rect:self.active_card.rect];
    bool emptystack = false;
    // If the deck is empty, we have to be able to detect a click on it with no card
    if(!cs) {
        UITouch* touch = [touches anyObject];
        CGPoint point  = [touch locationInView:self];
        cs = [self find_active_stack:point];
        emptystack = true;
    }

    ssViewController *myController = (ssViewController *)[self firstAvailableUIViewController];
    
    //[self.active_card cancel_move];
    //[self setNeedsDisplay];
    if(cs) {
        if(cs.stack_type == deck && (self.active_card_source_stack.stack_type == deck || [self.deck.cards count] == 0)) {
            
                // When canceling a stack drag, make sure you clean up everything
                CGRect rect;
                rect = self.active_card.rect;
                rect.size.height = self.bounds.size.height-self.active_card.rect.origin.y+45;
                [self setNeedsDisplayInRect:rect];
                
                [self.active_card cancel_move];
                [self setNeedsDisplayInRect:self.active_card_source_stack.rect];

        
            NSLog(@"KDR Tapped deck");
            if([self.deck.cards count] == 0) {
                NSLog(@"KDR out of cards");
                /* Move everything from the deal to the deck */
                int deal_count =[self.deal.cards count];
                for(int i=0; i<deal_count; i++) {
                    [self.deck add_card:[self.deal get_top_card]];
                    [[self.deck.cards lastObject] setFace_up:false];
                }
                [self setNeedsDisplayInRect:self.deck.rect];
                

            }
            else {
                /* Take up to 3 cards from the deck and move them to the deal */
                int deck_count = [self.deck.cards count];
                self.deck_just_tapped = 0;
                for(int i=0; i<3 && i<deck_count; i++) {
                    [self.deal add_card:[self.deck get_top_card]];
                    [[self.deal.cards lastObject] setFace_up:true];
                    self.deck_just_tapped++;
                }
            }
            [myController enable_undo];
            self.active_card = NULL;
            // Refresh the appropriate rectangles
            
            [self setNeedsDisplayInRect:self.deal.rect];
            
            if([self.deck.cards count] == 0) {
                [self setNeedsDisplayInRect:self.deck.rect];
            }
            
            if([self.deal.cards count] == 0) {
                // Reset the size of the rectangle for the deal
                CGRect rec = [self.deal rect];
                rec.size = CGSizeMake(rec.size.width, self.deck.rect.size.height);
                [self.deal setRect:rec];
                [self setNeedsDisplayInRect:self.deal.rect];
            }
            
            //[self setNeedsDisplay];
            NSLog(@"Deck has %d cards",[self.deck.cards count]);
            NSLog(@"Deal has %d cards",[self.deal.cards count]);
        }
        else if(cs.stack_type == cardstack || cs.stack_type == suitstack){
            card *dropped_on = [cs.cards lastObject];
            if([self accept_card_move:self.active_card_source_stack :cs :dropped_on]) {
                //[cs add_card:self.active_card];
                //[self.active_card_source_stack remove_card:self.active_card];
                
                self.active_card_dest_stack = cs;
                
                [myController enable_undo];
                [self setNeedsDisplayInRect:self.active_card.rect];
                
                CGRect rect;
                rect = self.active_card.rect;
                rect.size.height = self.bounds.size.height-self.active_card.rect.origin.y+45;
                [self setNeedsDisplayInRect:rect];

                
                [self.active_card change_stack:self.active_card_source_stack:cs];
                // Redraw the white rectangle if there are no more cards
                if([self.active_card_source_stack.cards count] == 0) {
                    [self setNeedsDisplayInRect:self.active_card_source_stack.rect];
                }
                [self setNeedsDisplayInRect:cs.rect];
                self.deck_just_tapped = 0;
                       
            }
            else {
                NSLog(@"KDR YEP 0");
                // When canceling a stack drag, make sure you clean up everything
                CGRect rect;
                rect = self.active_card.rect;
                rect.size.height = self.bounds.size.height-self.active_card.rect.origin.y+45;
                [self setNeedsDisplayInRect:rect];
                
                [self.active_card cancel_move];
                [self setNeedsDisplayInRect:self.active_card_source_stack.rect];

            }
            
        }
        else {
             NSLog(@"KDR YEP 1");
            [self setNeedsDisplayInRect:self.active_card.rect];
            [self.active_card cancel_move];
            [self setNeedsDisplayInRect:self.active_card_source_stack.rect];
        }
    }
    else {
         NSLog(@"KDR YEP 2");
        // Not dropped on a stack; put it back where it was
        [self setNeedsDisplayInRect:self.active_card.rect];
        [self.active_card cancel_move];
        [self setNeedsDisplayInRect:self.active_card_source_stack.rect];
        
    }
      /*
	if (_activeCard)
	{
        UITouch* touch = [touches anyObject];
        CGPoint point = [touch locationInView:self];
		[_activeCard setPos:point.x - xCap:point.y - yCap];
		
        
        // Change car deck to another
        Deck* toDeck = [self findActiveDeck:point];
        if (toDeck) {
            Card* onTopOfCard = [toDeck getTopCard];
            BOOL acceptMove = [self acceptCardMove:_activeCard.ownerDeck:toDeck:onTopOfCard];
            if(acceptMove) {
                // From deck to new deck
                BOOL ret = [_activeCard changeDeckTo:_activeCard.ownerDeck:toDeck];
                if (!ret) {
                    [_activeCard cancelMove];
                }
            } else {
                [_activeCard cancelMove];
            }
        } else {
            [_activeCard cancelMove];
        }
        
        
        [self setNeedsDisplay];
		_activeCard = nil;
        toDeck = nil;
	}
     */
    // This piece of code makes all possible moves to suitstacks
    if(self.autocomplete) {
        while([self find_card_for_suitstack]) {}
    }
    
    bool won = true;
    // Check to see if we've just won
    for(int i=0; i<[self.suitstacks count]; i++) {
        card_stack *test = (card_stack *)self.suitstacks[i];
        if([test.cards count] != 13) {
            won = false;
        }
    }
    if(won == true) {
        NSLog(@"You've won!");
        [self run_victory];
    }
    else {
        NSLog(@"Keep playing :)");
    }
    // Why did I do this?
    //self.active_card = NULL;
}

// I don't like how I designed this code; card_put_up actually increments the score.
// accept_card_move should just be the test without that side effect.
-(BOOL)accept_card_move: (card_stack *)from :(card_stack *)to :(card *)onTopOfCard
{
    /* Debug: allow all moves */
    //return true;
    
    // Once cards are in the suitstacks, they're there for good
    if (from.stack_type == suitstack || from.stack_type == deck)
        return false;
    
    if(to == from)
        return false;
    
    if(to.stack_type == deal)
        return false;
    
    if(to.stack_type == deck)
        return false;
    
    if(to.stack_type == cardstack) {
        if([to.cards count] == 0) {
            if(from.stack_type == fub) {
                // until face up blind is empty, allow cards from the fub to fill empty spaces
                return true;
            }
            else if([self.fub.cards count] == 0){
                // face up blind is empty; only allow cards of the appropriate rank
                // suit stack starter minus one, or king if ace is starter
                if(self.active_card.rank == self.suit_stack_starter-1 || (self.suit_stack_starter == 1 && self.active_card.rank == 13)) {
                    return true;
                }
            }
        }
        else if(from.stack_type == fub || from.stack_type == cardstack || from.stack_type == deal) {
            NSLog(@"dragging color: %u dropped on color: %u ranks: %d %d",self.active_card.color,onTopOfCard.color,self.active_card.rank,onTopOfCard.rank);
            if(self.active_card.color == onTopOfCard.color) {
                return false;
            }
            if(self.active_card.rank == onTopOfCard.rank-1 || (self.active_card.rank == 13 && onTopOfCard.rank == 1)) {
                return true;
            }
        }
    }
    
    if(to.stack_type == suitstack) {
        if([to.cards count] == 0 && self.active_card.rank == self.suit_stack_starter) {
            [self card_put_up];
            return true;
        }
        // Corner cases
        if(([to.cards count] != 0) && (self.active_card.suit == onTopOfCard.suit) && (self.active_card.rank == onTopOfCard.rank+1 || (self.active_card.rank == 1 && onTopOfCard.rank == 13))) {
            [self card_put_up];
            return true;
        }
    }
    
    /*
    if (to.deckType != ESource && to.deckType != ETarget)
        return false;
    
    if ([to.cardArray count]>0) {
        if (to.deckType == ESource) {
            if(_activeCard.cardType == onTopOfCard.cardType ||
               onTopOfCard.cardId != _activeCard.cardId+1 ||
               onTopOfCard.black == _activeCard.black) {
                return false;
            }
        } else if (to.deckType == ETarget) {
            if(onTopOfCard.cardId+1 != _activeCard.cardId ||
               onTopOfCard.cardType != _activeCard.cardType) {
                return false;
            }
        }
    } else {
        if(_activeCard.cardId != 13 && to.deckType == ESource)
            return false;
        
        if(to.deckType == ETarget && _activeCard.cardId != 1)
            return false;
    }
    */
    
    return false;
}

// This function tries to find and make a single valid move from any visible stack to any suit stack
- (BOOL)find_card_for_suitstack
{
    card *backup_active = self.active_card;
    
    // Over all suitstacks, check each source
    for(int i=0; i<[self.suitstacks count]; i++) {
        card *topCard = [((card_stack *)self.suitstacks[i]).cards lastObject];
        //NSLog(@"TopCard: %p",topCard);
        
        // Check cardstacks
        for(int j=0; j<[self.cardstacks count]; j++) {
            
            self.active_card = [((card_stack *)self.cardstacks[j]).cards lastObject];
            if([self accept_card_move:self.cardstacks[j] :self.suitstacks[i] :topCard]) {
                // Make the move
                [self.active_card change_stack:self.cardstacks[j] :self.suitstacks[i]];
                self.active_card = backup_active;
                [self setNeedsDisplay];
                return true;
            }
        }
        
        // Check fub
        self.active_card = [((card_stack *)self.fub).cards lastObject];
        if([self accept_card_move:self.fub :self.suitstacks[i] :topCard]) {
            // Make the move
            [self.active_card change_stack:self.fub :self.suitstacks[i]];
            self.active_card = backup_active;
            [self setNeedsDisplay];
            return true;
        }

        // Check deal
        self.active_card = [((card_stack *)self.deal).cards lastObject];
        if([self accept_card_move:self.deal :self.suitstacks[i] :topCard]) {
            // Make the move
            [self.active_card change_stack:self.deal :self.suitstacks[i]];
            self.active_card = backup_active;
            [self setNeedsDisplay];
            return true;
        }
    }
    
    self.active_card = backup_active;
    return false;
}

-(void)tryToPutUpCardAtPoint:(CGPoint)point
{
    self.active_card         = [self find_tapped_card:point];
    card_stack *source_stack = [self find_active_stack:point];
    if(self.active_card) {
        
        for(int i=0; i<4; i++) {
            card *topCard = [((card_stack *)self.suitstacks[i]).cards lastObject];
            if([self accept_card_move:source_stack :_suitstacks[i] :topCard]) {
                [self.active_card change_stack:source_stack :self.suitstacks[i]];
                [self setNeedsDisplay];
                // Check for victory
                bool won = true;
                // Check to see if we've just won
                for(int i=0; i<[self.suitstacks count]; i++) {
                    card_stack *test = (card_stack *)self.suitstacks[i];
                    if([test.cards count] != 13) {
                        won = false;
                    }
                }
                if(won == true) {
                    NSLog(@"You've won!");
                    [self run_victory];
                }
                else {
                    NSLog(@"Keep playing :)");
                }

                break;
            }
        }
    }
}

- (void)card_put_up
{
    self.score += 5;
    ssViewController * myController = (ssViewController *)[self firstAvailableUIViewController];
    if(myController != nil) {
        //NSLog(@"KDR controller obtained successfully");
        [myController update_bucks];
    }
    else {
        NSLog(@"KDR COULD NOT OBTAIN CONTROLLER");
    }
}

- (void)dealloc
{
    NSLog(@"KDR dealloc called");
}

@end
