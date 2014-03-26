//
//  ssViewController.m
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 6/2/13.
//  Copyright (c) 2013 Kevin DeRonne. All rights reserved.
//

#import "ssViewController.h"
#import "mainView.h"
#import <UIKit/UiColor.h>
#import "NSMutableArray+Shuffling.h"

@interface ssViewController ()

@property (weak, nonatomic) IBOutlet UILabel *bucks_counter;
@property (weak, nonatomic) IBOutlet UILabel *wins_counter;
@property (weak, nonatomic) IBOutlet UILabel *losses_counter;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *undo_button;
@property (weak, nonatomic) IBOutlet UISwitch *autocomplete;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *help_button;
@property (weak) UIPopoverController *myPopover;


@end

@implementation ssViewController


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    CGSize popsize;
    popsize.height = 275;
    popsize.width  = 720;
    self.myPopover = [(UIStoryboardPopoverSegue *)segue popoverController];
    [self.myPopover setPopoverContentSize:popsize animated:true];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if (self.myPopover) {
        [self.myPopover dismissPopoverAnimated:YES];
        return NO;
    }
    else {
        return YES;
    }
}

- (IBAction)start_new_game:(id)sender {
    // KDR I'm hoping I don't need to free self.cards and whatever else--that just calling init_table
    // will cause the "automatic reference counter" to free whatever I've overwritten.
    // However, I'm not particularly confident about this.
    

    self.cards = nil;

    // Remove all cards
    [[self.deck subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [[self.deal subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [[self.fub  subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    for(int i=0; i<4; i++) {
        [[self.suitstacks[i]  subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [[self.cardstacks[i]  subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    // Remove card stacks
    [self.deck removeFromSuperview];
    [self.deal removeFromSuperview];
    [self.fub  removeFromSuperview];
    for(int i=0; i<4; i++) {
        [self.suitstacks[i] removeFromSuperview];
        [self.cardstacks[i] removeFromSuperview];
    }
    
    if(self.just_won) {
        // Have to get rid of the cards differently if we just won
        NSArray *viewsToRemove = [self.view subviews];
        for (UIView *v in viewsToRemove) {
            if([v isKindOfClass:[card class]]) {
                [v removeFromSuperview];
            }
        }
    }

    [self init_table];
    
    self.score -= 45;
    if(self.just_won) {
        self.just_won = 0;
    }
    else {
        self.losses++;
    }
    [self update_bucks];
    [self update_wins];
    [self update_losses];
    
    self.active_card = nil;
    [self redraw_table];
}

- (IBAction)undo_move:(id)sender {
    
    _undo_button.enabled = false;
    
    //[mv find_card_for_suitstack];  // For testing functions
    
    NSLog(@"Active card: %@ %@ %@",self.active_card,self.active_card_dest_stack,self.active_card_source_stack);
    /* We should only get to this point without an active card if the deck tap is being undone */
    if(self.deck_just_tapped) {
        [self undo_deck_tap];
    }
    else {
        // Make sure we subtract bucks if a move to a suitstack is being undone
        if(self.active_card_dest_stack.stack_type == suitstack) {
            self.score -= 5;
            [self update_bucks];
        }
        [self.active_card change_stack:self.active_card_dest_stack:self.active_card_source_stack];
    }
    //[mv setNeedsDisplay];
}

- (void)update_ac_switch {
    [self.autocomplete setOn:self.autocomplete];
    /*
    if(mv.autocomplete) {
        [_autocomplete setOn:YES];
    }
    else {
        [_autocomplete setOn:NO];
    }
     */
    
}

- (void)update_bucks {

    self.bucks_counter.text = [NSString stringWithFormat:@"$%d",self.score];
    if(self.score < 0) {
        [self.bucks_counter setTextColor:[UIColor redColor]];
    }
    else {
        [self.bucks_counter setTextColor:[UIColor blackColor]];
    }

}

- (void)update_wins {

    self.wins_counter.text = [NSString stringWithFormat:@"Wins: %d",self.wins];
}

- (void)update_losses {

    self.losses_counter.text = [NSString stringWithFormat:@"Losses: %d",self.losses];
}

- (void)init_table {
    NSLog(@"\n\n\nDON'T BE FOOLED INIT_TABLE CALLED\n\n\n");
    self.mytest = [[ssTest alloc] init];
    [self.view addSubview:_mytest.myview];
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
    _undo_button.enabled = false;
    
    int screen_width = CGRectGetWidth(self.view.bounds);
    //int screenHeight = self.bounds.size.height;
    NSLog(@"KDR init_table screen width: %d",screen_width);
    
    self.view.restorationIdentifier = @"mainView";
    
    if (self.cards != nil) {
        NSLog(@"KDR already have cards!");
        return;
    }
    
    int card_width  = screen_width / 10;
    int card_height = card_width * 1.55;
    //int cap = (screen_width - card_width*7) / 8;
    
    
    //int toprow_spacer = card_height/1.4;
    //int second_spacer = card_height*2.1;
    
    // Since we immediately redraw table, these have no effect
    card_width = 0;
    card_height = 0;
    int toprow_spacer = 0;
    int second_spacer = 0;
    
    NSLog(@"Card width: %d %d %d",screen_width,card_width,card_height);
    
    self.backgroundImage = [UIImage imageNamed:@"background.png"];
    
    // Create card views
    self.cards =  [[NSMutableArray alloc] init];
    [self create_cards:card_width:card_height];
    [self.cards shuffle];
    
    // Associate them with the main view
    /*
     for(int i=0; i<[self.cards count]; i++) {
     [self addSubview:self.cards[i]];
     }
     */
    
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
        card_stack *asuitstack = [[card_stack alloc] initWithData:(i*card_width+(i*50)):toprow_spacer:card_width:card_height:suitstack];
        if(i==0) {
            card* card = [self get_random_card];
            [card setFace_up:true];
            [asuitstack add_card:card];
            self.suit_stack_starter = card.rank;
            card = nil;
        }
        else {
            
            asuitstack.layer.borderWidth = 1;
            asuitstack.layer.borderColor = [[UIColor whiteColor] CGColor];
        }
        [self.suitstacks addObject:asuitstack];
        [self.view addSubview:asuitstack];
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
    self.deal = [[card_stack alloc] initWithData:0:0:card_width:card_height:deal];
    self.deal.layer.borderWidth = 1;
    self.deal.layer.borderColor = [[UIColor whiteColor] CGColor];
    
    // Create four card stacks
    for(int i=0; i<4; i++) {
        card_stack *acardstack = [[card_stack alloc] initWithData:0:second_spacer:card_width:card_height:cardstack];
        
        card* card = [self get_random_card];
        [card setFace_up:true];
        [acardstack add_card:card];
        card = nil;
        
        [self.cardstacks addObject:acardstack];
        [self.view addSubview:acardstack];
        acardstack = nil;
    }
    [self.view addSubview:self.deck];
    [self.view addSubview:self.deal];
    [self.view addSubview:self.fub];
    self.active_card = NULL;
}

- (void)redraw_table
{
    
    //int screen_width = self.bounds.size.width;
    int screen_width = CGRectGetWidth(self.view.bounds);
    //int screenHeight = self.bounds.size.height;
    NSLog(@"Redraw_table called KDR screen width: %d",screen_width);
    
    int card_width = screen_width / 10;
    int card_height = card_width * 1.55;
    
    int toprow_spacer = card_height/2.0;
    int second_spacer = card_height*2.0;
    
    
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
    //_fub.layer.borderWidth = 1;
    //_fub.layer.borderColor = [[UIColor orangeColor] CGColor];
    
    NSLog(@"before suit stacks");
    // Resize the four suit stacks
    for(int i=0; i<4; i++) {
        [_suitstacks[i] resize:(card_width*4)+(i*card_width+(i*50)):toprow_spacer:card_width:card_height];
        //((card_stack *)_suitstacks[i]).layer.borderWidth = 2;
        //((card_stack *)_suitstacks[i]).layer.borderColor = [[UIColor blueColor] CGColor];
    }
    
    [_deck resize:card_width/5:second_spacer:card_width:card_height];
    
    //_deck.layer.borderWidth = 2;
    //_deck.layer.borderColor = [[UIColor redColor] CGColor];
    
    [_deal resize:card_width+(card_width/5)+20:second_spacer:card_width:card_height];
    
    //_deal.layer.borderWidth = 2;
    //_deal.layer.borderColor = [[UIColor blackColor] CGColor];
    
    NSLog(@"Before card stacks");
    for(int i=0; i<4; i++) {
        [_cardstacks[i] resize:(card_width*4)+(i*card_width+(i*50)):second_spacer:card_width:card_height];
        //((card_stack *)_cardstacks[i]).layer.borderWidth = 2;
        //((card_stack *)_cardstacks[i]).layer.borderColor = [[UIColor greenColor] CGColor];
        
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
    //[self setNeedsDisplay];
}

- (void)init_table_trivial
{
    
    int screen_width = CGRectGetWidth(self.view.bounds);
    self.view.restorationIdentifier = @"mainView";
    
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
        [self.view addSubview:asuitstack];
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
        [self.view addSubview:acardstack];
        acardstack = nil;
    }
    
    [self.view addSubview:self.deal];
    [self.view addSubview:self.deck];
    [self.view addSubview:self.fub];
    
    
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
    
    int screen_width = CGRectGetWidth(self.view.bounds);
    self.view.restorationIdentifier = @"mainView";
    
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

-(void)create_cards:(int)width :(int)height {
    NSString *back_img = @"cardback.png";
    
    for (int i=1; i<=13; i++) {
        NSString* face_img = [NSString stringWithFormat:@"club%d.png",i];
        NSString* cap_img = [NSString stringWithFormat:@"c.club%d.png",i];
        card *acard = [[card alloc] initWithData:Clubs:i:face_img:back_img:cap_img:0:0:i:width:height];
        [acard setColor:Black];
        [self.cards addObject:acard];
        acard = nil;
    }
    
    for (int i=1; i<=13; i++) {
        NSString* face_img = [NSString stringWithFormat:@"diamond%d.png",i];
        NSString* cap_img = [NSString stringWithFormat:@"c.diamond%d.png",i];
        card *acard = [[card alloc] initWithData:Diamonds:i:face_img:back_img:cap_img:0:0:i:width:height];
        [acard setColor:Red];
        [self.cards addObject:acard];
        acard = nil;
    }
    
    for (int i=1; i<=13; i++) {
        NSString* face_img = [NSString stringWithFormat:@"heart%d.png",i];
        NSString* cap_img = [NSString stringWithFormat:@"c.heart%d.png",i];
        card *acard = [[card alloc] initWithData:Hearts:i:face_img:back_img:cap_img:0:0:i:width:height];
        [acard setColor:Red];
        [self.cards addObject:acard];
        acard = nil;
    }
    
    for (int i=1; i<=13; i++) {
        NSString* face_img = [NSString stringWithFormat:@"spade%d.png",i];
        NSString* cap_img = [NSString stringWithFormat:@"c.spade%d.png",i];
        card *acard = [[card alloc] initWithData:Spades:i:face_img:back_img:cap_img:0:0:i:width:height];
        [acard setColor:Black];
        [self.cards addObject:acard];
        acard = nil;
    }
    
    
}

-(card*)get_random_card {
    card* ret = nil;
    int r = 0;
    
    unsigned long max = ([self.cards count]-1);
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
        if(CGRectContainsPoint(cs.frame,point))
        {
            return cs;
        }
    }
    
    for(card_stack *cs in self.suitstacks)
    {
        if(CGRectContainsPoint(cs.frame,point))
        {
            return cs;
        }
    }
    
    if(CGRectContainsPoint(self.deck.frame,point))
    {
        return self.deck;
    }
    
    if(CGRectContainsPoint(self.deal.frame,point))
    {
        return self.deal;
    }
    
    if(CGRectContainsPoint(self.fub.frame,point))
    {
        return self.fub;
    }
    
    return nil;
}

-(card_stack *)find_active_stack_rect:(CGRect)rect
{
    
    
    for(card_stack *cs in self.cardstacks)
    {
        if(CGRectIntersectsRect(cs.frame, rect))
        {
            return cs;
        }
    }
    
    for(card_stack *cs in self.suitstacks)
    {
        if(CGRectIntersectsRect(cs.frame, rect))
        {
            return cs;
        }
    }
    if(CGRectIntersectsRect(self.deck.frame,rect))
    {
        return self.deck;
    }
    if(CGRectIntersectsRect(self.deal.frame,rect))
    {
        return self.deal;
    }
    
    if(CGRectIntersectsRect(self.fub.frame,rect))
    {
        return self.fub;
    }
    
    return nil;
}

-(card_stack *)find_stack_under_hover:(UIImageView*)hover
{
    // Get the coordinates of hover relative to its stack (its super view)
    UIView *hover_superview     = [hover superview];
    //CGRect hover_superview_rect = [hover_superview convertRect:hover.bounds fromView:hover];
    
    // Get the coordinates of hover relative to the main view
    CGRect hover_mainview_rect  = [self.view convertRect:hover.frame fromView:hover_superview];
    
    for(card_stack *cs in self.cardstacks)
    {
        if(CGRectIntersectsRect(cs.frame, hover_mainview_rect))
        {
            return cs;
        }
    }
    
    for(card_stack *cs in self.suitstacks)
    {
        if(CGRectIntersectsRect(cs.frame, hover_mainview_rect))
        {
            return cs;
        }
    }
    if(CGRectIntersectsRect(self.deck.frame, hover_mainview_rect))
    {
        return self.deck;
    }
    if(CGRectIntersectsRect(self.deal.frame, hover_mainview_rect))
    {
        return self.deal;
    }
    
    if(CGRectIntersectsRect(self.fub.frame, hover_mainview_rect))
        
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


        [self update_bucks];
        [self update_wins];
        _undo_button.enabled = false;
      
        // Visual "reward" for winning
        
        int offset = 75;
        int stacknum = 0;
        for(card_stack *cs in self.suitstacks) {
            int cardnum  = 0;
            for(card *card in cs.cards) {
                [card removeFromSuperview];  // not necessary I believe; a view can only have one superview
                [self.view addSubview:card];
                card.card_parent = nil;
                float x = (cardnum*card.frame.size.width*0.735)+10;
                float y = offset+(stacknum*card.frame.size.height);
                CGRect rect = card.frame;
                CGPoint point;
                point.x = x;
                point.y = y;
                rect.origin = point;
                
                [card setFrame:rect];
                card.card_parent  = nil;
                
                int screen_width  = CGRectGetWidth(self.view.bounds);
                int screen_height = CGRectGetHeight(self.view.bounds);
                if(x> screen_width || y>screen_height) {
                    NSLog(@"KDR OUT OF BOUNDS!!!!!!!!!!!!!");
                }
                //NSLog(@"x: %f y %f height: %f stacknum: %d",x, y,card.rect.size.height,stacknum);
                
                
                //[self setNeedsDisplayInRect:rect];
                
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
    CGPoint point       = [touchPoint locationInView:self.view];
	
    //_prev_point = point;
    
    UIView *viewTapped = [self.view hitTest:point withEvent:event];
    if([viewTapped isKindOfClass:[card class]]) {
        self.active_card = (card *)viewTapped;
        self.active_card_source_stack = (card_stack *)[viewTapped superview];
        [self.active_card save_pos];
        NSLog(@"active card started at: %f %f",self.active_card.frame.origin.x,self.active_card.frame.origin.y);
        
        // Ensure proper z-ordering, even when dragging a stack
        [[viewTapped superview] bringSubviewToFront:viewTapped];
        
        [self.view bringSubviewToFront:[viewTapped superview]];
        card *cp = ((card *)viewTapped).card_parent;
        while(cp) {
            [[cp superview] bringSubviewToFront:cp];
            cp = cp.card_parent;
        }
        
    }
    else {
        //NSLog(@"No card tapped");
        self.active_card = nil;
    }
    
    //self.active_card  = [self find_tapped_card:point];
    
    
    if(self.active_card) {
        //NSLog(@"Tapped: rank: %d suit: %u",self.active_card.rank,self.active_card.suit);
        self.xCap = point.x - self.active_card.frame.origin.x;
        self.yCap = point.y - self.active_card.frame.origin.y;
    }
    
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    //ssViewController *vc = (ssViewController *)[self firstAvailableUIViewController];
    
    
    
    UITouch* touch = [touches anyObject];
    CGPoint point  = [touch locationInView:self.view];
    
    //if(CGRectContainsPoint([vc.cardback frame], point)) {
    //    vc.cardback.center = point;
    //}
    
	if (self.active_card && (self.just_won || self.active_card_source_stack.stack_type != deck))
	{
        
		[self.active_card set_pos:point.x - self.xCap:point.y - self.yCap];
		
        //[self setNeedsDisplay];
        
        // Optimize drawing with clipping when user moves cards
        
        //int x = ABS(_prev_point.x - point.x) + 45;
        //int y = ABS(_prev_point.y - point.y) + 45;
        //_prev_point = point;
        
        
        //  Slower, though possibly smoother, animation
        /*
         int x = point.x;
         int y = point.y;
         */
        
        //CGRect rect;
        //rect = self.active_card.frame;
        //rect.origin.x -= x;
        //rect.origin.y -= y;
        //rect.size.width += x*2;
        //rect.size.height = self.bounds.size.height-self.active_card.frame.origin.y+45;
        //self.active_card.frame = rect;
        //[self setNeedsDisplayInRect:rect];
        
        //[self setNeedsDisplay];
    }
}
- (void)undo_deck_tap
{
    NSLog(@"KDR Undoing deck tap");
    if([self.deal.cards count] == 0) {
        /* Move everything from the deck back to the deal */
        unsigned long deck_count =[self.deck.cards count];
        for(int i=0; i<deck_count; i++) {
            [self.deal add_card:[self.deck get_top_card]];
            [[self.deal.cards lastObject] setFace_up:true];
        }
        //[self setNeedsDisplayInRect:self.deal.frame];
        
    }
    else {
        /* Take the top 3 cards from the deal and move them to the deck */
        unsigned long deal_count = [self.deal.cards count];
        for(int i=0; i<self.deck_just_tapped && i<deal_count; i++) {
            [self.deck add_card:[self.deal get_top_card]];
            [[self.deck.cards lastObject] setFace_up:false];
        }
    }
    
    if([self.deal.cards count] == 0) {
        self.deal.layer.borderWidth = 1;
        self.deal.layer.borderColor = [[UIColor whiteColor] CGColor];
    }
    
    self.active_card = NULL;
    // Refresh the appropriate rectangles
    
    //[self setNeedsDisplayInRect:self.deck.frame];
    
    if([self.deal.cards count] == 0) {
        //[self setNeedsDisplayInRect:self.deal.frame];
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
    NSLog(@"Deck has %lu cards",(unsigned long)[self.deck.cards count]);
    NSLog(@"Deal has %lu cards",(unsigned long)[self.deal.cards count]);
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(self.just_won)
        return;
    
    card_stack *cs;
    //NSLog(@"Called touchesEnded");
    if(self.active_card) {
        //NSLog(@"KDR KDR active card %@",self.active_card);
        cs = [self find_stack_under_hover:self.active_card];
        //NSLog(@"active card ended at: %f %f",self.active_card.frame.origin.x,self.active_card.frame.origin.y);
    }
    else {
        UITouch* touchPoint = [touches anyObject];
        CGPoint point       = [touchPoint locationInView:self.view];
        cs = [self find_active_stack:point];
    }
    
    bool emptystack = false;
    // If the deck is empty, we have to be able to detect a click on it with no card
    if(!cs) {
        UITouch* touch = [touches anyObject];
        CGPoint point  = [touch locationInView:self.view];
        cs = [self find_active_stack:point];
        emptystack = true;
        NSLog(@"\n\nKDR Couldn't find cs!");
    }
    
    //[self.active_card cancel_move];
    //[self setNeedsDisplay];
    if(cs) {
        if(cs.stack_type == deck) {
            NSLog(@"Card dropped on deck");
        }
        if(cs.stack_type == deal) {
            NSLog(@"Card dropped on deal");
        }
        if(cs.stack_type == suitstack) {
            NSLog(@"Card dropped on suitstack");
        }
        if(cs.stack_type == cardstack) {
            NSLog(@"Card dropped on cardstack");
        }
        if(cs.stack_type == fub) {
            NSLog(@"Card dropped on fub");
        }
        
        if(cs.stack_type == deck && (self.active_card_source_stack.stack_type == deck || [self.deck.cards count] == 0)) {
            
            // When canceling a stack drag, make sure you clean up everything
            /*
             CGRect rect;
             rect = self.active_card.frame;
             rect.size.height = self.bounds.size.height-self.active_card.frame.origin.y+45;
             [self setNeedsDisplayInRect:rect];
             
             [self.active_card cancel_move];
             [self setNeedsDisplayInRect:self.active_card_source_stack.frame];
             */
            
            
            NSLog(@"KDR Tapped deck");
            if([self.deck.cards count] == 0) {
                NSLog(@"KDR out of cards");
                /* Move everything from the deal to the deck */
                unsigned long deal_count =[self.deal.cards count];
                for(int i=0; i<deal_count; i++) {
                    [self.deck add_card:[self.deal get_top_card]];
                    [[self.deck.cards lastObject] setFace_up:false];
                }
                //[self setNeedsDisplayInRect:self.deck.frame];
                
                
            }
            else {
                /* Take up to 3 cards from the deck and move them to the deal */
                unsigned long deck_count = [self.deck.cards count];
                self.deck_just_tapped = 0;
                for(int i=0; i<3 && i<deck_count; i++) {
                    [self.deal add_card:[self.deck get_top_card]];
                    //[[self.deal.cards lastObject] setFace_up:true];
                    self.deck_just_tapped++;
                }
            }
            _undo_button.enabled = true;
            self.active_card = NULL;
            // Refresh the appropriate rectangles
            
            if([self.deck.cards count] == 0) {
                
                self.deck.layer.borderWidth = 1;
                self.deck.layer.borderColor = [[UIColor whiteColor] CGColor];
            }
            
            if([self.deal.cards count] == 0) {
                // Reset the size of the rectangle for the deal
                CGRect rec = self.deal.frame;
                rec.size = CGSizeMake(rec.size.width, self.deck.frame.size.height);
                [self.deal setFrame:rec];
                
                self.deal.layer.borderWidth = 1;
                self.deal.layer.borderColor = [[UIColor whiteColor] CGColor];
                
            }
            
            //[self setNeedsDisplay];
            NSLog(@"Deck has %lu cards",(unsigned long)[self.deck.cards count]);
            NSLog(@"Deal has %lu cards",(unsigned long)[self.deal.cards count]);
        }
        else if(cs.stack_type == cardstack || cs.stack_type == suitstack){
            card *dropped_on = [cs.cards lastObject];
            if([self accept_card_move:self.active_card_source_stack :cs :dropped_on]) {
                //[cs add_card:self.active_card];
                //[self.active_card_source_stack remove_card:self.active_card];
                
                self.active_card_dest_stack = cs;
                
                _undo_button.enabled = true;
                //[self setNeedsDisplayInRect:self.active_card.frame];
                
                //CGRect rect;
                //rect = self.active_card.frame;
                //rect.size.height = self.bounds.size.height-self.active_card.frame.origin.y+45;
                //[self setNeedsDisplayInRect:rect];
                
                
                [self.active_card change_stack:self.active_card_source_stack:cs];
                
                // Redraw the white rectangle if there are no more cards
                //if([self.active_card_source_stack.cards count] == 0) {
                //    [self setNeedsDisplayInRect:self.active_card_source_stack.frame];
                //}
                //[self setNeedsDisplayInRect:cs.frame];
                self.deck_just_tapped = 0;
                
            }
            else {
                NSLog(@"KDR Card move to cardstack or suitstack canceled: Not accepted");
                // When canceling a stack drag, make sure you clean up everything
                CGRect rect;
                rect = self.active_card.frame;
                rect.size.height = self.view.bounds.size.height-self.active_card.frame.origin.y+45;
                //[self setNeedsDisplayInRect:rect];
                
                [self.active_card cancel_move];
                //[self setNeedsDisplayInRect:self.active_card_source_stack.frame];
                
            }
            
        }
        else {
            NSLog(@"KDR Card Move to invalid stack type");
            //[self setNeedsDisplayInRect:self.active_card.frame];
            [self.active_card cancel_move];
            //[self setNeedsDisplayInRect:self.active_card_source_stack.frame];
        }
    }
    else {
        NSLog(@"KDR Card move to nowhere");
        // Not dropped on a stack; put it back where it was
        //[self setNeedsDisplayInRect:self.active_card.frame];
        [self.active_card cancel_move];
        //[self setNeedsDisplayInRect:self.active_card_source_stack.frame];
        
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
        //NSLog(@"You've won!");
        [self run_victory];
    }
    else {
        //NSLog(@"Keep playing :)");
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
                //[self setNeedsDisplay];
                return true;
            }
        }
        
        // Check fub
        self.active_card = [((card_stack *)self.fub).cards lastObject];
        if([self accept_card_move:self.fub :self.suitstacks[i] :topCard]) {
            // Make the move
            [self.active_card change_stack:self.fub :self.suitstacks[i]];
            self.active_card = backup_active;
            //[self setNeedsDisplay];
            return true;
        }
        
        // Check deal
        self.active_card = [((card_stack *)self.deal).cards lastObject];
        if([self accept_card_move:self.deal :self.suitstacks[i] :topCard]) {
            // Make the move
            [self.active_card change_stack:self.deal :self.suitstacks[i]];
            self.active_card = backup_active;
            //[self setNeedsDisplay];
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
                //[self setNeedsDisplay];
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

- (void)card_put_up{
    self.score += 5;
    [self update_bucks];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _restorationIdentifier = @"ssViewController";
    //self.identifier = @"ssViewController";
    self.view.restorationIdentifier = @"mainView";
    
	// Do any additional setup after loading the view, typically from a nib.
    
    NSLog(@"KDR viewDidLoad called");

    
    NSLog(self.do_init_table ? @"do_init table is YES" : @" do_init table is NO");

    //NSLog(@"Deck has %d",[self.deck.cards count]);
    
    //if(self.do_init_table) {



    //[self init_table];

    //[self init_table_trivial]; self.autocomplete = true;
    //[self init_table_debug];

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    tapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapGesture];
    [self.view addSubview:self.mytest.myview];

    /*
    }
    else {
        [self update_wins];
        [self update_losses];
        [self update_bucks];
    }
     */
    self.do_init_table = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    NSLog(@"viewDidAppear called view: %@",self.view);
    
    int i = 0;
    for(UIView *s in [self.view subviews]) {
        NSLog(@"Subview %d %@",i,s);
        i++;
    }

    if(self.do_init_table) {
    //if(0) {
        self.score  = -45;
        self.wins   = 0;
        self.losses = 0;
        [self.autocomplete setOn:true];
        
        [self update_wins];
        [self update_losses];
        [self update_bucks];
        [self init_table];
        
        self.do_init_table = NO;
    }
    //[self redraw_table];
    
}

- (void)handleTapGesture:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateRecognized) {
        // handling code
        
        CGPoint point = [sender locationInView:self.view];
        // Put up the card under point if possible
        NSLog(@"double tap recognized at %f,%f",point.x,point.y);
        [self tryToPutUpCardAtPoint:point];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    //NSLog(@"KDR viewWillAppear called init_table is %d",self.do_init_table);
    
    //NSLog(@"KDR self: %@",self.view);

    //NSLog(@"KDR view: %@",mv);
    //NSLog(@"KDR score is: %d",self.score);

    

}
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
  // Redraw cards that are already on the table
    NSLog(@"Just rotated");
    [self redraw_table];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// returns the URL to the application's Documents directory
- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

-(void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    
    NSLog(@"KDR encoding state");
    // If you don't call this, decodeRestorableStateWithCoder doesn't get called.
    //[super encodeRestorableStateWithCoder:coder ];
    
    for(UIView *v in [self.view subviews]) {
        NSLog(@"at encoding time, %@",v);
    }
    
    //[coder encodeObject:(mainView *)self.view forKey:@"mainView"];
    
    [coder encodeInt:self.score forKey:@"score"];
    [coder encodeInt:self.wins  forKey:@"wins"];
    [coder encodeInt:self.just_won  forKey:@"just_won"];
    [coder encodeInt:self.losses  forKey:@"losses"];
    [coder encodeBool:self.autocomplete  forKey:@"autocomplete"];
    [coder encodeInt:self.xCap  forKey:@"xCap"];
    [coder encodeInt:self.yCap  forKey:@"yCap"];
    [coder encodeInt:self.suit_stack_starter  forKey:@"suit_stack_starter"];
    [coder encodeObject:self.mytest forKey:@"testkey"];
    
    //[coder encodeInt:((card *)self.fub.cards[0]).rank forKey:@"fub"];
    
    [coder encodeObject:self.cards forKey:@"cards"];
    [coder encodeObject:self.suitstacks forKey:@"suitstacks"];
    [coder encodeObject:self.cardstacks forKey:@"cardstacks"];
    [coder encodeObject:self.fub forKey:@"fub"];
    [coder encodeObject:self.deck forKey:@"deck"];
    [coder encodeObject:self.deal forKey:@"deal"];

    
    /*
    mainView *mv = (mainView *)self.view;
    NSURL *dataFileURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"SavedData"];
    [NSKeyedArchiver archiveRootObject:mv toFile:[dataFileURL path]];

    
    //card_stack *deck = mv.deck;
     */
    [super encodeRestorableStateWithCoder:coder];
     
    NSLog(@"KDR State encoded");
}

-(void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    
    NSLog(@"KDR decoding state");
    [super decodeRestorableStateWithCoder:coder];
    
    self.do_init_table = false;
    
    if([coder containsValueForKey:@"fub"]) {
        NSLog(@"Fub in coder");
    }
    
    NSLog(@"Fub before decoding: %@",self.fub);
    self.score        = [coder decodeIntForKey:@"score"];
    self.wins         = [coder decodeIntForKey:@"wins"];
    self.losses       = [coder decodeIntForKey:@"losses"];
    self.just_won     = [coder decodeIntForKey:@"just_won"];
    self.xCap         = [coder decodeIntForKey:@"xCap"];
    self.yCap         = [coder decodeIntForKey:@"yCap"];
    //self.autocomplete = [coder decodeBoolForKey:@"autocomplete"];
    self.suit_stack_starter = [coder decodeIntForKey:@"suit_stack_starter"];
    
    

    self.cards      = [coder decodeObjectForKey:@"cards"];
    self.suitstacks = [coder decodeObjectForKey:@"suitstacks"];
    self.cardstacks = [coder decodeObjectForKey:@"cardstacks"];
    self.fub        = [coder decodeObjectForKey:@"fub"];
    self.deck       = [coder decodeObjectForKey:@"deck"];
    self.deal       = [coder decodeObjectForKey:@"deal"];
    
    
    self.mytest = [coder decodeObjectForKey:@"testkey"];
    NSLog(@"view in decode: %@",self.view);
    NSLog(@"simple int: %d",self.mytest.simple);
    NSLog(@"test view: %@",self.mytest.myview);
    
    NSLog(@"view has image: %@",self.mytest.myview.image);
    [self.mytest.myview setHidden:false];
    [self.view addSubview:self.mytest.myview];
    
    [self update_bucks];
    [self update_wins];
    [self update_losses];
    [self update_ac_switch];
    
    /*
    [self.view addSubview:self.deck];
    [self.view addSubview:self.deal];
    [self.view addSubview:self.fub];
     */
    int i = 0;
    for(UIView *s in [self.view subviews]) {
        NSLog(@"Subview %d %@",i,s);
        i++;
    }
    

    /*
    [self.cardstacks removeAllObjects];
    [self.suitstacks removeAllObjects];

    int suitstack_number = 0;
    int cardstack_number = 0;
    for(UIView *s in [self subviews]) {
        NSLog(@"Subview %d %@",i,s);
        
        if([s isKindOfClass:[card_stack class]]) {
            NSString *stack_type = [s.restorationIdentifier substringWithRange:NSMakeRange(9,1)];
            if([stack_type isEqualToString:@"0"]) {
                self.fub = (card_stack *)s;
                [self.fub.cards removeAllObjects]; // Necessary because init table gets called before we get here.  (bug/hack, really)
                for(UIImageView *c in [self.fub subviews]) {
                    //NSLog(@"Subview of fub: %@",c.restorationIdentifier);
                    [self.fub.cards addObject:c];
                }
            }
            else if([stack_type isEqualToString:@"1"]) {
                [self.suitstacks addObject:s];
                for(UIImageView *c in [s subviews]) {
                    //NSLog(@"Subview of deck: %@",c.restorationIdentifier);
                    [((card_stack *)self.suitstacks[suitstack_number]).cards addObject:c];
                }
                suitstack_number++;
                
            }
            else if([stack_type isEqualToString:@"2"]) {
                                [self.cardstacks addObject:s];
                for(UIImageView *c in [self.deck subviews]) {
                    //NSLog(@"Subview of deck: %@",c.restorationIdentifier);
                    [self.deck.cards addObject:c];
                }

            }
            else if([stack_type isEqualToString:@"3"]) {
                self.deck = (card_stack *)s;
                [self.deck.cards removeAllObjects];
                for(UIImageView *c in [self.deck subviews]) {
                    //NSLog(@"Subview of deck: %@",c.restorationIdentifier);
                    [self.deck.cards addObject:c];
                }
                 NSLog(@"Deck at decode time has %d cards",[((card_stack *)s).cards count]);
            }
            else if([stack_type isEqualToString:@"4"]) {
                self.deal = (card_stack *)s;
                // No need to remove cards from deal as init_table doesn't produce any
                NSLog(@"Deal at decode time has %d cards",[((card_stack *)s).cards count]);
                for(UIImageView *c in [self.deck subviews]) {
                    //NSLog(@"Subview of deck: %@",c.restorationIdentifier);
                    [self.deck.cards addObject:c];
                }

            }

        }
        
        i++;
    }
    
  
    int numberOfSuitstacks = 0;
    for(UIView *s in self.suitstacks) {
        //[self addSubview:s];
        numberOfSuitstacks++;
    }
    NSLog(@"Number of suitstacks: %d",numberOfSuitstacks);
    
    int numberOfCardstacks = 0;
    for(UIView *s in self.cardstacks) {
        //[self addSubview:s];
        numberOfCardstacks++;
    }
    NSLog(@"Number of cardstacks: %d",numberOfCardstacks);
    
    NSLog(@"made it HERE");
     
    
    NSArray *viewsToRestore = [self subviews];
    for (card_stack *v in viewsToRestore) {
        if([v isKindOfClass:[card_stack class]]) {
            [v makeSubViewsOfCards];
        }
    }
    

    //[[self subviews] makeObjectsPerformSelector:@selector(makeSubViewsOfCards)];
    
    // Even if we call init_table here it doesn't set things up properly.
    // self.view pointer is different?

    NSLog(@"KDR score is %d",self.score);
    NSLog(@"KDR deck has %d",[self.deck.cards count]);
  
    
    NSURL *dataFileURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"SavedData"];
    self.view = [NSKeyedUnarchiver unarchiveObjectWithFile:[dataFileURL path]];

     
    
    
    if([coder containsValueForKey:@"mainview"]) {
        NSLog(@"KDR decoding state: %@",self.view);
        self.do_init_table = false;
        //        mainView *self = (mainView *)self.view;
     
        [super decodeRestorableStateWithCoder:coder];
        //[self.view setNeedsDisplay];
    }
    else {
        self.do_init_table = true;
    }
     */
    //NSLog(@"KDR self.view: %@",self.view);
    
}
@end
