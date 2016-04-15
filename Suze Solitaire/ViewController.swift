//
//  ViewController.swift
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 2/7/16.
//  Copyright © 2016 Kevin DeRonne. All rights reserved.
//

// TODO:  
// Add popup to confirm new game (?)
// Try to save state when swiped up
// Fix cards on suitstacks after rotating device
// Fix dragging stack of cards makes top card dissappear
// Go through all functions in ssViewController and make sure you either don't need them or have a swift version
// Fix card parents not being cleaned properly after auto move


//
// DONE:
// Fix bug where autobucks makes a move from the deal, then you tap undo. (undo now disabled after any autobucks action)
// Enable autocomplete button; fix code that changes its state
// Implement Undo
// Rename "Help" to "How to play"
// Add Segue to get to how to play screen
// Fix tapping on empty deck
// Fix borders appearing when they shouldn't  (was a debug statement in cardStack.swift)
// Implement state restoration
// Fix auto move emptying a cardstack not leaving a border (index problem in findCardForSuitStack making it so that the card wasn't in the stack we were trying to remove it from)
// Fix bug where a card from the FUB can't be placed on an empty cardstack after an autobucks move (same bug as above)
// Implement initTableTrivial
// Test Winning
// Fix bug where you can stick something to an empty deck

import UIKit

class ViewController: UIViewController {

    // MARK: OutletProperties
    
    @IBOutlet weak var bucksBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var winsBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var lossesBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var undoBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var autoSwitch: UISwitch!
    
    // MARK: Computed Properties
    var score: Int {
        get {
            let components = bucksBarButtonItem.title?.componentsSeparatedByString("$")
            return Int(components![1])!
        }
        set(newScore) {
            bucksBarButtonItem.title = String(format: "$%d", newScore)
            if newScore < 0 {
                bucksBarButtonItem.tintColor = UIColor.redColor()
            }
            else {
                bucksBarButtonItem.tintColor = UIColor.blackColor()
            }
        }
    }
    
    var wins: Int {
        get {
            let components = winsBarButtonItem.title?.componentsSeparatedByString(" ")
            return Int(components![1])!
        }
        set(newWins) {
            winsBarButtonItem.title = String(format: "Wins: %d", newWins)
        }
    }
    
    var losses: Int {
        get {
            let components = lossesBarButtonItem.title?.componentsSeparatedByString(" ")
            return Int(components![1])!
        }
        set(newLosses) {
            lossesBarButtonItem.title = String(format:"Losses: %d", newLosses)
        }
    }
    
    // MARK: Properties
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
    
    // Initial deck to pull cards from when setting up a game
    var cards      = [Card?]()
    // The ordered stacks at the top
    var suitStacks = [CardStack?]()
    // The working stacks at the bottom
    var cardStacks = [CardStack?]()
    // The "face up blind" stack
    var fub:  CardStack? = nil
    // The stack from which cards are drawn
    var deck: CardStack? = nil
    // The stack containing previously drawn cards
    var deal: CardStack? = nil
    
    // Allows us to quickly figure out which card was tapped
    var viewTagToCard  = [Int:Card?]()
    // Allows us to quickly figure out which stack was tapped
    var viewTagToStack = [Int:CardStack?]()
    
    
    // MARK: Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.navigationController?.navigationBarHidden = true // might need in viewDidAppear
        
        let tapGesture = UITapGestureRecognizer(target: self, action: "handleTapGesture:")
        tapGesture.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(tapGesture)
    }
    
    override func viewDidAppear(animated: Bool) {
        if self.doInitTable {
            print("Initializing table")
            self.score  = -45
            self.wins   = 0
            self.losses = 0
            self.autoSwitch.setOn(false, animated: true)
            self.initTable()
            self.doInitTable = false;
        }
        self.redrawTable()
    }
    
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        self.redrawTable()
    }
    
    override func encodeRestorableStateWithCoder(coder: NSCoder) {
    
        print("KDR encoding state");
        
        coder.encodeInteger(self.score,   forKey:"score")
        coder.encodeInteger(self.wins,    forKey:"wins")
        coder.encodeBool(self.justWon,    forKey: "justWon")
        coder.encodeInteger(self.losses,  forKey:"losses")
        coder.encodeBool(self.autoSwitch.enabled,  forKey:"autocomplete")
        coder.encodeInteger(self.xCap,    forKey:"xCap")
        coder.encodeInteger(self.yCap,    forKey:"yCap")
        coder.encodeInteger(self.suitStackStarter,  forKey:"suitStackStarter")
        
        for i in 0..<4 {
            coder.encodeObject(self.suitStacks[i], forKey:String("suitstack%d",i))
            coder.encodeObject(self.cardStacks[i], forKey:String("cardstack%d",i))
        }
        
        //coder.encodeObject(self.cards,      forKey:"cards")
        
        coder.encodeObject(self.fub,  forKey:"fub")
        coder.encodeObject(self.deck, forKey:"deck")
        coder.encodeObject(self.deal, forKey:"deal")
        
        super.encodeRestorableStateWithCoder(coder)
        
        print("KDR State encoded")
    }
    
    override func decodeRestorableStateWithCoder(coder: NSCoder) {
        print("KDR decoding state")
        super.decodeRestorableStateWithCoder(coder)
        
        self.doInitTable = false;
        
        self.score        = coder.decodeIntegerForKey("score")
        self.wins         = coder.decodeIntegerForKey("wins")
        self.losses       = coder.decodeIntegerForKey("losses")
        self.justWon      = coder.decodeBoolForKey("justWon")
        self.xCap         = coder.decodeIntegerForKey("xCap")
        self.yCap         = coder.decodeIntegerForKey("yCap")
        self.autoSwitch.enabled = coder.decodeBoolForKey("autocomplete")
        self.suitStackStarter   = coder.decodeIntegerForKey("suitStackStarter")
        
        
        
        //self.cards      = coder.decodeObjectforKey("cards")
        
        self.cards      = [Card?]()
        self.suitStacks = [CardStack?]()
        self.cardStacks = [CardStack?]()

        
        for i in 0..<4 {
            self.suitStacks.append(coder.decodeObjectForKey(String("suitstack%d",i)) as! CardStack?)
            self.cardStacks.append(coder.decodeObjectForKey(String("cardstack%d",i)) as! CardStack?)
        }
        
        self.fub        = coder.decodeObjectForKey("fub")  as! CardStack?
        self.deck       = coder.decodeObjectForKey("deck") as! CardStack?
        self.deal       = coder.decodeObjectForKey("deal") as! CardStack?
    }
    
    override func applicationFinishedRestoringState() {
        print("KDR Setting up subviews")
        
        self.view.addSubview(self.fub!.view)
        self.view.addSubview(self.deck!.view)
        self.view.addSubview(self.deal!.view)
        
        
        for i in 0..<4 {
            self.view.addSubview(self.cardStacks[i]!.view)
            self.view.addSubview(self.suitStacks[i]!.view)
        }
        
        // Loop over all cards and assign tags to their views, building the viewTagToCard and viewTagToStack
        // arrays in the process.
        var tagCount = 0
        for i in 0..<self.fub!.cards.count {
            
            self.fub!.cards[i].view.tag = tagCount;
            self.viewTagToCard[tagCount]  = self.fub!.cards[i]
            self.viewTagToStack[tagCount] = self.fub
            tagCount++;
        }
        
        for i in 0..<self.deck!.cards.count {
            self.deck!.cards[i].view.tag = tagCount
            self.viewTagToCard[tagCount]  = self.deck!.cards[i]
            self.viewTagToStack[tagCount] = self.deck
            tagCount++;
        }
        
        for i in 0..<self.deal!.cards.count {
            self.deal!.cards[i].view.tag = tagCount
            self.viewTagToCard[tagCount]  = self.deal!.cards[i]
            self.viewTagToStack[tagCount] = self.deal
            tagCount++;
        }
        
        for j in 0..<4 {
            for i in 0..<self.cardStacks[j]!.cards.count {
                self.cardStacks[j]!.cards[i].view.tag = tagCount
                self.viewTagToCard[tagCount]  = self.cardStacks[j]!.cards[i]
                self.viewTagToStack[tagCount] = self.cardStacks[j]
                tagCount++;
            }
            for i in 0..<self.suitStacks[j]!.cards.count {
                self.suitStacks[j]!.cards[i].view.tag = tagCount
                self.viewTagToCard[tagCount]  = self.suitStacks[j]!.cards[i]
                self.viewTagToStack[tagCount] = self.suitStacks[j]
                tagCount++;
            }
        }
        
        print("Deck has \(self.deck!.cards.count)")
    }
    
    func handleTapGesture(sender: UITapGestureRecognizer) {
        if sender.state == UIGestureRecognizerState.Recognized {
            // handling code
            
            let point = sender.locationInView(self.view)
            // Put up the card under point if possible
            //NSLog(@"double tap recognized at %f,%f",point.x,point.y);
            self.tryToPutUpCardAtPoint(point)
        }
    }
    
    func tryToPutUpCardAtPoint(point: CGPoint) {
        if let sourceStack = self.findActiveStack(point) {
            if (self.activeCard != nil) {
            
                for i in 0..<4 {
                    
                    let topCard = self.suitStacks[i]!.cards.last
                    if self.acceptCardMove(sourceStack, destinationStack: self.suitStacks[i]!, onTopOfCard: topCard) {
                        
                        self.moveCardBetweenStacks(self.activeCard, sourceStack: sourceStack, destinationStack: self.suitStacks[i]!)
                        
                        // Check to see if we've just won
                        var won = true;
                        for i in 0..<4 {
                            if self.suitStacks[i]!.cards.count != 13 {
                                won = false
                            }
                        }
                        
                        if(won == true) {
                            self.runVictory()
                        }
                        // If we've put up a card, we don't need to check further stacks
                        return
                    }
                }
            }
        }
    }

    
    @IBAction func startNewGame(sender: AnyObject) {
        
        self.cards.removeAll()
        
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
        // MARK: Debug trivial table
        // self.initTableTrivial()
        self.activeCard = nil
        self.redrawTable()
        print("Found \(self.suitStacks.count) suitstacks")
    }
    
    @IBAction func undoMove(sender: UIBarButtonItem) {
        // You only get one undo
        self.undoBarButtonItem.enabled = false
        
        /* We should only get to this point if the deck tap is being undone */
        if self.deckTaps > 0 {
            self.undoDeckTap()
        }
        else {
            if self.activeCardDestinationStack?.stackType == .suitstack {
                self.score -= 5 // Do we ever get here?
            }
            self.moveCardBetweenStacks(self.activeCard, sourceStack: self.activeCardDestinationStack!, destinationStack: self.activeCardSourceStack!)
        }
        
    }
    
    func undoDeckTap() {
        print("KDR Undoing deck tap")
        
        if self.deal!.cards.isEmpty {
            /* Move everything from the deck back to the deal */
           let deckCount = self.deck!.cards.count
            for _ in 0..<deckCount {
                let aCard = self.deck?.getTopCard()
                aCard!.cardParent = nil
                self.deal!.addCard(aCard!)
                self.deal!.cards.last!.faceUp = true
                self.viewTagToStack[aCard!.view.tag] = self.deal
            }
        }
        else {
            /* Take the top 3 cards from the deal and move them to the deck */
            let dealCount = self.deal!.cards.count
            var i = 0
            while i < self.deckTaps && i < dealCount {

                let aCard = self.deal!.getTopCard()
                // Set child cards of card being moved back to have no parent, so they aren't linked to things in the deck.
                
                self.deck!.addCard(aCard!)
                
                self.deal!.cards.last?.cardParent = nil
                
                self.deck!.cards.last?.faceUp = false
                self.viewTagToStack[aCard!.view.tag] = self.deck;
                i++
            }
        }
        
        if self.deal!.cards.isEmpty {
            self.deal!.view.layer.borderWidth = 1;
            self.deal!.view.layer.borderColor = UIColor.whiteColor().CGColor
        }
        
        self.activeCard = nil

        print("Deck has \(self.deck!.cards.count) cards")
        print("Deal has \(self.deal!.cards.count) cards")
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
        
        // Make sure the suitStack and cardStack arrays are clear (maybe this should be in startNewGame instead?)
        self.suitStacks.removeAll()
        self.cardStacks.removeAll()
        
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
        let aCard = self.cards.removeFirst()!
        dest.addCard(aCard)
        self.viewTagToCard[aCard.view.tag]  = aCard
        self.viewTagToStack[aCard.view.tag] = dest
        return aCard

    }
   
    
    func initTableTrivial() {
        print("Init table TRIVIAL called")
        self.undoBarButtonItem.enabled = false
        
        self.view.restorationIdentifier = "mainView"
        
        guard self.cards.count == 0 else {
            // We already have cards.  This should never happen.
            print("Bailing from initTableTrivial: cards count: \(self.cards.count)")
            return
        }
        
        
        // Create cards and shuffle them
        self.createCards()
        
        // Make sure the suitStack and cardStack arrays are clear (maybe this should be in startNewGame instead?)
        self.suitStacks.removeAll()
        self.cardStacks.removeAll()
        self.fub!.cards.removeAll()
        self.deck!.cards.removeAll()
        self.deal!.cards.removeAll()
        
        print("Cards created: \(self.cards.count)")
        
        // Create the suitstacks and cardstacks
        for i in 0..<4 {
            let aSuitStack = CardStack(type: .suitstack)
            for _ in 0..<10 {
                self.addCardToStack(aSuitStack)
            }
            self.suitStacks.append(aSuitStack)
            self.view.addSubview(aSuitStack.view)
            
            let aCardStack = CardStack(type: .cardstack)
            let topCard    = self.cards.removeFirst()!
            let middleCard = self.cards.removeFirst()!
            let bottomCard = self.cards.removeFirst()!
            
            topCard.faceUp    = true
            middleCard.faceUp = true
            bottomCard.faceUp = true
            
            if i == 2 {
                self.fub!.addCard(topCard)
                aCardStack.addCard(bottomCard)
                aCardStack.addCard(middleCard)
            }
            else if(i==3) {
                self.deal!.addCard(topCard)
                aCardStack.addCard(bottomCard)
                aCardStack.addCard(middleCard)
            }
            else {
                aCardStack.addCard(bottomCard)
                aCardStack.addCard(middleCard)
                aCardStack.addCard(topCard)
            }
            self.viewTagToCard[topCard.view.tag]  = topCard;
            self.viewTagToStack[topCard.view.tag] = aCardStack;
            
            self.viewTagToCard[bottomCard.view.tag]  = bottomCard;
            self.viewTagToStack[bottomCard.view.tag] = aCardStack;
            
            self.viewTagToCard[middleCard.view.tag]  = middleCard;
            self.viewTagToStack[middleCard.view.tag] = aCardStack;
            
            
            self.cardStacks.append(aCardStack)
            self.view.addSubview(aCardStack.view)
        }

        self.view.addSubview(self.deck!.view)
        self.view.addSubview(self.deal!.view)
        self.view.addSubview(self.fub!.view)
        
        print("Deck has \(self.deck!.cards.count)")
    }

    
    /*
        This function (redrawTable) is where the table layout actually gets done.  initTable just sets up the structures
        All of this is pretty hiddeous, with way too many constants but at least they're (mostly) based off of the screen size handed to us.
    */

    func redrawTable() {
        let screenWidth = CGRectGetWidth(self.view.bounds);
        let toolbarBottom = CGRectGetHeight((self.navigationController?.navigationBar.bounds)!)+(self.navigationController?.navigationBar.frame.origin.y)!
    
        var cardWidth  = CGFloat(screenWidth / 7);
        var cardHeight = cardWidth * 1.2;
        
        let toprowSpacer = toolbarBottom+cardHeight*0.1;  // Space from the top of the screen to the first row of cards.
        var secondSpacer = toprowSpacer+cardHeight*1.8;   // Space from the top row of cards to the second row
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
        
        // Get integer versions as that's what resize takes (maybe it shouldn't?)
        let cardHeightInt = Int(cardHeight)
        let cardWidthInt  = Int(cardWidth)
        
        // fub has too many cards and overlaps the deck on the iphone if we don't fudge it a little (hence the -15)
        self.fub!.resize(CGPoint(x: cardWidth/5, y: toprowSpacer), width: cardWidthInt, cardHeight: cardHeightInt)
        
        // Resize the four suit stacks
        for i in 0..<4 {
            var x = cardWidth * leftRightGapMultiplier
                x += CGFloat(i)*cardWidth + CGFloat(i)*widthSpacer
            
            self.suitStacks[i]!.resize(CGPoint(x: x, y: toprowSpacer), width: cardWidthInt, cardHeight: cardHeightInt)
        }
        
        self.deck!.resize(CGPoint(x: cardWidth/5, y: secondSpacer), width: cardWidthInt, cardHeight: cardHeightInt)
        self.deal!.resize(CGPoint(x: cardWidth+dealSpacer, y: secondSpacer), width: cardWidthInt, cardHeight: cardHeightInt)
        
        // Resize the four card stacks
        for i in 0..<4 {
            var x = cardWidth * leftRightGapMultiplier
            x += CGFloat(i)*cardWidth + CGFloat(i)*widthSpacer

            self.cardStacks[i]!.resize(CGPoint(x: x, y: secondSpacer), width: cardWidthInt, cardHeight: cardHeightInt)
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
        if viewTapped!.isKindOfClass(UIImageView) {
            self.activeCard            = self.viewTagToCard[viewTapped!.tag]!
            self.activeCardSourceStack = self.viewTagToStack[viewTapped!.tag]!
            self.activeCard?.savePos()
            
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
        if droppedOnCardStack == nil {
            droppedOnCardStack = self.findActiveStack(point!)
            
        }
        
        if droppedOnCardStack == nil {
            // Not dropped on a stack; put it back where it was (card move to nowhere)
            self.activeCard?.cancelMove()
        }
        else {
            
            // Tapped deck
            
            if droppedOnCardStack!.stackType == .deck && (self.deck!.cards.isEmpty || self.activeCardSourceStack?.stackType == .deck) {
                if self.deck!.cards.isEmpty {
                    // tapped empty deck
                    self.activeCard?.cancelMove()
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
                    // Take up to 3 cards from the deck and move them to the deal
                    print("Deck tapped")
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
                if self.acceptCardMove(self.activeCardSourceStack!, destinationStack: droppedOnCardStack!, onTopOfCard: droppedOnCard) {
                    self.activeCardDestinationStack = droppedOnCardStack
                    self.undoBarButtonItem.enabled  = true
                    self.moveCardBetweenStacks(self.activeCard!, sourceStack: self.activeCardSourceStack!, destinationStack: droppedOnCardStack!)
                    self.deckTaps = 0
                }
                else {
                    // Card move to cardstack or suitstack cancelled because it wasn't accepted
                    // Cancelling a stack drag; clean up everything.
                    print("move canceled due to lack of acceptance")
                    //var rect = self.activeCard!.view.frame
                    // TODO: investigate that 45, might be a source of problems.
                    //rect.size.height = self.view.bounds.size.height - self.activeCard!.view.frame.origin.y+45
                    self.activeCard?.cancelMove()
                }
            }
            else {
                // Card move to invalid stack type
                if let activeCard = self.activeCard {
                    activeCard.cancelMove()
                }
            }
        }
        
        // Make all possible moves to suitstacks
        if self.autoSwitch.on {
            while self.findCardForSuitstack() {
                undoBarButtonItem.enabled = false
            }
        }
        
        // Check to see if we've just won
        var won = true
        for i in 0..<self.suitStacks.count {
            if self.suitStacks[i]!.cards.count != 13 {
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
        if !self.justWon {
            self.activeCard = nil
            self.score += 250
            self.wins++
            self.undoBarButtonItem.enabled = false
            
            // Visual "reward" for winning
            
            let offset = CGFloat(75)
            var stacknum = CGFloat(0)
            for cs in self.suitStacks {
                var cardnum  = CGFloat(0)
                for card in cs!.cards {
                    card.view.removeFromSuperview()  // not necessary I believe; a view can only have one superview
                    self.view.addSubview(card.view)
                    card.cardParent = nil
                    let x = (cardnum*card.view.frame.size.width*0.735)+10;
                    let y = offset+(stacknum as CGFloat*(card.view.frame.size.height))
                    var rect = card.view.frame;
                    rect.origin = CGPoint(x:x, y:y)
                    
                    card.view.frame = rect
                    card.cardParent = nil
                    
                    let screenWidth  = CGRectGetWidth(self.view.bounds)
                    let screenHeight = CGRectGetHeight(self.view.bounds)
                    
                    if x>screenWidth || y>screenHeight {
                        NSLog("KDR OUT OF BOUNDS!!!!!!!!!!!!!")
                    }
                    
                    cardnum++
                }
                stacknum++
            }
            
        }
        self.justWon = true
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
                
                if self.acceptCardMove(self.cardStacks[j]!, destinationStack: self.suitStacks[i]!, onTopOfCard: topCard) {
                    // Make the move
                    self.moveCardBetweenStacks(self.activeCard!, sourceStack: self.cardStacks[j]!, destinationStack: self.suitStacks[i]!)
                    self.activeCard = backupActive
                    return true
                }
            }
            
            // Check fub
            self.activeCard = self.fub!.cards.last
            if self.acceptCardMove(self.fub!, destinationStack: self.suitStacks[i]!, onTopOfCard: topCard) {
                // Make the move
                self.moveCardBetweenStacks(self.activeCard!, sourceStack: self.fub!, destinationStack: self.suitStacks[i]!)
                self.activeCard = backupActive;
                return true;
            }
            
            // Check deal
            self.activeCard = self.deal!.cards.last
            if self.acceptCardMove(self.deal!, destinationStack: self.suitStacks[i]!, onTopOfCard: topCard) {
                // Make the move
                self.moveCardBetweenStacks(self.activeCard!, sourceStack: self.deal!, destinationStack: self.suitStacks[i]!)
                self.activeCard = backupActive;
                return true;
            }
        }
        
        self.activeCard = backupActive
        return false
    }
    
    // This function checks to see if an attempted card move is valid
    func acceptCardMove(sourceStack: CardStack, destinationStack: CardStack, onTopOfCard: Card?) -> Bool {
        print("Acceptance testing for move from stack type \(sourceStack.stackType) to \(destinationStack.stackType)")
        //self.autoSwitch.setOn(false, animated: true); return true // debug only
        
        if sourceStack === destinationStack {
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
        
        if self.activeCard == nil {
            return false
        }
        
        if destinationStack.stackType == .suitstack {
            if destinationStack.cards.isEmpty && self.activeCard!.rank == self.suitStackStarter {
                self.score += 5
                return true
            }
            // Corner cases
            if let onTopOfCardRank = onTopOfCard?.rank {
                if(!destinationStack.cards.isEmpty && (self.activeCard!.suit == onTopOfCard!.suit) && (self.activeCard!.rank == onTopOfCardRank+1 || (self.activeCard!.rank == 1 && onTopOfCardRank == 13))) {
                    self.score += 5
                    return true
                }
            }
        }

        if destinationStack.stackType == .cardstack {
            if destinationStack.cards.isEmpty {
                if sourceStack.stackType == .fub {
                    // until the face up blind is empty, allow cards from the fub to fill empty spaces
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
                if let onTopOfCardColor = onTopOfCard?.color {
                    if(self.activeCard!.color == onTopOfCardColor) {
                    return false
                    }
                }
                if let onTopOfCardRank = onTopOfCard?.rank {
                    if(self.activeCard!.rank == onTopOfCardRank-1 || (self.activeCard!.rank == 13 && onTopOfCardRank == 1)) {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    func moveCardBetweenStacks(cardToMove: Card?, sourceStack: CardStack, destinationStack: CardStack) -> Bool {
        // Since this is a recursive function, we stop when the card we're trying to move doesn't exist.
        if (cardToMove != nil && sourceStack !== destinationStack){
            
            sourceStack.removeCard(cardToMove!)
            destinationStack.addCard(cardToMove!)
            
            // Clean parent card reference from sourceStack
            sourceStack.cards.last?.cardParent = nil
            
            self.viewTagToStack[cardToMove!.view.tag] = destinationStack
            self.moveCardBetweenStacks(cardToMove!.cardParent, sourceStack: sourceStack, destinationStack: destinationStack)
            
            cardToMove!.cardParent = nil
            
            return true
        }
        return false
    }
}
