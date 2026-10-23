//
//  ViewController+Appearance.swift
//  Suze Solitaire
//

import UIKit

// Dark mode: a dimmer felt, softer stack outlines, and toolbar and banner text in the label color so it's light on the
// dark glass, like the buttons at the top.  The cards stay the same.
extension ViewController {

    static let feltColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.090, green: 0.220, blue: 0.098, alpha: 1)
            : UIColor(red: 0.179, green: 0.437, blue: 0.192, alpha: 1)
    }

    func setUpAppearance() {
        self.view.backgroundColor = ViewController.feltColor
        for item in [self.winsBarButtonItem, self.lossesBarButtonItem] {
            item?.tintColor = .label
        }
        self.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (vc: ViewController, _: UITraitCollection) in
            vc.applyAppearance()
        }
        self.applyAppearance()
    }

    // Brings the stack outlines, whose layer colors don't adapt on their own, up to date
    func applyAppearance() {
        CardStack.isDark = self.traitCollection.userInterfaceStyle == .dark
        for case let stack? in [self.fub, self.deck, self.deal] + self.suitStacks + self.cardStacks {
            stack.outline.borderColor = CardStack.outlineColor.cgColor
        }
    }
}
