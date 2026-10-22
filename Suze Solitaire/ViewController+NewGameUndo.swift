//
//  ViewController+NewGameUndo.swift
//  Suze Solitaire
//

import UIKit

// New Game deals straight away, then a banner briefly offers to bring back the game it replaced, in case the tap was
// a mistake.  Tapping Undo restores that game exactly, including the score and loss it cost.
extension ViewController {

    func offerNewGameUndo(restoring previousGame: SavedGame) {
        self.dismissNewGameUndo(animated: false)
        self.gameBeforeNewGame = previousGame

        let banner = self.addBanner(message: "New game dealt", buttonTitle: "Undo", symbol: "arrow.uturn.backward",
                                    hint: "Brings back the game you were playing") { [unowned self] in
            self.undoNewGame()
        }
        self.newGameUndoBanner = banner
        self.updateAccessibility()
        self.announce("New game dealt. Undo is available for a few seconds.")

        // Leave VoiceOver users longer to reach the button
        let duration = ViewController.newGameUndoDuration * (UIAccessibility.isVoiceOverRunning ? 2 : 1)
        let timer = DispatchWorkItem { [weak self] in
            self?.dismissNewGameUndo(animated: true)
            // The new deal might have nothing to play, which waited on this banner
            self?.updateNoMovesBanner()
        }
        self.newGameUndoTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: timer)
    }

    func undoNewGame() {
        guard let previousGame = self.gameBeforeNewGame, let board = previousGame.board else {
            return
        }
        self.dismissNewGameUndo(animated: true)

        self.clearTable()
        self.score     = previousGame.score
        self.wins      = previousGame.wins
        self.losses    = previousGame.losses
        self.autoMoves = previousGame.autocomplete
        if !self.restoreBoard(board, suitStackStarter: previousGame.suitStackStarter) {
            // Shouldn't happen, since the snapshot came from a live table; at least leave a playable one
            self.initTable()
        }
        self.lastMove   = nil
        self.deckTaps   = 0
        self.activeCard = nil
        self.undoBarButtonItem.isEnabled = false
        self.redrawTable()
        self.updateNoMovesBanner()
        self.announce("Previous game restored")
    }

    // A Liquid Glass capsule above the toolbar with a message and a button, styled like the toolbar's buttons: the same
    // height, font and label-colored text
    func addBanner(message: String, buttonTitle: String, symbol: String, hint: String, action: @escaping () -> Void) -> UIView {
        let label = UILabel()
        label.text      = message
        label.textColor = .label
        label.font      = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        // Wraps when the banner is in the narrow landscape column
        label.numberOfLines = 0
        label.textAlignment = .center

        var config = UIButton.Configuration.plain()
        config.title        = buttonTitle
        config.image        = UIImage(systemName: symbol)
        config.imagePadding = 6
        config.baseForegroundColor = .label
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .body, scale: .medium)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .body).withBoldTrait()
            return attributes
        }
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in action() })
        button.accessibilityHint = hint

        let row = UIStackView(arrangedSubviews: [label, button])
        row.spacing   = 4
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        let banner: UIVisualEffectView
        if #available(iOS 26.0, *) {
            banner = UIVisualEffectView(effect: UIGlassEffect())
            // A capsule on one line, rounded corners when stacked in the landscape column
            banner.cornerConfiguration = .capsule(maximumRadius: 22)
        }
        else {
            banner = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
            banner.layer.cornerRadius = 22
            banner.clipsToBounds      = true
        }
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.contentView.addSubview(row)
        self.view.addSubview(banner)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: banner.contentView.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: banner.contentView.trailingAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: banner.contentView.topAnchor, constant: 2),
            row.bottomAnchor.constraint(equalTo: banner.contentView.bottomAnchor, constant: -2),
            banner.heightAnchor.constraint(greaterThanOrEqualToConstant: ViewController.bannerHeight),
        ])
        self.placeBanner(banner)
        self.keepControlsInFront()

        banner.alpha = 0
        UIView.animate(withDuration: 0.25) {
            banner.alpha = 1
        }
        return banner
    }

    func removeBanner(_ banner: UIView, animated: Bool) {
        UIView.animate(withDuration: animated ? 0.25 : 0, animations: {
            banner.alpha = 0
        }, completion: { _ in
            banner.removeFromSuperview()
        })
    }

    func dismissNewGameUndo(animated: Bool) {
        self.newGameUndoTimer?.cancel()
        self.newGameUndoTimer  = nil
        self.gameBeforeNewGame = nil
        guard let banner = self.newGameUndoBanner else {
            return
        }
        self.newGameUndoBanner = nil
        self.removeBanner(banner, animated: animated)
        self.updateAccessibility()
    }
}

extension UIFont {
    func withBoldTrait() -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(.traitBold) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
