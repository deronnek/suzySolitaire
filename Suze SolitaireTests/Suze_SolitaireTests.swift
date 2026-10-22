//
//  Suze_SolitaireTests.swift
//  Suze SolitaireTests
//

import XCTest
@testable import Suze_Solitaire

@MainActor
final class Suze_SolitaireTests: XCTestCase {

    var vc: ViewController!
    // A view controller only holds its navigation controller weakly, so the test keeps them alive
    var navigationControllers = [UINavigationController]()

    override class func setUp() {
        super.setUp()
        // The first accessibilityActivate() in a fresh process once returned false without running the view's activate
        // block, presumably while UIKit's accessibility support loaded; make that first call here, before any test
        MainActor.assumeIsolated {
            _ = UIView().accessibilityActivate()
        }
    }

    override func setUp() async throws {
        // Keep tests away from the real saved game
        ViewController.savedGameURL = FileManager.default.temporaryDirectory.appendingPathComponent("SavedGame-\(UUID().uuidString).json")
        Card.customBackImageURL     = FileManager.default.temporaryDirectory.appendingPathComponent("CardBack-\(UUID().uuidString).png")
        Card.customBackImage        = nil
        UserDefaults.standard.removeObject(forKey: ViewController.showsNoMovesKey)
        UserDefaults.standard.removeObject(forKey: ViewController.highlightsDropsKey)
        vc = try self.makeViewController()
        vc.score  = -45
        vc.wins   = 0
        vc.losses = 0
        vc.initTable()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: ViewController.savedGameURL)
        try? FileManager.default.removeItem(at: Card.customBackImageURL)
        Card.customBackImage = nil
        UserDefaults.standard.removeObject(forKey: ViewController.showsNoMovesKey)
        UserDefaults.standard.removeObject(forKey: ViewController.highlightsDropsKey)
        vc = nil
        navigationControllers = []
    }

    func makeViewController() throws -> ViewController {
        let storyboard = UIStoryboard(name: "MainStoryboard", bundle: Bundle(for: ViewController.self))
        let nav = try XCTUnwrap(storyboard.instantiateInitialViewController() as? UINavigationController)
        self.navigationControllers.append(nav)
        let vc  = try XCTUnwrap(nav.topViewController as? ViewController)
        vc.loadViewIfNeeded()
        return vc
    }

    func tags(_ stack: CardStack?) -> [Int] {
        return stack!.cards.map { $0.view.tag }
    }

    func allStacks(_ vc: ViewController) -> [CardStack?] {
        return [vc.fub, vc.deck, vc.deal] + vc.suitStacks + vc.cardStacks
    }

    func testNewTableUsesEveryCardOnce() {
        XCTAssertEqual(vc.fub!.cards.count, 13)
        XCTAssertEqual(vc.deck!.cards.count, 34)
        XCTAssertEqual(vc.deal!.cards.count, 0)
        XCTAssertEqual(vc.suitStacks.map { $0!.cards.count }, [1, 0, 0, 0])
        XCTAssertEqual(vc.cardStacks.map { $0!.cards.count }, [1, 1, 1, 1])
        XCTAssertEqual(allStacks(vc).flatMap(tags).sorted(), Array(0..<52))
        XCTAssertEqual(vc.suitStackStarter, vc.suitStacks[0]!.cards[0].rank)
    }

    func testTableFitsOnScreen() {
        for width in [320.0, 375.0, 390.0, 430.0] {
            vc.view.frame = CGRect(x: 0, y: 0, width: width, height: 844)
            vc.redrawTable()
            for stack in allStacks(vc) {
                XCTAssertGreaterThanOrEqual(stack!.view.frame.minX, 0)
                // Leave a visible margin so the rightmost column's border isn't cut off by the screen edge
                XCTAssertLessThanOrEqual(stack!.view.frame.maxX, CGFloat(width) - 5, "\(stack!.stackType) runs off a \(width)pt screen")
            }
        }
    }

    func testOnlyTopCardOfBlindAndDealShowsItsFace() {
        for _ in 0..<3 {
            vc.deal!.addCard(toadd: vc.deck!.getTopCard()!)
        }
        for stack in [vc.fub!, vc.deal!] {
            XCTAssertTrue(stack.cards.last!.view.image === stack.cards.last!.faceImage)
            XCTAssertTrue(stack.cards.dropLast().allSatisfy { $0.view.image === Card.blankFaceImage }, "\(stack.stackType)")

            // Taking the top card reveals the one underneath
            let top = stack.getTopCard()!
            XCTAssertTrue(stack.cards.last!.view.image === stack.cards.last!.faceImage)
            XCTAssertTrue(top.view.image === top.faceImage)
        }
    }

    func testEmptyStacksKeepCardSizedOutlines() {
        // Empty a lower stack and the deal, then lay out the table as happens after every move
        let stack = vc.cardStacks[0]!
        vc.fub!.addCard(toadd: stack.getTopCard()!)
        XCTAssertTrue(stack.cards.isEmpty)
        XCTAssertTrue(vc.deal!.cards.isEmpty)
        vc.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        vc.redrawTable()

        let cardSize = vc.cardStacks[1]!.cards[0].view.frame.size
        XCTAssertEqual(stack.view.frame.size, cardSize)
        XCTAssertEqual(vc.deal!.view.frame.size, cardSize)
    }

    // iPad Split View, Slide Over and Stage Manager windows can be any size; small ones get the iPhone layout
    func testWindowSizeChoosesLayout() {
        for (width, height) in [(320.0, 900.0), (375.0, 1000.0), (507.0, 800.0)] {
            vc.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
            vc.redrawTable()
            XCTAssertEqual(vc.cardStacks[0]!.cards[0].view.frame.width, CGFloat(Int(width / 7.4)), "\(width)x\(height)")
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            vc.view.frame = CGRect(x: 0, y: 0, width: 820, height: 1180)
            vc.redrawTable()
            XCTAssertEqual(vc.cardStacks[0]!.cards[0].view.frame.width, 82)
        }
    }

    func testLandscapeTableFitsOnScreen() {
        for (width, height) in [(844.0, 390.0), (932.0, 430.0), (667.0, 375.0)] {
            vc.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
            vc.redrawTable()
            for stack in allStacks(vc) {
                XCTAssertGreaterThanOrEqual(stack!.view.frame.minX, 0)
                XCTAssertLessThanOrEqual(stack!.view.frame.maxX, CGFloat(width), "\(stack!.stackType) runs off a \(width)pt screen")
                XCTAssertLessThanOrEqual(stack!.view.frame.maxY, vc.toolbar.frame.minY, "\(stack!.stackType) runs under the toolbar at \(width)x\(height)")
            }
        }
    }

    func testUpperStacksClearLowerStacks() {
        // An upper stack with two or more cards shows the one under its top card peeking out below it
        for stack in vc.suitStacks {
            stack!.addCard(toadd: vc.deck!.getTopCard()!)
            stack!.addCard(toadd: vc.deck!.getTopCard()!)
        }
        for (width, height) in [(390.0, 844.0), (844.0, 390.0), (932.0, 430.0), (874.0, 402.0), (667.0, 375.0)] {
            vc.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
            vc.redrawTable()
            for i in 0..<4 {
                XCTAssertLessThanOrEqual(vc.suitStacks[i]!.view.frame.maxY, vc.cardStacks[i]!.view.frame.minY,
                                         "upper stack \(i + 1) overlaps the lower one at \(width)x\(height)")
            }
        }
    }

    func testLongStacksSqueezeAboveToolbar() {
        // Pile most of the deck onto one lower stack
        let stack = vc.cardStacks[0]!
        for _ in 0..<20 {
            stack.addCard(toadd: vc.deck!.getTopCard()!)
        }
        for (width, height) in [(390.0, 844.0), (844.0, 390.0)] {
            vc.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
            vc.redrawTable()
            XCTAssertLessThanOrEqual(stack.view.frame.maxY, vc.toolbar.frame.minY, "\(width)x\(height)")
            XCTAssertLessThan(stack.cardSliceHeight, stack.baseSliceHeight)
            // Every card should still show a sliver
            XCTAssertGreaterThanOrEqual(stack.cardSliceHeight, 2)
        }
    }

    func testSaveAndRestoreRoundTrip() throws {
        vc.score  = 120
        vc.wins   = 3
        vc.losses = 2
        vc.autoMoves = true
        // Deal three cards so every stack type has something in it
        for _ in 0..<3 {
            vc.deal!.addCard(toadd: vc.deck!.getTopCard()!)
        }
        let expected = allStacks(vc).map(tags)

        vc.saveGame()
        let saved = try XCTUnwrap(vc.loadSavedGame())
        XCTAssertEqual(saved.score, 120)
        XCTAssertEqual(saved.wins, 3)
        XCTAssertEqual(saved.losses, 2)
        XCTAssertTrue(saved.autocomplete)

        let restored = try self.makeViewController()
        XCTAssertTrue(restored.restoreBoard(try XCTUnwrap(saved.board), suitStackStarter: saved.suitStackStarter))
        XCTAssertEqual(allStacks(restored).map(tags), expected)
        XCTAssertEqual(restored.suitStackStarter, vc.suitStackStarter)

        for stack in allStacks(restored) {
            for (i, card) in stack!.cards.enumerated() {
                XCTAssertTrue(restored.viewTagToStack[card.view.tag]! === stack)
                XCTAssertTrue(card.view.superview === stack!.view)
                // Cards in the deck are unlinked; elsewhere each card's parent is the one on top of it
                if stack!.stackType == .deck || i == stack!.cards.count - 1 {
                    XCTAssertNil(card.cardParent)
                }
                else {
                    XCTAssertTrue(card.cardParent === stack!.cards[i + 1])
                }
            }
        }
    }

    func testWonGameSavesStatsButNotBoard() throws {
        vc.wins    = 5
        vc.justWon = true
        vc.saveGame()
        let saved = try XCTUnwrap(vc.loadSavedGame())
        XCTAssertEqual(saved.wins, 5)
        XCTAssertNil(saved.board)
    }

    func testButtonActionsExist() {
        // A storyboard action whose selector doesn't match an @IBAction crashes when the button is tapped
        let items = (vc.navigationItem.leftBarButtonItems ?? []) + (vc.navigationItem.rightBarButtonItems ?? []) + (vc.toolbar.items ?? [])
        for item in items {
            guard let action = item.action else { continue }
            let target = (item.target as? NSObject) ?? vc!
            XCTAssertTrue(target.responds(to: action), "\(item.title ?? "untitled") button sends \(action), which \(type(of: target)) doesn't implement")
        }
    }

    func testMenuShowsAutoMovesState() throws {
        func autoState() throws -> UIMenuElement.State {
            let menu = try XCTUnwrap(vc.menuBarButtonItem?.menu)
            return try XCTUnwrap(menu.children.compactMap { $0 as? UIAction }.first { $0.title == "Auto Moves" }).state
        }
        XCTAssertEqual(try autoState(), .off)
        vc.autoMoves = true
        XCTAssertEqual(try autoState(), .on)
    }

    func testDraggingFromTheBlindShowsTheCardUnderneath() throws {
        let fub   = try XCTUnwrap(vc.fub)
        let top   = try XCTUnwrap(fub.cards.last)
        let under = fub.cards[fub.cards.count - 2]
        XCTAssertTrue(under.view.image === Card.blankFaceImage)
        fub.updateFaces(lifting: top)
        XCTAssertTrue(under.view.image === under.faceImage)
        XCTAssertTrue(top.view.image === top.faceImage)
        XCTAssertTrue(fub.cards[0].view.image === Card.blankFaceImage)
        // Dropped back where it was
        fub.updateFaces()
        XCTAssertTrue(under.view.image === Card.blankFaceImage)
        // Dragging a card that isn't on top reveals nothing
        fub.updateFaces(lifting: under)
        XCTAssertTrue(under.view.image === Card.blankFaceImage)
    }

    func testInterruptedDragPutsCardsBack() throws {
        vc.redrawTable()
        let fub   = try XCTUnwrap(vc.fub)
        let top   = try XCTUnwrap(fub.cards.last)
        let under = fub.cards[fub.cards.count - 2]
        let start = top.view.frame.origin
        // Mid-drag, as touchesBegan and touchesMoved leave it
        let touch = UITouch()
        vc.activeTouch           = touch
        vc.activeCard            = top
        vc.activeCardSourceStack = fub
        top.savePos()
        top.setPos(point: CGPoint(x: start.x + 120, y: start.y + 200))
        fub.updateFaces(lifting: top)

        vc.touchesCancelled([touch], with: nil)
        XCTAssertEqual(top.view.frame.origin, start)
        XCTAssertTrue(under.view.image === Card.blankFaceImage)
        XCTAssertNil(vc.activeCard)
        XCTAssertNil(vc.activeTouch)
        XCTAssertEqual(fub.cards.last, top)
    }

    func testCloselyStackedCardsDontPileUpShadows() throws {
        vc.redrawTable()
        func shadowed(_ stack: CardStack?) -> [Int] {
            return stack!.cards.indices.filter { stack!.cards[$0].view.layer.shadowOpacity > 0 }
        }
        // The blind's 13 cards fan less than a card's height, so its bottom and top cards outline it
        XCTAssertEqual(shadowed(vc.fub), [0, 12])
        XCTAssertEqual(shadowed(vc.deck), [vc.deck!.cards.count - 1])
        // Lower stacks fan wide enough that every card keeps its shadow
        for stack in vc.cardStacks {
            XCTAssertEqual(shadowed(stack), Array(stack!.cards.indices))
        }
    }

    func testResetStatsClearsWinsAndLosses() throws {
        let menu  = try XCTUnwrap(vc.menuBarButtonItem?.menu)
        let reset = try XCTUnwrap(menu.children.compactMap { $0 as? UIAction }.first { $0.title.hasPrefix("Reset Wins") })
        XCTAssertTrue(reset.attributes.contains(.destructive))

        vc.wins   = 3
        vc.losses = 7
        vc.score  = 120
        vc.startNewGameWithSender(sender: self)
        XCTAssertNotNil(vc.newGameUndoBanner)
        vc.resetStats()
        XCTAssertEqual(vc.wins, 0)
        XCTAssertEqual(vc.losses, 0)
        XCTAssertEqual(vc.score, 75, "money is kept")
        // The New Game undo can't bring the old counts back
        XCTAssertNil(vc.gameBeforeNewGame)
        // and the reset survives a relaunch
        let saved = try XCTUnwrap(vc.loadSavedGame())
        XCTAssertEqual([saved.wins, saved.losses], [0, 0])
    }

    func testBuildDateFromTestFlightBuildNumber() throws {
        let date  = try XCTUnwrap(ViewController.buildDate(buildNumber: "20261019.2212"))
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        XCTAssertEqual([parts.year, parts.month, parts.day, parts.hour, parts.minute], [2026, 10, 19, 22, 12])
        // Builds not numbered by date still get a date
        XCTAssertNotNil(ViewController.buildDate(buildNumber: "1"))
    }

    func testCardBackImageIsCardShaped() throws {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 400)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1000, height: 400))
        }
        let back = Card.cardBackImage(from: photo)
        XCTAssertEqual(back.size.width, 500)
        XCTAssertEqual(back.size.height, (500 * Card.aspectRatio).rounded(), accuracy: 1)
        let pixels = try XCTUnwrap(back.cgImage?.dataProvider?.data as Data?)
        let row    = try XCTUnwrap(back.cgImage?.bytesPerRow)
        func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[y * row + x * 4 + 3] }
        XCTAssertEqual(alpha(0, 0), 0, "corners should be cut off")
        XCTAssertEqual(alpha(250, 360), 255)
    }

    func testCustomCardBackAppliesToDeckAndPersists() {
        let back = Card.cardBackImage(from: UIImage(systemName: "star")!)
        vc.setCardBack(back)
        XCTAssertTrue(vc.deck!.cards.allSatisfy { $0.view.image === back })
        XCTAssertTrue(FileManager.default.fileExists(atPath: Card.customBackImageURL.path))
        // Face-up cards keep their faces
        XCTAssertFalse(vc.fub!.cards.contains { $0.view.image === back })

        vc.setCardBack(nil)
        XCTAssertFalse(vc.deck!.cards.contains { $0.view.image === back })
        XCTAssertFalse(FileManager.default.fileExists(atPath: Card.customBackImageURL.path))
    }

    // MARK: Undoing New Game

    func testNewGameCanBeUndone() {
        vc.score  = 100
        vc.losses = 2
        vc.autoMoves = true
        for _ in 0..<3 {
            vc.deal!.addCard(toadd: vc.deck!.getTopCard()!)
        }
        let board = allStacks(vc).map(tags)

        vc.startNewGameWithSender(sender: vc)
        XCTAssertNotNil(vc.newGameUndoBanner)
        XCTAssertEqual(vc.score, 55)
        XCTAssertEqual(vc.losses, 3)
        XCTAssertTrue(vc.deal!.cards.isEmpty)

        vc.undoNewGame()
        XCTAssertNil(vc.newGameUndoBanner)
        XCTAssertEqual(allStacks(vc).map(tags), board)
        XCTAssertEqual(vc.score, 100)
        XCTAssertEqual(vc.losses, 2)
        XCTAssertTrue(vc.autoMoves)
        // The restored table is fully wired up for play
        XCTAssertTrue(allStacks(vc).allSatisfy { stack in stack!.cards.allSatisfy { vc.viewTagToStack[$0.view.tag]! === stack } })
        XCTAssertTrue(allStacks(vc).allSatisfy { $0!.view.superview === vc.view })
    }

    func testNoUndoAfterAWin() {
        vc.justWon = true
        vc.startNewGameWithSender(sender: vc)
        XCTAssertNil(vc.newGameUndoBanner)
        XCTAssertNil(vc.gameBeforeNewGame)
    }

    func testUndoGoesBackOnlyOneNewGame() {
        let losses = vc.losses
        vc.startNewGameWithSender(sender: vc)
        let secondBoard = allStacks(vc).map(tags)
        vc.startNewGameWithSender(sender: vc)
        vc.undoNewGame()
        XCTAssertEqual(allStacks(vc).map(tags), secondBoard)
        XCTAssertEqual(vc.losses, losses + 1)
    }

    func testNewGameUndoBannerGoesAway() {
        ViewController.newGameUndoDuration = 0.1
        defer { ViewController.newGameUndoDuration = 5 }
        vc.startNewGameWithSender(sender: vc)
        let banner = vc.newGameUndoBanner
        XCTAssertNotNil(banner)
        let gone = expectation(description: "banner removed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertNil(self.vc.newGameUndoBanner)
            XCTAssertNil(self.vc.gameBeforeNewGame)
            XCTAssertNil(banner?.superview)
            gone.fulfill()
        }
        wait(for: [gone], timeout: 2)
    }

    // MARK: VoiceOver

    func activate(_ stack: CardStack) {
        // What VoiceOver calls on a double-tap
        XCTAssertTrue(stack.view.accessibilityActivate())
    }

    func testCardAccessibilityNames() {
        let names = Set(allStacks(vc).flatMap { $0!.cards.map { $0.accessibilityName } })
        XCTAssertEqual(names.count, 52)
        XCTAssertTrue(names.contains("Ace of Spades"))
        XCTAssertTrue(names.contains("10 of Hearts"))
        XCTAssertTrue(names.contains("Queen of Diamonds"))
    }

    func testStacksDescribeThemselves() {
        vc.redrawTable()
        XCTAssertEqual(vc.deck!.view.accessibilityLabel, "Deck")
        XCTAssertEqual(vc.deck!.view.accessibilityValue, "34 cards")
        XCTAssertEqual(vc.deal!.view.accessibilityValue, "Empty")
        XCTAssertEqual(vc.fub!.view.accessibilityValue, "\(vc.fub!.cards.last!.accessibilityName) on top, 13 cards")
        XCTAssertEqual(vc.cardStacks[2]!.view.accessibilityLabel, "Lower stack 3")
        XCTAssertEqual(vc.cardStacks[2]!.view.accessibilityValue, vc.cardStacks[2]!.cards[0].accessibilityName)
        XCTAssertEqual(vc.suitStacks[0]!.view.accessibilityLabel, "Upper stack 1")
        // Only the stacks and the toolbar are exposed; the individual card images aren't
        XCTAssertEqual(vc.view.accessibilityElements?.count, 12)
    }

    func testActivatingDeckDeals() {
        vc.redrawTable()
        activate(vc.deck!)
        XCTAssertEqual(vc.deal!.cards.count, 3)
        XCTAssertEqual(vc.deck!.cards.count, 31)
    }

    func testSelectThenActivateDestinationMovesCard() {
        // Empty a lower stack; the blind's top card may always fill an empty lower stack
        let target = vc.cardStacks[0]!
        vc.deck!.addCard(toadd: target.getTopCard()!)
        vc.redrawTable()
        let card = vc.fub!.cards.last!

        activate(vc.fub!)
        XCTAssertTrue(vc.accessibilitySelection?.card === card)
        XCTAssertTrue(vc.fub!.view.accessibilityTraits.contains(.selected))
        XCTAssertEqual(target.view.accessibilityHint, "Double-tap to move \(card.accessibilityName) here")

        activate(target)
        XCTAssertTrue(target.cards.last === card)
        XCTAssertNil(vc.accessibilitySelection)
        XCTAssertTrue(vc.undoBarButtonItem.isEnabled)
    }

    // Takes a particular card off the table, to build stacks for a test
    func take(_ rank: Int, _ suit: cardSuit) -> Card {
        let card = vc.viewTagToCard.values.compactMap { $0 }.first { $0.rank == rank && $0.suit == suit }!
        if let stack = vc.viewTagToStack[card.view.tag] ?? nil, stack.cards.contains(card) {
            stack.removeCard(toRemove: card)
            stack.cards.last?.cardParent = nil
        }
        // Unlink it from the card that was on top of it, so moving it later doesn't carry that card along
        card.cardParent = nil
        return card
    }

    func stack(_ type: cardStackType, _ cards: [Card]) -> CardStack {
        let stack = CardStack(type: type)
        cards.forEach { stack.addCard(toadd: $0) }
        return stack
    }

    func accepts(_ card: Card, from source: CardStack, to destination: CardStack) -> Bool {
        vc.activeCard = card
        return vc.acceptCardMove(sourceStack: source, destinationStack: destination, onTopOfCard: destination.cards.last)
    }

    // Clears the table and sets up just the given cards, with Aces starting the upper stacks
    func setUpBoard(lower: [[Card]], deck: [Card] = [], deal: [Card] = [], fub: [Card] = []) {
        for stack in allStacks(vc) {
            for card in stack!.cards {
                stack!.removeCard(toRemove: card)
            }
        }
        vc.suitStackStarter = 1
        func put(_ cards: [Card], on stack: CardStack?) {
            for card in cards {
                stack!.addCard(toadd: card)
                vc.viewTagToStack[card.view.tag] = stack
            }
        }
        for (i, stack) in lower.enumerated() {
            put(stack, on: vc.cardStacks[i])
        }
        put(deck, on: vc.deck)
        put(deal, on: vc.deal)
        put(fub, on: vc.fub)
        vc.redrawTable()
    }

    // Lower stacks with nothing to play among them
    func deadLowerStacks() -> [[Card]] {
        return [[take(5, .Spades)], [take(5, .Hearts)], [take(9, .Clubs)], [take(9, .Diamonds)]]
    }

    func testStuckWhenNothingCanMove() {
        setUpBoard(lower: deadLowerStacks())
        XCTAssertEqual(vc.playState(), .stuck)
    }

    func testPlayableCardOnTheTable() {
        setUpBoard(lower: deadLowerStacks(), deal: [take(4, .Hearts)])
        XCTAssertEqual(vc.playState(), .canPlay, "the 4 of Hearts goes on the 5 of Spades")
        setUpBoard(lower: deadLowerStacks(), fub: [take(1, .Clubs)])
        XCTAssertEqual(vc.playState(), .canPlay, "the Ace goes up")
    }

    func testNeedsDealWhenTheDeckHasAPlayableCard() {
        // Dealing turns up the last card of the three, the 4 of Hearts
        setUpBoard(lower: deadLowerStacks(), deck: [take(4, .Hearts), take(2, .Clubs), take(3, .Clubs)])
        XCTAssertEqual(vc.playState(), .needsDeal)
    }

    func testStuckWhenTheDeckNeverTurnsUpThePlayableCard() {
        // Dealt three at a time, the 4 of Hearts is always under the 2 of Clubs
        setUpBoard(lower: deadLowerStacks(), deck: [take(2, .Clubs), take(3, .Clubs), take(4, .Hearts)])
        XCTAssertEqual(vc.playState(), .stuck)
    }

    func testSwappingARunBetweenMatchingCardsIsntAMove() {
        // The 5 of Spades could go from the 6 of Diamonds to the 6 of Hearts, but that only swaps the red sixes
        setUpBoard(lower: [[take(6, .Diamonds), take(5, .Spades)], [take(6, .Hearts)], [take(9, .Clubs)], [take(9, .Diamonds)]])
        XCTAssertEqual(vc.playState(), .stuck)
        // Off the Jack, it uncovers a new card
        setUpBoard(lower: [[take(11, .Clubs), take(5, .Spades)], [take(6, .Hearts)], [take(9, .Clubs)], [take(9, .Diamonds)]])
        XCTAssertEqual(vc.playState(), .canPlay)
    }

    func testNoMovesBannerFollowsTheGameAndTheMenu() throws {
        setUpBoard(lower: deadLowerStacks(), deck: [take(4, .Hearts)])
        vc.updateNoMovesBanner()
        XCTAssertEqual(vc.noMovesBanner?.accessibilityIdentifier, "Nothing to play")

        // Dealing the 4 of Hearts gives something to play
        vc.tapDeck()
        vc.finishTurn()
        XCTAssertNil(vc.noMovesBanner)

        // Playing it leaves nothing
        let four = vc.deal!.cards.last!
        vc.performMove(card: four, from: vc.deal!, to: vc.cardStacks[0]!)
        vc.finishTurn()
        XCTAssertEqual(vc.noMovesBanner?.accessibilityIdentifier, "No moves left")

        let menu   = try XCTUnwrap(vc.menuBarButtonItem?.menu)
        let toggle = try XCTUnwrap(menu.children.compactMap { $0 as? UIAction }.first { $0.title == "Show When Stuck" })
        XCTAssertEqual(toggle.state, .on)
        vc.showsNoMoves = false
        XCTAssertNil(vc.noMovesBanner)
        XCTAssertEqual(try XCTUnwrap(vc.menuBarButtonItem?.menu?.children.compactMap { $0 as? UIAction }.first { $0.title == "Show When Stuck" }).state, .off)
    }

    func testNoMovesLeftWaitsAfterTheDeal() {
        setUpBoard(lower: deadLowerStacks())
        vc.gameDealtDate = Date()
        vc.updateNoMovesBanner()
        XCTAssertNil(vc.noMovesBanner, "a game that was just dealt gets a few seconds before it's called")
        XCTAssertNotNil(vc.stuckBannerTimer)
        vc.gameDealtDate = Date(timeIntervalSinceNow: -ViewController.stuckBannerDelay)
        vc.updateNoMovesBanner()
        XCTAssertEqual(vc.noMovesBanner?.accessibilityIdentifier, "No moves left")
        XCTAssertNil(vc.stuckBannerTimer)

        // "Nothing to play" doesn't wait: it offers the deal
        setUpBoard(lower: deadLowerStacks(), deck: [take(4, .Hearts)])
        vc.gameDealtDate = Date()
        vc.updateNoMovesBanner()
        XCTAssertEqual(vc.noMovesBanner?.accessibilityIdentifier, "Nothing to play")
    }

    func testHintWigglesTheCardToMove() throws {
        setUpBoard(lower: deadLowerStacks(), deal: [take(4, .Hearts)])
        let move = try XCTUnwrap(vc.findMove())
        XCTAssertEqual(move.card.rank, 4)
        XCTAssertTrue(move.to === vc.cardStacks[0], "the 4 of Hearts goes on the 5 of Spades")
        vc.showHint()
        XCTAssertNotNil(move.card.view.layer.animation(forKey: "hint"))
        XCTAssertNil(vc.cardStacks[0]!.cards.last!.view.layer.animation(forKey: "hint"))
    }

    func testHintPointsAtTheDeckOrSaysThereAreNoMoves() throws {
        setUpBoard(lower: deadLowerStacks(), deck: [take(4, .Hearts), take(2, .Clubs), take(3, .Clubs)])
        vc.showHint()
        XCTAssertNotNil(vc.deck!.cards.last!.view.layer.animation(forKey: "hint"))

        // Asking for a hint shows "No moves left" even with the banner turned off and the game just dealt
        vc.showsNoMoves = false
        setUpBoard(lower: deadLowerStacks())
        vc.gameDealtDate = Date()
        vc.showHint()
        XCTAssertEqual(vc.noMovesBanner?.accessibilityIdentifier, "No moves left")
    }

    func testDropHighlightIsOffByDefaultAndOnlyMarksValidSpots() throws {
        setUpBoard(lower: deadLowerStacks(), deal: [take(4, .Hearts)])
        let four = try XCTUnwrap(vc.deal!.cards.last)
        vc.activeCard            = four
        vc.activeCardSourceStack = vc.deal
        func hover(over stack: CardStack) {
            four.view.frame = four.view.superview!.convert(stack.view.frame, from: vc.view)
            vc.updateDropHighlight()
        }
        hover(over: vc.cardStacks[0]!)
        XCTAssertNil(vc.dropHighlight, "off unless turned on in the menu")

        let toggle = try XCTUnwrap(vc.menuBarButtonItem?.menu?.children.compactMap { $0 as? UIAction }.first { $0.title == "Highlight Drop Spot" })
        XCTAssertEqual(toggle.state, .off)
        vc.highlightsDrops = true
        hover(over: vc.cardStacks[0]!)
        let highlight = try XCTUnwrap(vc.dropHighlight, "the 4 of Hearts can go on the 5 of Spades")
        XCTAssertNotNil(highlight.superview)
        hover(over: vc.cardStacks[1]!)
        XCTAssertNil(vc.dropHighlight, "but not on the 5 of Hearts")
        XCTAssertNil(highlight.superview)

        hover(over: vc.cardStacks[0]!)
        vc.endTouch(at: four.view.center)
        XCTAssertNil(vc.dropHighlight, "dropping the card clears it")
    }

    func testCoveredBlindCardCantBePickedUp() {
        let fub = vc.fub!
        vc.beginTouch(at: .zero, on: fub.cards[5].view)
        XCTAssertNil(vc.activeCard)
        XCTAssertNil(vc.tableTapStart, "a touch on the blind isn't a tap on the table")
        vc.beginTouch(at: .zero, on: fub.cards.last!.view)
        XCTAssertTrue(vc.activeCard === fub.cards.last)
    }

    func testTappingTheTableDeals() {
        vc.redrawTable()
        let deckCount = vc.deck!.cards.count
        let spot = CGPoint(x: 5, y: vc.toolbar.frame.minY - 20)
        vc.beginTouch(at: spot, on: vc.view)
        vc.endTouch(at: CGPoint(x: spot.x + 3, y: spot.y + 2))
        XCTAssertEqual(vc.deck!.cards.count, deckCount - 3)
        XCTAssertEqual(vc.deal!.cards.count, 3)

        // A drag across the table isn't a tap
        vc.beginTouch(at: spot, on: vc.view)
        vc.endTouch(at: CGPoint(x: spot.x + 100, y: spot.y))
        XCTAssertEqual(vc.deck!.cards.count, deckCount - 3)

        // Nor is a tap on a banner
        let banner = vc.addBanner(message: "Test", buttonTitle: "OK", symbol: "checkmark", hint: "") {}
        vc.beginTouch(at: spot, on: banner)
        XCTAssertNil(vc.tableTapStart)
    }

    func testOnlyTheBlindsTopCardCanMove() {
        let fub   = vc.fub!
        let empty = stack(.cardstack, [])
        XCTAssertFalse(accepts(fub.cards[5], from: fub, to: empty), "a card under the top one would bring the rest of the blind")
        XCTAssertTrue(accepts(fub.cards.last!, from: fub, to: empty))
    }

    func testOnlyTheDealsTopCardCanMove() {
        let deal  = stack(.deal, [take(9, .Hearts), take(5, .Clubs)])
        let lower = stack(.cardstack, [take(10, .Spades)])
        XCTAssertFalse(accepts(deal.cards[0], from: deal, to: lower))
    }

    func testRunsCantGoToUpperStacks() {
        let upper = stack(.suitstack, [take(4, .Hearts)])
        let lower = stack(.cardstack, [take(5, .Hearts), take(4, .Clubs)])
        XCTAssertFalse(accepts(lower.cards[0], from: lower, to: upper), "the 4 of Clubs would land on the Hearts")
        lower.removeCard(toRemove: lower.cards[1])
        XCTAssertTrue(accepts(lower.cards[0], from: lower, to: upper))
    }

    func testOnlyRealRunsMoveBetweenLowerStacks() {
        let target = stack(.cardstack, [take(10, .Hearts)])
        let run    = stack(.cardstack, [take(9, .Spades), take(8, .Diamonds), take(7, .Clubs)])
        XCTAssertTrue(accepts(run.cards[0], from: run, to: target))
        let notRun = stack(.cardstack, [take(9, .Clubs), take(3, .Diamonds)])
        XCTAssertFalse(accepts(notRun.cards[0], from: notRun, to: target))
        let sameColor = stack(.cardstack, [take(9, .Diamonds), take(8, .Hearts)])
        XCTAssertFalse(accepts(sameColor.cards[0], from: sameColor, to: stack(.cardstack, [take(10, .Clubs)])))
    }

    func testSecondFingerIsIgnoredWhileDragging() {
        let first = UITouch(), second = UITouch()
        vc.activeTouch = first
        let card = vc.fub!.cards.last!
        vc.activeCard = card
        vc.touchesBegan([second], with: nil)
        XCTAssertTrue(vc.activeTouch === first)
        XCTAssertTrue(vc.activeCard === card)
        vc.touchesEnded([second], with: nil)
        XCTAssertTrue(vc.activeTouch === first, "lifting the other finger doesn't end the drag")
    }

    func testIllegalMoveLeavesBoardAlone() {
        vc.redrawTable()
        // An upper stack only takes the starting rank or the next card of its suit; a lower stack's single card that
        // isn't one of those can't go onto the empty second upper stack
        guard let source = vc.cardStacks.first(where: { $0!.cards.last!.rank != vc.suitStackStarter })! else { return }
        let card = source.cards.last!
        activate(source)
        activate(vc.suitStacks[1]!)
        XCTAssertTrue(source.cards.last === card)
        XCTAssertTrue(vc.suitStacks[1]!.cards.isEmpty)
        XCTAssertNil(vc.accessibilitySelection)
    }

    func testLowerStacksOfferSelectActionForEveryCard() {
        let stack = vc.cardStacks[0]!
        stack.addCard(toadd: vc.deck!.getTopCard()!)
        vc.redrawTable()
        let names = stack.view.accessibilityCustomActions?.map { $0.name } ?? []
        for card in stack.cards {
            XCTAssertTrue(names.contains("Select \(card.accessibilityName)"), "\(names)")
        }
        XCTAssertTrue(names.contains("Move \(stack.cards.last!.accessibilityName) to an upper stack"))
    }

    // MARK: Kevin's open to-dos

    // Each card in a fanned stack is linked to the card on top of it; the top card and every deck card are unlinked
    func assertLinksConsistent(_ file: StaticString = #filePath, line: UInt = #line) {
        for stack in [vc.fub!, vc.deal!] + vc.cardStacks.map({ $0! }) {
            for (i, card) in stack.cards.enumerated() {
                let expected = i + 1 < stack.cards.count ? stack.cards[i + 1] : nil
                XCTAssertTrue(card.cardParent === expected, "\(vc.accessibilityName(of: stack)) card \(i)", file: file, line: line)
            }
        }
        XCTAssertTrue(vc.deck!.cards.allSatisfy { $0.cardParent == nil }, "deck", file: file, line: line)
    }

    // "Fix dragging stack of cards makes top card dissappear": picking up a run has to lift the whole run in order
    func testPickingUpARunKeepsItsCardsInOrder() {
        let first = vc.cardStacks[0]!, second = vc.cardStacks[1]!
        for _ in 0..<2 {
            first.addCard(toadd: vc.deck!.getTopCard()!)
        }
        let run = first.cards
        vc.performMove(card: run[0], from: first, to: second)

        vc.liftRun(startingAt: run[0])
        XCTAssertEqual(second.view.subviews.suffix(3), run.map { $0.view }, "the touched card mustn't cover the cards on it")
        XCTAssertTrue(vc.view.subviews.last === second.view)
    }

    // "Fix card parents not being cleaned properly after auto move"
    func testCardLinksStayConsistentThroughPlay() {
        assertLinksConsistent()

        // Deal, then put a card that can go up on top of a lower stack and let auto moves take it
        vc.tapDeck()
        vc.finishTurn()
        assertLinksConsistent()
        // Another card of the starting rank is somewhere outside the upper stacks; lift it out, keeping its old stack's
        // links intact, and put it on a lower stack
        let starter = ([vc.fub!, vc.deck!, vc.deal!] + vc.cardStacks.map { $0! }).flatMap { $0.cards }.first { $0.rank == vc.suitStackStarter }!
        let from  = vc.viewTagToStack[starter.view.tag]!!
        let index = from.cards.firstIndex(of: starter)!
        from.removeCard(toRemove: starter)
        if index > 0 && from.stackType != .deck {
            from.cards[index - 1].cardParent = index < from.cards.count ? from.cards[index] : nil
        }
        starter.cardParent = nil
        vc.cardStacks[1]!.addCard(toadd: starter)
        vc.viewTagToStack[starter.view.tag] = vc.cardStacks[1]
        vc.autoMoves = true
        vc.finishTurn()
        XCTAssertTrue(vc.suitStacks.contains { $0!.cards.contains { $0 === starter } }, "auto moves should have put the card up")
        assertLinksConsistent()

        // Move a run, undo it, and recycle the deck
        let first = vc.cardStacks[0]!
        first.addCard(toadd: vc.deck!.getTopCard()!)
        vc.performMove(card: first.cards[0], from: first, to: vc.cardStacks[2]!)
        assertLinksConsistent()
        vc.undoMove(vc.undoBarButtonItem)
        assertLinksConsistent()
        while !vc.deck!.cards.isEmpty {
            vc.tapDeck()
        }
        vc.tapDeck()
        assertLinksConsistent()
    }

    // "Fix cards on suitstacks after rotating device"
    func testSuitStackCardsAfterRotating() {
        let suit = vc.suitStacks[0]!
        for _ in 0..<3 {
            suit.addCard(toadd: vc.deck!.getTopCard()!)
        }
        for (width, height) in [(390.0, 844.0), (844.0, 390.0), (390.0, 844.0)] {
            vc.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
            vc.redrawTable()
            let cardSize = vc.cardStacks[0]!.cards[0].view.frame.size
            for (i, card) in suit.cards.enumerated() {
                XCTAssertEqual(card.view.frame.size, cardSize, "\(width)x\(height)")
                XCTAssertEqual(card.view.frame.minY, i == 0 ? 0 : CGFloat(suit.cardSliceHeight), "\(width)x\(height)")
            }
            XCTAssertTrue(suit.view.subviews.last === suit.cards.last!.view, "the top card should be drawn on top")
            XCTAssertEqual(suit.view.frame.height, cardSize.height + CGFloat(suit.cardSliceHeight), accuracy: 1)
        }
    }

    func testMovedRunStaysTogether() {
        // Build a three-card run on a lower stack, move it, then move it again by its bottom card
        let first = vc.cardStacks[0]!, second = vc.cardStacks[1]!, third = vc.cardStacks[2]!
        for _ in 0..<2 {
            first.addCard(toadd: vc.deck!.getTopCard()!)
        }
        let run = first.cards
        vc.performMove(card: run[0], from: first, to: second)
        XCTAssertTrue(run[0].cardParent === run[1])
        XCTAssertTrue(run[1].cardParent === run[2])
        XCTAssertNil(run[2].cardParent)

        let beforeThird = third.cards
        vc.performMove(card: run[0], from: second, to: third)
        XCTAssertEqual(third.cards, beforeThird + run)
        XCTAssertEqual(second.cards.count, 1, "only the stack's original card should be left behind")
    }

    func testUndoAfterTouchingAnotherCard() {
        // Move the top blind card onto a lower stack (skipping the rules check; only undo is under test)
        let fubCard = vc.fub!.cards.last!
        let target  = vc.cardStacks[0]!
        vc.performMove(card: fubCard, from: vc.fub!, to: target)
        XCTAssertTrue(target.cards.last === fubCard)

        // Touching a different card used to make undo act on that card instead, which crashed
        vc.activeCard            = vc.cardStacks[1]!.cards.last
        vc.activeCardSourceStack = vc.cardStacks[1]
        vc.undoMove(vc.undoBarButtonItem)

        XCTAssertTrue(vc.fub!.cards.last === fubCard)
        XCTAssertEqual(target.cards.count, 1)
        XCTAssertTrue(vc.viewTagToStack[fubCard.view.tag]! === vc.fub)
        XCTAssertFalse(vc.undoBarButtonItem.isEnabled)
    }

    func testUndoMovesWholeStackBack() {
        let from = vc.cardStacks[0]!
        let to   = vc.cardStacks[1]!
        from.addCard(toadd: vc.fub!.getTopCard()!)
        let moved  = from.cards
        let before = to.cards

        vc.performMove(card: moved[0], from: from, to: to)
        XCTAssertEqual(to.cards, before + moved)
        XCTAssertTrue(from.cards.isEmpty)

        vc.undoMove(vc.undoBarButtonItem)
        XCTAssertEqual(from.cards, moved)
        XCTAssertEqual(to.cards, before)
        XCTAssertTrue(moved[0].cardParent === moved[1])
        XCTAssertNil(moved[1].cardParent)
        XCTAssertNil(before.last!.cardParent)
    }

    func testRulesTextIsNumberedWithoutAsterisks() {
        let text = HowToPlayViewController.rulesText().string
        XCTAssertFalse(text.contains("*"))
        XCTAssertEqual(text.components(separatedBy: "\n").count, HowToPlayViewController.rules.count)
        XCTAssertTrue(text.hasPrefix("1.\t"))
    }

    func testRestoreRejectsInvalidBoard() throws {
        var board = ViewController.SavedGame.Board(fub: tags(vc.fub), deck: tags(vc.deck), deal: tags(vc.deal),
                                                   suitStacks: vc.suitStacks.map(tags), cardStacks: vc.cardStacks.map(tags))
        board.deck[0] = board.deck[1]  // duplicate card

        let restored = try self.makeViewController()
        XCTAssertFalse(restored.restoreBoard(board, suitStackStarter: 1))
        XCTAssertNil(restored.fub)
        XCTAssertTrue(restored.suitStacks.isEmpty)
    }
}
