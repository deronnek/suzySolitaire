//
//  ViewController+Menu.swift
//  Suze Solitaire
//

import PhotosUI
import UIKit

// The "..." menu in the bottom corner: a hint, auto moves, the no-moves banner, the drop highlight, how to deal, the cards' artwork and back, resetting wins and losses,
// Unlimited Undo, the About box, and on engineers' phones the Debug menu (see ViewController+Debug.swift)
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
        let back = UIMenu(title: "Back", subtitle: Card.customBackImage == nil ? "Default" : "Photo", image: UIImage(systemName: "photo"),
                          children: [choosePhoto, useDefault])
        let cards = UIMenu(title: "Cards", image: UIImage(systemName: "rectangle.portrait.on.rectangle.portrait"),
                           children: [self.artworkMenu(), back])

        let stats = UIAction(title: "Stats", image: UIImage(systemName: "chart.bar")) { _ in
            self.showStats()
        }

        let about = UIAction(title: "About", image: UIImage(systemName: "info.circle")) { _ in
            self.showAbout()
        }
        let howToPlay = UIAction(title: "How to Play", image: UIImage(systemName: "questionmark.circle")) { _ in
            self.showHowToPlay()
        }
        let items: [UIMenuElement?] = [UIMenu(options: .displayInline, children: [hint, howToPlay, stats]), auto, noMoves, drops, self.dealingMenu(), cards,
                                       self.unlimitedUndoMenu(), about, self.debugMenu()]
        return UIMenu(children: items.compactMap { $0 })
    }

    // How New Game deals, each choice with what it means
    func dealingMenu() -> UIMenu {
        let picked = self.dealing
        let choices = Dealing.allCases.map { dealing in
            UIAction(title: dealing.title, subtitle: dealing.detail, state: picked == dealing ? .on : .off) { _ in
                self.dealing = dealing
            }
        }
        return UIMenu(title: "Dealing", subtitle: picked.title, image: UIImage(systemName: "checkmark.seal"),
                      children: [UIMenu(title: "From the next new game", options: .displayInline, children: choices)])
    }

    // Which set of card faces to show, or Default for the game's own (big ranks in Abril Fatface), each with
    // its king of hearts to show what it looks like
    func artworkMenu() -> UIMenu {
        let picked = CardFaces.picked
        let choose = { [unowned self] (faces: CardFaces?) in
            CardFaces.picked = faces
            // Laid out again, so the cards' outlines and shadows take the new faces' corners
            self.redrawTable()
            self.updateMenu()
        }
        let automatic = UIAction(title: "Default", subtitle: CardFaces.standard.title,
                                 image: UIImage(systemName: "wand.and.stars"), state: picked == nil ? .on : .off) { _ in
            choose(nil)
        }
        let sets = CardFaces.allCases.map { faces in
            UIAction(title: faces.title, image: self.artworkPreview(faces), state: picked == faces ? .on : .off) { _ in
                choose(faces)
            }
        }
        return UIMenu(title: "Artwork", subtitle: picked?.title ?? "Default", image: UIImage(systemName: "suit.heart"),
                      children: [UIMenu(options: .displayInline, children: [automatic]), UIMenu(options: .displayInline, children: sets)])
    }

    // A set's king of hearts, small enough for a menu, with its corners
    func artworkPreview(_ faces: CardFaces) -> UIImage? {
        guard let king = UIImage(named: "\(faces.rawValue)/king_of_hearts") else {
            return nil
        }
        let size = CGSize(width: 20, height: 20 * Card.aspectRatio)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.width * faces.cornerRadiusFraction).addClip()
            king.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysOriginal)
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
            if self.viewTagToStack[card.view.tag]??.stackType == .deck {
                card.view.image = card.backImage
            }
        }
        self.updateMenu()
    }

    // MARK: Wins and losses

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
