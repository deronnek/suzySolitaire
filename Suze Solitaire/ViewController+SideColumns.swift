//
//  ViewController+SideColumns.swift
//  Suze Solitaire
//

import UIKit

// The score, wins and losses are chalked on the felt rather than shown as buttons, since they only show the numbers:
// along the bottom next to the "..." button, or in iPhone landscape, which is too short for a toolbar under the table,
// in a column under New Game on the left, with the "..." menu and the banners under Undo on the right.  redrawTable
// keeps the cards between the columns.
extension ViewController {

    static let sideColumnWidth: CGFloat = 116
    static let sideColumnSpacing: CGFloat = 8

    // Whether there's room for the big-card layout in both directions, on any device (a full iPad, iPhone Duo unfolded)
    var roomyTable: Bool {
        let bounds = self.view.bounds
        return bounds.width >= 600 && bounds.height >= 600
    }

    // Whether the window is phone-sized and wider than it is tall (narrow iPad windows count too)
    var usesSideColumns: Bool {
        let bounds = self.view.bounds
        return !self.roomyTable && bounds.width > bounds.height
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

    // Shows the toolbar or the side columns to suit the window, and puts the banners next to whichever is showing
    func updateControlPlacement() {
        let side = self.usesSideColumns
        if side && self.sideColumns == nil {
            self.buildSideColumns()
        }
        self.toolbar.isHidden = side
        // The navigation bar's buttons sit 24 points into the safe area's margin beside the Dynamic Island or notch
        let safe  = self.view.safeAreaInsets
        let inset = max(16, max(safe.left, safe.right) - 24)
        for constraint in self.view.constraints where constraint.identifier == "sideColumnInset" {
            constraint.constant = constraint.firstAttribute == .leading ? inset : -inset
        }
        self.sideColumns?.left.isHidden  = !side
        self.sideColumns?.right.isHidden = !side
        if side {
            self.alignMenuWithUndo()
        }
        self.chalkLine.isHidden = side
        self.updateChalk()
        if let banner = self.noMovesBanner {
            self.placeBanner(banner)
        }
        self.keepControlsInFront()
    }

    func buildSideColumns() {
        let chalk = (0..<3).map { _ in
            let label = UILabel()
            // Shrinks rather than cut off a long record
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
            return label
        }
        let left = UIStackView(arrangedSubviews: chalk)
        left.axis    = .vertical
        left.spacing = ViewController.sideColumnSpacing
        left.isLayoutMarginsRelativeArrangement = true
        left.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 0)

        let menu = self.sideButton()
        menu.configuration?.image = UIImage(systemName: "ellipsis")
        menu.accessibilityLabel   = "More"
        menu.showsMenuAsPrimaryAction = true
        menu.menu = self.buildMenu()
        let right = UIStackView(arrangedSubviews: [menu])
        right.axis      = .vertical
        right.alignment = .trailing

        let safe = self.view.safeAreaLayoutGuide
        // updateControlPlacement lines these up with New Game and Undo
        let leading  = left.leadingAnchor.constraint(equalTo: self.view.leadingAnchor)
        let trailing = right.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        leading.identifier  = "sideColumnInset"
        trailing.identifier = "sideColumnInset"
        for column in [left, right] {
            column.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(column)
        }
        NSLayoutConstraint.activate([
            leading,
            left.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            left.widthAnchor.constraint(equalToConstant: ViewController.sideColumnWidth),
            trailing,
            right.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            right.widthAnchor.constraint(equalToConstant: ViewController.sideColumnWidth),
        ] + [menu.widthAnchor, menu.heightAnchor].map { anchor in
            // alignMenuWithUndo matches these to Undo
            let size = anchor.constraint(equalToConstant: 44)
            size.identifier = "menuSize"
            return size
        })
        self.sideColumns = (left, right, chalk, menu)
    }

    func sideButton() -> UIButton {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        }
        else {
            config = .gray()
            config.cornerStyle = .capsule
        }
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .body)
            return attributes
        }
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .body, scale: .medium)
        config.contentInsets = NSDirectionalEdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14)
        return UIButton(configuration: config)
    }

    // Puts the "..." button right under Undo at the same size.  Where the navigation bar puts its buttons beside the
    // Dynamic Island or notch varies by device, so this measures Undo rather than working it out from the safe area.
    func alignMenuWithUndo() {
        guard let columns = self.sideColumns, let bar = self.navigationController?.navigationBar else {
            return
        }
        bar.layoutIfNeeded()
        func find(_ view: UIView) -> UIView? {
            if view.accessibilityIdentifier == "undo" && view.bounds.width > 0 {
                return view
            }
            return view.subviews.lazy.compactMap(find).first
        }
        guard let undo = find(bar) else {
            return
        }
        // Undo's glass circle reaches 4 points past the button itself
        let frame = self.view.convert(undo.bounds, from: undo)
        let size  = max(44, frame.height + 8)
        for constraint in self.view.constraints where constraint.identifier == "sideColumnInset" && constraint.firstItem === columns.right {
            constraint.constant = frame.midX + size / 2 - self.view.bounds.width
        }
        for constraint in columns.menu.constraints where constraint.identifier == "menuSize" {
            constraint.constant = size
        }
    }

    func setUpChalk() {
        let bucks = self.bucksBarButtonItem!, wins = self.winsBarButtonItem!, losses = self.lossesBarButtonItem!
        // The toolbar's number items keep the numbers but aren't shown, leaving the "..." button at the right
        for item in [bucks, wins, losses] {
            item.isHidden = true
        }
        self.toolbar.items = [bucks, wins, losses, .flexibleSpace()] + [self.menuBarButtonItem].compactMap { $0 }
        let line = self.chalkLine
        line.adjustsFontSizeToFitWidth = true
        line.minimumScaleFactor = 0.6
        line.translatesAutoresizingMaskIntoConstraints = false
        // Painted on the table, so under the cards
        self.view.insertSubview(line, at: 0)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            line.trailingAnchor.constraint(lessThanOrEqualTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -88),
            line.centerYAnchor.constraint(equalTo: self.toolbar.centerYAnchor),
        ])
        self.updateChalk()
    }

    // Chalks the toolbar's numbers on the felt: the score in red chalk when it's below zero
    func updateChalk() {
        guard let bucks = self.bucksBarButtonItem, let wins = self.winsBarButtonItem, let losses = self.lossesBarButtonItem else {
            return
        }
        let negative = (bucks.title ?? "").hasPrefix("$-")
        let shadow = NSShadow()
        shadow.shadowColor      = UIColor.white.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 1.5
        func chalk(_ string: String?, red: Bool = false, size: CGFloat) -> NSAttributedString {
            let color = red ? UIColor(red: 1, green: 0.62, blue: 0.6, alpha: 0.92) : UIColor.white.withAlphaComponent(0.88)
            return NSAttributedString(string: string ?? "", attributes: [
                .font: UIFont(name: "Chalkduster", size: size) ?? .systemFont(ofSize: size), .foregroundColor: color, .shadow: shadow])
        }
        let titles = [bucks.title, wins.title, losses.title]
        // Bigger on the wider iPad table
        let size: CGFloat = self.traitCollection.horizontalSizeClass == .regular ? 24 : 17
        let line = NSMutableAttributedString(attributedString: chalk(titles[0], red: negative, size: size))
        for title in titles.dropFirst() {
            line.append(chalk("   " + (title ?? ""), size: size))
        }
        self.chalkLine.attributedText     = line
        self.chalkLine.accessibilityLabel = titles.compactMap { $0 }.joined(separator: ", ")
        for (i, label) in (self.sideColumns?.chalk ?? []).enumerated() {
            label.attributedText = chalk(titles[i], red: i == 0 && negative, size: 18)
        }
    }

    // Under the table's toolbar on one line, or in the right column under the "..." button with the message, symbol and
    // button title stacked to fit
    func placeBanner(_ banner: UIView) {
        // The width constraint lives on the banner, the others on the view
        let old = (self.view.constraints + banner.constraints).filter { $0.identifier == "bannerPlacement" && $0.firstItem === banner }
        NSLayoutConstraint.deactivate(old)
        let stacked = self.usesSideColumns && self.sideColumns != nil
        if let content = (banner as? UIVisualEffectView)?.contentView, let row = content.subviews.first as? UIStackView {
            row.axis    = stacked ? .vertical : .horizontal
            row.spacing = stacked ? 2 : 4
            for inset in content.constraints where inset.identifier == "bannerInset" {
                // Even in the column; on one line the button's own padding evens out the right side
                switch inset.firstAttribute {
                    case .leading:  inset.constant = stacked ? 10 : 20
                    case .trailing: inset.constant = stacked ? -10 : -8
                    case .top:      inset.constant = stacked ? 8 : 2
                    default:        inset.constant = stacked ? -8 : -2
                }
            }
            for case let label as UILabel in row.arrangedSubviews {
                label.numberOfLines = stacked ? 0 : 1
            }
            for case let button as UIButton in row.arrangedSubviews {
                button.configuration?.imagePlacement = stacked ? .top : .leading
                button.configuration?.imagePadding   = stacked ? 2 : 6
                // On one line the button keeps its whole title; the message gives way first
                button.setContentCompressionResistancePriority(stacked ? .defaultHigh : .required, for: .horizontal)
                button.invalidateIntrinsicContentSize()
            }
        }
        let constraints: [NSLayoutConstraint]
        if stacked, let columns = self.sideColumns {
            constraints = [
                banner.trailingAnchor.constraint(equalTo: columns.right.trailingAnchor),
                banner.topAnchor.constraint(equalTo: columns.menu.bottomAnchor, constant: 12),
                banner.widthAnchor.constraint(equalToConstant: ViewController.sideColumnWidth),
            ]
        }
        else {
            constraints = [
                banner.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                banner.bottomAnchor.constraint(equalTo: self.toolbar.topAnchor, constant: -ViewController.bannerSpacing),
            ]
        }
        for constraint in constraints {
            constraint.identifier = "bannerPlacement"
        }
        NSLayoutConstraint.activate(constraints)
    }

    // Banners and the side columns sit above the cards, which get brought to the front as they move
    func keepControlsInFront() {
        let controls: [UIView?] = [self.sideColumns?.left, self.sideColumns?.right, self.noMovesBanner]
        for case let control? in controls {
            self.view.bringSubviewToFront(control)
        }
    }
}
