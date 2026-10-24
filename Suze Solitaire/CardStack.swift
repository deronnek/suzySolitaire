//
//  CardStack.swift
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 2/11/16.
//  Copyright © 2016 Kevin DeRonne. All rights reserved.
//

import Foundation
import UIKit

enum cardStackType {
    case fub
    case suitstack
    case cardstack
    case deck
    case deal
    
    func simpleDescription() -> String {
        switch self {
            case .fub:
                return "fub"
            case .suitstack:
                return "suitstack"
            case .cardstack:
                return "cardstack"
            case .deck:
                return "deck"
            case .deal:
                return "deal"
        }
    }
}

@MainActor
class CardStack: NSObject {
    var cards = [Card]() {
        didSet {
            self.updateShadows()
            self.updateFaces()
        }
    }
    var stackType = cardStackType.cardstack
    var cardSliceHeight = 30
    // The fan spacing when there's room; resize squeezes cardSliceHeight below this so tall stacks still fit
    var baseSliceHeight = 30
    var stackZ = Int()
    var view   = UIView()
    // The card-sized outline of the stack's spot, chalked on the felt like the score: under its cards, so it shows
    // whenever they're moved off it.  It's a chalk texture with gaps worn into it, showing through a straight
    // rounded-rectangle stroke with clumps of chalk along its edges.
    let outline = CALayer()
    let outlineStroke = CAShapeLayer()
    let outlineClumps = [CAShapeLayer(), CAShapeLayer(), CAShapeLayer(), CAShapeLayer()]
    // How far apart cards in the blind (fub) and deal are fanned
    static let fannedSliceHeight = 5
    // Softer on the dimmer dark-mode felt.  ViewController.applyAppearance sets isDark.
    static var isDark = false
    static var outlineColor: CGColor {
        CardStack.isDark ? CardStack.darkChalk : CardStack.lightChalk
    }
    static let lightChalk = CardStack.chalk(alpha: 1).cgColor
    static let darkChalk  = CardStack.chalk(alpha: 0.6).cgColor

    // Chalk: solid white, worn through in small irregular spots, the same every launch
    static func chalk(alpha: CGFloat) -> UIColor {
        var generator = SeededGenerator(seed: 52)
        let format = UIGraphicsImageRendererFormat()
        format.scale  = 2
        format.opaque = false
        let size  = CGFloat(64)
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            UIColor.white.withAlphaComponent(alpha).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            context.cgContext.setBlendMode(.clear)
            for _ in 0..<1800 {
                let x = CGFloat.random(in: 0..<size, using: &generator)
                let y = CGFloat.random(in: 0..<size, using: &generator)
                let w = CGFloat.random(in: 0.3...1.4, using: &generator)
                let h = CGFloat.random(in: 0.3...1.1, using: &generator)
                context.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
            }
        }
        return UIColor(patternImage: image)
    }
    
    init(type: cardStackType) {
//        var point = CGPoint(x: x, y: y)
//        let rect  = CGRect(origin: point, size: CGSize(width: width, height: height))
//        self.view.frame = rect
//        
//        point.x += CGFloat(Float(width)/2.0)
//        point.y += CGFloat(Float(height)/2.0)
//        
//        self.view = UIView(frame: rect)
//        self.view.center = point
        
        
        self.view.isUserInteractionEnabled = true
        
        //self.identifier = NSUUID().UUIDString()
        switch type {
            case .fub, .deal:
                self.cardSliceHeight = CardStack.fannedSliceHeight
                self.baseSliceHeight = CardStack.fannedSliceHeight
            case .deck, .cardstack, .suitstack:
                break // default value is fine for these
        }
        self.stackType = type
        self.outlineStroke.fillColor   = nil
        self.outlineStroke.strokeColor = UIColor.black.cgColor
        self.outlineStroke.lineWidth   = 1
        // Lumps of chalk of different sizes along the line make its edges ragged: a few wide ones far apart, more
        // middling ones, and lots of small ones, at irregular lengths so they don't repeat in a pattern
        var generator = SeededGenerator(seed: 7)
        // The further out from the line, the fainter, so the chalk fades away at its edges
        let clumps: [(width: CGFloat, dash: ClosedRange<CGFloat>, gap: ClosedRange<CGFloat>, cap: CAShapeLayerLineCap, opacity: Float)] = [
            (2.5, 0.4...2.2, 2...7, .round, 0.6),
            (2, 0.6...3.5, 0.8...3, .round, 0.8),
            (1.7, 0.2...1, 0.2...1.2, .butt, 0.9),
            // Stray flecks just off the line
            (3.4, 0.2...0.6, 0.6...3, .butt, 0.35),
        ]
        let mask = CALayer()
        mask.addSublayer(self.outlineStroke)
        for (layer, clump) in zip(self.outlineClumps, clumps) {
            layer.fillColor   = nil
            layer.strokeColor = UIColor.black.cgColor
            layer.lineWidth   = clump.width
            layer.lineCap     = clump.cap
            layer.opacity     = clump.opacity
            layer.lineDashPattern = (0..<40).map { i in
                NSNumber(value: Double(CGFloat.random(in: i % 2 == 0 ? clump.dash : clump.gap, using: &generator)))
            }
            mask.addSublayer(layer)
        }
        self.outline.mask = mask
        self.outline.backgroundColor = CardStack.outlineColor
        self.view.layer.insertSublayer(self.outline, at: 0)
    }
    
    // ViewController.applyAppearance calls this when dark mode changes
    func updateOutlineColor() {
        self.outline.backgroundColor = CardStack.outlineColor
    }
    
    // maxHeight, if given, is how tall the stack may get; fanned stacks overlap more tightly to stay within it.  compact
    // is true for the iPhone-style layout, which also fans lower stacks more tightly.
    func resize(point: CGPoint, width: Int, cardHeight: Int, maxHeight: Int? = nil, compact: Bool = true) {
        var rect = CGRect(origin: point, size: CGSize(width: width, height: cardHeight))
        // Size the outline to a card and round it to match, without the implicit animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let bounds = CGRect(x: 0, y: 0, width: width, height: cardHeight)
        let radius = CGFloat(width) * Card.cornerRadiusFraction
        let path = UIBezierPath(roundedRect: bounds.insetBy(dx: 1.8, dy: 1.8), cornerRadius: radius).cgPath
        self.outline.frame = bounds
        self.outline.mask?.frame = bounds
        for layer in [self.outlineStroke] + self.outlineClumps {
            layer.frame = bounds
            layer.path  = path
        }
        CATransaction.commit()
        // Make stacking tighter in the iPhone-style layout
        if self.stackType == .suitstack || self.stackType == .cardstack {
            self.baseSliceHeight = compact ? Int(Double(cardHeight)/2.5) : 30
        }
        self.cardSliceHeight = self.baseSliceHeight
        if let maxHeight = maxHeight, self.cards.count > 1, self.stackType == .cardstack || self.stackType == .fub || self.stackType == .deal {
            self.cardSliceHeight = max(2, min(self.baseSliceHeight, (maxHeight - cardHeight) / (self.cards.count - 1)))
        }
        switch self.stackType {
            case .deck:
                rect.size.height = CGFloat(cardHeight)
            case .deal, .fub, .cardstack:
                // An empty stack still gets a full card-sized outline
                rect.size.height = CGFloat(cardHeight + max(self.cards.count-1, 0)*self.cardSliceHeight)
            case .suitstack:
                if self.cards.count > 1 {
                    rect.size.height = CGFloat(cardHeight + self.cardSliceHeight)
                }
                else {
                    rect.size.height = CGFloat(cardHeight)
                }
        }
        
        self.view.frame = rect
        
        var y = 0
        for i in 0..<self.cards.count {
            y = 0
            switch self.stackType {
                case .cardstack, .fub, .deal:
                    y = i*self.cardSliceHeight
                case .suitstack:
                    if i > 0 {
                        y = self.cardSliceHeight
                    }
                case .deck:
                    y = 0
                
            }
            self.cards[i].resize(point: CGPoint(x: 0, y: y), width: width, height: cardHeight)
            self.cards[i].savedCap = self.cardSliceHeight
        }
        self.updateShadows()
    }

    // Only the top card of the blind and deal can be played, so the ones under it show blank faces.  While the top
    // card is being dragged away, the card it uncovers shows its face, as it will once the move is made.
    func updateFaces(lifting lifted: Card? = nil) {
        guard self.stackType == .fub || self.stackType == .deal, let top = self.cards.last else {
            return
        }
        let uncovered = lifted === top && self.cards.count > 1 ? self.cards[self.cards.count - 2] : nil
        for card in self.cards {
            // Called on every move of a drag, so leave images that are already right alone
            let image = card === top || card === uncovered ? card.faceImage : Card.blankFaceImage
            if card.view.image !== image {
                card.view.image = image
            }
        }
        if let uncovered = uncovered {
            uncovered.view.layer.shadowOpacity = Card.shadowOpacity
            uncovered.setShadowPath(trimmingTop: 0)
        }
        else {
            self.updateShadows()
        }
    }

    // Overlapping shadows add up, so stacks whose cards sit close together only give shadows to the cards needed to
    // outline the whole stack
    func updateShadows() {
        let shadowed: (Int) -> Bool
        switch self.stackType {
            case .deck:
                // The cards sit exactly on top of each other
                shadowed = { $0 == self.cards.count - 1 }
            case .fub, .deal:
                // A card's shadow reaches down a card's height, so every few cards are enough to cover the edges
                let cardHeight = self.cards.first.map { Int($0.view.bounds.height) } ?? 0
                let step = max(1, cardHeight / max(1, self.cardSliceHeight))
                shadowed = { $0 % step == 0 || $0 == self.cards.count - 1 }
            case .cardstack, .suitstack:
                shadowed = { _ in true }
        }
        // The shadow along the top of a card in the middle of the fan would fall on the card above it as a dark line, so
        // those cards only shadow their sides; the cards above them already cover the top of the sides
        let middleTrim = self.stackType == .fub || self.stackType == .deal ? CGFloat(self.cardSliceHeight) + 4 : 0
        for (i, card) in self.cards.enumerated() {
            card.view.layer.shadowOpacity = shadowed(i) ? Card.shadowOpacity : 0
            card.setShadowPath(trimmingTop: i == 0 || i == self.cards.count - 1 ? 0 : middleTrim)
        }
    }
    
    func setPos(point: CGPoint) {
        self.view.frame.origin = point
    }
    
    func addCard(toadd: Card) {
        // Set card new position.  Remember: the position of a subview is relative to its super view
        var pos = CGPoint()
        pos.x   = 0
        
        if self.stackType == .deck {
            toadd.view.image = toadd.backImage
        }
        else {
            toadd.view.image = toadd.faceImage
        }
        
        // Handle visual stacking here by adjusting y value
        if (self.stackType == .cardstack || self.stackType == .fub || self.stackType == .deal) && self.cards.count > 0 {
            pos.y = CGFloat(self.cardSliceHeight*self.cards.count-1)
        }
        else {
            pos.y = 0
        }
        
        if self.stackType == .suitstack && self.cards.count > 0 {
            pos.y = pos.y + CGFloat(self.cardSliceHeight)
        }
        
        toadd.savedCap = self.cardSliceHeight
        toadd.setPos(point: pos)
        
        // If the stack is to be shown, make rect larger
        if ((self.stackType == .cardstack || self.stackType == .fub || self.stackType == .deal) && self.cards.count > 0) || (self.stackType == .suitstack && self.cards.count == 1) {
            var rec = self.view.frame
            rec.size = CGSizeMake(rec.size.width, rec.size.height + CGFloat(self.cardSliceHeight))
            self.view.frame = rec
        }
        
        // Keep track of internal z order so we know how high the card should be
        self.stackZ = self.stackZ+1
        toadd.zLocation = self.stackZ

        // Parent card
        // We actually need to set parents for deal and fub so you can't grab cards willy-nilly.  l
        // deck cards are perfectly aligned so there's no risk for that stack.
        if self.stackType == .deck {
            toadd.cardParent = nil
        }
        else {
            let childCard = self.cards.last
            childCard?.cardParent = toadd
        }
        
        // Card ownership is transfered to array
        self.cards.append(toadd)
        
        
        // We always add a card at the end of the array.  Parent will be set properly above if more cards get added.
        //toadd.cardParent = nil
        // Doing this causes some very strange bugs--cards get stacked with incorrect slice heights
        
        toadd.view.isExclusiveTouch = true
        self.view.addSubview(toadd.view)
    }
    
    func removeCard(toRemove: Card) {
        // make rect smaller (the rectangles get long and ugly otherwise)
        if (self.stackType == .cardstack) && self.cards.count > 1 {
            var rec = self.view.frame
            rec.size = CGSizeMake(rec.size.width, rec.size.height - CGFloat(self.cardSliceHeight))
            self.view.frame = rec
        }
        let index = self.cards.firstIndex(of:toRemove)
        self.cards.remove(at:index!)
        // KDR a little awkward that I send a message to the card to remove itself from us, effectively
        toRemove.view.removeFromSuperview();

    }
    
//    func makeSubViewsOfCards() {
//        var failNow = Card?()
//        failNow = nil
//        let _ = failNow!
//    }
    
    func getCardAtPosition(point: CGPoint) -> Card? {
        var activeCard: Card? = nil
        if self.stackType == .deck || self.stackType == .deal || self.stackType == .fub {
            let card = self.cards.last
            if CGRectContainsPoint(card!.view.frame, point) {
                activeCard = card
            }
        }
        else {
            for card in self.cards {
                if CGRectContainsPoint(card.view.frame, point) {
                    if activeCard == nil {
                        activeCard = card
                    }
                    else {
                        if card.zLocation > activeCard?.zLocation ?? 0 {
                            activeCard = card
                        }
                    }
                }
            }
        }
        return activeCard
    }
    
    func getTopCard() -> Card? {
        if let top = self.cards.last {
            self.cards.removeLast()
            return top
        }
        return nil
    }
    
}
