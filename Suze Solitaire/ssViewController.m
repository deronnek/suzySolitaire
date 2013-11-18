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


@end

@implementation ssViewController


- (IBAction)help_tapped:(id)sender {
    NSLog(@"Help tapped");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"How to play" message:@"Move cards to upper stacks, make bucks.  Keep autobucks on for easymode." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
    [alert show];
}

- (IBAction)autocomplete_change:(id)sender {
    NSLog(@"Switched");
    UISwitch *autocomplete = (UISwitch *)sender;
    mainView *mv = (mainView *)self.view;
    
    mv.autocomplete = [autocomplete isOn];

}

- (IBAction)start_new_game:(id)sender {
    NSLog(@"new game button tapped");
    // KDR I'm hoping I don't need to free self.cards and whatever else--that just calling init_table
    // will cause the "automatic reference counter" to free whatever I've overwritten.
    // However, I'm not particularly confident about this.
    
    mainView *mv = (mainView *)self.view;

    mv.cards = nil;
    
    /*
     self.deck  = nil;
     self.deal  = nil;
     self.cardstacks = nil;
     self.suitstacks = nil;
     self.fub        = nil;
     */
    
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
    
    [mv setNeedsDisplay];
}


- (IBAction)undo_move:(id)sender {
    
    _undo_button.enabled = false;
    mainView *mv = (mainView *)self.view;
    //[mv find_card_for_suitstack];  // For testing functions
    
    NSLog(@"Active card: %@ %@ %@",mv.active_card,mv.active_card_dest_stack,mv.active_card_source_stack);
    
    // Make sure we subtract bucks if a move to a suitstack is being undone
    if(mv.active_card_dest_stack.stack_type == suitstack) {
        mv.score -= 5;
        [self update_bucks];
    }
    
    [mv.active_card change_stack:mv.active_card_dest_stack:mv.active_card_source_stack];
    [mv setNeedsDisplay];
}

- (void)enable_undo {
    _undo_button.enabled = true;
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
    [mv setNeedsDisplay];
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
    
    NSLog(self.do_init_table ? @"do_init table is Yes" : @" do_init table is No");

    NSLog(@"Deck has %d",[mv.deck.cards count]);
    
    //if(self.do_init_table) {
   
    mv.score = -45;
    mv.wins   = 0;
    mv.losses = 0;
    mv.autocomplete = true;
    [self update_wins];
    [self update_losses];
    [self update_bucks];
    [mv init_table];
    //[mv init_table_trivial];

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
    //mainView *mv = (mainView *)self.view;
    //NSLog(@"KDR view: %@",mv);
    //NSLog(@"KDR score is: %d",mv.score);
    //[mv init_table];
     

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
    
    //[coder encodeObject:(mainView *)self.view forKey:@"mainView"];
    
    [coder encodeInt:((mainView *)self.view).score forKey:@"score"];
    [coder encodeInt:((mainView *)self.view).wins  forKey:@"wins"];
    [coder encodeInt:((mainView *)self.view).just_won  forKey:@"just_won"];
    [coder encodeInt:((mainView *)self.view).losses  forKey:@"losses"];
    [coder encodeBool:((mainView *)self.view).autocomplete  forKey:@"autocomplete"];
    [coder encodeInt:((mainView *)self.view).xCap  forKey:@"xCap"];
    [coder encodeInt:((mainView *)self.view).yCap  forKey:@"yCap"];
    [coder encodeInt:((mainView *)self.view).suit_stack_starter  forKey:@"suit_stack_starter"];
    
    [coder encodeObject:((mainView *)self.view).cards forKey:@"cards"];
    [coder encodeObject:((mainView *)self.view).suitstacks forKey:@"suitstacks"];
    [coder encodeObject:((mainView *)self.view).cardstacks forKey:@"cardstacks"];
    [coder encodeObject:((mainView *)self.view).fub forKey:@"fub"];
    [coder encodeObject:((mainView *)self.view).deck forKey:@"deck"];
    [coder encodeObject:((mainView *)self.view).deal forKey:@"deal"];
    
    /*
    mainView *mv = (mainView *)self.view;
    NSURL *dataFileURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"SavedData"];
    [NSKeyedArchiver archiveRootObject:mv toFile:[dataFileURL path]];

    
    //card_stack *deck = mv.deck;
     
    [super encodeRestorableStateWithCoder:coder];
     */
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
    mv.suitstacks = [coder decodeObjectForKey:@"suitstacks"];
    mv.cardstacks = [coder decodeObjectForKey:@"cardstacks"];
    mv.fub        = [coder decodeObjectForKey:@"fub"];
    mv.deck       = [coder decodeObjectForKey:@"deck"];
    mv.deal       = [coder decodeObjectForKey:@"deal"];
    
    
    [self update_bucks];
    [self update_wins];
    [self update_losses];
    [self update_ac_switch];
    
    
    // Even if we call init_table here it doesn't set things up properly.
    // self.view pointer is different?
/*
    NSLog(@"KDR score is %d",mv.score);
    NSLog(@"KDR deck has %d",[mv.deck.cards count]);
  */
    /*
    NSURL *dataFileURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"SavedData"];
    self.view = [NSKeyedUnarchiver unarchiveObjectWithFile:[dataFileURL path]];

     */
    
    /*
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
