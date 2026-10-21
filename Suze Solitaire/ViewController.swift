//
//  ViewController.swift
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 2/7/16.
//  Copyright © 2016 Kevin DeRonne. All rights reserved.
//

//
// DONE:
// Add popup to confirm new game (instead, New Game offers Undo for a few seconds)
// Fix cards on suitstacks after rotating device (the table re-lays out on every size change; covered by a test)
// Fix dragging stack of cards makes top card dissappear (moved runs lost the links that lift them together when dragged)
// Go through all functions in ssViewController and make sure you either don't need them or have a swift version (Objective-C version removed)
// Fix card parents not being cleaned properly after auto move (card links are checked through play by a test)
// Fix bug where autobucks makes a move from the deal, then you tap undo. (undo now disabled after any autobucks action)
// Enable autocomplete button; fix code that changes its state
// Implement Undo
// Rename "Help" to "How to play"
// Add Segue to get to how to play screen
// Fix tapping on empty deck
// Fix borders appearing when they shouldn't  (was a debug statement in cardStack.swift)
// Implement state restoration (now saves the game to a file when the app is backgrounded)
// Fix auto move emptying a cardstack not leaving a border (index problem in findCardForSuitStack making it so that the card wasn't in the stack we were trying to remove it from)
// Fix bug where a card from the FUB can't be placed on an empty cardstack after an autobucks move (same bug as above)
// Implement initTableTrivial
// Test Winning
// Fix bug where you can stick something to an empty deck

import UIKit
import UIKit.UIGestureRecognizerSubclass


class ViewController: UIViewController {

    // MARK: OutletProperties
    
    @IBOutlet weak var bucksBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var winsBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var lossesBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var undoBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var toolbar: UIToolbar!
    var menuBarButtonItem: UIBarButtonItem? = nil
    
    // Whether any card that can go up to a suit stack is moved there automatically
    var autoMoves = false {
        didSet {
            self.updateMenu()
        }
    }
    
    // MARK: Computed Properties
    var score: Int {
        get {
            let components = bucksBarButtonItem.title?.components(separatedBy:"$")
            return Int(components![1])!
        }
        set(newScore) {
            bucksBarButtonItem.title = String(format: "$%d", newScore)
            if newScore < 0 {
                bucksBarButtonItem.tintColor = UIColor.red
            }
            else {
                bucksBarButtonItem.tintColor = UIColor.black
            }
        }
    }
    
    var wins: Int {
        get {
            let components = winsBarButtonItem.title?.components(separatedBy:" ")
            return Int(components![1])!
        }
        set(newWins) {
            winsBarButtonItem.title = String(format: "Wins: %d", newWins)
        }
    }
    
    var losses: Int {
        get {
            let components = lossesBarButtonItem.title?.components(separatedBy:" ")
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
    // While the banner after New Game is showing, the game it would bring back (see ViewController+NewGameUndo.swift)
    var gameBeforeNewGame: SavedGame? = nil
    var newGameUndoBanner: UIView? = nil
    var newGameUndoTimer: DispatchWorkItem? = nil
    static var newGameUndoDuration: TimeInterval = 5
    
    // The card a VoiceOver user has selected to move, and the stack it's in (see ViewController+Accessibility.swift)
    var accessibilitySelection: (card: Card, stack: CardStack)? = nil
    
    // The last card move, so it can be undone: the cards moved (bottom to top), and the stacks they came from and went to
    var lastMove: (cards: [Card], from: CardStack, to: CardStack)? = nil
    
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
        //let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGesture(sender:_:)))
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGesture))
        tapGesture.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(tapGesture)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.saveGame), name: UIScene.didEnterBackgroundNotification, object: nil)
        
        let menuItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: self.buildMenu())
        menuItem.accessibilityLabel = "More"
        self.toolbar.items = (self.toolbar.items ?? []) + [menuItem]
        self.menuBarButtonItem = menuItem
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if self.doInitTable {
            if let saved = self.loadSavedGame() {
                print("Restoring saved game")
                self.score  = saved.score
                self.wins   = saved.wins
                self.losses = saved.losses
                self.autoMoves = saved.autocomplete
                if saved.board == nil || !self.restoreBoard(saved.board!, suitStackStarter: saved.suitStackStarter) {
                    // The saved game had been won (or couldn't be read), so deal a new one
                    self.score -= 45
                    self.initTable()
                }
            }
            else {
                print("Initializing table")
                self.score  = -45
                self.wins   = 0
                self.losses = 0
                self.autoMoves = false
                self.initTable()
            }
            self.doInitTable = false;
        }
        self.redrawTable()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.redrawTable()
        }
    }
    
    // MARK: Saving and restoring games
    
    // A snapshot of the game.  Cards are identified by their view tag (see createCards), and each stack lists its
    // cards bottom to top.
    struct SavedGame: Codable {
        struct Board: Codable {
            var fub:        [Int]
            var deck:       [Int]
            var deal:       [Int]
            var suitStacks: [[Int]]
            var cardStacks: [[Int]]
        }
        var score:            Int
        var wins:             Int
        var losses:           Int
        var autocomplete:     Bool
        var suitStackStarter: Int
        // nil if the game was just won; the next launch deals a new game
        var board:            Board?
    }
    
    static var savedGameURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("SavedGame.json")
    
    // A snapshot of the game as it stands, or nil before the first deal
    func currentGame() -> SavedGame? {
        guard let fub = self.fub, let deck = self.deck, let deal = self.deal else {
            return nil
        }
        let tags = { (stack: CardStack?) in stack!.cards.map { $0.view.tag } }
        let board = SavedGame.Board(fub: tags(fub), deck: tags(deck), deal: tags(deal),
                                    suitStacks: self.suitStacks.map(tags), cardStacks: self.cardStacks.map(tags))
        return SavedGame(score: self.score, wins: self.wins, losses: self.losses, autocomplete: self.autoMoves,
                         suitStackStarter: self.suitStackStarter, board: self.justWon ? nil : board)
    }
    
    @objc func saveGame() {
        guard let game = self.currentGame() else {
            return
        }
        do {
            try JSONEncoder().encode(game).write(to: ViewController.savedGameURL, options: .atomic)
        }
        catch {
            print("Failed to save game: \(error)")
        }
    }
    
    func loadSavedGame() -> SavedGame? {
        guard let data = try? Data(contentsOf: ViewController.savedGameURL) else {
            return nil
        }
        return try? JSONDecoder().decode(SavedGame.self, from: data)
    }
    
    // Returns false if the saved board isn't a valid deal, in which case the caller should start a new table.
    func restoreBoard(_ board: SavedGame.Board, suitStackStarter: Int) -> Bool {
        let allTags = board.fub + board.deck + board.deal + board.suitStacks.joined() + board.cardStacks.joined()
        guard allTags.sorted() == Array(0..<52), board.suitStacks.count == 4, board.cardStacks.count == 4 else {
            print("Saved board is invalid; ignoring it")
            return false
        }
        
        self.undoBarButtonItem.isEnabled = false
        self.cards.removeAll()
        self.createCards()
        var cardsByTag = [Int: Card]()
        for case let card? in self.cards {
            cardsByTag[card.view.tag] = card
        }
        self.cards.removeAll()
        
        // Rebuild each stack the same way initTable does, so card parents get set up by addCard
        let makeStack = { (type: cardStackType, tags: [Int]) -> CardStack in
            let stack = CardStack(type: type)
            for tag in tags {
                let aCard = cardsByTag[tag]!
                stack.addCard(toadd: aCard)
                self.viewTagToCard[tag]  = aCard
                self.viewTagToStack[tag] = stack
            }
            return stack
        }
        
        self.suitStackStarter = suitStackStarter
        self.fub        = makeStack(.fub, board.fub)
        self.suitStacks = board.suitStacks.map { makeStack(.suitstack, $0) }
        self.deck       = makeStack(.deck, board.deck)
        self.deal       = makeStack(.deal, board.deal)
        self.cardStacks = board.cardStacks.map { makeStack(.cardstack, $0) }
        
        for stack in self.suitStacks + self.cardStacks + [self.deck, self.deal, self.fub] {
            self.view.addSubview(stack!.view)
        }
        self.activeCard = nil
        return true
    }
    
    @objc func handleTapGesture(sender: UITapGestureRecognizer) {
        if sender.state == UIGestureRecognizer.State.recognized {
            // handling code
            
            let point = sender.location(in: self.view)
            // Put up the card under point if possible
            //NSLog(@"double tap recognized at %f,%f",point.x,point.y);
            self.tryToPutUpCardAtPoint(point: point)
        }
    }
    
    func tryToPutUpCardAtPoint(point: CGPoint) {
        if let sourceStack = self.findActiveStack(point: point), let card = self.activeCard {
            if self.putUp(card: card, from: sourceStack) {
                self.finishTurn()
            }
        }
    }
    
    // Moves a card to whichever upper stack will take it; returns whether one did
    @discardableResult
    func putUp(card: Card, from sourceStack: CardStack) -> Bool {
        self.activeCard = card
        for i in 0..<4 {
            let topCard = self.suitStacks[i]!.cards.last
            if self.acceptCardMove(sourceStack: sourceStack, destinationStack: self.suitStacks[i]!, onTopOfCard: topCard) {
                self.performMove(card: card, from: sourceStack, to: self.suitStacks[i]!)
                return true
            }
        }
        return false
    }

    
    // Removes every stack and its cards from the screen
    func clearTable() {
        self.cards.removeAll()
        
        for viewContainer in [self.deck, self.deal, self.fub] + self.suitStacks + self.cardStacks {
            viewContainer!.view.subviews.forEach({ $0.removeFromSuperview() })
            viewContainer!.view.removeFromSuperview()
        }
    }
    
    @IBAction func startNewGameWithSender(sender: AnyObject) {
        // A game that's already won has nothing to lose, so only unfinished games can be brought back
        let previousGame = self.justWon ? nil : self.currentGame()
        
        self.clearTable()
        
        if self.justWon {
            // Have to get rid of the cards differently if we just won, as they are now just subviews of our view
            for v in self.view.subviews {
                if v.isKind(of:UIImageView.self) {
                    v.removeFromSuperview();
                }
            }
            self.justWon = false
        }
        else {
            self.losses += 1
        }
        
        self.score -= 45
        self.initTable()
        // MARK: Debug trivial table
        // self.initTableTrivial()
        self.activeCard = nil
        self.redrawTable()
        print("Found \(self.suitStacks.count) suitstacks")
        
        if let previousGame = previousGame {
            self.offerNewGameUndo(restoring: previousGame)
        }
        else {
            self.dismissNewGameUndo(animated: false)
        }
    }
    
    // The storyboard connects the undo button to undoMove:, so the parameter must be unlabeled
    @IBAction func undoMove(_ sender: UIBarButtonItem) {
        // You only get one undo
        self.undoBarButtonItem.isEnabled = false
        let frames = self.cardFrames()
        
        if self.deckTaps > 0 {
            self.undoDeckTap()
        }
        else if let move = self.lastMove, move.cards.allSatisfy({ card in move.to.cards.contains(card) }) {
            // Put the cards back in the same order, which also restores their parent links
            for card in move.cards {
                if move.to.stackType == .suitstack {
                    self.score -= 5
                }
                move.to.removeCard(toRemove: card)
                move.from.addCard(toadd: card)
                self.viewTagToStack[card.view.tag] = move.from
            }
            move.to.cards.last?.cardParent = nil
            move.cards.last?.cardParent    = nil
        }
        self.lastMove   = nil
        self.activeCard = nil
        self.layOutAndSlide(from: frames)
    }
    
    // Moves a card, and any cards on top of it, and remembers the move so it can be undone
    func performMove(card: Card, from source: CardStack, to destination: CardStack) {
        let frames = self.cardFrames()
        let countBefore = destination.cards.count
        self.moveCardBetweenStacks(cardToMove: card, sourceStack: source, destinationStack: destination)
        self.lastMove = (Array(destination.cards[countBefore...]), source, destination)
        self.deckTaps = 0
        self.undoBarButtonItem.isEnabled = true
        self.layOutAndSlide(from: frames)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: Animation
    
    // Where every card on the table is, in the main view's coordinates, by view tag
    func cardFrames() -> [Int: CGRect] {
        var frames = [Int: CGRect]()
        for case let card? in self.viewTagToCard.values {
            if let superview = card.view.superview {
                frames[card.view.tag] = self.view.convert(card.view.frame, from: superview)
            }
        }
        return frames
    }
    
    // Lays out the table, then slides each card that moved from where it was (see cardFrames) to its new place
    func layOutAndSlide(from oldFrames: [Int: CGRect]) {
        self.redrawTable()
        if UIAccessibility.isReduceMotionEnabled {
            return
        }
        for case let card? in self.viewTagToCard.values {
            guard let superview = card.view.superview, let old = oldFrames[card.view.tag] else {
                continue
            }
            let end   = card.view.frame
            let start = superview.convert(old, from: self.view)
            if start.origin == end.origin {
                continue
            }
            // Keep the moving card above the stacks it passes over
            self.view.bringSubviewToFront(superview)
            card.view.frame = start
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                card.view.frame = end
            }
        }
        if let banner = self.newGameUndoBanner {
            self.view.bringSubviewToFront(banner)
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
                self.deal!.addCard(toadd: aCard!)
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
                
                self.deck!.addCard(toadd: aCard!)
                
                self.deal!.cards.last?.cardParent = nil
                
                self.deck!.cards.last?.faceUp = false
                self.viewTagToStack[aCard!.view.tag] = self.deck;
                i += 1
            }
        }
        
        if self.deal!.cards.isEmpty {
            self.deal!.view.layer.borderWidth = 1;
            self.deal!.view.layer.borderColor = UIColor.white.cgColor
        }
        
        self.activeCard = nil

        print("Deck has \(self.deck!.cards.count) cards")
        print("Deal has \(self.deal!.cards.count) cards")
    }
    
    
    func initTable() {
        print("Init table called")
        self.undoBarButtonItem.isEnabled = false
        
        self.view.restorationIdentifier = "mainView"
        
        guard self.cards.count == 0 else {
            // We already have cards.  This should never happen.
            print("Bailing from initTable: cards count: \(self.cards.count)")
            return
        }
        
        
        // Create cards and shuffle them
        self.createCards()
        self.cards.shuffle()
        
        // Make sure the suitStack and cardStack arrays are clear (maybe this should be in startNewGame instead?)
        self.suitStacks.removeAll()
        self.cardStacks.removeAll()
        
        print("Cards created: \(self.cards.count)")
        
        // Create the face up blind (fub)
        
        self.fub = CardStack(type: .fub)
        for _ in 0..<13 {
            addCardToStack(dest: self.fub!)
        }

        // Create the suitstacks (upper stacks)
        for i in 0..<4 {
            let aSuitStack = CardStack(type: .suitstack)
            if i == 0 {
                let aCard = self.addCardToStack(dest: aSuitStack)
                self.suitStackStarter = aCard.rank
            }
            self.suitStacks.append(aSuitStack)
            self.view.addSubview(aSuitStack.view)
        }
        
        // Create the deck
        self.deck = CardStack(type: .deck)
        for _ in 0..<34 {
            self.addCardToStack(dest: self.deck!)
        }
        
        // Create the deal
        self.deal = CardStack(type: .deal)
        
        // Create the four card stacks (lower stacks)
        for _ in 0..<4 {
            let aCardStack = CardStack(type: .cardstack)
            self.addCardToStack(dest: aCardStack)
            self.cardStacks.append(aCardStack)
            self.view.addSubview(aCardStack.view)
        }
        
        self.view.addSubview(self.deck!.view)
        self.view.addSubview(self.deal!.view)
        self.view.addSubview(self.fub!.view)
        self.activeCard = nil
        
        print("Deck has \(self.deck!.cards.count)")
    }
    
    
    
    @discardableResult
    func addCardToStack(dest: CardStack) -> Card{
        let aCard = self.cards.removeFirst()!
        dest.addCard(toadd: aCard)
        self.viewTagToCard[aCard.view.tag]  = aCard
        self.viewTagToStack[aCard.view.tag] = dest
        return aCard

    }
   
    
    func initTableTrivial() {
        print("Init table TRIVIAL called")
        self.undoBarButtonItem.isEnabled = false
        
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
                self.addCardToStack(dest: aSuitStack)
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
                self.fub!.addCard(toadd: topCard)
                aCardStack.addCard(toadd: bottomCard)
                aCardStack.addCard(toadd: middleCard)
            }
            else if(i==3) {
                self.deal!.addCard(toadd: topCard)
                aCardStack.addCard(toadd: bottomCard)
                aCardStack.addCard(toadd: middleCard)
            }
            else {
                aCardStack.addCard(toadd: bottomCard)
                aCardStack.addCard(toadd: middleCard)
                aCardStack.addCard(toadd: topCard)
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
        guard self.fub != nil else {
            // No table yet
            return
        }
        self.view.layoutIfNeeded()
        let bounds = self.view.bounds
        let safe   = self.view.safeAreaInsets
        let toolbarBottom = CGRectGetHeight((self.navigationController?.navigationBar.bounds)!)+(self.navigationController?.navigationBar.frame.origin.y)!
        // Fanned stacks may reach down to just above the bottom toolbar
        let tableBottom = self.toolbar.frame.minY - 8
        // The iPad layout needs room; narrow iPad windows (Split View, Slide Over, Stage Manager) use the iPhone layout
        let isPad = UIDevice.current.userInterfaceIdiom == .pad && bounds.width >= 600 && bounds.height >= 600
        
        var cardWidth, cardHeight: CGFloat
        var fubPoint, deckPoint, dealPoint: CGPoint
        var stackXs = [CGFloat]()
        var toprowSpacer, secondSpacer: CGFloat
        
        if !isPad && bounds.width > bounds.height {
            // iPhone landscape: size the cards so two rows fit in the height, with the blind, deck and deal side by side on
            // the left, then a wider gap and the four stacks.  The top row takes 1.6 card heights (a margin, the upper
            // stacks' cards with the one under them peeking out below, and a gap), leaving the lower stacks 1.4 to fan in.
            cardHeight = (tableBottom - toolbarBottom) / 3
            cardWidth  = cardHeight / Card.aspectRatio
            var gap    = cardWidth / 5
            let rowWidth       = { 7*cardWidth + 5*gap + cardWidth*0.6 }
            let availableWidth = bounds.width - safe.left - safe.right
            if rowWidth() > availableWidth {
                let scale = availableWidth / rowWidth()
                cardWidth *= scale; cardHeight *= scale; gap *= scale
            }
            let left = safe.left + (availableWidth - rowWidth()) / 2
            toprowSpacer = toolbarBottom + cardHeight*0.1
            // Upper stacks show the card under their top one this far below it (see CardStack.resize)
            let peek     = CGFloat(Int(cardHeight/2.5))
            secondSpacer = toprowSpacer + cardHeight + peek + cardHeight*0.1
            fubPoint  = CGPoint(x: left, y: toprowSpacer)
            deckPoint = CGPoint(x: left + cardWidth + gap, y: toprowSpacer)
            dealPoint = CGPoint(x: left + 2*(cardWidth + gap), y: toprowSpacer)
            let stacksLeft = left + 3*cardWidth + 2*gap + cardWidth*0.6
            stackXs = (0..<4).map { stacksLeft + CGFloat($0)*(cardWidth + gap) }
        }
        else {
            // On iPhone the rows span 7.2 card widths (the fub/deck/deal column, then the gap and four stacks), plus a cardWidth/5
            // margin on the right.  The iPad sizes its cards below, but its row spacing is still based on screenWidth/7.
            let screenWidth = CGRectGetWidth(bounds);
            cardWidth  = CGFloat(screenWidth / (isPad ? 7 : 7.4));
            cardHeight = cardWidth * Card.aspectRatio;
            
            toprowSpacer = toolbarBottom+cardHeight*0.1;  // Space from the top of the screen to the first row of cards.
            var leftRightGapMultiplier = CGFloat(2.8);
            
            var widthSpacer  = cardWidth/15;
            var dealSpacer   = 2*(cardWidth/5);
            
            if(isPad) {
                cardWidth    = screenWidth/10;
                widthSpacer  = cardWidth/2.0;
                dealSpacer   = 2*(cardWidth/5);
                leftRightGapMultiplier = 4;
                cardHeight   = cardWidth*Card.aspectRatio;
                
            }
            
            // The second row starts just below the blind with all 13 of its cards fanned out
            secondSpacer = toprowSpacer + cardHeight + CGFloat(12*CardStack.fannedSliceHeight) + cardHeight*0.15
            
            fubPoint  = CGPoint(x: cardWidth/5, y: toprowSpacer)
            deckPoint = CGPoint(x: cardWidth/5, y: secondSpacer)
            dealPoint = CGPoint(x: cardWidth+dealSpacer, y: secondSpacer)
            stackXs   = (0..<4).map { cardWidth*leftRightGapMultiplier + CGFloat($0)*(cardWidth + widthSpacer) }
        }
        
        // Get integer versions as that's what resize takes (maybe it shouldn't?)
        let cardHeightInt = Int(cardHeight)
        let cardWidthInt  = Int(cardWidth)
        let place = { (stack: CardStack?, point: CGPoint) in
            stack!.resize(point: point, width: cardWidthInt, cardHeight: cardHeightInt, maxHeight: Int(tableBottom - point.y), compact: !isPad)
        }
        
        place(self.fub, fubPoint)
        place(self.deck, deckPoint)
        place(self.deal, dealPoint)
        for i in 0..<4 {
            place(self.suitStacks[i], CGPoint(x: stackXs[i], y: toprowSpacer))
            place(self.cardStacks[i], CGPoint(x: stackXs[i], y: secondSpacer))
        }
        self.updateAccessibility()
    }
    
    func createCards() {
        let backImgFile = "cardback.png";
        var tagCounter  = 0;
        var faceImgFile = String()
        
        
        for suit in [cardSuit.Clubs, .Diamonds, .Hearts, .Spades] {
            for i in 1...13 {
                if(UIDevice.current.userInterfaceIdiom == .pad) {
                    faceImgFile = String.init(format: suit.simpleDescription() + "%d.png", i)
                }
                else {
                    faceImgFile = String.init(format: suit.simpleDescription() + "%d-iphone.png",i)
                }
                
                let aCard = Card(suit: suit, rank: i, faceImageFilename: faceImgFile, backImageFilename: backImgFile, tag: tagCounter)
                self.cards.append(aCard)
                tagCounter += 1;
            }
        }
    }
    
    // MARK: Touches Implementations
    override dynamic func touchesBegan(_ touches:Set<UITouch>, with event: UIEvent?) {
        let point = touches.first?.location(in: self.view)
        let viewTapped = self.view.hitTest(point!, with: event)
        if viewTapped!.isKind(of:UIImageView.self) {
            self.activeCard            = self.viewTagToCard[viewTapped!.tag]!
            self.activeCardSourceStack = self.viewTagToStack[viewTapped!.tag]!
            self.activeCard?.savePos()
            self.liftRun(startingAt: self.activeCard!)
        }
        else {
            self.activeCard = nil
        }
        
        if (self.activeCard != nil) {
            self.xCap = Int(point!.x - self.activeCard!.view.frame.origin.x)
            self.yCap = Int(point!.y - self.activeCard!.view.frame.origin.y)
        }
    }
    
    // Brings a card being picked up, and the cards on top of it, above everything else so they stay visible while dragged
    func liftRun(startingAt card: Card) {
        card.view.superview?.bringSubviewToFront(card.view)
        if let stackView = card.view.superview {
            self.view.bringSubviewToFront(stackView)
        }
        var cardParent = card.cardParent
        while cardParent != nil {
            cardParent!.view.superview?.bringSubviewToFront(cardParent!.view)
            cardParent = cardParent?.cardParent
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        let point = touches.first?.location(in: self.view)
        
        if self.activeCard != nil && (self.justWon || self.activeCardSourceStack?.stackType != .deck) {
            self.activeCard!.setPos(point: CGPoint(x: point!.x - CGFloat(self.xCap), y: point!.y - CGFloat(self.yCap)))
            // Show what the drag uncovers (only once the card moves, so taps don't flash it)
            self.activeCardSourceStack?.updateFaces(lifting: self.activeCard)
        }
    }
    
    // TODO: refactor touchesEnded.  It's convoluted, does too much, and just bad all around.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.justWon {
            return
        }
        
        var droppedOnCardStack: CardStack? = nil
        let point = touches.first?.location(in: self.view)
        if self.activeCard != nil {
            droppedOnCardStack = self.findStackUnderHover(hover: self.activeCard!.view)
            
        }
        
        // if the deck is empty, we have to be able to detect a click on it with no card
        if droppedOnCardStack == nil {
            droppedOnCardStack = self.findActiveStack(point: point!)
            
        }
        
        if droppedOnCardStack == nil {
            // Not dropped on a stack; put it back where it was (card move to nowhere)
            self.activeCard?.cancelMove()
        }
        else {
            
            // Tapped deck
            
            if droppedOnCardStack!.stackType == .deck && (self.deck!.cards.isEmpty || self.activeCardSourceStack?.stackType == .deck) {
                self.tapDeck()
            }
            else if(droppedOnCardStack?.stackType == .cardstack || droppedOnCardStack?.stackType == .suitstack) {
                let droppedOnCard = droppedOnCardStack!.cards.last
                if self.acceptCardMove(sourceStack: self.activeCardSourceStack!, destinationStack: droppedOnCardStack!, onTopOfCard: droppedOnCard) {
                    self.performMove(card: self.activeCard!, from: self.activeCardSourceStack!, to: droppedOnCardStack!)
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
        // A card that went back covers the one under it again
        self.activeCardSourceStack?.updateFaces()
        
        self.finishTurn()
    }
    // iOS cancels touches it takes over mid-drag, such as for an incoming call or a system gesture; put the cards back
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.justWon {
            return
        }
        self.activeCard?.cancelMove()
        self.activeCardSourceStack?.updateFaces()
        self.activeCard = nil
    }
    // MARK: End of touches implementations
    
    // Deals up to three cards from the deck, or turns the deal back over when the deck is empty
    func tapDeck() {
        let frames = self.cardFrames()
        defer {
            self.layOutAndSlide(from: frames)
        }
        if self.deck!.cards.isEmpty {
            // tapped empty deck
            self.activeCard?.cancelMove()
            let dealCount = self.deal!.cards.count
            for _ in 0..<dealCount {
                if let aCard = self.deal?.getTopCard() {
                    aCard.cardParent = nil
                    self.deck?.addCard(toadd: aCard)
                    self.deck!.cards.last?.faceUp = false
                    self.viewTagToStack[aCard.view.tag] = self.deck
                }
            }
            // Any non-zero count works here: undoDeckTap moves the whole deck back when the deal is empty
            self.deckTaps = 1
        }
        else {
            // Take up to 3 cards from the deck and move them to the deal
            print("Deck tapped")
            let deckCount  = self.deck!.cards.count
            self.deckTaps  = 0
            let cardsToAdd = 3 > deckCount ? deckCount : 3
            for _ in 0..<cardsToAdd {
                if let aCard = self.deck?.getTopCard() {
                    self.deal?.addCard(toadd: aCard)
                    self.viewTagToStack[aCard.view.tag] = self.deal
                }
                self.deckTaps += 1
            }
        }
        self.undoBarButtonItem.isEnabled = true
        self.lastMove   = nil
        self.activeCard = nil
        
        // Refresh the appropriate rectangles (if used the moveCardBetweenStacks function above this wouldn't be necessary, but it needs to be smarter about 
        // things like parent relationships first)
        if self.deck!.cards.isEmpty {
            self.deck!.view.layer.borderWidth = 1
            self.deck!.view.layer.borderColor = UIColor.white.cgColor
        }
        
        if self.deal!.cards.isEmpty {
            // Reset the size of the rectangle for the deal
            var rec  = self.deal!.view.frame
            rec.size = CGSizeMake(rec.size.width, self.deck!.view.frame.size.height)
            self.deal!.view.frame = rec
            self.deal!.view.layer.borderWidth = 1
            self.deal!.view.layer.borderColor = UIColor.white.cgColor

        }
    }
    
    // Everything that happens after the player moves: automatic moves, layout, and checking for a win
    func finishTurn() {
        let frames = self.cardFrames()
        // Make all possible moves to suitstacks
        if self.autoMoves {
            while self.findCardForSuitstack() {
                undoBarButtonItem.isEnabled = false
            }
        }
        
        // Re-lay out so stacks that grew squeeze to fit above the toolbar
        self.layOutAndSlide(from: frames)
        
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
    
    func findStackUnderHover(hover: UIImageView) -> CardStack? {
        // Get the coordinates of hover relative to its stack (its super view)
        let hoverSuperview = hover.superview
        
        // Get the coordinates of hover relative to the main view
        let hoverMainViewRect  = self.view.convert(hover.frame, from:hoverSuperview);
        
        
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
            self.announce("You won! $250")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.activeCard = nil
            self.score += 250
            self.wins += 1
            self.undoBarButtonItem.isEnabled = false
            
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
                    
                    cardnum += 1
                }
                stacknum += 1
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
                
                if self.acceptCardMove(sourceStack: self.cardStacks[j]!, destinationStack: self.suitStacks[i]!, onTopOfCard: topCard) {
                    // Make the move
                    self.moveCardBetweenStacks(cardToMove: self.activeCard!, sourceStack: self.cardStacks[j]!, destinationStack: self.suitStacks[i]!)
                    self.activeCard = backupActive
                    return true
                }
            }
            
            // Check fub
            self.activeCard = self.fub!.cards.last
            if self.acceptCardMove(sourceStack: self.fub!, destinationStack: self.suitStacks[i]!, onTopOfCard: topCard) {
                // Make the move
                self.moveCardBetweenStacks(cardToMove: self.activeCard!, sourceStack: self.fub!, destinationStack: self.suitStacks[i]!)
                self.activeCard = backupActive;
                return true;
            }
            
            // Check deal
            self.activeCard = self.deal!.cards.last
            if self.acceptCardMove(sourceStack: self.deal!, destinationStack: self.suitStacks[i]!, onTopOfCard: topCard) {
                // Make the move
                self.moveCardBetweenStacks(cardToMove: self.activeCard!, sourceStack: self.deal!, destinationStack: self.suitStacks[i]!)
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
    
    @discardableResult
    func moveCardBetweenStacks(cardToMove: Card?, sourceStack: CardStack, destinationStack: CardStack) -> Bool {
        // Since this is a recursive function, we stop when the card we're trying to move doesn't exist.
        if (cardToMove != nil && sourceStack !== destinationStack){
            
            sourceStack.removeCard(toRemove: cardToMove!)
            destinationStack.addCard(toadd: cardToMove!)
            
            // Clean parent card reference from sourceStack
            sourceStack.cards.last?.cardParent = nil
            
            self.viewTagToStack[cardToMove!.view.tag] = destinationStack
            // Then the cards on top of it.  Adding each one to the destination links it to the card below, so the run can
            // be moved together again later.
            self.moveCardBetweenStacks(cardToMove: cardToMove!.cardParent, sourceStack: sourceStack, destinationStack: destinationStack)
            
            return true
        }
        return false
    }
}
