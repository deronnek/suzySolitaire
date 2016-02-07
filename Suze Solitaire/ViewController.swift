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
    
    var doInitTable = true
    var restorationIdentifier = "mainViewController"
    var xCap = 0
}
