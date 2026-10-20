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

        let label = UILabel()
        label.text      = "New game dealt"
        label.textColor = .white
        label.font      = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true

        var config = UIButton.Configuration.plain()
        config.title = "Undo"
        config.baseForegroundColor = .systemYellow
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .subheadline).withBoldTrait()
            return attributes
        }
        let button = UIButton(configuration: config, primaryAction: UIAction { [unowned self] _ in self.undoNewGame() })
        button.accessibilityHint = "Brings back the game you were playing"

        let row = UIStackView(arrangedSubviews: [label, button])
        row.spacing   = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        let banner = UIView()
        banner.backgroundColor    = UIColor.black.withAlphaComponent(0.75)
        banner.layer.cornerRadius = 20
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(row)
        self.view.addSubview(banner)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -6),
            row.topAnchor.constraint(equalTo: banner.topAnchor, constant: 2),
            row.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -2),
            banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
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
