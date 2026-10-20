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

class CardStack: NSObject, NSCoding {
    func encode(with coder: NSCoder) {
        
    }
    
    var cards = [Card]()
    var stackType = cardStackType.cardstack
    var cardSliceHeight = 30
    var stackZ = Int()
    var view   = UIView()
    let keysForEncoding = ["cards", "cardSliceHeight", "stackZ"]
    
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
                self.cardSliceHeight = 2
            case .deck, .cardstack, .suitstack:
                break // default value is fine for these
        }
        self.stackType = type
        // Assume we have no cards and need a border
        self.view.layer.borderWidth = 1
        self.view.layer.borderColor = UIColor.white.cgColor
    }
    
    // MARK: State restoration
    func encodeWithCoder(aCoder: NSCoder) {
        for key in self.keysForEncoding {
            aCoder.encode(self.value(forKey: key), forKey: key)
        }
        aCoder.encode(self.stackType.simpleDescription(), forKey:"stackType")
    }
    
//    required convenience init?(coder aDecoder: NSCoder) {
//        let stackType = aDecoder.decodeObjectForKey("stackType") as! cardStackType
//        self.init(type: stackType)
//    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init()
        
        self.view = UIView()
        self.view.decodeRestorableState(with: aDecoder)
        
        for key in self.keysForEncoding {
            self.setValue(aDecoder.decodeObject(forKey: key), forKey: key)
        }
        
        self.stackType = self.descriptionToEnum(description: aDecoder.decodeObject(forKey: "stackType") as! String)

        
        for i in 0..<self.cards.count {
            self.view.addSubview(self.cards[i].view)
            if self.stackType == .deck {
                self.cards[i].view.image = UIImage(imageLiteralResourceName: self.cards[i].backImageFilename)
            }
        }
        
        if self.cards.count == 0 {
            self.view.layer.borderWidth = 1
            self.view.layer.borderColor = UIColor.white.cgColor
        }
    }
    
    func descriptionToEnum(description: String) -> cardStackType {
        switch description {
            case "fub":
                return .fub
            case "suitstack":
                return .suitstack
            case "cardstack":
                return .cardstack
            case "deck":
                return .deck
            case "deal":
                return .deal
            default:
                exit(1)
        }
    }
    
    func resize(point: CGPoint, width: Int, cardHeight: Int) {
        var rect = CGRect(origin: point, size: CGSize(width: width, height: cardHeight))
        // Make stacking tighter if we're not on an ipad
        if UIDevice.current.userInterfaceIdiom != UIUserInterfaceIdiom.pad {
            if self.stackType == .suitstack || self.stackType == .cardstack {
                self.cardSliceHeight = Int(Double(cardHeight)/2.5)
            }
        }
        switch self.stackType {
            case .deck:
                rect.size.height = CGFloat(cardHeight)
            case .deal, .fub, .cardstack:
                rect.size.height = CGFloat(cardHeight + (self.cards.count-1)*self.cardSliceHeight)
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
        
        // If we're adding a card, we have at least one and don't want the border
        self.view.layer.borderWidth = 0;
        
        // MARK: Debug: turn on borders
        //self.view.layer.borderWidth = 2;
        
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
        print(self.cards[0], toRemove)
        let index = self.cards.firstIndex(of:toRemove)
        self.cards.remove(at:index!)
        
        if self.cards.isEmpty {
            self.view.layer.borderWidth = 1;
            self.view.layer.borderColor = UIColor.white.cgColor
        }
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
