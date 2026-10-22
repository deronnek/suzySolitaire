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

//enum cardSuitError: ErrorType {
//    case InvalidSuitDescription
//}

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

@MainActor
class Card: NSObject {
    // Height / width of the card images
    static let aspectRatio: CGFloat = 726.0 / 500.0
    // Corner radius as a fraction of card width; matches the corners cut into the card images
    static let cornerRadiusFraction: CGFloat = 0.06
    static let shadowOpacity: Float = 0.35
    
    // A plain white face, shown on covered cards in the blind and deal so their fanned edges don't give away rank or suit
    static let blankFaceImage: UIImage = {
        let size   = CGSize(width: 500, height: 500 * Card.aspectRatio)
        let format = UIGraphicsImageRendererFormat()
        format.scale  = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.width * Card.cornerRadiusFraction).fill()
        }
    }()
    
    // A card back chosen by the player, or nil for the default
    static var customBackImageURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("CardBack.png")
    static var customBackImage = UIImage(contentsOfFile: Card.customBackImageURL.path)
    
    // Crops a photo to card proportions with the same rounded corners as the card images
    static func cardBackImage(from photo: UIImage) -> UIImage {
        let size   = CGSize(width: 500, height: 500 * Card.aspectRatio)
        let format = UIGraphicsImageRendererFormat()
        format.scale  = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.width * Card.cornerRadiusFraction).addClip()
            let scale = max(size.width / photo.size.width, size.height / photo.size.height)
            let drawn = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
            photo.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2, width: drawn.width, height: drawn.height))
        }
    }
    
    // MARK: Properties
    var color  = cardColor.Black
    var rank   = Int()
    var suit   = cardSuit.Clubs
    var faceUp = false
    var faceImageFilename = String()
    var backImageFilename = String()
    var zLocation  = Int()
    var savedPos   = CGPoint()
    var savedCap   = Int()
    var cardParent: Card? = nil
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
        
        self.view      = UIImageView(image: UIImage(imageLiteralResourceName: faceImageFilename))
        self.view.tag  = tag
        self.faceImage = UIImage(imageLiteralResourceName: faceImageFilename)
        self.backImage = Card.customBackImage ?? UIImage(imageLiteralResourceName: backImageFilename)
      
        self.color = suit.color()
//        
//        let point = CGPoint(x: x, y: y)
//        let rect  = CGRect(origin: point, size: CGSize(width:width, height:height))
//        self.view.frame  = rect
//        self.view.center = point
        
        
        self.view.isUserInteractionEnabled = true
        
        // The outline and shadow are drawn here rather than in the images so they stay crisp at any card size
        self.view.layer.borderWidth   = 0.5
        self.view.layer.borderColor   = UIColor.black.withAlphaComponent(0.8).cgColor
        self.view.layer.shadowColor   = UIColor.black.cgColor
        self.view.layer.shadowOpacity = Card.shadowOpacity
        self.view.layer.shadowRadius  = 1.5
        self.view.layer.shadowOffset  = .zero
        
        self.cardParent = nil
        // create a unique identifier for this object, used in state restoration
        //self.restorationIdentifier
        
        
    }
    // MARK: Drawing
    func drawSelfAndParent() {
        if self.faceUp {
            self.view.isHidden = false;
        }
        self.cardParent?.drawSelfAndParent()
    }
    
    func resize(point: CGPoint, width:Int, height:Int) {
        self.view.frame = CGRect(origin: point, size: CGSize(width: width, height: height))
        self.view.layer.cornerRadius = CGFloat(width) * Card.cornerRadiusFraction
        self.setShadowPath(trimmingTop: 0)
    }

    // Casts the shadow from the card's outline, less `trim` points off the top
    func setShadowPath(trimmingTop trim: CGFloat) {
        var rect = self.view.bounds
        rect.origin.y    += trim
        rect.size.height -= trim
        self.view.layer.shadowPath = UIBezierPath(roundedRect: rect, cornerRadius: self.view.layer.cornerRadius).cgPath
    }
    
    func cancelMove() {
        self.setPos(point: self.savedPos)
        self.cardParent?.cancelMove()
    }
    
    func setPos(point: CGPoint) {
        var rect        = self.view.frame
        rect.origin     = point
        self.view.frame = rect
        
        self.cardParent?.setPos(point: CGPoint(x: point.x, y: point.y+CGFloat(self.savedCap)))
    }
    
    func savePos() {
        self.savedPos = self.view.frame.origin
        self.cardParent?.savePos()
    }
}
