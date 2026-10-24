//
//  ViewController+UnlimitedUndo.swift
//  Suze Solitaire
//

import StoreKit
import UIKit

// Unlimited Undo, a one-time purchase: Undo steps back a turn at a time, auto moves included, as far as the start of
// the game.  Like the free undo, right after New Game it brings back the game New Game replaced, but only until the
// first move or deal in the new one; a won game can't be brought back at all.  Without it, Undo only takes back the
// last move or deal (see undoMove).  Every turn is recorded either way, so buying it mid-game can take back moves made
// before.
extension ViewController {

    // A snapshot of the table before the move or deal that starts a turn; the auto moves after it are part of that turn
    func recordTurn() {
        guard !self.justWon, let game = self.currentGame(), game.board != nil else {
            return
        }
        // The first turn of a new game: the one before it can't be brought back any more
        if self.gameBeforeNewGame != nil {
            self.undoHistory.removeAll()
        }
        self.undoHistory.append(game)
    }

    // Puts the table back as it was before the last turn, sliding the cards back to where they were
    func undoTurn() {
        guard let game = self.undoHistory.popLast(), let board = game.board else {
            return
        }
        let frames = self.cardFrames()
        self.clearTable()
        self.score  = game.score
        self.wins   = game.wins
        self.losses = game.losses
        if !self.restoreBoard(board, suitStackStarter: game.suitStackStarter) {
            // Shouldn't happen, since the snapshot came from a live table; at least leave a playable one
            self.initTable()
        }
        self.gameBeforeNewGame = nil
        self.lastMove   = nil
        self.deckTaps   = 0
        self.activeCard = nil
        self.accessibilitySelection = nil
        self.refreshUndo()
        self.layOutAndSlide(from: frames)
        self.updateNoMovesBanner()
    }

    // Brings the Undo button and the menu up to date with the purchase and what there is to undo
    func refreshUndo() {
        self.canUndo = self.canUndo
    }

    @objc func unlimitedUndoChanged() {
        self.hasUnlimitedUndo = UndoStore.shared.isPurchased
    }

    // The menu's Unlimited Undo item: what it does and its price, or a check mark once it's bought
    func unlimitedUndoMenu() -> UIMenu {
        if self.hasUnlimitedUndo {
            let owned = UIAction(title: "Unlimited Undo", subtitle: "Purchased. Thank you!", image: UIImage(systemName: "arrow.uturn.backward.circle"),
                                 attributes: .disabled, state: .on) { _ in }
            return UIMenu(options: .displayInline, children: [owned])
        }
        let price = UndoStore.shared.product.map { " · " + $0.displayPrice } ?? ""
        let buy = UIAction(title: "Unlimited Undo", subtitle: "Undo every move, even auto moves" + price,
                           image: UIImage(systemName: "arrow.uturn.backward.circle")) { _ in
            self.buyUnlimitedUndo()
        }
        let restore = UIAction(title: "Restore Purchase", image: UIImage(systemName: "arrow.clockwise.icloud")) { _ in
            self.restoreUnlimitedUndo()
        }
        return UIMenu(options: .displayInline, children: [buy, restore])
    }

    func buyUnlimitedUndo() {
        guard let scene = self.view.window?.windowScene else {
            return
        }
        Task {
            switch await UndoStore.shared.purchase(confirmIn: scene) {
                case .purchased:
                    self.showStoreMessage("Unlimited Undo", "Undo now takes back as many moves as you like, even auto moves and New Game.")
                case .pending:
                    self.showStoreMessage("Waiting for Approval", "Unlimited Undo will turn on once the purchase is approved.")
                case .cancelled:
                    break
                case .failed(let message):
                    self.showStoreMessage("Couldn't Buy Unlimited Undo", message)
            }
        }
    }

    func restoreUnlimitedUndo() {
        Task {
            await UndoStore.shared.restore()
            if !UndoStore.shared.isPurchased {
                self.showStoreMessage("Nothing to Restore", "This Apple Account hasn't bought Unlimited Undo.")
            }
        }
    }

    func showStoreMessage(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}

// The Unlimited Undo purchase, kept up to date with the App Store.  The app delegate starts it at launch; it posts
// changedNotification when the purchase turns on or off (bought, restored, refunded or shared through Family Sharing).
@MainActor
final class UndoStore {
    static let shared = UndoStore()
    static let productID = "unlimited_undo"
    static let changedNotification = Notification.Name("UnlimitedUndoChanged")

    enum Outcome: Equatable {
        case purchased, pending, cancelled
        case failed(String)
    }

    private(set) var product: Product?
    private(set) var isPurchased = false {
        didSet {
            if isPurchased != oldValue {
                NotificationCenter.default.post(name: UndoStore.changedNotification, object: self)
            }
        }
    }
    private var updates: Task<Void, Never>?

    func start() {
        guard self.updates == nil else {
            return
        }
        // Purchases made elsewhere: on another device, through Ask to Buy, or refunds
        self.updates = Task {
            for await update in Transaction.updates {
                await self.apply(update)
            }
        }
        Task {
            await self.refresh()
            _ = await self.loadProduct()
        }
    }

    // Why the product couldn't be loaded last time, to tell the player
    private(set) var loadFailure: String?

    func loadProduct() async -> Product? {
        if self.product == nil {
            do {
                self.product = try await Product.products(for: [UndoStore.productID]).first
                // The App Store answered but didn't have it: not set up, or not cleared for sale yet
                self.loadFailure = self.product == nil ? "Unlimited Undo isn't available from the App Store yet. Try again later." : nil
            }
            catch {
                self.loadFailure = "The App Store couldn't be reached (\(error.localizedDescription)). Try again later."
            }
        }
        return self.product
    }

    func refresh() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement, transaction.productID == UndoStore.productID, transaction.revocationDate == nil {
                owned = true
            }
        }
        self.isPurchased = owned
    }

    func purchase(confirmIn scene: UIScene) async -> Outcome {
        guard let product = await self.loadProduct() else {
            return .failed(self.loadFailure ?? "The App Store couldn't be reached. Try again later.")
        }
        do {
            switch try await product.purchase(confirmIn: scene) {
                case .success(let result):
                    guard case .verified = result else {
                        return .failed("The App Store couldn't confirm the purchase.")
                    }
                    await self.apply(result)
                    return .purchased
                case .pending:
                    return .pending
                case .userCancelled:
                    return .cancelled
                @unknown default:
                    return .cancelled
            }
        }
        catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await self.refresh()
    }

    private func apply(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            return
        }
        if transaction.productID == UndoStore.productID {
            self.isPurchased = transaction.revocationDate == nil
        }
        await transaction.finish()
    }
}
