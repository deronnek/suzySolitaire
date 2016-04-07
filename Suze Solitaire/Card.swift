//
//  Card.swift
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 2/11/16.
//  Copyright © 2016 Kevin DeRonne. All rights reserved.
//

import Foundation
import CoreGraphics // for CGPoint
import UIKit // for UIImageView

enum cardSuit {
    case Clubs
    case Diamonds
    case Hearts
    case Spades
    
    func simpleDescription() -> String {
        switch self {
        case .Spades:
            return "spade"
        case .Hearts:
            return "heart"
        case .Diamonds:
            return "diamond"
        case .Clubs:
            return "club"
        }
    }
    
    func color () -> cardColor {
        switch self {
        case .Spades:
            return .Black
        case .Hearts:
            return .Red
        case .Diamonds:
            return .Red
        case .Clubs:
            return .Black
        }
    }
}

enum cardColor {
    case Red
    case Black
}

class Card: AnyObject {
    // MARK: Properties
    var keysForEncoding = ["color","rank","suit","faceUp", "faceImageFilename","zLocation", "savedPosition", "cardParent"]
    var color  = cardColor.Black
    var rank   = Int()
    var suit   = cardSuit.Clubs
    var faceUp = false
    var faceImageFilename = String()
    var backImageFilename = String()
    var zLocation  = Int()
    var savedPos   = CGPoint()
    var savedCap   = Int()
    var cardParent = Card?()
    var view       = UIImageView()
    var backImage  = UIImage()
    var faceImage  = UIImage()
    //var identifier =
    
    init(suit: cardSuit, rank: Int, faceImageFilename: String, backImageFilename: String, tag: Int) {
        self.suit              = suit
        self.rank              = rank
        self.faceImageFilename = faceImageFilename
        self.backImageFilename = backImageFilename
        //self.zLocation         = zLocation
        
        self.view      = UIImageView(image: UIImage(imageLiteral: faceImageFilename))
        self.view.tag  = tag
        self.faceImage = UIImage(imageLiteral: faceImageFilename)
        self.backImage = UIImage(imageLiteral: backImageFilename)
      
        self.color = suit.color()
//        
//        let point = CGPoint(x: x, y: y)
//        let rect  = CGRect(origin: point, size: CGSize(width:width, height:height))
//        self.view.frame  = rect
//        self.view.center = point
        
        
        self.view.userInteractionEnabled = true
        
        self.cardParent = nil
        // create a unique identifier for this object, used in state restoration
        //self.restorationIdentifier
        
        
    }
    // MARK: Drawing
    func drawSelfAndParent() {
        if self.faceUp {
            self.view.hidden = false;
        }
        self.cardParent?.drawSelfAndParent()
    }
    
    func resize(point: CGPoint, width:Int, height:Int) {
        self.view.frame = CGRect(origin: point, size: CGSize(width: width, height: height))
    }
    
    func cancelMove() {
        self.setPos(self.savedPos)
        self.cardParent?.cancelMove()
    }
    
    func setPos(point: CGPoint) {
        var rect        = self.view.frame
        rect.origin     = point
        self.view.frame = rect
        
        self.cardParent?.setPos(CGPoint(x: point.x, y: point.y+CGFloat(self.savedCap)))
    }
    
    func savePos() {
        self.savedPos = self.view.frame.origin
        self.cardParent?.savePos()
    }
}