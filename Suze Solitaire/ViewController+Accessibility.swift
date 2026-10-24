//
//  ViewController+Accessibility.swift
//  Suze Solitaire
//

import UIKit

extension Card {
    // e.g. "Queen of Hearts"
    var accessibilityName: String {
        let rank: String
        switch self.rank {
            case 1:  rank = "Ace"
            case 11: rank = "Jack"
            case 12: rank = "Queen"
            case 13: rank = "King"
            default: rank = String(self.rank)
        }
        let suit: String
        switch self.suit {
            case .Clubs:    suit = "Clubs"
            case .Diamonds: suit = "Diamonds"
            case .Hearts:   suit = "Hearts"
            case .Spades:   suit = "Spades"
        }
        return "\(rank) of \(suit)"
    }
}

// VoiceOver can't drag cards, so each stack is one element: double-tap a stack to select its top card, then double-tap
// another stack to move it there.  Double-tapping the deck deals.  Lower stacks also offer actions to select any of
// their cards (to move a run), and stacks with a playable top card offer an action to move it to an upper stack.
extension ViewController {

    func accessibilityName(of stack: CardStack) -> String {
        if let i = self.suitStacks.firstIndex(where: { $0 === stack }) {
            return "Upper stack \(i + 1)"
        }
        if let i = self.cardStacks.firstIndex(where: { $0 === stack }) {
            return "Lower stack \(i + 1)"
        }
        switch stack.stackType {
            case .fub:  return "Blind"
            case .deck: return "Deck"
            default:    return "Deal"
        }
    }

    func accessibilityValue(of stack: CardStack) -> String {
        let cards = stack.cards
        guard let top = cards.last else {
            return "Empty"
        }
        let count = cards.count == 1 ? "1 card" : "\(cards.count) cards"
        switch stack.stackType {
            case .deck:
                return count
            case .cardstack:
                // Bottom to top, so runs can be read off
                return cards.map { $0.accessibilityName }.joined(separator: ", ")
            default:
                return "\(top.accessibilityName) on top, \(count)"
        }
    }

    func updateAccessibility() {
        guard let fub = self.fub, let deck = self.deck, let deal = self.deal else {
            return
        }
        // Drop a selection whose card has since moved
        if let selection = self.accessibilitySelection, !selection.stack.cards.contains(selection.card) {
            self.accessibilitySelection = nil
        }
        let stacks = [fub, deck, deal] + self.suitStacks.map { $0! } + self.cardStacks.map { $0! }
        for stack in stacks {
            let view = stack.view
            let selected = self.accessibilitySelection?.stack === stack
            view.isAccessibilityElement = true
            view.accessibilityLabel     = self.accessibilityName(of: stack)
            view.accessibilityValue     = (selected ? "Selected \(self.accessibilitySelection!.card.accessibilityName). " : "") + self.accessibilityValue(of: stack)
            view.accessibilityTraits    = selected ? [.button, .selected] : .button
            view.accessibilityHint      = self.accessibilityHint(for: stack)
            view.accessibilityActivateBlock = { [unowned self] in
                self.accessibilityActivate(stack)
                return true
            }
            view.accessibilityCustomActions = self.accessibilityActions(for: stack)
        }
        self.view.accessibilityElements = stacks.map { $0.view } + (self.usesSideColumns ? [self.sideColumns?.left, self.sideColumns?.right].compactMap { $0 } : [self.toolbar!]) + [self.noMovesBanner].compactMap { $0 }
    }

    func accessibilityHint(for stack: CardStack) -> String? {
        if stack.stackType == .deck {
            return stack.cards.isEmpty ? "Double-tap to turn the deal over" : "Double-tap to deal three cards"
        }
        if let selection = self.accessibilitySelection {
            return selection.stack === stack ? "Double-tap to deselect" : "Double-tap to move \(selection.card.accessibilityName) here"
        }
        if stack.stackType != .suitstack, let top = stack.cards.last {
            return "Double-tap to select \(top.accessibilityName)"
        }
        return nil
    }

    func accessibilityActions(for stack: CardStack) -> [UIAccessibilityCustomAction] {
        var actions = [UIAccessibilityCustomAction]()
        guard stack.stackType != .deck, stack.stackType != .suitstack, let top = stack.cards.last else {
            return actions
        }
        actions.append(UIAccessibilityCustomAction(name: "Move \(top.accessibilityName) to an upper stack") { [unowned self] _ in
            self.accessibilitySelection = nil
            if self.putUp(card: top, from: stack) {
                self.finishTurn()
                self.announce("Moved \(top.accessibilityName) to an upper stack")
            }
            else {
                self.announce("\(top.accessibilityName) can't go to an upper stack yet")
            }
            self.activeCard = nil
            return true
        })
        if stack.stackType == .cardstack {
            for card in stack.cards.reversed() {
                actions.append(UIAccessibilityCustomAction(name: "Select \(card.accessibilityName)") { [unowned self] _ in
                    self.select(card, in: stack)
                    return true
                })
            }
        }
        return actions
    }

    func accessibilityActivate(_ stack: CardStack) {
        if self.justWon {
            return
        }
        if stack.stackType == .deck {
            self.accessibilitySelection = nil
            let wasEmpty = stack.cards.isEmpty
            self.tapDeck()
            self.finishTurn()
            if wasEmpty {
                self.announce("Turned the deal over")
            }
            else if let top = self.deal?.cards.last {
                self.announce("Dealt. \(top.accessibilityName) on top")
            }
            return
        }

        if let selection = self.accessibilitySelection {
            self.accessibilitySelection = nil
            if selection.stack === stack {
                self.updateAccessibility()
                self.announce("Deselected")
                return
            }
            let name = selection.card.accessibilityName
            self.activeCard = selection.card
            if self.acceptCardMove(sourceStack: selection.stack, destinationStack: stack, onTopOfCard: stack.cards.last) {
                self.performMove(card: selection.card, from: selection.stack, to: stack)
                self.finishTurn()
                self.announce("Moved \(name) to \(self.accessibilityName(of: stack))" + (self.justWon ? ". You won!" : ""))
            }
            else {
                self.updateAccessibility()
                self.announce("Can't move \(name) there")
            }
            self.activeCard = nil
            return
        }

        guard stack.stackType != .suitstack, let top = stack.cards.last else {
            self.announce("Nothing to select")
            return
        }
        self.select(top, in: stack)
    }

    func select(_ card: Card, in stack: CardStack) {
        self.accessibilitySelection = (card, stack)
        self.updateAccessibility()
        self.announce("Selected \(card.accessibilityName). Double-tap a stack to move it there.")
    }

    func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
