//
//  ViewController+Debug.swift
//  Suze Solitaire
//
//  A Debug section in the "..." menu, for trying out things that are hard to reach by playing, such as winning, and
//  the other sets of card faces.
//  Builds run from Xcode always have it.  TestFlight builds have it only on phones unlocked for an engineer: a long
//  press on the score shows the phone's code, scripts/debug-unlock.sh signs it with a private key kept off the repo,
//  and the signature pasted back unlocks that phone alone.  App Store builds never have it.
//

import CryptoKit
import StoreKit
import UIKit

@MainActor
enum DebugAccess {
    // The public half of the key scripts/debug-unlock.sh signs with (~/.suze-solitaire/debug-unlock-key.pem)
    static var publicKey = try! P256.Signing.PublicKey(x963Representation: Data(base64Encoded:
        "BPe5Gm1nJoI/ZZacIF5VhIe+55zySg73efHpT+6dJJk0VuFfQ2noCjMKqcBT0odK6c2mpAgP2cjhrZk/Qjpozjk=")!)
    static let unlockKey = "DebugUnlock"
    static let cardFacesKey = "DebugCardFaces"

    // The card faces picked in the Debug menu, if any, while it's unlocked
    static var cardFaces: CardFaces? {
        guard self.isUnlocked else {
            return nil
        }
        return UserDefaults.standard.string(forKey: self.cardFacesKey).flatMap(CardFaces.init(rawValue:))
    }

    // Whether this copy came from TestFlight (or Xcode), found out at launch (see checkInstall)
    static var isTestFlight = false

    static var isXcodeBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // Whether this copy can be unlocked at all; App Store copies can't
    static var canUnlock: Bool {
        self.isXcodeBuild || self.isTestFlight
    }

    static var isUnlocked: Bool {
        self.isXcodeBuild || self.isTestFlight && self.isValid(UserDefaults.standard.string(forKey: self.unlockKey) ?? "", for: self.deviceCode)
    }

    // Eight letters and digits that stand for this phone, from its ID for this developer's apps.  They change only if
    // every app from the developer is deleted.
    static var deviceCode: String {
        let id = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let digest = Array(SHA256.hash(data: Data("Suze Solitaire \(id)".utf8)))
        // Crockford's base 32, which leaves out letters that look like digits
        let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        let bits = digest.prefix(5).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        return String((0..<8).map { alphabet[Int(bits >> (35 - 5 * UInt64($0)) & 31)] })
    }

    static func message(for code: String) -> Data {
        Data("Suze Solitaire debug unlock \(code)".utf8)
    }

    // An unlock is the key's signature of the phone's code, in URL-safe base 64, as scripts/debug-unlock.sh prints it
    static func isValid(_ unlock: String, for code: String) -> Bool {
        var base64 = unlock.filter { !$0.isWhitespace }.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let der = Data(base64Encoded: base64), let signature = try? P256.Signing.ECDSASignature(derRepresentation: der) else {
            return false
        }
        return self.publicKey.isValidSignature(signature, for: self.message(for: code))
    }

    // TestFlight copies are signed for the sandbox, App Store copies for production
    static func checkInstall() async {
        guard let result = try? await AppTransaction.shared else {
            return
        }
        let environment = result.unsafePayloadValue.environment
        self.isTestFlight = environment == .sandbox || environment == .xcode
    }

    // AppStore/Screenshots/game-almost-won.json: one card from winning, which Auto Moves puts up when it's on
    static let almostWon = ViewController.SavedGame.Board(
        fub: [], deck: [], deal: [],
        suitStacks: [[45, 46, 47, 48, 49, 50, 51, 39, 40, 41], [32, 33, 34, 35, 36, 37, 38, 26, 27],
                     [6, 7, 8, 9, 10, 11, 12, 0], [19, 20, 21, 22, 23, 24, 25, 13, 14]],
        cardStacks: [[5, 30, 3, 28, 1], [31, 4, 16], [18, 43, 29, 2], [44, 17, 42, 15]])
}

extension ViewController {

    func setUpDebugAccess() {
        let press = UILongPressGestureRecognizer(target: self, action: #selector(self.scorePressed))
        self.chalkLine.isUserInteractionEnabled = true
        self.chalkLine.addGestureRecognizer(press)
        // Builds from Xcode have the menu anyway, and asking in the simulator wants an Apple Account
        guard !DebugAccess.isXcodeBuild else {
            return
        }
        Task {
            await DebugAccess.checkInstall()
            self.updateMenu()
        }
    }

    func debugMenu() -> UIMenu? {
        guard DebugAccess.isUnlocked else {
            return nil
        }
        let almostWon = UIAction(title: "Almost Won", image: UIImage(systemName: "flag.checkered")) { _ in
            self.dealAlmostWon()
        }
        let winNow = UIAction(title: "Win Now", image: UIImage(systemName: "trophy")) { _ in
            self.winNow()
        }
        var children: [UIMenuElement] = [almostWon, winNow, self.cardFacesMenu()]
        if !DebugAccess.isXcodeBuild {
            children.append(UIAction(title: "Lock Debug Menu", image: UIImage(systemName: "lock")) { _ in
                UserDefaults.standard.removeObject(forKey: DebugAccess.unlockKey)
                // Back to the game's own card faces
                self.redrawTable()
                self.updateMenu()
            })
        }
        return UIMenu(title: "Debug", image: UIImage(systemName: "ladybug"), children: children)
    }

    // Which of the four sets of card faces to show, or Automatic for the game's own choice by table size
    func cardFacesMenu() -> UIMenu {
        let picked = DebugAccess.cardFaces
        let choose = { [unowned self] (faces: CardFaces?) in
            UserDefaults.standard.set(faces?.rawValue, forKey: DebugAccess.cardFacesKey)
            // Laid out again, so the cards' outlines and shadows take the new faces' corners
            self.redrawTable()
            self.updateMenu()
        }
        let automatic = UIAction(title: "Automatic", subtitle: "Small on a phone, large on a roomy table", state: picked == nil ? .on : .off) { _ in
            choose(nil)
        }
        let sets = CardFaces.allCases.map { faces in
            UIAction(title: faces.title, state: picked == faces ? .on : .off) { _ in
                choose(faces)
            }
        }
        return UIMenu(title: "Card Faces", subtitle: (picked ?? Card.faces).title, image: UIImage(systemName: "suit.spade"),
                      children: [UIMenu(options: .displayInline, children: [automatic]), UIMenu(options: .displayInline, children: sets)])
    }

    // A long press on the score shows this phone's code, to be signed by scripts/debug-unlock.sh, and takes the unlock
    @objc func scorePressed(_ press: UILongPressGestureRecognizer) {
        guard press.state == .began, self.presentedViewController == nil else {
            return
        }
        guard DebugAccess.canUnlock else {
            // The check at launch can fail, say offline or before the App Store has its record of the install, which left
            // the press doing nothing; this asks again
            Task {
                await DebugAccess.checkInstall()
                if DebugAccess.canUnlock {
                    self.updateMenu()
                    self.showDebugUnlock()
                }
            }
            return
        }
        self.showDebugUnlock()
    }

    func showDebugUnlock() {
        guard self.presentedViewController == nil else {
            return
        }
        let code = DebugAccess.deviceCode
        let pretty = code.prefix(4) + "-" + code.suffix(4)
        if DebugAccess.isUnlocked {
            let alert = UIAlertController(title: "Debug Menu", message: "The Debug menu is on for this phone (\(pretty)).", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        let alert = UIAlertController(title: "Debug Menu",
                                      message: "This phone's code is \(pretty).  Paste the unlock that scripts/debug-unlock.sh makes for it.",
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Unlock"
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "Copy Code", style: .default) { _ in
            UIPasteboard.general.string = code
        })
        alert.addAction(UIAlertAction(title: "Unlock", style: .default) { [unowned self] _ in
            let unlock = alert.textFields?.first?.text ?? ""
            if DebugAccess.isValid(unlock, for: code) {
                UserDefaults.standard.set(unlock, forKey: DebugAccess.unlockKey)
                self.redrawTable()
                self.updateMenu()
                self.announce("Debug menu unlocked")
            }
            else {
                let wrong = UIAlertController(title: "That Unlock Doesn't Fit", message: "It has to be made for this phone's code, \(pretty).", preferredStyle: .alert)
                wrong.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(wrong, animated: true)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true)
    }

    // Swaps the game for one a card from winning, without counting a loss.  As after New Game, Undo brings back the
    // game it replaced.
    func dealAlmostWon() {
        let previousGame = self.justWon ? nil : self.currentGame()
        if self.justWon {
            self.endCelebration()
            self.justWon = false
        }
        self.clearTable()
        _ = self.restoreBoard(DebugAccess.almostWon, suitStackStarter: 7)
        self.undoHistory.removeAll()
        self.lastMove   = nil
        self.deckTaps   = 0
        self.accessibilitySelection = nil
        self.redrawTable()
        self.dealtDate = Date()
        self.updateNoMovesBanner()
        if let previousGame {
            self.offerNewGameUndo(restoring: previousGame)
        }
        else {
            self.canUndo = false
        }
    }

    // Puts every card up on its suit stack, sliding them there, and wins
    func winNow() {
        guard !self.justWon else {
            return
        }
        let stacks = [self.fub, self.deck, self.deal] + self.suitStacks + self.cardStacks
        let cards = stacks.flatMap { $0?.cards ?? [] }
        let started = self.suitStacks.compactMap { $0?.cards.first?.suit }
        let suits = started + [cardSuit.Clubs, .Diamonds, .Hearts, .Spades].filter { !started.contains($0) }
        let board = SavedGame.Board(fub: [], deck: [], deal: [], suitStacks: suits.map { suit in
            // From the starter rank round to the one below it
            cards.filter { $0.suit == suit }.sorted { ($0.rank - self.suitStackStarter + 13) % 13 < ($1.rank - self.suitStackStarter + 13) % 13 }.map { $0.view.tag }
        }, cardStacks: [[], [], [], []])
        self.recordTurn()
        let frames = self.cardFrames()
        self.clearTable()
        _ = self.restoreBoard(board, suitStackStarter: self.suitStackStarter)
        self.layOutAndSlide(from: frames)
        self.finishTurn()
    }
}
