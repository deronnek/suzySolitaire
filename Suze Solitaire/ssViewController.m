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

@property (weak, nonatomic) IBOutlet UIBarButtonItem *bucks_counter;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *wins_counter;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *losses_counter;
@property (weak, nonatomic) IBOutlet UIToolbar *topToolBar;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *undo_button;
@property (weak, nonatomic) IBOutlet UISwitch *autocomplete;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *help_button;
@property (weak) UIPopoverController *myPopover;


@property bool do_init_table;
@property (nonatomic, copy) NSString *restorationIdentifier;
@property (strong, nonatomic) IBOutlet UIImageView *cardback;

// These next two keep the card under the cursor where it's grabbed instead
// of always at the upper left corner
@property    int xCap;
@property    int yCap;

@property (nonatomic, retain) UIImage* backgroundImage;

// Active card under user touch
@property    card *active_card;
@property    card_stack *active_card_source_stack;
@property    card_stack *active_card_dest_stack;

@property (nonatomic) int score;
@property (nonatomic) int wins;
@property (nonatomic) int losses;
@property int deck_just_tapped;
@property int just_won;
@property ssTest *mytest;

@property    (nonatomic, retain) NSMutableArray *cards; // Initial deck to pull from when setting up a game
@property    (nonatomic, retain) NSMutableArray *suitstacks;
@property    (nonatomic, retain) NSMutableArray *cardstacks;
@property    (nonatomic, retain) card_stack     *fub;  // The "face up blind" stack
@property    (nonatomic, retain) card_stack     *deck; // The stack from which cards are drawn
@property    (nonatomic, retain) card_stack     *deal; // The stack containing previously drawn cards

@property (nonatomic, strong) NSMutableArray *viewTagToCard;  // Allows us to quickly figure out which card was tapped
@property (nonatomic, strong) NSMutableArray *viewTagToStack; // Allows us to quickly figure out which stack was tapped

@property    int suit_stack_starter;

@end

@implementation ssViewController

-(NSMutableArray *)viewTagToCard {
    if(!_viewTagToCard) {
        _viewTagToCard  = [[NSMutableArray alloc] initWithCapacity:52];
        for(int i=0; i<52; i++) {
            [_viewTagToCard  addObject:[NSNull null]];
        }
    }
    return _viewTagToCard;
}

-(NSMutableArray *)viewTagToStack {
    if(!_viewTagToStack) {
        _viewTagToStack = [[NSMutableArray alloc] initWithCapacity:52];
        for(int i=0; i<52; i++) {
            [_viewTagToStack addObject:[NSNull null]];
        }
    }
    return _viewTagToStack;
}

- (void)setWins:(int)wins {
    _wins = wins;
    self.wins_counter.title = [NSString stringWithFormat:@"Wins: %d",_wins];
}

- (void)setScore:(int)score {
    _score = score;
    
    self.bucks_counter.title = [NSString stringWithFormat:@"$%d",_score];
    if(_score < 0) {
        [self.bucks_counter setTintColor:[UIColor redColor]];
    }
    else {
        [self.bucks_counter setTintColor:[UIColor blackColor]];
    }
}

- (void)setLosses:(int)losses {
    _losses = losses;
    self.losses_counter.title = [NSString stringWithFormat:@"Losses: %d",_losses];
}


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
    // Based on my memory usage not going up substantially with successive "new game" taps, I think I'm good.

    self.cards = nil;

    // Remove all cards
    [[self.deck.view subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [[self.deal.view subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [[self.fub.view  subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    for(int i=0; i<4; i++) {
        [[((card_stack *)self.suitstacks[i]).view  subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [[((card_stack *)self.cardstacks[i]).view  subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    //[self setWins:1000];
    
    // Remove card stacks
    [self.deck.view removeFromSuperview];
    [self.deal.view removeFromSuperview];
    [self.fub.view  removeFromSuperview];
    for(int i=0; i<4; i++) {
        [((card_stack *)self.suitstacks[i]).view removeFromSuperview];
        [((card_stack *)self.cardstacks[i]).view removeFromSuperview];
    }
    
    if(self.just_won) {
        // Have to get rid of the cards differently if we just won
        NSArray *viewsToRemove = [self.view subviews];
        for (UIView *v in viewsToRemove) {
            if([v isKindOfClass:[UIImageView class]]) {
                [v removeFromSuperview];
            }
        }
    }

    //[self init_table_trivial];
    [self init_table];
    
    self.score -= 45;
    if(self.just_won) {
        self.just_won = 0;
    }
    else {
        self.losses++;
    }
    
    self.active_card = nil;
    [self redraw_table];
}

- (IBAction)undo_move:(id)sender {
    
    _undo_button.enabled = false;
    
    //[self.find_card_for_suitstack];  // For testing functions by tapping the undo button
    
    NSLog(@"Active card: %@ %@ %@",self.active_card,self.active_card_dest_stack,self.active_card_source_stack);
    /* We should only get to this point without an active card if the deck tap is being undone */
    if(self.deck_just_tapped) {
        [self undo_deck_tap];
    }
    else {
        // Make sure we subtract bucks if a move to a suitstack is being undone
        if(self.active_card_dest_stack.stack_type == suitstack) {
            self.score -= 5;
        }
        [self change_stack:self.active_card:self.active_card_dest_stack:self.active_card_source_stack];
    }
}

- (void)update_ac_switch {
    [self.autocomplete setOn:self.autocomplete];
}

- (void)init_table {
    NSLog(@"\n\n\nDON'T BE FOOLED INIT_TABLE CALLED\n\n\n");
    
    _undo_button.enabled = false;
    
    int screen_width = CGRectGetWidth(self.view.bounds);
    NSLog(@"KDR init_table screen width: %d",screen_width);
    
    self.view.restorationIdentifier = @"mainView";
    
    if (self.cards != nil) {
        NSLog(@"KDR already have cards!");
        return;
    }
    
    int card_width  = screen_width / 10;
    int card_height = card_width * 1.55;
    
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
        self.viewTagToCard[card.view.tag]  = card;
        self.viewTagToStack[card.view.tag] = self.fub;
        
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
            self.viewTagToCard[card.view.tag]  = card;
            self.viewTagToStack[card.view.tag] = asuitstack;
            card = nil;
        }
        else {
            
            asuitstack.view.layer.borderWidth = 1;
            asuitstack.view.layer.borderColor = [[UIColor whiteColor] CGColor];
        }
        [self.suitstacks addObject:asuitstack];
        [self.view addSubview:asuitstack.view];
        asuitstack = nil;
    }
    
    // Create the deck
    self.deck = [[card_stack alloc] initWithData:card_width/5:second_spacer:card_width:card_height:deck];
    for(int i=0; i<34; i++) {
        card* card = [self get_random_card];
        [self.deck add_card:card];
        self.viewTagToCard[card.view.tag]  = card;
        self.viewTagToStack[card.view.tag] = self.deck;
        card = nil;
    }
    
    // Create the deal
    self.deal = [[card_stack alloc] initWithData:0:0:card_width:card_height:deal];
    self.deal.view.layer.borderWidth = 1;
    self.deal.view.layer.borderColor = [[UIColor whiteColor] CGColor];
    
    // Create four card stacks
    for(int i=0; i<4; i++) {
        card_stack *acardstack = [[card_stack alloc] initWithData:0:second_spacer:card_width:card_height:cardstack];
        
        card* card = [self get_random_card];
        [card setFace_up:true];
        [acardstack add_card:card];
        
        self.viewTagToCard[card.view.tag]  = card;
        self.viewTagToStack[card.view.tag] = acardstack;

        card = nil;
        
        [self.cardstacks addObject:acardstack];
        [self.view addSubview:acardstack.view];
        

        acardstack = nil;
    }
    NSLog(@"self.deck.view: %@",self.deck.view);
    [self.view addSubview:self.deck.view];
    [self.view addSubview:self.deal.view];
    [self.view addSubview:self.fub.view];
    self.active_card = NULL;
}
/* 
 This function is where the table layout actually gets done.  init_table just sets up the structures
 */
- (void)redraw_table {
    
    //int screen_width = self.bounds.size.width;
    int screen_width = CGRectGetWidth(self.view.bounds);
    //int screen_height = CGRectGetHeight(self.view.bounds);
    //int screenHeight = self.bounds.size.height;
    int toolbarBottom = CGRectGetHeight(self.topToolBar.bounds)+self.topToolBar.frame.origin.y;
    
    NSLog(@"Redraw_table called KDR screen width: %d %f",screen_width,self.topToolBar.frame.origin.y);
    
    int card_width  = screen_width / 10;
    int card_height = card_width * 1.55;
    
    int toprow_spacer = toolbarBottom+card_height*0.1;  // Space from the top of the screen to the first row of cards.
    int second_spacer = toprow_spacer+card_height*1.8; // Space from the top row of cards to the second row
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        second_spacer = toprow_spacer+card_height*1.35;
    }
    
    int width_spacer  = card_width/2.0;
    int deal_spacer   = 2*(card_width/5);
    
    
    [_fub resize:card_width/5:toprow_spacer:card_width:card_height];  // fub has too many cards and overlaps the deck on the iphone if we don't fudge it a little (hence the -15)
    
    if([_fub.cards count] == 0) {
        _fub.view.layer.borderWidth = 1;
        _fub.view.layer.borderColor = [[UIColor whiteColor] CGColor];
    }
    
    NSLog(@"before suit stacks");
    // Resize the four suit stacks
    for(int i=0; i<4; i++) {
        [_suitstacks[i] resize:(card_width*4)+(i*card_width+(i*width_spacer)):toprow_spacer:card_width:card_height];
        if([((card_stack *)_suitstacks[i]).cards count] == 0) {
            ((card_stack *)_suitstacks[i]).view.layer.borderWidth = 1;
            ((card_stack *)_suitstacks[i]).view.layer.borderColor = [[UIColor whiteColor] CGColor];
        }
    }
    
    [_deck resize:card_width/5:second_spacer:card_width:card_height];
    
    if([_deck.cards count] == 0) {
        _deck.view.layer.borderWidth = 1;
        _deck.view.layer.borderColor = [[UIColor whiteColor] CGColor];
    }
    
    [_deal resize:card_width+deal_spacer:second_spacer:card_width:card_height];
    
    if([_deal.cards count] == 0) {
        _deal.view.layer.borderWidth = 1;
        _deal.view.layer.borderColor = [[UIColor whiteColor] CGColor];
    }
    
    NSLog(@"Before card stacks");
    for(int i=0; i<4; i++) {
        [_cardstacks[i] resize:(card_width*4)+(i*card_width+(i*width_spacer)):second_spacer:card_width:card_height];
        if([((card_stack *)_cardstacks[i]).cards count] == 0) {
            ((card_stack *)_cardstacks[i]).view.layer.borderWidth = 1;
            ((card_stack *)_cardstacks[i]).view.layer.borderColor = [[UIColor whiteColor] CGColor];
        }
    }
    
}

- (void)init_table_trivial {
    
    self.view.restorationIdentifier = @"mainView";
    
    if (self.cards != nil)
        return;
    
    int card_width = 0;
    int card_height = 0;
    
    int toprow_spacer = 0;
    int second_spacer = 0;
    
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
    
    // Create the deck
    self.deck = [[card_stack alloc] initWithData:card_width/5:second_spacer:card_width:card_height:deck];
    
    // Create the deal
    self.deal = [[card_stack alloc] initWithData:0:0:card_width:card_height:deal];
    self.deal.view.layer.borderWidth = 1;
    self.deal.view.layer.borderColor = [[UIColor whiteColor] CGColor];

    
    // Create four suit stacks and cardstacks
    for(int i=0; i<4; i++) {
        card_stack *asuitstack = [[card_stack alloc] initWithData:(i*card_width+(i*50)):toprow_spacer:card_width:card_height:suitstack];
        for(int j=0; j<10; j++) {
            card* card = [self get_next_card];
            [card setFace_up:true];
            [asuitstack add_card:card];
            self.suit_stack_starter = card.rank;
            self.viewTagToCard[card.view.tag]  = card;
            self.viewTagToStack[card.view.tag] = asuitstack;
            card = nil;
        }
        [self.suitstacks addObject:asuitstack];
        [self.view addSubview:asuitstack.view];
        asuitstack = nil;
        
        card_stack *acardstack = [[card_stack alloc] initWithData:0:second_spacer:card_width:card_height:cardstack];
        
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
        self.viewTagToCard[topcard.view.tag]  = topcard;
        self.viewTagToStack[topcard.view.tag] = acardstack;
        
        self.viewTagToCard[bottomcard.view.tag]  = bottomcard;
        self.viewTagToStack[bottomcard.view.tag] = acardstack;
        
        self.viewTagToCard[middlecard.view.tag]  = middlecard;
        self.viewTagToStack[middlecard.view.tag] = acardstack;

        
        [self.cardstacks addObject:acardstack];
        [self.view addSubview:acardstack.view];
        acardstack = nil;
    }
    
    [self.view addSubview:self.deal.view];
    [self.view addSubview:self.deck.view];
    [self.view addSubview:self.fub.view];
    
    
    
}

// This doesn't work yet with the latest (3/27/2014) code factoring
- (void)init_table_debug {
    
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
    int tagCounter = 0;
    for (int i=1; i<=13; i++) {
        NSString* face_img = [NSString stringWithFormat:@"club%d.png",i];
        card *acard = [[card alloc] initWithData:Clubs:i:face_img:back_img:0:0:i:width:height:tagCounter];
        [acard setColor:Black];
        [self.cards addObject:acard];
        acard = nil;
        tagCounter++;
    }
    
    for (int i=1; i<=13; i++) {
        NSString* face_img = [NSString stringWithFormat:@"diamond%d.png",i];
        card *acard = [[card alloc] initWithData:Diamonds:i:face_img:back_img:0:0:i:width:height:tagCounter];
        [acard setColor:Red];
        [self.cards addObject:acard];
        acard = nil;
        tagCounter++;
    }
    
    for (int i=1; i<=13; i++) {
        NSString* face_img = [NSString stringWithFormat:@"heart%d.png",i];

        card *acard = [[card alloc] initWithData:Hearts:i:face_img:back_img:0:0:i:width:height:tagCounter];
        [acard setColor:Red];
        [self.cards addObject:acard];
        acard = nil;
        tagCounter++;
    }
    
    for (int i=1; i<=13; i++) {
        NSString* face_img = [NSString stringWithFormat:@"spade%d.png",i];
        card *acard = [[card alloc] initWithData:Spades:i:face_img:back_img:0:0:i:width:height:tagCounter];
        [acard setColor:Black];
        [self.cards addObject:acard];
        acard = nil;
        tagCounter++;
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

-(card*)get_next_card {
    card* ret = nil;
    int r = 0;
    
    ret = [self.cards objectAtIndex:r];
    [self.cards removeObject:ret];
    
    return ret;
}

-(card_stack *)find_active_stack:(CGPoint)point {
    
    
    for(card_stack *cs in self.cardstacks)
    {
        if(CGRectContainsPoint(cs.view.frame,point))
        {
            return cs;
        }
    }
    
    for(card_stack *cs in self.suitstacks)
    {
        if(CGRectContainsPoint(cs.view.frame,point))
        {
            return cs;
        }
    }
    
    if(CGRectContainsPoint(self.deck.view.frame,point))
    {
        return self.deck;
    }
    
    if(CGRectContainsPoint(self.deal.view.frame,point))
    {
        return self.deal;
    }
    
    if(CGRectContainsPoint(self.fub.view.frame,point))
    {
        return self.fub;
    }
    
    return nil;
}

-(card_stack *)find_active_stack_rect:(CGRect)rect {
    
    
    for(card_stack *cs in self.cardstacks)
    {
        if(CGRectIntersectsRect(cs.view.frame, rect))
        {
            return cs;
        }
    }
    
    for(card_stack *cs in self.suitstacks)
    {
        if(CGRectIntersectsRect(cs.view.frame, rect))
        {
            return cs;
        }
    }
    if(CGRectIntersectsRect(self.deck.view.frame,rect))
    {
        return self.deck;
    }
    if(CGRectIntersectsRect(self.deal.view.frame,rect))
    {
        return self.deal;
    }
    
    if(CGRectIntersectsRect(self.fub.view.frame,rect))
    {
        return self.fub;
    }
    
    return nil;
}

-(card_stack *)find_stack_under_hover:(UIImageView*)hover {
    // Get the coordinates of hover relative to its stack (its super view)
    UIView *hover_superview     = [hover superview];
    //CGRect hover_superview_rect = [hover_superview convertRect:hover.bounds fromView:hover];
    
    // Get the coordinates of hover relative to the main view
    CGRect hover_mainview_rect  = [self.view convertRect:hover.frame fromView:hover_superview];
    
    for(card_stack *cs in self.cardstacks)
    {
        if(CGRectIntersectsRect(cs.view.frame, hover_mainview_rect))
        {
            return cs;
        }
    }
    
    for(card_stack *cs in self.suitstacks)
    {
        if(CGRectIntersectsRect(cs.view.frame, hover_mainview_rect))
        {
            return cs;
        }
    }
    if(CGRectIntersectsRect(self.deck.view.frame, hover_mainview_rect))
    {
        return self.deck;
    }
    if(CGRectIntersectsRect(self.deal.view.frame, hover_mainview_rect))
    {
        return self.deal;
    }
    
    if(CGRectIntersectsRect(self.fub.view.frame, hover_mainview_rect))
        
    {
        return self.fub;
    }
    
    return nil;
}

-(void)run_victory {
    if(!self.just_won) {
        self.active_card = nil;
        self.score += 250;
        self.wins++;

        _undo_button.enabled = false;
      
        // Visual "reward" for winning
        
        int offset = 75;
        int stacknum = 0;
        for(card_stack *cs in self.suitstacks) {
            int cardnum  = 0;
            for(card *card in cs.cards) {
                [card.view removeFromSuperview];  // not necessary I believe; a view can only have one superview
                [self.view addSubview:card.view];
                card.card_parent = nil;
                float x = (cardnum*card.view.frame.size.width*0.735)+10;
                float y = offset+(stacknum*card.view.frame.size.height);
                CGRect rect = card.view.frame;
                CGPoint point;
                point.x = x;
                point.y = y;
                rect.origin = point;
                
                [card.view setFrame:rect];
                card.card_parent  = nil;
                
                int screen_width  = CGRectGetWidth(self.view.bounds);
                int screen_height = CGRectGetHeight(self.view.bounds);
                if(x> screen_width || y>screen_height) {
                    NSLog(@"KDR OUT OF BOUNDS!!!!!!!!!!!!!");
                }
                
                cardnum++;
            }
            stacknum++;
        }
        
    }
    self.just_won = 1;
}

-(void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
    UITouch* touchPoint = [touches anyObject];
    CGPoint point       = [touchPoint locationInView:self.view];
    //_prev_point = point;
    
    UIView *viewTapped = [self.view hitTest:point withEvent:event];
    NSLog(@"viewTapped: %@",viewTapped);
    if([viewTapped isKindOfClass:[UIImageView class]]) {
        // Somehow we need to find the object containing a pointer to viewTapped
        self.active_card              = self.viewTagToCard[viewTapped.tag];
        self.active_card_source_stack = self.viewTagToStack[viewTapped.tag];
        //self.active_card_source_stack = (card_stack *)[viewTapped.view superview];
        [self.active_card save_pos];
        
       NSLog(@"active card started at: %@ %f %f",self.active_card, self.active_card.view.frame.origin.x,self.active_card.view.frame.origin.y);
        
        // Ensure proper z-ordering, even when dragging a stack
        [[viewTapped superview] bringSubviewToFront:viewTapped];
        
        [self.view bringSubviewToFront:[viewTapped superview]];
        
        card *cp = self.active_card.card_parent;
        while(cp) {
            [[cp.view superview] bringSubviewToFront:cp.view];
            cp = cp.card_parent;
        }
        
    }
    else {
        //NSLog(@"No card tapped");
        self.active_card = nil;
    }
    
    
    if(self.active_card) {
        //NSLog(@"Tapped: rank: %d suit: %u",self.active_card.rank,self.active_card.suit);
        self.xCap = point.x - self.active_card.view.frame.origin.x;
        self.yCap = point.y - self.active_card.view.frame.origin.y;
    }
    
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {

    UITouch* touch = [touches anyObject];
    CGPoint point  = [touch locationInView:self.view];
    
	if (self.active_card && (self.just_won || self.active_card_source_stack.stack_type != deck)) {
        [self.active_card set_pos:point.x - self.xCap:point.y - self.yCap];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if(self.just_won)
        return;
    
    card_stack *cs;
    //NSLog(@"Called touchesEnded");
    if(self.active_card) {
        //NSLog(@"KDR KDR active card %@",self.active_card);
        cs = [self find_stack_under_hover:self.active_card.view];
        //NSLog(@"active card ended at: %f %f",self.active_card.frame.origin.x,self.active_card.frame.origin.y);
    }
    else {
        UITouch* touchPoint = [touches anyObject];
        CGPoint point       = [touchPoint locationInView:self.view];
        cs = [self find_active_stack:point];
        NSLog(@"Deck has: %luu",(unsigned long)[self.deck.cards count]);
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
            
            NSLog(@"KDR Tapped deck");
            if([self.deck.cards count] == 0) {
                NSLog(@"KDR out of cards");
                /* Move everything from the deal to the deck */
                unsigned long deal_count =[self.deal.cards count];
                for(int i=0; i<deal_count; i++) {
                    card *acard = [self.deal get_top_card];
                    acard.card_parent = nil;  // Deck cards have no parents.
                    [self.deck add_card:acard];
                    [[self.deck.cards lastObject] setFace_up:false];
                    self.viewTagToStack[acard.view.tag] = self.deck;
                }
                //[self setNeedsDisplayInRect:self.deck.frame];
                
            }
            else {
                /* Take up to 3 cards from the deck and move them to the deal */
                unsigned long deck_count = [self.deck.cards count];
                self.deck_just_tapped = 0;
                for(int i=0; i<3 && i<deck_count; i++) {
                    card *acard   = [self.deck get_top_card];
                    [self.deal add_card:acard];
                    self.viewTagToStack[acard.view.tag] = self.deal;
                    self.deck_just_tapped++;
                }
            }
            _undo_button.enabled = true;
            self.active_card = NULL;
            // Refresh the appropriate rectangles
            
            if([self.deck.cards count] == 0) {
                
                self.deck.view.layer.borderWidth = 1;
                self.deck.view.layer.borderColor = [[UIColor whiteColor] CGColor];
            }
            
            if([self.deal.cards count] == 0) {
                // Reset the size of the rectangle for the deal
                CGRect rec = self.deal.view.frame;
                rec.size = CGSizeMake(rec.size.width, self.deck.view.frame.size.height);
                [self.deal.view setFrame:rec];
                
                self.deal.view.layer.borderWidth = 1;
                self.deal.view.layer.borderColor = [[UIColor whiteColor] CGColor];
                
            }
            
            //[self setNeedsDisplay];
            NSLog(@"Deck has %lu cards",(unsigned long)[self.deck.cards count]);
            NSLog(@"Deal has %lu cards",(unsigned long)[self.deal.cards count]);
        }
        else if(cs.stack_type == cardstack || cs.stack_type == suitstack){
            card *dropped_on = [cs.cards lastObject];
            if([self accept_card_move:self.active_card_source_stack :cs :dropped_on]) {
                
                self.active_card_dest_stack = cs;
                
                _undo_button.enabled = true;
                
                [self change_stack:self.active_card:self.active_card_source_stack:cs];
                
                // Redraw the white rectangle if there are no more cards
                self.deck_just_tapped = 0;
                
            }
            else {
                NSLog(@"KDR Card move to cardstack or suitstack canceled: Not accepted");
                // When canceling a stack drag, make sure you clean up everything
                CGRect rect;
                rect = self.active_card.view.frame;
                rect.size.height = self.view.bounds.size.height-self.active_card.view.frame.origin.y+45;
                
                [self.active_card cancel_move];
            }
            
        }
        else {
            NSLog(@"KDR Card Move to invalid stack type");
            [self.active_card cancel_move];
        }
    }
    else {
        NSLog(@"KDR Card move to nowhere");
        // Not dropped on a stack; put it back where it was
        [self.active_card cancel_move];
    }
    // This piece of code makes all possible moves to suitstacks
    if([self.autocomplete isOn]) {
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

- (void)undo_deck_tap {
    NSLog(@"KDR Undoing deck tap");
    if([self.deal.cards count] == 0) {
        /* Move everything from the deck back to the deal */
        unsigned long deck_count =[self.deck.cards count];
        for(int i=0; i<deck_count; i++) {
            card *acard = [self.deck get_top_card];
            acard.card_parent = nil;
            [self.deal add_card:acard];
            [[self.deal.cards lastObject] setFace_up:true];
            self.viewTagToStack[acard.view.tag] = self.deal;
        }
        //[self setNeedsDisplayInRect:self.deal.frame];
        
    }
    else {
        /* Take the top 3 cards from the deal and move them to the deck */
        unsigned long deal_count = [self.deal.cards count];
        for(int i=0; i<self.deck_just_tapped && i<deal_count; i++) {
            card *acard = [self.deal get_top_card];
            // Set child cards of card being moved back to have no parent, so they aren't linked to things in the deck.
            
            [self.deck add_card:acard];
            
            card *child_card = [self.deal.cards lastObject];
            child_card.card_parent = nil;

            [[self.deck.cards lastObject] setFace_up:false];
            self.viewTagToStack[acard.view.tag] = self.deck;
        }
    }
    
    if([self.deal.cards count] == 0) {
        self.deal.view.layer.borderWidth = 1;
        self.deal.view.layer.borderColor = [[UIColor whiteColor] CGColor];
    }
    
    self.active_card = NULL;
    // Refresh the appropriate rectangles
    
    //[self setNeedsDisplayInRect:self.deck.frame];
    
    if([self.deal.cards count] == 0) {
        //[self setNeedsDisplayInRect:self.deal.frame];
    }
    NSLog(@"Deck has %lu cards",(unsigned long)[self.deck.cards count]);
    NSLog(@"Deal has %lu cards",(unsigned long)[self.deal.cards count]);
    
}

// I don't like how I designed this code; card_put_up actually increments the score.
// accept_card_move should just be the test without that side effect.
-(BOOL)accept_card_move: (card_stack *)from :(card_stack *)to :(card *)onTopOfCard {
    /* Debug: allow all moves (autocomplete must be off or this will loop forever) */
    //[self.autocomplete setOn:NO]; return true;
    
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
    return false;
}

// This function tries to find and make a single valid move from any visible stack to any suit stack
- (BOOL)find_card_for_suitstack {
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
                [self change_stack:self.active_card :self.cardstacks[j] :self.suitstacks[i]];
                self.active_card = backup_active;
                //[self setNeedsDisplay];
                return true;
            }
        }
        
        // Check fub
        self.active_card = [((card_stack *)self.fub).cards lastObject];
        if([self accept_card_move:self.fub :self.suitstacks[i] :topCard]) {
            // Make the move
            [self change_stack:self.active_card :self.fub :self.suitstacks[i]];
            self.active_card = backup_active;
            //[self setNeedsDisplay];
            return true;
        }
        
        // Check deal
        self.active_card = [((card_stack *)self.deal).cards lastObject];
        if([self accept_card_move:self.deal :self.suitstacks[i] :topCard]) {
            // Make the move
            [self change_stack:self.active_card :self.deal :self.suitstacks[i]];
            self.active_card = backup_active;
            //[self setNeedsDisplay];
            return true;
        }
    }
    
    self.active_card = backup_active;
    return false;
}

-(void)tryToPutUpCardAtPoint:(CGPoint)point {
    card_stack *source_stack = [self find_active_stack:point];
    if(self.active_card) {
        
        for(int i=0; i<4; i++) {
            card *topCard = [((card_stack *)self.suitstacks[i]).cards lastObject];
            if([self accept_card_move:source_stack :_suitstacks[i] :topCard]) {
                [self change_stack:self.active_card :source_stack :self.suitstacks[i]];
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

- (void)card_put_up {
    self.score += 5;
}

-(BOOL)change_stack:(card *)acard :(card_stack *)from_stack :(card_stack *)to_stack {
    // Since this is a recursive function, we stop when the card we're trying to move doesn't exist.
    if (acard != nil && from_stack != to_stack){
        
        [from_stack remove_card:acard];
        [to_stack add_card:acard];
        
        // Clean parent card reference
        card *last = [from_stack.cards lastObject];
        [last setCard_parent:nil];
        
        self.viewTagToStack[acard.view.tag] = to_stack;
        
        [self change_stack:acard.card_parent:from_stack:to_stack];
        
        return TRUE;
    }
    return FALSE;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _restorationIdentifier = @"ssViewController";
    //self.identifier = @"ssViewController";
    self.view.restorationIdentifier = @"mainView";
    
	// Do any additional setup after loading the view, typically from a nib.
    
    NSLog(@"KDR viewDidLoad called");

    NSLog(self.do_init_table ? @"do_init table is YES" : @" do_init table is NO");

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    tapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapGesture];

    self.do_init_table = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    NSLog(@"viewDidAppear called view: %@",self.view);
    

    if(self.do_init_table) {

        self.score  = -45;
        self.wins   = 0;
        self.losses = 0;
        [self.autocomplete setOn:false];
        
        [self init_table];
        
        self.do_init_table = NO;
    }
    [self redraw_table];
    
    int i = 0;
    NSLog(@"FUB itself: %@",self.fub.view);
    for(UIView *s in [self.fub.view subviews]) {
        NSLog(@"FUB Subview %d %@",i,s);
        i++;
    }

    
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
    
    [self update_ac_switch];
    
    NSLog(@"fub: %@",self.fub.view);
    
    [self.view addSubview:self.deck.view];
    [self.view addSubview:self.deal.view];
    [self.view addSubview:self.fub.view];

    
    for(int i=0; i<4; i++) {
        [self.view addSubview:((card_stack *)self.cardstacks[i]).view];
        [self.view addSubview:((card_stack *)self.suitstacks[i]).view];
    }
    
    // Loop over all cards and assign tags to their views, building the viewTagToCard and viewTagToStack
    // arrays in the process.
    int tagCount = 0;
    for(int i=0; i<[self.fub.cards count]; i++) {
        NSLog(@"KDR HERE");
        ((card*)self.fub.cards[i]).view.tag = tagCount;
        self.viewTagToCard[tagCount]  = self.fub.cards[i];
        self.viewTagToStack[tagCount] = self.fub;
        tagCount++;
    }
    
    for(int i=0; i<[self.deck.cards count]; i++) {
        ((card*)self.deck.cards[i]).view.tag = tagCount;
 
        self.viewTagToCard[tagCount]  = self.deck.cards[i];
        self.viewTagToStack[tagCount] = self.deck;
        tagCount++;
    }
    
    for(int i=0; i<[self.deal.cards count]; i++) {
        ((card*)self.deal.cards[i]).view.tag = tagCount;
        self.viewTagToCard[tagCount]  = self.deal.cards[i];
        self.viewTagToStack[tagCount] = self.deal;
        tagCount++;
    }
    
    for(int j=0; j<4; j++) {
        for(int i=0; i<[((card_stack *)self.cardstacks[j]).cards count]; i++) {
            ((card *)((card_stack *)self.cardstacks[j]).cards[i]).view.tag = tagCount;
            self.viewTagToCard[tagCount]  = ((card_stack *)self.cardstacks[j]).cards[i];
            self.viewTagToStack[tagCount] = self.cardstacks[j];
            tagCount++;
        }
        for(int i=0; i<[((card_stack *)self.suitstacks[j]).cards count]; i++) {
            ((card *)((card_stack *)self.suitstacks[j]).cards[i]).view.tag = tagCount;
            self.viewTagToCard[tagCount]  = ((card_stack *)self.suitstacks[j]).cards[i];
            self.viewTagToStack[tagCount] = self.suitstacks[j];
            tagCount++;
        }
    }
}
@end
