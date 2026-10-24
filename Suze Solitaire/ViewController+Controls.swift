//
//  ViewController+Controls.swift
//  Suze Solitaire
//

import UIKit

// The table's buttons keep to its corners in every layout, all the same size: New Game at the top left, Undo at the top
// right, and the "..." menu at the bottom right, under Undo.  The score, wins and losses are written on the felt along the
// bottom rather than shown as buttons, since they only show the numbers.  iPhone Duo folded is the exception: the system
// puts the navigation bar's New Game and Undo in a strip down the side of the screen, so the "..." button goes at the
// bottom of that strip.  redrawTable keeps the cards clear of all of them.
extension ViewController {

    // The system's buttons in iPhone Duo's strip, which the app can't measure: their size, and how far their centers are
    // from the edge of the table
    static let stripButtonSize: CGFloat  = 48
    static let stripButtonInset: CGFloat = 36

    // Whether there's room for the big-card layout in both directions, on any device (a full iPad, iPhone Duo unfolded)
    var roomyTable: Bool {
        let bounds = self.view.bounds
        return bounds.width >= 600 && bounds.height >= 600
    }

    // Whether the table is wider than it is tall, so its stacks go in two long rows between New Game and Undo
    var isLandscape: Bool {
        self.view.bounds.width > self.view.bounds.height
    }

    // Whether the system shows the navigation buttons in a strip down the side of the screen instead of a bar across the
    // top, as iPhone Duo does
    var barsInStrip: Bool {
        (self.navigationController?.navigationBar.frame.height ?? 44) < 1
    }

    // Switches every card between its small- and large-table art, keeping covered and face-down cards as they are
    func useLargeCardArt(_ large: Bool) {
        guard large != Card.largeArt else {
            return
        }
        let cards = self.viewTagToCard.values.compactMap { $0 }
        let showingFaces = cards.filter { $0.view.image === $0.faceImage }
        Card.largeArt = large
        for card in showingFaces {
            card.view.image = card.faceImage
        }
    }

    // Whether Undo can be used, in the navigation bar and on the table
    var canUndo: Bool {
        get { self.undoBarButtonItem.isEnabled }
        set {
            self.undoBarButtonItem.isEnabled = newValue
            self.undoButton.isEnabled = newValue
        }
    }

    // The size of the corner buttons: the HIG's 44 points on iPhone, and bigger on the bigger table, where 44 looks lost
    var cornerButtonSize: CGFloat {
        self.roomyTable ? 56 : 44
    }

    // Puts New Game, Undo and the "..." button in the table's corners, the score along the bottom beside "...", and the
    // banners just above them, and returns where the buttons are for redrawTable to lay the cards out around.  New Game
    // and Undo are nil in iPhone Duo's strip, which the app can't measure.
    @discardableResult
    func updateControlPlacement() -> (newGame: CGRect?, undo: CGRect?, menu: CGRect) {
        self.toolbar.isHidden = true
        let bounds = self.view.bounds
        let safe   = self.view.safeAreaInsets
        let strip  = self.barsInStrip
        // iPhone Duo's strip shows the navigation bar's buttons; everywhere else the table has its own, so they can all
        // be one size and the cards can sit between them
        self.navigationItem.leftBarButtonItem   = strip ? self.newGameBarButtonItem : nil
        self.navigationItem.rightBarButtonItems = strip ? [self.undoBarButtonItem] : []
        for button in [self.newGameButton, self.undoButton, self.menuButton] where button.superview == nil {
            self.view.addSubview(button)
        }
        self.newGameButton.isHidden = strip
        self.undoButton.isHidden    = strip

        var newGame: CGRect?, undo: CGRect?
        let menu: CGRect
        var chalkLeft: CGFloat, chalkRight: CGFloat
        if strip {
            // At the bottom of the strip, which is on the right in portrait and the left in landscape
            let size = ViewController.stripButtonSize
            let midX = safe.right > safe.left ? bounds.width - safe.right + ViewController.stripButtonInset : safe.left - ViewController.stripButtonInset
            menu = CGRect(x: midX - size / 2, y: bounds.height - safe.bottom - size, width: size, height: size)
            chalkLeft  = safe.left + 16
            chalkRight = bounds.width - safe.right - 16
        }
        else {
            // Where the navigation bar would put its buttons: just under the status bar, or 24 points from the top without
            // one, and 24 points into the margin beside the Dynamic Island or notch.  The bigger table gets more room.
            let size  = self.cornerButtonSize
            let roomy = self.roomyTable
            let statusBar = self.view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
            let top   = max(statusBar, 24) + (roomy ? 12 : 0)
            let margin = roomy ? 24 : 16 as CGFloat
            let left  = max(margin, safe.left - 24)
            let right = bounds.width - max(margin, safe.right - 24)
            // As far from the bottom as the top buttons are from the status bar (or the top), but clear of the home
            // indicator and the screen's rounded corner
            let below = max(safe.bottom, top - statusBar, margin)
            newGame = CGRect(x: left, y: top, width: size, height: size)
            undo    = CGRect(x: right - size, y: top, width: size, height: size)
            menu    = CGRect(x: right - size, y: bounds.height - below - size, width: size, height: size)
            chalkLeft  = left + 8
            chalkRight = menu.minX - 16
        }
        // The symbols grow with the buttons
        let symbol = UIImage.SymbolConfiguration(pointSize: round(self.cornerButtonSize * 0.4), weight: .regular)
        for button in [self.newGameButton, self.undoButton, self.menuButton] {
            button.configuration?.preferredSymbolConfigurationForImage = symbol
        }
        self.newGameButton.frame = newGame ?? .zero
        self.undoButton.frame    = undo ?? .zero
        self.menuButton.frame    = menu
        for constraint in self.view.constraints + self.chalkLine.constraints where constraint.identifier == "chalkPlacement" {
            switch constraint.firstAttribute {
                case .leading:  constraint.constant = chalkLeft
                case .centerY:  constraint.constant = menu.midY
                default:        constraint.constant = max(0, chalkRight - chalkLeft)
            }
        }

        self.updateChalk()
        if let banner = self.noMovesBanner {
            self.placeBanner(banner)
        }
        self.keepControlsInFront()
        return (newGame, undo, menu)
    }

    // A Liquid Glass circle with a symbol, sized by updateControlPlacement
    func cornerButton(symbol: String) -> UIButton {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        }
        else {
            config = .gray()
            config.cornerStyle = .capsule
        }
        config.image = UIImage(systemName: symbol)
        config.contentInsets = .zero
        return UIButton(configuration: config)
    }

    func makeCornerButton(symbol: String, label: String, action: @escaping () -> Void) -> UIButton {
        let button = self.cornerButton(symbol: symbol)
        button.accessibilityLabel = label
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        return button
    }

    func makeMenuButton() -> UIButton {
        let button = self.cornerButton(symbol: "ellipsis")
        button.accessibilityLabel = "More"
        button.showsMenuAsPrimaryAction = true
        button.menu = self.buildMenu()
        return button
    }

    func setUpChalk() {
        let bucks = self.bucksBarButtonItem!, wins = self.winsBarButtonItem!, losses = self.lossesBarButtonItem!
        // The toolbar's number items keep the numbers but aren't shown
        for item in [bucks, wins, losses] {
            item.isHidden = true
        }
        self.toolbar.isHidden = true
        let line = self.chalkLine
        line.adjustsFontSizeToFitWidth = true
        line.minimumScaleFactor = 0.5
        line.translatesAutoresizingMaskIntoConstraints = false
        // Painted on the table, so under the cards
        self.view.insertSubview(line, at: 0)
        // updateControlPlacement moves it beside the "..." button; it shrinks to fit rather than run under it
        let placement = [
            line.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 24),
            line.centerYAnchor.constraint(equalTo: self.view.topAnchor),
            line.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
        ]
        for constraint in placement {
            constraint.identifier = "chalkPlacement"
        }
        NSLayoutConstraint.activate(placement)
        self.updateChalk()
        self.registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (vc: ViewController, _: UITraitCollection) in
            vc.updateChalk()
        }
    }

    // Writes the toolbar's numbers on the felt in Futura: the score in red when it's below zero
    func updateChalk() {
        guard let bucks = self.bucksBarButtonItem, let wins = self.winsBarButtonItem, let losses = self.lossesBarButtonItem else {
            return
        }
        let negative = (bucks.title ?? "").hasPrefix("$-")
        let shadow = NSShadow()
        shadow.shadowColor      = UIColor.white.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 1.5
        func chalk(_ string: String?, red: Bool = false, size: CGFloat) -> NSAttributedString {
            NSAttributedString(string: string ?? "", attributes: [
                .font: UIFont(name: "Futura-Medium", size: size) ?? .systemFont(ofSize: size, weight: .medium),
                .foregroundColor: red ? UIColor(red: 1, green: 0.62, blue: 0.6, alpha: 0.92) : UIColor.white.withAlphaComponent(0.88),
                .shadow: shadow])
        }
        let titles = [bucks.title, wins.title, losses.title]
        // Bigger on the bigger table, and following the text size set in Settings, up to twice as big so it stays on
        // the bottom row
        let base: CGFloat = self.roomyTable ? 24 : 17
        let size = min(UIFontMetrics(forTextStyle: .body).scaledValue(for: base, compatibleWith: self.traitCollection), base * 2)
        let line = NSMutableAttributedString(attributedString: chalk(titles[0], red: negative, size: size))
        for title in titles.dropFirst() {
            line.append(chalk("   " + (title ?? ""), size: size))
        }
        self.chalkLine.attributedText     = line
        self.chalkLine.accessibilityLabel = titles.compactMap { $0 }.joined(separator: ", ")
    }

    // Just above the "..." button and the score in portrait, where redrawTable leaves room for it, or in landscape beside
    // them on the bottom row, which the cards keep clear of
    func placeBanner(_ banner: UIView) {
        let old = self.view.constraints.filter { $0.identifier == "bannerPlacement" && $0.firstItem === banner }
        NSLayoutConstraint.deactivate(old)
        if let content = (banner as? UIVisualEffectView)?.contentView {
            for inset in content.constraints where inset.identifier == "bannerInset" {
                // The button's own padding evens out the right side
                switch inset.firstAttribute {
                    case .leading:  inset.constant = 20
                    case .trailing: inset.constant = -8
                    case .top:      inset.constant = 2
                    default:        inset.constant = -2
                }
            }
        }
        let menu = self.menuButton.frame
        let safe = self.view.safeAreaLayoutGuide
        let constraints: [NSLayoutConstraint]
        if self.isLandscape {
            // Beside the "..." button, or at the right end of the row when it's in iPhone Duo's strip on the left
            let right = self.barsInStrip ? self.view.bounds.width - self.view.safeAreaInsets.right - 16 : menu.minX - ViewController.bannerSpacing
            let clear = banner.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: self.chalkLine.frame.maxX + ViewController.bannerSpacing)
            clear.priority = .defaultHigh
            constraints = [
                banner.trailingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: right),
                banner.centerYAnchor.constraint(equalTo: self.view.topAnchor, constant: menu.midY),
                clear,
            ]
        }
        else {
            constraints = [
                banner.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
                banner.bottomAnchor.constraint(equalTo: self.view.topAnchor, constant: menu.minY - ViewController.bannerSpacing),
            ]
        }
        for constraint in constraints {
            constraint.identifier = "bannerPlacement"
        }
        NSLayoutConstraint.activate(constraints)
    }

    // Banners and the buttons sit above the cards, which get brought to the front as they move
    func keepControlsInFront() {
        let controls: [UIView?] = [self.newGameButton, self.undoButton, self.menuButton, self.noMovesBanner]
        for case let control? in controls where control.superview === self.view {
            self.view.bringSubviewToFront(control)
        }
    }
}

// iOS 26's navigation bar spans the screen and takes every touch in its band, even between its buttons.  This one lets
// those through to the table, whose landscape top row sits between New Game and Undo.
class TableNavigationBar: UINavigationBar {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        // The bar's backgrounds and content view span its width; its buttons and title don't
        if let hit = hit, hit.bounds.width >= self.bounds.width - 1 {
            return nil
        }
        return hit
    }
}
