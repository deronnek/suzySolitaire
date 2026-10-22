//
//  ViewController+NoMoves.swift
//  Suze Solitaire
//

import UIKit

// After each turn, a banner points out when nothing on the table can be played: it offers to deal when a card the deck
// would turn up can be played, and a new game when going through the whole deck wouldn't help either.  It can be
// turned off in the "..." menu.
extension ViewController {

    enum PlayState: Equatable {
        // A card on the table can be played
        case canPlay
        // Only a card from further into the deck can be played
        case needsDeal
        // Nothing can be played, even going through the whole deck
        case stuck
    }

    static let showsNoMovesKey = "ShowsNoMoves"

    var showsNoMoves: Bool {
        get {
            UserDefaults.standard.object(forKey: ViewController.showsNoMovesKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ViewController.showsNoMovesKey)
            self.updateNoMovesBanner()
            self.updateMenu()
        }
    }

    func playState() -> PlayState {
        if self.tableHasMove() {
            return .canPlay
        }
        let shown = self.deal?.cards.last
        let laterDeals = self.cardsTheDeckWillDeal().filter { $0 !== shown }
        return laterDeals.contains { self.hasDestination($0, from: .deal) } ? .needsDeal : .stuck
    }

    // Whether a visible card can make a move that gets somewhere.  Moving a run off a card it could equally sit on
    // only swaps it between two matching cards, so it doesn't count unless the card under it can then go up.
    func tableHasMove() -> Bool {
        if let top = self.fub?.cards.last, self.hasDestination(top, from: .fub) {
            return true
        }
        if let top = self.deal?.cards.last, self.hasDestination(top, from: .deal) {
            return true
        }
        for case let source? in self.cardStacks {
            for (i, card) in source.cards.enumerated() where self.isRun(from: card, in: source) {
                let below = i > 0 ? source.cards[i - 1] : nil
                let destinations = (i == source.cards.count - 1 ? self.suitStacks : []) + self.cardStacks
                for case let destination? in destinations where destination !== source {
                    guard self.canMove(card, from: source, to: destination, onTopOfCard: destination.cards.last) else {
                        continue
                    }
                    if destination.stackType == .suitstack {
                        return true
                    }
                    if let below = below {
                        // Uncovers a card that isn't part of the run, frees one to go up, or splits the run into an
                        // empty stack, leaving a new card to build on
                        let uncoversNewCard = !self.isRun(from: below, in: source)
                        let belowCanGoUp = self.suitStacks.contains { self.destinationAccepts(below, from: .cardstack, to: $0!, onTopOfCard: $0!.cards.last) }
                        if uncoversNewCard || belowCanGoUp || destination.cards.isEmpty {
                            return true
                        }
                    }
                    else if !destination.cards.isEmpty {
                        // Empties a lower stack
                        return true
                    }
                }
            }
        }
        return false
    }

    // Whether card, at the top of a stack of sourceType, could go to an upper or lower stack
    func hasDestination(_ card: Card, from sourceType: cardStackType) -> Bool {
        return (self.suitStacks + self.cardStacks).contains { destination in
            self.destinationAccepts(card, from: sourceType, to: destination!, onTopOfCard: destination!.cards.last)
        }
    }

    // The cards that will be on top of the deal as the deck is tapped through, turning it over once, without playing any
    // (the same steps as tapDeck)
    func cardsTheDeckWillDeal() -> [Card] {
        var deck = self.deck?.cards ?? []
        var deal = self.deal?.cards ?? []
        var shown = [Card]()
        let start = (deck.map { $0.view.tag }, deal.map { $0.view.tag })
        for _ in 0...(2 * (deck.count + deal.count) + 2) {
            if deck.isEmpty {
                deck = deal.reversed()
                deal = []
            }
            else {
                for _ in 0..<min(3, deck.count) {
                    deal.append(deck.removeLast())
                }
            }
            if let top = deal.last {
                shown.append(top)
            }
            if (deck.map { $0.view.tag }, deal.map { $0.view.tag }) == start {
                break
            }
        }
        return shown
    }

    func updateNoMovesBanner() {
        let state = self.justWon || !self.showsNoMoves ? .canPlay : self.playState()
        let message: String?
        switch state {
            case .canPlay:   message = nil
            case .needsDeal: message = "Nothing to play"
            case .stuck:     message = "No moves left"
        }
        // Leave a banner that already says the same thing alone, so it doesn't flicker as the deck is tapped through
        if let banner = self.noMovesBanner, banner.accessibilityIdentifier == message {
            return
        }
        if let banner = self.noMovesBanner {
            self.removeBanner(banner, animated: true)
            self.noMovesBanner = nil
        }
        // Wait for the New Game undo banner, which sits in the same spot, to go away
        guard let message = message, self.newGameUndoBanner == nil else {
            self.updateAccessibility()
            return
        }

        let banner: UIView
        if state == .needsDeal {
            let turnOver = self.deck?.cards.isEmpty ?? true
            banner = self.addBanner(message: message, buttonTitle: turnOver ? "Turn Over" : "Deal",
                                    symbol: turnOver ? "arrow.2.squarepath" : "rectangle.stack",
                                    hint: turnOver ? "Turns the deal back over" : "Deals three more cards") { [unowned self] in
                self.tapDeck()
                self.finishTurn()
            }
        }
        else {
            banner = self.addBanner(message: message, buttonTitle: "New Game", symbol: "plus.circle",
                                    hint: "Deals a new game") { [unowned self] in
                self.startNewGameWithSender(sender: self)
            }
        }
        banner.accessibilityIdentifier = message
        self.noMovesBanner = banner
        self.updateAccessibility()
        self.announce(message)
    }
}
