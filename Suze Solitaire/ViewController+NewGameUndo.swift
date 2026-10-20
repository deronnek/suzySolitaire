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

        // Styled like the toolbar's buttons: a Liquid Glass capsule at the same height, with the same font and black text
        let label = UILabel()
        label.text      = "New game dealt"
        label.textColor = .black
        label.font      = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true

        var config = UIButton.Configuration.plain()
        config.title        = "Undo"
        config.image        = UIImage(systemName: "arrow.uturn.backward")
        config.imagePadding = 6
        config.baseForegroundColor = .black
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .body, scale: .medium)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .body).withBoldTrait()
            return attributes
        }
        let button = UIButton(configuration: config, primaryAction: UIAction { [unowned self] _ in self.undoNewGame() })
        button.accessibilityHint = "Brings back the game you were playing"

        let row = UIStackView(arrangedSubviews: [label, button])
        row.spacing   = 4
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        let banner: UIVisualEffectView
        if #available(iOS 26.0, *) {
            banner = UIVisualEffectView(effect: UIGlassEffect())
            banner.cornerConfiguration = .capsule()
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
            banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            banner.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: self.toolbar.topAnchor, constant: -12),
        ])
        self.newGameUndoBanner = banner

        banner.alpha = 0
        UIView.animate(withDuration: 0.25) {
            banner.alpha = 1
        }
        self.updateAccessibility()
        self.announce("New game dealt. Undo is available for a few seconds.")

        // Leave VoiceOver users longer to reach the button
        let duration = ViewController.newGameUndoDuration * (UIAccessibility.isVoiceOverRunning ? 2 : 1)
        let timer = DispatchWorkItem { [weak self] in
            self?.dismissNewGameUndo(animated: true)
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
        self.announce("Previous game restored")
    }

    func dismissNewGameUndo(animated: Bool) {
        self.newGameUndoTimer?.cancel()
        self.newGameUndoTimer  = nil
        self.gameBeforeNewGame = nil
        guard let banner = self.newGameUndoBanner else {
            return
        }
        self.newGameUndoBanner = nil
        UIView.animate(withDuration: animated ? 0.25 : 0, animations: {
            banner.alpha = 0
        }, completion: { _ in
            banner.removeFromSuperview()
        })
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
