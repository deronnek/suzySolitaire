//
//  ViewController.swift
//  Suze Solitaire
//
//  Created by Kevin DeRonne on 2/7/16.
//  Copyright © 2016 Kevin DeRonne. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    // MARK: Properties
    
    @IBOutlet weak var topToolBar: UIToolbar!
    @IBOutlet weak var bucksBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var winsBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var lossesBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var undoBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var autoSwitch: UISwitch!
    @IBOutlet weak var helpBarButton: UIBarButtonItem!
    
    // MARK: Computed Properties
    var score: Int {
        get {
            return Int(bucksBarButtonItem.title!)!
        }
        set(newScore) {
            bucksBarButtonItem.title = String(newScore)
        }
    }
    var wins: Int {
        get {
            return Int(winsBarButtonItem.title!)!
        }
        set(newWins) {
            winsBarButtonItem.title = String(newWins)
        }
    }
    var losses: Int {
        get {
            return Int(lossesBarButtonItem.title!)!
        }
        set(newLosses) {
            lossesBarButtonItem.title = String(newLosses)
        }
    }
    
    var doInitTable = true
    var xCap = 0
    var yCap = 0;
    
    var activeCard           = Card()
    var cardSourceStack      = CardStack()
    var cardDestinationStack = CardStack()
    
    var deckTaps   = 0
    var justWon    = false
    // The rank of the first card in the suitStacks
    var suitStackStarter = -1
    
    // Initial deck to pull cards from when setting up a game
    var cards      = []
    // The ordered stacks at the top
    var suitStacks = []
    // The working stacks at the bottom
    var cardStacks = []
    // The "face up blind" stack
    var fub = CardStack()
    // The stack from which cards are drawn
    var deck = CardStack()
    // The stack containing previously drawn cards
    var deal = CardStack()
    
    // Allows us to quickly figure out which card was tapped
    var viewTagToCard  = []
    // Allows us to quickly figure out which stack was tapped
    var viewTagToStack = []
    
    // MARK: Methods
    override func viewDidLoad() {
        restorationIdentifier = "mainViewController"
    }
}
