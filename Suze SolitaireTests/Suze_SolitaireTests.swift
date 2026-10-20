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
        vc = try self.makeViewController()
        vc.score  = -45
        vc.wins   = 0
        vc.losses = 0
        vc.initTable()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: ViewController.savedGameURL)
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
        vc.autoSwitch.setOn(true, animated: false)
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
