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
    // Held strongly, since they leave the navigation bar except in iPhone Duo's strip (see ViewController+Controls.swift)
    @IBOutlet var undoBarButtonItem: UIBarButtonItem!
    var newGameBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var toolbar: UIToolbar!
    // The table's own New Game, Undo and "..." buttons in its corners
    lazy var newGameButton = self.makeCornerButton(symbol: "arrow.triangle.2.circlepath", label: "New Game") { [unowned self] in self.startNewGameWithSender(sender: self) }
    lazy var undoButton    = self.makeCornerButton(symbol: "arrow.uturn.backward", label: "Undo") { [unowned self] in self.undoMove(self) }
    lazy var menuButton    = self.makeMenuButton()
    // The score, wins and losses written on the felt beside the "..." button
    let chalkLine = UILabel()
    lazy var scoreCounter = ScoreCounter { [unowned self] in self.updateChalk() }
    // The size the table was last laid out for (see viewDidLayoutSubviews)
    var laidOutSize = CGSize.zero
    // Banners sit this far above the toolbar, and the table stops short of them
    static let bannerSpacing: CGFloat = 12
    static let bannerHeight: CGFloat  = 44
    
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
            // Once the table is showing, the score on the felt counts its way to the new one
            self.scoreCounter.count(to: newScore, animated: self.view.window != nil && !self.doInitTable)
            if newScore < 0 {
                bucksBarButtonItem.tintColor = .systemRed
            }
            else {
                bucksBarButtonItem.tintColor = .label
            }
            self.updateChalk()
        }
    }
    
    var wins: Int {
        get {
            let components = winsBarButtonItem.title?.components(separatedBy:" ")
            return Int(components![1])!
        }
        set(newWins) {
            winsBarButtonItem.title = String(format: "Wins: %d", newWins)
            self.updateChalk()
        }
    }
    
    var losses: Int {
        get {
            let components = lossesBarButtonItem.title?.components(separatedBy:" ")
            return Int(components![1])!
        }
        set(newLosses) {
            lossesBarButtonItem.title = String(format:"Losses: %d", newLosses)
            self.updateChalk()
        }
    }
    
    // MARK: Properties
    var doInitTable = true
    var xCap = 0
    var yCap = 0;
    
    var activeCard:                      Card? = nil
    // The finger moving activeCard; other fingers are ignored until it lifts
    var activeTouch:                  UITouch? = nil
    var activeCardSourceStack:      CardStack? = nil
    // Until the first move or deal after New Game, the game Undo would bring back (see ViewController+NewGameUndo.swift)
    var gameBeforeNewGame: SavedGame? = nil
    // The table before each turn this session, oldest first, for Unlimited Undo (see ViewController+UnlimitedUndo.swift)
    var undoHistory = [SavedGame]() {
        didSet {
            self.refreshUndo()
        }
    }
    var hasUnlimitedUndo = false {
        didSet {
            self.refreshUndo()
            self.updateMenu()
        }
    }
    // The banner saying there's nothing to play (see ViewController+NoMoves.swift)
    var noMovesBanner: UIView? = nil
    // When cards were last dealt, by a new game or the deck, and the timer that shows the no-moves banner once it's been a
    // few seconds
    var dealtDate: Date? = nil
    var noMovesBannerTimer: DispatchWorkItem? = nil
    // Outlines where the card being dragged would land (see ViewController+Hints.swift)
    var dropHighlight: UIView? = nil
    weak var dropHighlightTarget: CardStack? = nil
    // Where the card being moved was picked up, to tell a drag from a tap
    var dragStart: CGPoint? = nil
    // Where a touch that started on the empty table went down, so lifting it nearby deals
    var tableTapStart: CGPoint? = nil
    
    // The card a VoiceOver user has selected to move, and the stack it's in (see ViewController+Accessibility.swift)
    var accessibilitySelection: (card: Card, stack: CardStack)? = nil
    
    // The last card move, so it can be undone: the cards moved (bottom to top), and the stacks they came from and went to
    var lastMove: (cards: [Card], from: CardStack, to: CardStack)? = nil
    
    var deckTaps   = 0
    var justWon    = false
    // The celebration of a win, over the table until New Game (see ViewController+Victory.swift)
    var victoryView: VictoryView? = nil
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
        // By default every touch's end waits until the double tap fails, which made taps and drops feel slow
        tapGesture.delaysTouchesEnded = false
        // Quick taps on the deck or the table each deal, rather than the second being taken as a double tap
        tapGesture.delegate = self
        self.view.addGestureRecognizer(tapGesture)
        self.setUpAppearance()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.saveGame), name: UIScene.didEnterBackgroundNotification, object: nil)
        
        self.setUpChalk()
        self.setUpDebugAccess()
        // New Game is a plus, like the New Game button in the "No moves left" banner
        self.newGameBarButtonItem = self.navigationItem.leftBarButtonItem
        self.newGameBarButtonItem.title = nil
        self.newGameBarButtonItem.image = UIImage(systemName: "arrow.triangle.2.circlepath")
        self.newGameBarButtonItem.accessibilityLabel = "New Game"
        self.hasUnlimitedUndo = UndoStore.shared.isPurchased
        NotificationCenter.default.addObserver(self, selector: #selector(self.unlimitedUndoChanged), name: UndoStore.changedNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // The view's traits aren't settled in viewDidLoad, so cards could be dealt in the wrong appearance
        self.applyAppearance()
        // scripts/layout-screenshots.sh passes -ScreenshotOrientation landscape to see the landscape layout
        if UserDefaults.standard.string(forKey: "ScreenshotOrientation") == "landscape" {
            self.view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        }
        #if DEBUG
        // scripts/win-video.sh passes -FinishTurnAfter <seconds> to play out the saved game's auto moves untouched
        let finishAfter = UserDefaults.standard.double(forKey: "FinishTurnAfter")
        if finishAfter > 0 && self.doInitTable {
            DispatchQueue.main.asyncAfter(deadline: .now() + finishAfter) {
                self.finishTurn()
            }
        }
        #endif
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
        self.updateNoMovesBanner()
    }
    
    // Folding or unfolding iPhone Duo, or resizing a window, can change the table's size at any time, not just on rotation
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if self.view.bounds.size != self.laidOutSize {
            self.laidOutSize = self.view.bounds.size
            self.redrawTable()
        }
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
        
        self.canUndo = false
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
            self.tryToPutUpCardAtPoint(point: point)
        }
    }
    
    // Whether a double tap starting on view could put up a card: it has to be a card that isn't in the deck
    func doubleTapCouldPutUp(_ view: UIView?) -> Bool {
        guard let view = view as? UIImageView, let stack = self.viewTagToStack[view.tag] ?? nil else {
            return false
        }
        return stack.stackType != .deck
    }

    func tryToPutUpCardAtPoint(point: CGPoint) {
        // The second tap's touch is cancelled once the double tap is recognized, before or after this; either way the card
        // is no longer being moved
        self.activeTouch = nil
        self.activeCard  = nil
        guard let view = self.view.hitTest(point, with: nil) as? UIImageView, let card = self.viewTagToCard[view.tag] ?? nil,
              let sourceStack = self.viewTagToStack[view.tag] ?? nil, sourceStack.stackType != .deck, card === sourceStack.cards.last else {
            return
        }
        card.cancelMove()
        sourceStack.updateFaces()
        if self.putUp(card: card, from: sourceStack) {
            self.activeCard = nil
            self.finishTurn()
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
            self.endCelebration()
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
        self.dealtDate = Date()
        print("Found \(self.suitStacks.count) suitstacks")
        
        self.gameBeforeNewGame = nil
        if let previousGame = previousGame {
            self.undoHistory.append(previousGame)
            self.offerNewGameUndo(restoring: previousGame)
        }
        self.updateNoMovesBanner()
    }
    
    // The storyboard connects the undo button to undoMove:, so the parameter must be unlabeled
    @IBAction func undoMove(_ sender: Any) {
        if self.hasUnlimitedUndo {
            self.undoTurn()
            return
        }
        // You only get one undo, which takes the table back to before the last turn
        self.canUndo = false
        _ = self.undoHistory.popLast()
        if self.gameBeforeNewGame != nil {
            self.undoNewGame()
            return
        }
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
        self.updateNoMovesBanner()
    }
    
    // Moves a card, and any cards on top of it, and remembers the move so it can be undone
    func performMove(card: Card, from source: CardStack, to destination: CardStack) {
        self.recordTurn()
        let frames = self.cardFrames()
        let countBefore = destination.cards.count
        self.moveCardBetweenStacks(cardToMove: card, sourceStack: source, destinationStack: destination)
        self.lastMove = (Array(destination.cards[countBefore...]), source, destination)
        self.deckTaps = 0
        self.gameBeforeNewGame = nil
        self.canUndo = true
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
    
    static let slideDuration: TimeInterval = 0.2

    // Lays out the table, then slides each card that moved from where it was (see cardFrames) to its new place
    func layOutAndSlide(from oldFrames: [Int: CGRect]) {
        self.redrawTable()
        if UIAccessibility.isReduceMotionEnabled {
            return
        }
        let moved = self.viewTagToCard.values.compactMap { $0 }.compactMap { card -> (Card, CGRect, CGRect)? in
            guard let superview = card.view.superview, let old = oldFrames[card.view.tag] else {
                return nil
            }
            let start = superview.convert(old, from: self.view)
            return start.origin == card.view.frame.origin ? nil : (card, start, card.view.frame)
        }
        // Cards still sliding from the last move, such as when the deck is tapped quickly, jump to where they were
        // going.  A layout that moves nothing, like the one at the end of each turn, leaves them to finish.
        if !moved.isEmpty {
            for case let card? in self.viewTagToCard.values {
                card.view.layer.removeAnimation(forKey: "position")
                card.view.layer.removeAnimation(forKey: "bounds")
            }
        }
        for (card, start, end) in moved {
            let superview = card.view.superview!
            // Keep the moving card above the stacks it passes over
            self.view.bringSubviewToFront(superview)
            card.view.frame = start
            UIView.animate(withDuration: ViewController.slideDuration, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                card.view.frame = end
            }
        }
        self.keepControlsInFront()
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
        
        self.activeCard = nil

        print("Deck has \(self.deck!.cards.count) cards")
        print("Deal has \(self.deal!.cards.count) cards")
    }
    
    
    func initTable() {
        print("Init table called")
        self.canUndo = false
        
        self.view.restorationIdentifier = "mainView"
        
        guard self.cards.count == 0 else {
            // We already have cards.  This should never happen.
            print("Bailing from initTable: cards count: \(self.cards.count)")
            return
        }
        
        
        // Create cards and shuffle them
        self.createCards()
        // scripts/screenshots.sh passes -ScreenshotSeed so the App Store screenshots always show the same deal
        if UserDefaults.standard.object(forKey: "ScreenshotSeed") != nil {
            var generator = SeededGenerator(seed: UInt64(UserDefaults.standard.integer(forKey: "ScreenshotSeed")))
            self.cards.shuffle(using: &generator)
        }
        else {
            self.cards.shuffle()
        }
        
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
        self.canUndo = false
        
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
        let controls = self.updateControlPlacement()
        self.view.layoutIfNeeded()
        let bounds = self.view.bounds
        let safe   = self.view.safeAreaInsets
        // Below New Game and Undo, or the top of the safe area beside iPhone Duo's strip
        let barBottom = controls.undo.map { $0.maxY + 10 } ?? safe.top
        let landscape = self.isLandscape
        let strip     = self.barsInStrip
        // Fanned stacks may reach down to the row of the "..." button and the score, or in portrait to just above the
        // banners over it
        let tableBottom = landscape
            ? controls.menu.minY - 8
            : controls.menu.minY - ViewController.bannerSpacing - ViewController.bannerHeight - 8
        // The roomy layout and its big cards, whatever the device: a full iPad, or iPhone Duo unfolded.  Narrow windows
        // (Split View, Slide Over, Stage Manager, a folded Duo) use the compact layout.
        let isPad = self.roomyTable
        self.useLargeCardArt(isPad)
        
        var cardWidth, cardHeight: CGFloat
        var fubPoint, deckPoint, dealPoint: CGPoint
        var stackXs = [CGFloat]()
        var toprowSpacer, secondSpacer: CGFloat
        
        if landscape {
            // Two long rows between New Game and Undo, starting level with them: the blind, deck and deal side by side,
            // then a wider gap and the four stacks.  The top row takes 1.5 card heights (its cards, the one under an upper
            // stack's top card peeking out below, and a gap), leaving the lower stacks 1.3 to fan in.  On iPhone Duo the
            // buttons are in the strip, so the rows use the whole table.
            let top   = strip ? safe.top + 16 : controls.undo?.minY ?? barBottom
            let left  = strip ? safe.left + 16 : (controls.newGame?.maxX ?? safe.left) + 16
            let right = strip ? bounds.width - safe.right - 16 : (controls.undo?.minX ?? bounds.width - safe.right) - 16
            cardHeight = (tableBottom - top) / 2.8
            cardWidth  = cardHeight / Card.aspectRatio
            // The roomy table's cards are limited by its width, so they sit closer together to be bigger
            var gap    = cardWidth / (isPad ? 8 : 5)
            let stacksGap = isPad ? 0.4 : 0.6
            let rowWidth = { 7*cardWidth + 5*gap + cardWidth*stacksGap }
            if rowWidth() > right - left {
                let scale = (right - left) / rowWidth()
                cardWidth *= scale; cardHeight *= scale; gap *= scale
            }
            let rowLeft = left + (right - left - rowWidth()) / 2
            toprowSpacer = top
            // Upper stacks show the card under their top one this far below it (see CardStack.resize)
            let peek     = isPad ? 30 : CGFloat(Int(cardHeight/2.5))
            secondSpacer = toprowSpacer + cardHeight + peek + cardHeight*0.1
            fubPoint  = CGPoint(x: rowLeft, y: toprowSpacer)
            deckPoint = CGPoint(x: rowLeft + cardWidth + gap, y: toprowSpacer)
            dealPoint = CGPoint(x: rowLeft + 2*(cardWidth + gap), y: toprowSpacer)
            let stacksLeft = rowLeft + 3*cardWidth + 2*gap + cardWidth*stacksGap
            stackXs = (0..<4).map { stacksLeft + CGFloat($0)*(cardWidth + gap) }
        }
        else {
            // From New Game's left edge to Undo's right: the blind over the deck and deal on the left, and the four stacks
            // on the right.  On iPhone 7 card widths in all, with the stacks close together; on the roomier table 7.6, a
            // fifth of a card apart.  iPhone Duo keeps its navigation buttons in a strip down the side, outside the safe area.
            let left  = controls.newGame?.minX ?? safe.left + 16
            let right = controls.undo?.maxX ?? bounds.width - safe.right - 16
            cardWidth  = (right - left) / (isPad ? 7.6 : 7)
            cardHeight = cardWidth * Card.aspectRatio
            let spacer = isPad ? cardWidth * 0.2 : cardWidth / 15
            
            toprowSpacer = barBottom + cardHeight*0.1  // Space from the top of the screen to the first row of cards.
            // The second row starts just below the blind with all 13 of its cards fanned out
            secondSpacer = toprowSpacer + cardHeight + CGFloat(12*CardStack.fannedSliceHeight) + cardHeight*0.15
            
            fubPoint  = CGPoint(x: left, y: toprowSpacer)
            deckPoint = CGPoint(x: left, y: secondSpacer)
            dealPoint = CGPoint(x: left + cardWidth*1.4, y: secondSpacer)
            stackXs   = (0..<4).map { right - 4*cardWidth - 3*spacer + CGFloat($0)*(cardWidth + spacer) }
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
                faceImgFile = String.init(format: suit.simpleDescription() + "%d-iphone.png", i)
                let largeFaceImgFile = String.init(format: suit.simpleDescription() + "%d.png", i)
                let aCard = Card(suit: suit, rank: i, faceImageFilename: faceImgFile, largeFaceImageFilename: largeFaceImgFile,
                                 backImageFilename: backImgFile, tag: tagCounter)
                self.cards.append(aCard)
                tagCounter += 1;
            }
        }
    }
    
    // MARK: Touches Implementations
    override dynamic func touchesBegan(_ touches:Set<UITouch>, with event: UIEvent?) {
        // Ignore a second finger while one is moving a card, unless that finger's touch went away without telling us
        if let active = self.activeTouch, active.phase != .ended && active.phase != .cancelled {
            return
        }
        guard let touch = touches.first else {
            return
        }
        self.activeTouch = touch
        let point = touch.location(in: self.view)
        self.beginTouch(at: point, on: self.view.hitTest(point, with: event))
    }
    
    // Picks up the card in viewTapped, if it can be played, or notes a touch on the empty table
    func beginTouch(at point: CGPoint?, on viewTapped: UIView?) {
        self.tableTapStart = nil
        self.dragStart     = point
        if viewTapped!.isKind(of:UIImageView.self) {
            let card  = self.viewTagToCard[viewTapped!.tag]!
            let stack = self.viewTagToStack[viewTapped!.tag]!
            // Cards under the top of the blind and deal can't be played, and picking one up would drag the blank cards above it
            if (stack?.stackType == .fub || stack?.stackType == .deal) && card !== stack?.cards.last {
                self.activeCard = nil
            }
            else {
                self.activeCard            = card
                self.activeCardSourceStack = stack
                self.activeCard?.savePos()
                self.liftRun(startingAt: self.activeCard!)
                if stack?.stackType != .deck {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
                }
            }
        }
        else {
            self.activeCard = nil
            // The table itself or an empty stack's outline, not a banner
            let stackViews = ([self.fub, self.deck, self.deal] + self.suitStacks + self.cardStacks).compactMap { $0?.view }
            if viewTapped === self.view || stackViews.contains(where: { $0 === viewTapped }) {
                self.tableTapStart = point
            }
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
        guard let touch = self.activeTouch, touches.contains(touch) else {
            return
        }
        let point: CGPoint? = touch.location(in: self.view)
        
        if self.activeCard != nil && self.activeCardSourceStack?.stackType != .deck {
            self.activeCard!.setPos(point: CGPoint(x: point!.x - CGFloat(self.xCap), y: point!.y - CGFloat(self.yCap)))
            // Show what the drag uncovers (only once the card moves, so taps don't flash it)
            self.activeCardSourceStack?.updateFaces(lifting: self.activeCard)
            self.updateDropHighlight()
        }
    }
    
    // TODO: refactor touchesEnded.  It's convoluted, does too much, and just bad all around.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = self.activeTouch, touches.contains(touch) else {
            return
        }
        self.activeTouch = nil
        if self.justWon {
            return
        }
        self.endTouch(at: touch.location(in: self.view))
    }
    
    // Drops the card being moved at point, or deals if the touch was a tap on the empty table
    func endTouch(at point: CGPoint?) {
        var droppedOnCardStack: CardStack? = nil
        self.removeDropHighlight()
        // A card dragged somewhere it can't go taps as it goes back, as gently as picking it up (a tap that doesn't move it doesn't)
        let draggedCard = self.activeCardSourceStack?.stackType == .deck ? nil : self.activeCard
        let dragged = draggedCard != nil && self.dragStart.map { hypot(point!.x - $0.x, point!.y - $0.y) >= 10 } == true
        defer {
            if dragged, let card = draggedCard, self.viewTagToStack[card.view.tag] ?? nil === self.activeCardSourceStack {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
            }
        }
        
        // A tap anywhere off the cards deals, as if the deck had been tapped
        if let start = self.tableTapStart, hypot(point!.x - start.x, point!.y - start.y) < 10 {
            self.tableTapStart = nil
            self.tapDeck()
            self.finishTurn()
            return
        }
        self.tableTapStart = nil
        if self.activeCard != nil {
            // Where the drop highlight shows, or else wherever the card is, to be turned down there
            droppedOnCardStack = self.dropTarget() ?? self.findStackUnderHover(hover: self.activeCard!.view)
            
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
        guard let touch = self.activeTouch, touches.contains(touch) else {
            return
        }
        self.activeTouch = nil
        self.removeDropHighlight()
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
        self.recordTurn()
        let frames = self.cardFrames()
        let shown  = self.deal?.cards.last
        defer {
            self.layOutAndSlide(from: frames)
            // The card on top of the deal fades to blank while the new cards slide over it, rather than going blank
            // before they're on their way or still showing its rank once they've landed
            if let shown = shown, shown !== self.deal?.cards.last, self.viewTagToStack[shown.view.tag] ?? nil === self.deal,
               !UIAccessibility.isReduceMotionEnabled {
                shown.view.image = shown.faceImage
                UIView.transition(with: shown.view, duration: ViewController.slideDuration,
                                  options: [.transitionCrossDissolve, .curveEaseOut, .allowUserInteraction]) {
                    shown.view.image = Card.blankFaceImage
                }
            }
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
        self.canUndo = true
        self.gameBeforeNewGame = nil
        self.lastMove   = nil
        self.activeCard = nil
        self.dealtDate  = Date()
        
        // Refresh the appropriate rectangles (if used the moveCardBetweenStacks function above this wouldn't be necessary, but it needs to be smarter about 
        // things like parent relationships first)
        if self.deal!.cards.isEmpty {
            // Reset the size of the rectangle for the deal
            var rec  = self.deal!.view.frame
            rec.size = CGSizeMake(rec.size.width, self.deck!.view.frame.size.height)
            self.deal!.view.frame = rec
        }
    }
    
    // Everything that happens after the player moves: automatic moves, layout, and checking for a win
    func finishTurn() {
        let frames = self.cardFrames()
        // Make all possible moves to suitstacks
        if self.autoMoves {
            while self.findCardForSuitstack() {
                self.canUndo = false
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
        self.updateNoMovesBanner()
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
            // A won game is over, so there's nothing to go back to
            self.undoHistory.removeAll()
            self.canUndo = false
            
            self.celebrateWin()
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
    // Whether card and the ones on top of it alternate colors and count down, as the lower stacks require
    func isRun(from card: Card, in stack: CardStack) -> Bool {
        guard let start = stack.cards.firstIndex(of: card) else {
            return false
        }
        let run = stack.cards[start...]
        return zip(run, run.dropFirst()).allSatisfy { lower, upper in
            upper.color != lower.color && (upper.rank == lower.rank - 1 || (upper.rank == 13 && lower.rank == 1))
        }
    }
    
    // Whether activeCard (and any cards on top of it) can move onto destinationStack, adding $5 if it's going to an upper stack
    func acceptCardMove(sourceStack: CardStack, destinationStack: CardStack, onTopOfCard: Card?) -> Bool {
        guard let card = self.activeCard, self.canMove(card, from: sourceStack, to: destinationStack, onTopOfCard: onTopOfCard) else {
            return false
        }
        if destinationStack.stackType == .suitstack {
            self.score += 5
        }
        return true
    }
    
    func canMove(_ card: Card, from sourceStack: CardStack, to destinationStack: CardStack, onTopOfCard: Card?) -> Bool {
        // Cards on top of the one picked up go with it.  Only the top card can leave the blind or deal, a single card at a
        // time goes to an upper stack, and runs only move between lower stacks.
        if card !== sourceStack.cards.last {
            if sourceStack.stackType != .cardstack || destinationStack.stackType != .cardstack || !self.isRun(from: card, in: sourceStack) {
                return false
            }
        }
        if sourceStack === destinationStack {
            return false
        }
        return self.destinationAccepts(card, from: sourceStack.stackType, to: destinationStack, onTopOfCard: onTopOfCard)
    }
    
    // The rules for what each stack takes, given the card that would go on top of it
    func destinationAccepts(_ card: Card, from sourceType: cardStackType, to destinationStack: CardStack, onTopOfCard: Card?) -> Bool {
        if sourceType == .suitstack || sourceType == .deck {
            return false
        }
        
        if destinationStack.stackType == .deal {
            return false
        }
        
        if destinationStack.stackType == .deck {
            return false
        }
        
        if destinationStack.stackType == .suitstack {
            if destinationStack.cards.isEmpty && card.rank == self.suitStackStarter {
                return true
            }
            // Corner cases
            if let onTopOfCardRank = onTopOfCard?.rank {
                if(!destinationStack.cards.isEmpty && (card.suit == onTopOfCard!.suit) && (card.rank == onTopOfCardRank+1 || (card.rank == 1 && onTopOfCardRank == 13))) {
                        return true
                }
            }
        }

        if destinationStack.stackType == .cardstack {
            if destinationStack.cards.isEmpty {
                if sourceType == .fub {
                    // until the face up blind is empty, allow cards from the fub to fill empty spaces
                    return true
                }
                else if self.fub!.cards.isEmpty {
                    // face up blind is empty; only allow cards of the appropriate rank
                    // suit stack starter minus one, or king if ace is starter
                    if card.rank == self.suitStackStarter-1 || (self.suitStackStarter == 1 && card.rank == 13) {
                        return true
                    }
                }
            }
            else if(sourceType == .fub || sourceType == .cardstack || sourceType == .deal) {
                if let onTopOfCardColor = onTopOfCard?.color {
                    if(card.color == onTopOfCardColor) {
                    return false
                    }
                }
                if let onTopOfCardRank = onTopOfCard?.rank {
                    if(card.rank == onTopOfCardRank-1 || (card.rank == 13 && onTopOfCardRank == 1)) {
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

extension ViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return self.doubleTapCouldPutUp(touch.view)
    }
}

// A repeatable shuffle (SplitMix64), for screenshots
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        self.state &+= 0x9E3779B97F4A7C15
        var z = self.state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
