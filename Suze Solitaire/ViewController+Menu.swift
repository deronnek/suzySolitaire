//
//  ViewController+Menu.swift
//  Suze Solitaire
//

import PhotosUI
import UIKit

// The "..." menu in the bottom corner: a hint, auto moves, the no-moves banner, the drop highlight, the card back, resetting wins and losses,
// Unlimited Undo, and the About box
extension ViewController: PHPickerViewControllerDelegate {

    func buildMenu() -> UIMenu {
        let auto = UIAction(title: "Auto Moves", image: UIImage(systemName: "wand.and.stars"), state: self.autoMoves ? .on : .off) { _ in
            self.autoMoves.toggle()
        }

        let hint = UIAction(title: "Hint", image: UIImage(systemName: "lightbulb")) { _ in
            self.showHint()
        }

        let noMoves = UIAction(title: "Show When Stuck", image: UIImage(systemName: "exclamationmark.bubble"), state: self.showsNoMoves ? .on : .off) { _ in
            self.showsNoMoves.toggle()
        }

        let drops = UIAction(title: "Highlight Drop Spot", image: UIImage(systemName: "scope"), state: self.highlightsDrops ? .on : .off) { _ in
            self.highlightsDrops.toggle()
        }

        let choosePhoto = UIAction(title: "Choose Photo…", image: UIImage(systemName: "photo.on.rectangle")) { _ in
            var config = PHPickerConfiguration()
            config.filter         = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            self.present(picker, animated: true)
        }
        let useDefault = UIAction(title: "Use Default", image: UIImage(systemName: "arrow.counterclockwise"),
                                  attributes: Card.customBackImage == nil ? .disabled : []) { _ in
            self.setCardBack(nil)
        }
        let cardBack = UIMenu(title: "Card Back", image: UIImage(systemName: "rectangle.portrait"), children: [choosePhoto, useDefault])

        let resetStats = UIAction(title: "Reset Wins & Losses…", image: UIImage(systemName: "arrow.counterclockwise.circle"),
                                  attributes: .destructive) { _ in
            self.confirmResetStats()
        }

        let about = UIAction(title: "About", image: UIImage(systemName: "info.circle")) { _ in
            self.showAbout()
        }
        let howToPlay = UIAction(title: "How to Play", image: UIImage(systemName: "questionmark.circle")) { _ in
            self.showHowToPlay()
        }
        return UIMenu(children: [UIMenu(options: .displayInline, children: [hint, howToPlay]), auto, noMoves, drops, cardBack, resetStats, self.unlimitedUndoMenu(), about])
    }

    func showHowToPlay() {
        let rules = self.storyboard!.instantiateViewController(withIdentifier: "howToPlay")
        self.navigationController?.pushViewController(rules, animated: true)
    }

    func updateMenu() {
        self.menuButton.menu = self.buildMenu()
    }

    // MARK: Card back

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        // The photo arrives on a background thread
        provider.loadObject(ofClass: UIImage.self) { @Sendable object, _ in
            guard let photo = object as? UIImage else {
                return
            }
            Task { @MainActor in
                self.setCardBack(Card.cardBackImage(from: photo))
            }
        }
    }

    // Uses `image` as the back of every card (nil restores the default) and remembers it across launches
    func setCardBack(_ image: UIImage?) {
        do {
            if let image = image {
                try image.pngData()?.write(to: Card.customBackImageURL, options: .atomic)
            }
            else if FileManager.default.fileExists(atPath: Card.customBackImageURL.path) {
                try FileManager.default.removeItem(at: Card.customBackImageURL)
            }
        }
        catch {
            print("Failed to save card back: \(error)")
        }
        Card.customBackImage = image

        for case let card? in self.viewTagToCard.values {
            card.backImage = image ?? UIImage(imageLiteralResourceName: card.backImageFilename)
            if self.viewTagToStack[card.view.tag]??.stackType == .deck {
                card.view.image = card.backImage
            }
        }
        self.updateMenu()
    }

    // MARK: Wins and losses

    func confirmResetStats() {
        let alert = UIAlertController(title: "Reset Wins & Losses?",
                                      message: "Your wins and losses will go back to zero. Your money and the current game won't change.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            self.resetStats()
        })
        self.present(alert, animated: true)
    }

    func resetStats() {
        // Undoing a New Game would bring the old counts back
        self.undoHistory.removeAll()
        if self.gameBeforeNewGame != nil {
            self.gameBeforeNewGame = nil
            self.canUndo = false
        }
        self.wins   = 0
        self.losses = 0
        self.saveGame()
        self.announce("Wins and losses reset")
    }

    // MARK: About

    func showAbout() {
        let info    = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build   = info["CFBundleVersion"] as? String ?? "?"
        var message = "Version \(version) (\(build))"
        if let date = ViewController.buildDate(buildNumber: build) {
            message += "\nBuilt " + DateFormatter.localizedString(from: date, dateStyle: .long, timeStyle: .short)
        }
        let alert = UIAlertController(title: "Suze Solitaire", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    static func buildDate(buildNumber: String) -> Date? {
        // scripts/testflight.sh numbers builds by the time they were made (yyyyMMdd.HHmm)
        let formatter = DateFormatter()
        formatter.locale     = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd.HHmm"
        if let date = formatter.date(from: buildNumber) {
            return date
        }
        // Other builds: when the executable was linked
        return (try? Bundle.main.executableURL?.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}
