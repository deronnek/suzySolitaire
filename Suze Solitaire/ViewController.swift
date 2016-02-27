//
//  ViewController.swift
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 2/7/16.
//  Copyright © 2016 Kevin DeRonne. All rights reserved.
//
// TODO:  popup to confirm new game
// Rename "Help" to "How to play"
// Fix bug where autobucks makes a move sourceStack the deal, then you tap undo.

import UIKit

class ViewController: UIViewController {

    // MARK: OutletProperties
    
    @IBOutlet weak var topToolBar: UIToolbar!
    @IBOutlet weak var bucksBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var winsBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var lossesBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var undoBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var autoSwitch: UISwitch!
    @IBOutlet weak var helpBarButton: UIBarButtonItem!
    
    // MARK: Computed Properties
    var score: Int {
        get {
            return Int(bucksBarButtonItem.title!)!
        }
        set(newScore) {
            bucksBarButtonItem.title = String(newScore)
        }
    }
    var wins: Int {
        get {
            return Int(winsBarButtonItem.title!)!
        }
        set(newWins) {
            winsBarButtonItem.title = String(newWins)
        }
    }
    var losses: Int {
        get {
            return Int(lossesBarButtonItem.title!)!
        }
        set(newLosses) {
            lossesBarButtonItem.title = String(newLosses)
        }
    }
    
    // Mark Properties
    var doInitTable = true
    var xCap = 0
    var yCap = 0;
    
    var activeCard:                      Card? = nil
    var activeCardSourceStack:      CardStack? = nil
    var activeCardDestinationStack: CardStack? = nil
    
    var deckTaps   = 0
    var justWon    = false
    // The rank of the first card in the suitStacks
    var suitStackStarter = -1
    
    // Initial deck to pull cards sourceStack when setting up a game
    var cards      = [Card?]()
    // The ordered stacks at the top
    var suitStacks = [CardStack?]()
    // The working stacks at the bottom
    var cardStacks = [CardStack?]()
    // The "face up blind" stack
    var fub:  CardStack? = nil
    // The stack sourceStack which cards are drawn
    var deck: CardStack? = nil
    // The stack containing previously drawn cards
    var deal: CardStack? = nil
    
    // Allows us to quickly figure out which card was tapped
    var viewTagToCard  = [Int:Card?]()
    // Allows us to quickly figure out which stack was tapped
    var viewTagToStack = [Int:CardStack?]()
    
    // MARK: Methods
    override func viewDidLoad() {
        restorationIdentifier = "mainViewController"
    }
    
    override func viewDidAppear(animated: Bool) {
        if self.doInitTable {
            print("Initializing table")
            self.score  = -45
            self.wins   = 0
            self.losses = 0
            self.autoSwitch.enabled = false
            self.initTable()
            
            self.doInitTable = false;
        }
        self.redrawTable()
    }
    
    @IBAction func startNewGame(sender: AnyObject) {
        self.cards = []
        for viewContainer in [self.deck, self.deal, self.fub] + self.suitStacks + self.cardStacks {
            viewContainer!.view.subviews.forEach({ $0.removeFromSuperview() })
            viewContainer!.view.removeFromSuperview()
        }
        
        if self.justWon {
            // Have to get rid of the cards differently if we just won, as they are now just subviews of our view
            for v in self.view.subviews {
                if v.isKindOfClass(UIImageView) {
                    v.removeFromSuperview();
                }
            }
            self.justWon = false
        }
        else {
            self.losses++
        }
        
        self.score -= 45
        self.initTable()
        self.activeCard = nil
        self.redrawTable()
    }
    
    func initTable() {
        print("Init table called")
        self.undoBarButtonItem.enabled = false
        
        self.view.restorationIdentifier = "mainView"
        
        guard self.cards.count == 0 else {
            // We already have cards.  This should never happen.
            print("Bailing from initTable: cards count: \(self.cards.count)")
            return
        }
        
        // Create cards and shuffle them
        self.createCards()
        self.cards.shuffleInPlace()
        
        print("Cards created: \(self.cards.count)")
        
        // Create the face up blind (fub)
        
        self.fub = CardStack(type: .fub)
        for _ in 0..<13 {
            addCardToStack(self.fub!)
        }

        // Create the suitstacks (upper stacks)
        for i in 0..<4 {
            let aSuitStack = CardStack(type: .suitstack)
            if i == 0 {
                let aCard = self.addCardToStack(aSuitStack)
                self.suitStackStarter = aCard.rank
            }
            self.suitStacks.append(aSuitStack)
            self.view.addSubview(aSuitStack.view)
        }
        
        // Create the deck
        self.deck = CardStack(type: .deck)
        for _ in 0..<34 {
            self.addCardToStack(self.deck!)
        }
        
        // Create the deal
        self.deal = CardStack(type: .deal)
        
        // Create the four card stacks (lower stacks)
        for _ in 0..<4 {
            let aCardStack = CardStack(type: .cardstack)
            self.addCardToStack(aCardStack)
            self.cardStacks.append(aCardStack)
            self.view.addSubview(aCardStack.view)
        }
        
        self.view.addSubview(self.deck!.view)
        self.view.addSubview(self.deal!.view)
        self.view.addSubview(self.fub!.view)
        self.activeCard = nil
        
        print("Deck has \(self.deck!.cards.count)")
    }
    
    func addCardToStack(dest: CardStack) -> Card{
        let aCard = self.cards.removeAtIndex(0)!
        dest.addCard(aCard)
        self.viewTagToCard[aCard.view.tag]  = aCard
        self.viewTagToStack[aCard.view.tag] = dest
        return aCard

    }
    
    /*
        This function (redrawTable) is where the table layout actually gets done.  initTable just sets up the structures
        All of this is pretty hiddeous, with way too many constants but at least they're (mostly) based off of the screen size handed to us.
    */

    func redrawTable() {
        let screenWidth = CGRectGetWidth(self.view.bounds);
        let toolbarBottom = CGRectGetHeight(self.topToolBar.bounds)+self.topToolBar.frame.origin.y;
    
        var cardWidth  = CGFloat(screenWidth / 7);
        var cardHeight = cardWidth * 1.2;
        
        let toprowSpacer = toolbarBottom+cardHeight*0.1;  // Space sourceStack the top of the screen to the first row of cards.
        var secondSpacer = toprowSpacer+cardHeight*1.8;   // Space sourceStack the top row of cards to the second row
        var leftRightGapMultiplier = CGFloat(2.8);
        
        var widthSpacer  = cardWidth/15;
        var dealSpacer   = 2*(cardWidth/5);
        
        if(UI_USER_INTERFACE_IDIOM() == .Pad) {
            cardWidth    = screenWidth/10;
            secondSpacer = toprowSpacer+cardHeight*1.35;
            widthSpacer  = cardWidth/2.0;
            dealSpacer   = 2*(cardWidth/5);
            leftRightGapMultiplier = 4;
            cardHeight   = cardWidth*1.55;
            
        }
        
        // fub has too many cards and overlaps the deck on the iphone if we don't fudge it a little (hence the -15)
        self.fub!.resize(CGPoint(x: cardWidth/5, y: toprowSpacer), width: Int(cardWidth), cardHeight: Int(cardHeight))
        
        // Resize the four suit stacks
        for i in 0..<4 {
            var x = cardWidth * leftRightGapMultiplier
                x += CGFloat(i)*cardWidth + CGFloat(i)*widthSpacer
            
            self.suitStacks[i]!.resize(CGPoint(x: x, y: toprowSpacer), width: Int(cardWidth), cardHeight: Int(cardHeight))
        }
        
        self.deck!.resize(CGPoint(x: cardWidth/5, y: secondSpacer), width: Int(cardWidth), cardHeight: Int(cardHeight))
        self.deal!.resize(CGPoint(x: cardWidth+dealSpacer, y: secondSpacer), width: Int(cardWidth), cardHeight: Int(cardHeight))
        
        for i in 0..<4 {
            var x = cardWidth * leftRightGapMultiplier
            x += CGFloat(i)*cardWidth + CGFloat(i)*widthSpacer

            self.cardStacks[i]!.resize(CGPoint(x: x, y: secondSpacer), width: Int(cardWidth), cardHeight: Int(cardHeight))
        }

    }
    
    func createCards() {
        let backImgFile = "cardback.png";
        var tagCounter  = 0;
        var faceImgFile = String()
        
        
        for suit in [cardSuit.Clubs, .Diamonds, .Hearts, .Spades] {
            for i in 1...13 {
                if(UI_USER_INTERFACE_IDIOM() == .Pad) {
                    faceImgFile = String.init(format: suit.simpleDescription() + "%d.png", i)
                }
                else {
                    faceImgFile = String.init(format: suit.simpleDescription() + "%d-iphone.png",i)
                }
                
                let aCard = Card(suit: suit, rank: i, faceImageFilename: faceImgFile, backImageFilename: backImgFile, tag: tagCounter)
                self.cards.append(aCard)
                tagCounter++;
            }
        }
    }
    
    // MARK: Touches Implementations
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let point = touches.first?.locationInView(self.view)
        let viewTapped = self.view.hitTest(point!, withEvent: event)
        if ((viewTapped?.isKindOfClass(UIImageView)) != nil) {
            self.activeCard            = self.viewTagToCard[viewTapped!.tag]!
            self.activeCardSourceStack = self.viewTagToStack[viewTapped!.tag]!
            
            viewTapped?.superview?.bringSubviewToFront(viewTapped!)
            self.view.bringSubviewToFront((viewTapped?.superview)!)
            
            var cardParent = self.activeCard?.cardParent
            while((cardParent) != nil) {
                cardParent!.view.superview?.bringSubviewToFront(cardParent!.view)
                cardParent = cardParent?.cardParent
            }
        }
        else {
            self.activeCard = nil
        }
        
        if (self.activeCard != nil) {
            self.xCap = Int(point!.x - self.activeCard!.view.frame.origin.x)
            self.yCap = Int(point!.y - self.activeCard!.view.frame.origin.y)
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let point = touches.first?.locationInView(self.view)
        
        if self.activeCard != nil && (self.justWon || self.activeCardSourceStack?.stackType != .deck) {
            self.activeCard!.setPos(CGPoint(x: point!.x - CGFloat(self.xCap), y: point!.y - CGFloat(self.yCap)))
        }
    }
    
    // TODO: refactor touchesEnded.  It's convoluted, does too much, and just bad all around.
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if self.justWon {
            return
        }
        
        
        
        var droppedOnCardStack: CardStack? = nil
        let point = touches.first?.locationInView(self.view)
        if self.activeCard != nil {
            droppedOnCardStack = self.findStackUnderHover(self.activeCard!.view)
        }
        
        // if the deck is empty, we have to be able to detect a click on it with no card
        if (droppedOnCardStack == nil) {
            droppedOnCardStack = self.findActiveStack(point!)
        }
        
        if droppedOnCardStack == nil {
            // Not dropped on a stack; put it back where it was (card move to nowhere)
            self.activeCard?.cancelMove()
        }
        else {
            // Tapped deck
            if droppedOnCardStack!.stackType == .deck && (self.activeCardSourceStack?.stackType == .deck || self.deck!.cards.isEmpty) {
                if self.deck!.cards.count == 0 {
                    // tapped empty deck
                    let dealCount = self.deal!.cards.count
                    for _ in 0..<dealCount {
                        if let aCard = self.deal?.getTopCard() {
                            aCard.cardParent = nil
                            self.deck?.addCard(aCard)
                            self.deck!.cards.last?.faceUp = false
                            self.viewTagToStack[aCard.view.tag] = self.deck
                        }
                    }
                }
                else {
                    // Take up to 3 cards sourceStack the deck and move them to the deal
                    let deckCount  = self.deck!.cards.count
                    self.deckTaps  = 0
                    let cardsToAdd = 3 > deckCount ? deckCount : 3
                    for _ in 0..<cardsToAdd {
                        if let aCard = self.deck?.getTopCard() {
                            self.deal?.addCard(aCard)
                            self.viewTagToStack[aCard.view.tag] = self.deal
                        }
                        self.deckTaps++
                    }
                }
                self.undoBarButtonItem.enabled = true
                self.activeCard = nil
                
                // Refresh the appropriate rectangles (if used the moveCardBetweenStacks function above this wouldn't be necessary, but it needs to be smarter about 
                // things like parent relationships first)
                if self.deck!.cards.isEmpty {
                    self.deck!.view.layer.borderWidth = 1
                    self.deck!.view.layer.borderColor = UIColor.whiteColor().CGColor
                }
                
                if self.deal!.cards.isEmpty {
                    // Reset the size of the rectangle for the deal
                    var rec  = self.deal!.view.frame
                    rec.size = CGSizeMake(rec.size.width, self.deck!.view.frame.size.height)
                    self.deal!.view.frame = rec
                    self.deal!.view.layer.borderWidth = 1
                    self.deal!.view.layer.borderColor = UIColor.whiteColor().CGColor

                }
                
            }
            else if(droppedOnCardStack?.stackType == .cardstack || droppedOnCardStack?.stackType == .suitstack) {
                let droppedOnCard = droppedOnCardStack!.cards.last
                if self.acceptCardMove(self.activeCardSourceStack!, destinationStack: droppedOnCardStack!, onTopOfCard: droppedOnCard!) {
                    self.activeCardDestinationStack = droppedOnCardStack
                    self.undoBarButtonItem.enabled  = true
                    self.moveCardBetweenStacks(self.activeCard!, sourceStack: self.activeCardSourceStack!, destinationStack: droppedOnCardStack!)
                    self.deckTaps = 0
                }
                else {
                    // Card move to cardstack or suitstack cancelled because it wasn't accepted
                    // Cancelling a stack drag; clean up everything.
                    var rect = self.activeCard!.view.frame
                    // TODO: investigate that 45, might be a source of problems.
                    rect.size.height = self.view.bounds.size.height - self.activeCard!.view.frame.origin.y+45
                    self.activeCard?.cancelMove()
                }
            }
            else {
                // Card move to invalid stack type
                self.activeCard!.cancelMove()
            }
        }
        
        // Make all possible moves to suitstacks
        if self.autoSwitch.enabled {
            while self.findCardForSuitstack() {
            }
        }
        
        // Check to see if we've just won
        var won = true
        for i in 0..<self.suitStacks.count {
            if self.suitStacks[i]!.cards.count != 14 {
                won = false
            }
        }
        
        if won {
            self.runVictory()
        }
    }
    // MARK: End of touches implementations
    
    func findStackUnderHover(hover: UIImageView) -> CardStack? {
        // Get the coordinates of hover relative to its stack (its super view)
        let hoverSuperview = hover.superview
        
        // Get the coordinates of hover relative to the main view
        let hoverMainViewRect  = self.view.convertRect(hover.frame, fromView:hoverSuperview);
        
        
        for cs in self.cardStacks {
            if CGRectIntersectsRect(cs!.view.frame, hoverMainViewRect) {
                return cs
            }
        }
        
        for cs in self.suitStacks {
            if CGRectIntersectsRect(cs!.view.frame, hoverMainViewRect) {
                return cs
            }
        }
        
        if CGRectIntersectsRect(self.deck!.view.frame, hoverMainViewRect) {
            return self.deck
        }
        
        if CGRectIntersectsRect(self.deal!.view.frame, hoverMainViewRect) {
            return self.deal
        }
        
        if CGRectIntersectsRect(self.fub!.view.frame, hoverMainViewRect) {
            return self.fub
        }
        
        return nil
    }
    
    func findActiveStack(point: CGPoint) -> CardStack? {
        
        for cs in self.cardStacks {
            if(CGRectContainsPoint(cs!.view.frame, point))
            {
                return cs
            }
        }
        
        for cs in self.suitStacks {
            if(CGRectContainsPoint(cs!.view.frame, point))
            {
                return cs
            }
        }
        
        if(CGRectContainsPoint(self.deck!.view.frame, point))
        {
            return self.deck
        }
        
        if(CGRectContainsPoint(self.deal!.view.frame, point))
        {
            return self.deal
        }
        
        if(CGRectContainsPoint(self.fub!.view.frame, point))
        {
            return self.fub
        }
        
        return nil;

    }
    
    func runVictory() {
        print("Yay")
    }
    
    func findCardForSuitstack() -> Bool {
       let backupActive = self.activeCard;
        
        // Over all suitstacks, check each source
        for i in 0..<self.suitStacks.count {
            let topCard = self.suitStacks[i]!.cards.last
            //NSLog(@"TopCard: %p",topCard);
            
            // Check cardstacks
            for j in 0..<self.cardStacks.count {
                
                self.activeCard = self.cardStacks[j]!.cards.last
                
                if self.acceptCardMove(self.cardStacks[j]!, destinationStack: self.suitStacks[i]!, onTopOfCard: topCard!) {
                    // Make the move
                    self.moveCardBetweenStacks(self.activeCard!, sourceStack: self.cardStacks[i]!, destinationStack: self.suitStacks[i]!)
                    self.activeCard = backupActive
                    return true
                }
            }
            
            // Check fub
            self.activeCard = self.fub!.cards.last
            if self.acceptCardMove(self.fub!, destinationStack: self.suitStacks[i]!, onTopOfCard: topCard!) {
                // Make the move
                self.moveCardBetweenStacks(self.activeCard!, sourceStack: self.fub!, destinationStack: self.suitStacks[i]!)
                self.activeCard = backupActive;
                return true;
            }
            
            // Check deal
            self.activeCard = self.deal!.cards.last
            if self.acceptCardMove(self.deal!, destinationStack: self.suitStacks[i]!, onTopOfCard: topCard!) {
                // Make the move
                self.moveCardBetweenStacks(self.activeCard!, sourceStack: self.deal!, destinationStack: self.suitStacks[i]!)
                self.activeCard = backupActive;
                return true;
            }
        }
        
        self.activeCard = backupActive
        return false
    }
    
    func acceptCardMove(sourceStack: CardStack, destinationStack: CardStack, onTopOfCard: Card) -> Bool {
        //self.autoSwitch.enabled = false; return true // debug only
        
        if sourceStack == destinationStack {
            return false
        }
        
        if sourceStack.stackType == .suitstack || sourceStack.stackType == .deck {
            return false
        }
        
        if destinationStack.stackType == .deal {
            return false
        }
        
        if destinationStack.stackType == .deck {
            return false
        }
        
        if destinationStack.stackType == .cardstack {
            if destinationStack.cards.isEmpty {
                if sourceStack.stackType == .fub {
                    // until the face up blind is empty, allow cards sourceStack the fub to fill empty spaces
                    return true
                }
                else if self.fub!.cards.isEmpty {
                    // face up blind is empty; only allow cards of the appropriate rank
                    // suit stack starter minus one, or king if ace is starter
                    if self.activeCard!.rank == self.suitStackStarter-1 || (self.suitStackStarter == 1 && self.activeCard!.rank == 13) {
                        return true
                    }
                }
            }
            else if(sourceStack.stackType == .fub || sourceStack.stackType == .cardstack || sourceStack.stackType == .deal) {
                if(self.activeCard!.color == onTopOfCard.color) {
                    return false
                }
                if(self.activeCard!.rank == onTopOfCard.rank-1 || (self.activeCard!.rank == 13 && onTopOfCard.rank == 1)) {
                    return true
                }
            }
        }
        
        if destinationStack.stackType == .suitstack {
            if destinationStack.cards.isEmpty && self.activeCard!.rank == self.suitStackStarter {
                self.score += 5
                return true
            }
            // Corner cases
            if(destinationStack.cards.isEmpty && (self.activeCard!.suit == onTopOfCard.suit) && (self.activeCard!.rank == onTopOfCard.rank+1 || (self.activeCard!.rank == 1 && onTopOfCard.rank == 13))) {
                self.score += 5
                return true
            }
        }
        return false

    }
    
    func moveCardBetweenStacks(cardToMove: Card?, sourceStack: CardStack, destinationStack: CardStack) -> Bool {
        // Since this is a recursive function, we stop when the card we're trying to move doesn't exist.
        if (cardToMove != nil && sourceStack != destinationStack){
            
            sourceStack.removeCard(cardToMove!)
            destinationStack.addCard(cardToMove!)
            
            // Clean parent card reference
            sourceStack.cards.last!.cardParent = nil
            
            self.viewTagToStack[cardToMove!.view.tag] = destinationStack
            self.moveCardBetweenStacks(cardToMove?.cardParent, sourceStack: sourceStack, destinationStack: destinationStack)
            
            return true
        }
        return false
    }
}
