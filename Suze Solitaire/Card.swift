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
}

enum cardColor {
    case Red
    case Black
}

class Card: NSObject {
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
    
    init(suit: cardSuit, rank: Int, faceImageFilename: String, backImageFilename: String, x: Int, y: Int, zLocation: Int, width: Int, height: Int, tag: Int) {
        self.suit              = suit
        self.rank              = rank
        self.faceImageFilename = faceImageFilename
        self.backImageFilename = backImageFilename
        self.zLocation         = zLocation
        
        self.view      = UIImageView(image: UIImage(imageLiteral: faceImageFilename))
        self.view.tag  = tag
        self.faceImage = UIImage(imageLiteral: faceImageFilename)
        self.backImage = UIImage(imageLiteral: backImageFilename)
        
        switch suit {
            case .Spades, .Clubs:
                self.color = .Black
            case .Diamonds, .Hearts:
                self.color = .Red
        }
        
        let point = CGPoint(x: x, y: y)
        let rect  = CGRect(origin: point, size: CGSize(width:width, height:height))
        self.view.frame  = rect
        self.view.center = point
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
        let rect  = CGRect(origin: point, size: CGSize(width: width, height: height))
        self.view.frame = rect
    }
    
    func cancelMove() {
        self.setPos(self.savedPos)
        self.cardParent?.cancelMove()
    }
    
    func setPos(point: CGPoint) {
        var rect = self.view.frame
        rect.origin = point
        self.view.frame = rect
    }
    
    func savePos() {
        self.savedPos = self.view.frame.origin
        self.cardParent?.savePos()
    }
}