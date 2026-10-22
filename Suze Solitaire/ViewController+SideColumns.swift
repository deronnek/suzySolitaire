//
//  ViewController+SideColumns.swift
//  Suze Solitaire
//

import UIKit

// iPhone landscape is too short for a toolbar under the table, so its buttons move to columns beside it: the score,
// wins and losses under New Game on the left, and the "..." menu and the banners under How to Play on the right.
// redrawTable keeps the cards between the columns.
extension ViewController {

    static let sideColumnWidth: CGFloat = 116
    static let sideColumnSpacing: CGFloat = 8

    // Whether the window is iPhone-sized and wider than it is tall (narrow iPad windows count too)
    var usesSideColumns: Bool {
        let bounds = self.view.bounds
        let isPad  = UIDevice.current.userInterfaceIdiom == .pad && bounds.width >= 600 && bounds.height >= 600
        return !isPad && bounds.width > bounds.height
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
        self.updateSideColumns()
        for banner in [self.newGameUndoBanner, self.noMovesBanner].compactMap({ $0 }) {
            self.placeBanner(banner)
        }
        self.keepControlsInFront()
    }

    func buildSideColumns() {
        let stats = [self.bucksBarButtonItem, self.winsBarButtonItem, self.lossesBarButtonItem].map { _ in
            let button = self.sideButton()
            // Like the toolbar's, these only show the numbers
            button.isUserInteractionEnabled = false
            button.accessibilityTraits = .staticText
            return button
        }
        let left = UIStackView(arrangedSubviews: stats)
        left.axis    = .vertical
        left.spacing = ViewController.sideColumnSpacing

        let menu = self.sideButton()
        menu.configuration?.image = UIImage(systemName: "ellipsis")
        menu.accessibilityLabel   = "More"
        menu.showsMenuAsPrimaryAction = true
        menu.menu = self.buildMenu()
        let right = UIStackView(arrangedSubviews: [menu])
        right.axis      = .vertical
        right.alignment = .trailing

        let safe = self.view.safeAreaLayoutGuide
        // updateControlPlacement lines these up with New Game and How to Play
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
            menu.widthAnchor.constraint(greaterThanOrEqualTo: menu.heightAnchor),
        ])
        self.sideColumns = (left, right, stats, menu)
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

    // Copies the toolbar's numbers and their colors to the side columns
    func updateSideColumns() {
        guard let columns = self.sideColumns else {
            return
        }
        for (item, button) in zip([self.bucksBarButtonItem, self.winsBarButtonItem, self.lossesBarButtonItem], columns.stats) {
            button.configuration?.title = item?.title
            button.configuration?.baseForegroundColor = item?.tintColor ?? .label
            button.accessibilityLabel = item?.title
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
        let controls: [UIView?] = [self.sideColumns?.left, self.sideColumns?.right, self.newGameUndoBanner, self.noMovesBanner]
        for case let control? in controls {
            self.view.bringSubviewToFront(control)
        }
    }
}
