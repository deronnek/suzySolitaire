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
    // The card-sized outline of the stack's spot, painted under its cards so it shows whenever they're moved off it
    let outline = CALayer()
    // How far apart cards in the blind (fub) and deal are fanned
    static let fannedSliceHeight = 5
    
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
        self.outline.borderWidth = 1
        self.outline.borderColor = UIColor.white.cgColor
        self.view.layer.insertSublayer(self.outline, at: 0)
    }
    
    // maxHeight, if given, is how tall the stack may get; fanned stacks overlap more tightly to stay within it.  compact
    // is true for the iPhone-style layout, which also fans lower stacks more tightly.
    func resize(point: CGPoint, width: Int, cardHeight: Int, maxHeight: Int? = nil, compact: Bool = true) {
        var rect = CGRect(origin: point, size: CGSize(width: width, height: cardHeight))
        // Size the outline to a card and round it to match, without the implicit animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.outline.frame        = CGRect(x: 0, y: 0, width: width, height: cardHeight)
        self.outline.cornerRadius = CGFloat(width) * Card.cornerRadiusFraction
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
