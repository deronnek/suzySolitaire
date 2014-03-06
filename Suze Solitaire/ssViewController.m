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

- (IBAction)autocomplete_change:(id)sender {
    UISwitch *autocomplete = (UISwitch *)sender;
    mainView *mv = (mainView *)self.view;
    
    mv.autocomplete = [autocomplete isOn];

}

- (IBAction)start_new_game:(id)sender {
    // KDR I'm hoping I don't need to free self.cards and whatever else--that just calling init_table
    // will cause the "automatic reference counter" to free whatever I've overwritten.
    // However, I'm not particularly confident about this.
    
    mainView *mv = (mainView *)self.view;

    mv.cards = nil;

    // Remove all cards
    [[mv.deck subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [[mv.deal subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [[mv.fub  subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    for(int i=0; i<4; i++) {
        [[mv.suitstacks[i]  subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [[mv.cardstacks[i]  subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    // Remove card stacks
    [mv.deck removeFromSuperview];
    [mv.deal removeFromSuperview];
    [mv.fub  removeFromSuperview];
    for(int i=0; i<4; i++) {
        [mv.suitstacks[i] removeFromSuperview];
        [mv.cardstacks[i] removeFromSuperview];
    }
    
    if(mv.just_won) {
        // Have to get rid of the cards differently if we just won
        NSArray *viewsToRemove = [mv subviews];
        for (UIView *v in viewsToRemove) {
            if([v isKindOfClass:[card class]]) {
                [v removeFromSuperview];
            }
        }
    }

    [mv init_table];
    
    mv.score -= 45;
    if(mv.just_won) {
        mv.just_won = 0;
    }
    else {
        mv.losses++;
    }
    [self update_bucks];
    [self update_wins];
    [self update_losses];
    
    mv.active_card = nil;
    [mv redraw_table];
}


- (IBAction)undo_move:(id)sender {
    
    _undo_button.enabled = false;
    mainView *mv = (mainView *)self.view;
    //[mv find_card_for_suitstack];  // For testing functions
    
    NSLog(@"Active card: %@ %@ %@",mv.active_card,mv.active_card_dest_stack,mv.active_card_source_stack);
    /* We should only get to this point without an active card if the deck tap is being undone */
    if(mv.deck_just_tapped) {
        [mv undo_deck_tap];
    }
    else {
        // Make sure we subtract bucks if a move to a suitstack is being undone
        if(mv.active_card_dest_stack.stack_type == suitstack) {
            mv.score -= 5;
            [self update_bucks];
        }
        [mv.active_card change_stack:mv.active_card_dest_stack:mv.active_card_source_stack];
    }
    //[mv setNeedsDisplay];
}

- (void)enable_undo {
    _undo_button.enabled = true;
}

- (void)disable_undo {
    _undo_button.enabled = false;
}

- (void)update_ac_switch {
    mainView *mv = (mainView *)self.view;
    [_autocomplete setOn:mv.autocomplete];
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
    mainView *mv = (mainView *)self.view;

    self.bucks_counter.text = [NSString stringWithFormat:@"$%d",mv.score];
    if(mv.score < 0) {
        [self.bucks_counter setTextColor:[UIColor redColor]];
    }
    else {
        [self.bucks_counter setTextColor:[UIColor blackColor]];
    }
    //[mv setNeedsDisplay];
}

- (void)update_wins {
    mainView *mv = (mainView *)self.view;
    self.wins_counter.text = [NSString stringWithFormat:@"Wins: %d",mv.wins];
}

- (void)update_losses {
    mainView *mv = (mainView *)self.view;
    self.losses_counter.text = [NSString stringWithFormat:@"Losses: %d",mv.losses];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    _restorationIdentifier = @"ssViewController";
    self.view.restorationIdentifier = @"mainView";
    
	// Do any additional setup after loading the view, typically from a nib.
    
    NSLog(@"KDR viewDidLoad called");

    mainView *mv = (mainView *)self.view;
    NSLog(@"mainView in viewDidLoad is %p",mv);
    
    NSLog(self.do_init_table ? @"do_init table is YES" : @" do_init table is NO");

    //NSLog(@"Deck has %d",[mv.deck.cards count]);
    
    //if(self.do_init_table) {



    //[mv init_table];

    //[mv init_table_trivial]; mv.autocomplete = true;
    //[mv init_table_debug];

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    tapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapGesture];

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
    NSLog(@"viewDidAppear called");
    mainView *mv = (mainView *)self.view;
    [mv redraw_table];
}

- (void)handleTapGesture:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateRecognized) {
        // handling code
        
        mainView *mv = (mainView *)self.view;
        CGPoint point = [sender locationInView:self.view];
        // Put up the card under point if possible
        NSLog(@"double tap recognized at %f,%f",point.x,point.y);
        [mv tryToPutUpCardAtPoint:point];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    //NSLog(@"KDR viewWillAppear called init_table is %d",self.do_init_table);
    
    //NSLog(@"KDR self: %@",self.view);
    mainView *mv = (mainView *)self.view;
    //NSLog(@"KDR view: %@",mv);
    //NSLog(@"KDR score is: %d",mv.score);
    if(self.do_init_table) {
        mv.score  = -45;
        mv.wins   = 0;
        mv.losses = 0;
        mv.autocomplete = true;
        
        [self update_wins];
        [self update_losses];
        [self update_bucks];
        [mv init_table];
        
        self.do_init_table = NO;
    }
    

}
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
  // Redraw cards that are already on the table
    NSLog(@"Just rotated");
    mainView *mv = (mainView *)self.view;
    [mv redraw_table];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// returns the URL to the application's Documents directory
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}



-(void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    
    NSLog(@"KDR encoding state");
    [super encodeRestorableStateWithCoder:coder ];
    
    for(UIView *v in [self.view subviews]) {
        NSLog(@"at encoding time, %@",v);
    }
    
    //[coder encodeObject:(mainView *)self.view forKey:@"mainView"];
    
    [coder encodeInt:((mainView *)self.view).score forKey:@"score"];
    [coder encodeInt:((mainView *)self.view).wins  forKey:@"wins"];
    [coder encodeInt:((mainView *)self.view).just_won  forKey:@"just_won"];
    [coder encodeInt:((mainView *)self.view).losses  forKey:@"losses"];
    [coder encodeBool:((mainView *)self.view).autocomplete  forKey:@"autocomplete"];
    [coder encodeInt:((mainView *)self.view).xCap  forKey:@"xCap"];
    [coder encodeInt:((mainView *)self.view).yCap  forKey:@"yCap"];
    [coder encodeInt:((mainView *)self.view).suit_stack_starter  forKey:@"suit_stack_starter"];
    
    /*
    [coder encodeObject:((mainView *)self.view).cards forKey:@"cards"];
    [coder encodeObject:((mainView *)self.view).suitstacks forKey:@"suitstacks"];
    [coder encodeObject:((mainView *)self.view).cardstacks forKey:@"cardstacks"];
    [coder encodeObject:((mainView *)self.view).fub forKey:@"fub"];
    [coder encodeObject:((mainView *)self.view).deck forKey:@"deck"];
    [coder encodeObject:((mainView *)self.view).deal forKey:@"deal"];
     */
    
    /*
    mainView *mv = (mainView *)self.view;
    NSURL *dataFileURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"SavedData"];
    [NSKeyedArchiver archiveRootObject:mv toFile:[dataFileURL path]];

    
    //card_stack *deck = mv.deck;
     */
    //[super encodeRestorableStateWithCoder:coder];
     
    NSLog(@"KDR State encoded");
}


-(void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    
    NSLog(@"KDR decoding state");
    
    self.do_init_table = true;
    [super decodeRestorableStateWithCoder:coder];
    
    mainView *mv = (mainView *)self.view;
    NSLog(@"mainView in decode is %p",mv);
    
    mv.score        = [coder decodeIntForKey:@"score"];
    mv.wins         = [coder decodeIntForKey:@"wins"];
    mv.losses       = [coder decodeIntForKey:@"losses"];
    mv.just_won     = [coder decodeIntForKey:@"just_won"];
    mv.xCap         = [coder decodeIntForKey:@"xCap"];
    mv.yCap         = [coder decodeIntForKey:@"yCap"];
    mv.autocomplete = [coder decodeBoolForKey:@"autocomplete"];
    mv.suit_stack_starter = [coder decodeIntForKey:@"suit_stack_starter"];

    mv.cards      = [coder decodeObjectForKey:@"cards"];
    
    //mv.suitstacks = [coder decodeObjectForKey:@"suitstacks"];
    //mv.cardstacks = [coder decodeObjectForKey:@"cardstacks"];

    //mv.fub        = [coder decodeObjectForKey:@"fub"];
    //mv.deck       = [coder decodeObjectForKey:@"deck"];
    //mv.deal       = [coder decodeObjectForKey:@"deal"];
    
    NSLog(@"Fub: %@",mv.fub);
    
    [self update_bucks];
    [self update_wins];
    [self update_losses];
    [self update_ac_switch];
    
    //[mv addSubview:mv.deck];
    //[mv addSubview:mv.deal];
    //[mv addSubview:mv.fub];
     
    int i = 0;
    for(UIView *s in [mv subviews]) {
        NSLog(@"Subview %d %@",i,s);
    }
    /*
    [mv.cardstacks removeAllObjects];
    [mv.suitstacks removeAllObjects];

    int suitstack_number = 0;
    int cardstack_number = 0;
    for(UIView *s in [mv subviews]) {
        NSLog(@"Subview %d %@",i,s);
        
        if([s isKindOfClass:[card_stack class]]) {
            NSString *stack_type = [s.restorationIdentifier substringWithRange:NSMakeRange(9,1)];
            if([stack_type isEqualToString:@"0"]) {
                mv.fub = (card_stack *)s;
                [mv.fub.cards removeAllObjects]; // Necessary because init table gets called before we get here.  (bug/hack, really)
                for(UIImageView *c in [mv.fub subviews]) {
                    //NSLog(@"Subview of fub: %@",c.restorationIdentifier);
                    [mv.fub.cards addObject:c];
                }
            }
            else if([stack_type isEqualToString:@"1"]) {
                [mv.suitstacks addObject:s];
                for(UIImageView *c in [s subviews]) {
                    //NSLog(@"Subview of deck: %@",c.restorationIdentifier);
                    [((card_stack *)mv.suitstacks[suitstack_number]).cards addObject:c];
                }
                suitstack_number++;
                
            }
            else if([stack_type isEqualToString:@"2"]) {
                                [mv.cardstacks addObject:s];
                for(UIImageView *c in [mv.deck subviews]) {
                    //NSLog(@"Subview of deck: %@",c.restorationIdentifier);
                    [mv.deck.cards addObject:c];
                }

            }
            else if([stack_type isEqualToString:@"3"]) {
                mv.deck = (card_stack *)s;
                [mv.deck.cards removeAllObjects];
                for(UIImageView *c in [mv.deck subviews]) {
                    //NSLog(@"Subview of deck: %@",c.restorationIdentifier);
                    [mv.deck.cards addObject:c];
                }
                 NSLog(@"Deck at decode time has %d cards",[((card_stack *)s).cards count]);
            }
            else if([stack_type isEqualToString:@"4"]) {
                mv.deal = (card_stack *)s;
                // No need to remove cards from deal as init_table doesn't produce any
                NSLog(@"Deal at decode time has %d cards",[((card_stack *)s).cards count]);
                for(UIImageView *c in [mv.deck subviews]) {
                    //NSLog(@"Subview of deck: %@",c.restorationIdentifier);
                    [mv.deck.cards addObject:c];
                }

            }

        }
        
        i++;
    }
    
  
    int numberOfSuitstacks = 0;
    for(UIView *s in mv.suitstacks) {
        //[mv addSubview:s];
        numberOfSuitstacks++;
    }
    NSLog(@"Number of suitstacks: %d",numberOfSuitstacks);
    
    int numberOfCardstacks = 0;
    for(UIView *s in mv.cardstacks) {
        //[mv addSubview:s];
        numberOfCardstacks++;
    }
    NSLog(@"Number of cardstacks: %d",numberOfCardstacks);
    
    NSLog(@"made it HERE");
     
    
    NSArray *viewsToRestore = [mv subviews];
    for (card_stack *v in viewsToRestore) {
        if([v isKindOfClass:[card_stack class]]) {
            [v makeSubViewsOfCards];
        }
    }
    

    //[[mv subviews] makeObjectsPerformSelector:@selector(makeSubViewsOfCards)];
    
    // Even if we call init_table here it doesn't set things up properly.
    // self.view pointer is different?

    NSLog(@"KDR score is %d",mv.score);
    NSLog(@"KDR deck has %d",[mv.deck.cards count]);
  
    
    NSURL *dataFileURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"SavedData"];
    self.view = [NSKeyedUnarchiver unarchiveObjectWithFile:[dataFileURL path]];

     
    
    
    if([coder containsValueForKey:@"mainview"]) {
        NSLog(@"KDR decoding state: %@",self.view);
        self.do_init_table = false;
        //        mainView *mv = (mainView *)self.view;
     
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
