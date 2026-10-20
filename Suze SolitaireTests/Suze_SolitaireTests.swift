//
//  Suze_SolitaireTests.swift
//  Suze SolitaireTests
//

import XCTest
@testable import Suze_Solitaire

final class Suze_SolitaireTests: XCTestCase {

    var vc: ViewController!

    override func setUpWithError() throws {
        // Keep tests away from the real saved game
        ViewController.savedGameURL = FileManager.default.temporaryDirectory.appendingPathComponent("SavedGame-\(UUID().uuidString).json")
        Card.customBackImageURL     = FileManager.default.temporaryDirectory.appendingPathComponent("CardBack-\(UUID().uuidString).png")
        Card.customBackImage        = nil
        vc = try self.makeViewController()
        vc.score  = -45
        vc.wins   = 0
        vc.losses = 0
        vc.initTable()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: ViewController.savedGameURL)
        try? FileManager.default.removeItem(at: Card.customBackImageURL)
        Card.customBackImage = nil
        vc = nil
    }

    func makeViewController() throws -> ViewController {
        let storyboard = UIStoryboard(name: "MainStoryboard", bundle: Bundle(for: ViewController.self))
        let nav = try XCTUnwrap(storyboard.instantiateInitialViewController() as? UINavigationController)
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
            return try XCTUnwrap(menu.children.first as? UIAction).state
        }
        XCTAssertEqual(try autoState(), .off)
        vc.autoMoves = true
        XCTAssertEqual(try autoState(), .on)
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
