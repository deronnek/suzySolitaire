//
//  ViewController+Hints.swift
//  Suze Solitaire
//

import UIKit

// Help seeing moves: Hint in the "..." menu wiggles a card that can be played (or the deck, when only dealing helps),
// and, if turned on in the menu, an outline (and a tick of haptic feedback) shows where the card being dragged would land.
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

    // How far around a stack a dragged card still counts as over it, as a fraction of the card's width
    static let dropReach: CGFloat = 0.25

    // The stack the card being dragged would go to if dropped now: of the stacks that would take it, the one it overlaps
    // most, counting a margin around each stack so near misses still land.  The margin doesn't count when the card is
    // squarely on another stack, so a card dropped on a stack that won't take it doesn't go next door.
    func dropTarget() -> CardStack? {
        guard let card = self.activeCard, let source = self.activeCardSourceStack, source.stackType != .deck,
              let superview = card.view.superview else {
            return nil
        }
        let dragged = self.view.convert(card.view.frame, from: superview)
        let reach   = dragged.width * ViewController.dropReach
        let center  = CGPoint(x: dragged.midX, y: dragged.midY)
        let stacks  = (self.suitStacks + self.cardStacks).compactMap { $0 }
        let squarelyOn = stacks.first { $0 !== source && $0.view.frame.contains(center) }
        var best: (stack: CardStack, overlap: CGFloat)? = nil
        for target in stacks where target !== source {
            let margin  = squarelyOn == nil || squarelyOn === target ? reach : 0
            let overlap = target.view.frame.insetBy(dx: -margin, dy: -margin).intersection(dragged)
            guard !overlap.isNull, !overlap.isEmpty, self.canMove(card, from: source, to: target, onTopOfCard: target.cards.last) else {
                continue
            }
            let area = overlap.width * overlap.height
            if area > (best?.overlap ?? 0) {
                best = (target, area)
            }
        }
        return best?.stack
    }

    // Outlines the card the dragged card would land on (or the empty stack), just under the dragged cards
    func updateDropHighlight() {
        guard self.highlightsDrops, let target = self.dropTarget(), let source = self.activeCardSourceStack else {
            self.removeDropHighlight()
            return
        }
        // Called on every move of a drag, so only redo the highlight when the target changes
        if target === self.dropHighlightTarget, self.dropHighlight?.superview != nil {
            return
        }
        self.dropHighlightTarget = target
        UISelectionFeedbackGenerator().selectionChanged()
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
        self.dropHighlight       = nil
        self.dropHighlightTarget = nil
    }
}
