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

// The four sets of card faces, vector images in Assets.xcassets/Cards (see scripts/import-cards.py): big corner ranks
// for the small cards of a phone-sized table, or the full design for a roomy table's big cards, each with its ranks in
// Arial or Abril Fatface.  The game uses the Arial ones; the Debug menu can show any of them.
enum CardFaces: String, CaseIterable {
    case smallArial = "SmallArial"
    case smallAbril = "SmallAbril"
    case largeArial = "LargeArial"
    case largeAbril = "LargeAbril"

    var title: String {
        switch self {
            case .smallArial: "Small, Arial"
            case .smallAbril: "Small, Abril Fatface"
            case .largeArial: "Large, Arial"
            case .largeAbril: "Large, Abril Fatface"
        }
    }

    // The corner radius of the card shape in the images, as a fraction of their width: the small cards' corners have a
    // radius of 10 of the card's 167 units, and the large ones' 6.86 inside a 0.25 margin, so their curve is centred
    // 7.11 in from each edge
    var cornerRadiusFraction: CGFloat {
        (self == .smallArial || self == .smallAbril ? 10 : 7.11) / 167.0869141
    }

    // The faces the game shows on a table of either size
    static func standard(large: Bool) -> CardFaces {
        large ? .largeArial : .smallArial
    }
}

@MainActor
class Card: NSObject {
    // Height / width of the card images
    static let aspectRatio: CGFloat = 242.6669922 / 167.0869141
    // Corner radius as a fraction of card width; matches the corners of the faces showing, which the card backs, blank
    // faces, outlines and shadows all follow
    static var cornerRadiusFraction: CGFloat {
        Card.faces.cornerRadiusFraction
    }
    static let shadowOpacity: Float = 0.35
    
    static let outlineColor = UIColor.black.withAlphaComponent(0.8)

    // A plain face, shown on covered cards in the blind and deal so their fanned edges don't give away rank or suit, one
    // for each set of faces' corners
    static var blankFaceImage: UIImage {
        if let image = Card.blankFaces[Card.faces] {
            return image
        }
        let image = Card.blankFace(.white)
        Card.blankFaces[Card.faces] = image
        return image
    }
    private static var blankFaces = [CardFaces: UIImage]()

    static func blankFace(_ color: UIColor) -> UIImage {
        let size   = CGSize(width: 500, height: 500 * Card.aspectRatio)
        let format = UIGraphicsImageRendererFormat()
        format.scale  = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.width * Card.cornerRadiusFraction).fill()
        }
    }
    
    // A card back chosen by the player, or nil for the default
    static var customBackImageURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("CardBack.png")
    static var customBackImage = UIImage(contentsOfFile: Card.customBackImageURL.path) {
        didSet {
            Card.backImages = [:]
        }
    }

    // The back every card shows, the player's or the default, with the corners of the faces showing.  Backs may come
    // with corners already cut, at up to the small cards' radius, so the picture is drawn 2% bigger than the card to
    // reach past them into the large cards' tighter corners.
    static var backImage: UIImage {
        if let image = Card.backImages[Card.faces] {
            return image
        }
        let source = Card.customBackImage ?? UIImage(imageLiteralResourceName: "cardback.png")
        let size   = CGSize(width: 500, height: 500 * Card.aspectRatio)
        let format = UIGraphicsImageRendererFormat()
        format.scale  = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.width * Card.cornerRadiusFraction).addClip()
            source.draw(in: CGRect(origin: .zero, size: size).insetBy(dx: -size.width * 0.01, dy: -size.height * 0.01))
        }
        Card.backImages[Card.faces] = image
        return image
    }
    private static var backImages = [CardFaces: UIImage]()

    // Crops a photo to card proportions; the corners are rounded as it's shown (see backImage)
    static func cardBackImage(from photo: UIImage) -> UIImage {
        let size   = CGSize(width: 500, height: 500 * Card.aspectRatio)
        let format = UIGraphicsImageRendererFormat()
        format.scale  = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
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
    var zLocation  = Int()
    var savedPos   = CGPoint()
    var savedCap   = Int()
    var cardParent: Card? = nil
    var view       = UIImageView()
    var backImage: UIImage {
        Card.backImage
    }
    // The faces every card shows, which change with the table's size (see ViewController.updateCardFaces); the table
    // can change size at any time, as when iPhone Duo folds
    static var faces = CardFaces.smallArial
    // Each set's image, loaded when first shown, so a card's face stays the same image while it's showing
    private var faceImages = [CardFaces: UIImage]()
    var faceImage: UIImage {
        if let image = self.faceImages[Card.faces] {
            return image
        }
        let image = UIImage(imageLiteralResourceName: "\(Card.faces.rawValue)/\(self.assetName)")
        self.faceImages[Card.faces] = image
        return image
    }
    // Its name in each set of faces, such as queen_of_hearts
    var assetName: String {
        let ranks = [1: "ace", 11: "jack", 12: "queen", 13: "king"]
        let suits: [cardSuit: String] = [.Clubs: "clubs", .Diamonds: "diamonds", .Hearts: "hearts", .Spades: "spades"]
        return "\(ranks[self.rank] ?? String(self.rank))_of_\(suits[self.suit]!)"
    }
    //var identifier =
    
    init(suit: cardSuit, rank: Int, tag: Int) {
        self.suit              = suit
        self.rank              = rank
        //self.zLocation         = zLocation
        
        self.view      = UIImageView()
        super.init()
        self.view.image = self.faceImage
        self.view.tag  = tag
      
        self.color = suit.color()
//        
//        let point = CGPoint(x: x, y: y)
//        let rect  = CGRect(origin: point, size: CGSize(width:width, height:height))
//        self.view.frame  = rect
//        self.view.center = point
        
        
        self.view.isUserInteractionEnabled = true
        
        // The outline and shadow are drawn here rather than in the images so they stay crisp at any card size
        self.view.layer.borderWidth   = 0.5
        self.view.layer.borderColor   = Card.outlineColor.cgColor
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
