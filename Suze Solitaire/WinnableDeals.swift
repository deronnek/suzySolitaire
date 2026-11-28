//
//  WinnableDeals.swift
//  Suze Solitaire
//

import UIKit

// How New Game deals: any shuffle, or one of a list of deals that can be won
enum Dealing: String, CaseIterable {
    case random, theory, cunning

    var title: String {
        switch self {
            case .random:  return "Totally Random"
            case .theory:  return "Winnable in Theory"
            case .cunning: return "Winnable with Cunning"
        }
    }

    var detail: String {
        switch self {
            case .random:  return "Any shuffle of the cards"
            case .theory:  return "Could be won by someone who saw every card"
            case .cunning: return "Won by a player who never peeked"
        }
    }

    var deals: WinnableDeals? {
        switch self {
            case .random:  return nil
            case .theory:  return WinnableDeals.theory
            case .cunning: return WinnableDeals.cunning
        }
    }
}

// Deals that can be won, for Dealing other than random: the ones scripts/winnable-deals.py won, knowing every card for
// theory, or playing as a player could, without peeking at covered cards or taking moves back, for cunning.  One per
// line as 52 letters, each a card's tag (A-Z then a-z) in the order initTable deals them.  Each is dealt with its ranks
// turned round by a random amount and its suits swapped about at random, keeping each card's color matched with the
// others.  Neither changes which moves can be made, as the upper stacks start from whatever rank is dealt and a King
// sits below an Ace, so each line gives 104 different-looking games that can all be won.
struct WinnableDeals {
    static let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    static let theory  = WinnableDeals(asset: "TheoryDeals")
    static let cunning = WinnableDeals(asset: "CunningDeals")

    let lines: [String]

    init(text: String) {
        self.lines = text.split(separator: "\n").map(String.init).filter { $0.count == 52 }
    }

    init(asset: String) {
        self.init(text: NSDataAsset(name: asset).flatMap { String(data: $0.data, encoding: .utf8) } ?? "")
    }

    // The tags of the cards in the order to deal them
    func shuffledTags() -> [Int]? {
        var generator = SystemRandomNumberGenerator()
        return self.shuffledTags(using: &generator)
    }

    func shuffledTags<G: RandomNumberGenerator>(using generator: inout G) -> [Int]? {
        guard let line = self.lines.randomElement(using: &generator) else {
            return nil
        }
        return WinnableDeals.variant(line, shift: Int.random(in: 0..<13, using: &generator), swap: Int.random(in: 0..<8, using: &generator))
    }

    static func decode(_ line: String) -> [Int] {
        line.compactMap { self.letters.firstIndex(of: $0) }
    }

    // The deal on line with every rank shift higher (round from King to Ace) and its suits swapped as swap says: bit 0
    // swaps Clubs and Spades, bit 1 Diamonds and Hearts, and bit 2 the black suits for the red
    static func variant(_ line: String, shift: Int, swap: Int) -> [Int] {
        self.decode(line).map { self.relabel($0, shift: shift, swap: swap) }
    }

    // Tags count Clubs, Diamonds, Hearts, then Spades, Ace to King
    static func relabel(_ tag: Int, shift: Int, swap: Int) -> Int {
        let bySuit = [[0, 3], [1, 2]]
        let suit = tag / 13, rank = tag % 13
        let color = suit == 1 || suit == 2 ? 1 : 0
        let place = bySuit[color].firstIndex(of: suit)! ^ (swap >> color & 1)
        return bySuit[color ^ (swap >> 2 & 1)][place] * 13 + (rank + shift) % 13
    }
}

extension ViewController {
    static let dealingKey = "Dealing"

    // How New Game deals, from the next new game on
    var dealing: Dealing {
        get {
            UserDefaults.standard.string(forKey: ViewController.dealingKey).flatMap(Dealing.init) ?? .random
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: ViewController.dealingKey)
            self.updateMenu()
        }
    }
}
