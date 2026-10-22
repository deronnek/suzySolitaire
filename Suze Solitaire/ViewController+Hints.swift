//
//  ViewController+Hints.swift
//  Suze Solitaire
//

import UIKit

// Help seeing moves: Hint in the "..." menu wiggles a card that can be played (or the deck, when only dealing helps),
// and, if turned on in the menu, an outline shows where the card being dragged would land.
extension ViewController {

    static let highlightsDropsKey = "HighlightsDrops"

    var highlightsDrops: Bool {
        get {
            UserDefaults.standard.bool(forKey: ViewController.highlightsDropsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ViewController.highlightsDropsKey)
            self.updateMenu()
        }
    }

    // MARK: Hint

    func showHint() {
        if let move = self.findMove() {
            let index = move.from.cards.firstIndex { $0 === move.card } ?? move.from.cards.count - 1
            self.wiggle(Array(move.from.cards[index...]).map { $0.view })
            self.announce("Move the \(move.card.accessibilityName) to \(self.accessibilityName(of: move.to).lowercased())")
            return
        }
        switch self.playState() {
            case .needsDeal:
                // The deck's top card, or its outline when it's empty and needs turning over
                self.wiggle([self.deck?.cards.last?.view ?? self.deck?.view].compactMap { $0 })
                self.announce(self.deck?.cards.isEmpty ?? true ? "Turn the deck over" : "Deal more cards")
            default:
                self.updateNoMovesBanner(forHint: true)
        }
    }

    // Rocks views side to side a few times
    func wiggle(_ views: [UIView]) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard !UIAccessibility.isReduceMotionEnabled else {
            // A pulse instead of motion
            for view in views {
                let pulse = CABasicAnimation(keyPath: "opacity")
                pulse.fromValue    = 1
                pulse.toValue      = 0.4
                pulse.duration     = 0.25
                pulse.autoreverses = true
                pulse.repeatCount  = 2
                view.layer.add(pulse, forKey: "hint")
            }
            return
        }
        for view in views {
            let wiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            wiggle.values         = [0, -0.07, 0.07, -0.07, 0.07, -0.035, 0]
            wiggle.duration       = 0.6
            wiggle.isAdditive     = true
            wiggle.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            view.layer.add(wiggle, forKey: "hint")
        }
    }

    // MARK: Drop highlight

    // The stack the card being dragged would go to if dropped now, if it would be accepted there
    func dropTarget() -> CardStack? {
        guard let card = self.activeCard, let source = self.activeCardSourceStack, source.stackType != .deck,
              let target = self.findStackUnderHover(hover: card.view),
              target.stackType == .cardstack || target.stackType == .suitstack,
              self.canMove(card, from: source, to: target, onTopOfCard: target.cards.last) else {
            return nil
        }
        return target
    }

    // Outlines the card the dragged card would land on (or the empty stack), just under the dragged cards
    func updateDropHighlight() {
        guard self.highlightsDrops, let target = self.dropTarget(), let source = self.activeCardSourceStack else {
            self.removeDropHighlight()
            return
        }
        let frame = target.cards.last.map { self.view.convert($0.view.frame, from: $0.view.superview) } ?? target.view.frame
        let highlight = self.dropHighlight ?? {
            let view = UIView()
            view.isUserInteractionEnabled = false
            view.layer.borderWidth   = 2.5
            view.layer.borderColor   = UIColor.systemYellow.withAlphaComponent(0.85).cgColor
            view.layer.shadowColor   = UIColor.systemYellow.cgColor
            view.layer.shadowOpacity = 0.6
            view.layer.shadowRadius  = 4
            view.layer.shadowOffset  = .zero
            self.dropHighlight = view
            return view
        }()
        highlight.frame = frame.insetBy(dx: -2, dy: -2)
        highlight.layer.cornerRadius = frame.width * Card.cornerRadiusFraction + 2
        // The dragged cards' stack view was brought to the front, so this sits above every other card
        self.view.insertSubview(highlight, belowSubview: source.view)
    }

    func removeDropHighlight() {
        self.dropHighlight?.removeFromSuperview()
        self.dropHighlight = nil
    }
}
