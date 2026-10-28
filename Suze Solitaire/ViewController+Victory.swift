//
//  ViewController+Victory.swift
//  Suze Solitaire
//
//  What happens when the game is won.  The cards leave the stacks for four rows, one for each suit from Ace to King,
//  then fly off the table toward the player a rank at a time, spinning and growing as they pass, until only "You Won!"
//  and a New Game button are left.  A tap skips ahead, and a card can be flicked off the table early.  With Reduce
//  Motion on, the cards fade instead.
//

import UIKit

extension ViewController {
    // Hands the won table over to a VictoryView, which plays out the celebration over the felt
    func celebrateWin() {
        let stacks = [self.fub, self.deck, self.deal] + self.suitStacks + self.cardStacks
        let cards = stacks.flatMap { $0?.cards ?? [] }
        let order = self.suitStacks.compactMap { $0?.cards.first?.suit }
        let suits = order.count == 4 ? order : [.Clubs, .Diamonds, .Hearts, .Spades]
        let rows: [[VictoryView.Flyer]] = suits.map { suit in
            cards.filter { $0.suit == suit }.sorted { $0.rank < $1.rank }.map { card in
                VictoryView.Flyer(image: card.view.image, frame: self.view.convert(card.view.frame, from: card.view.superview),
                                  cornerRadius: card.view.layer.cornerRadius)
            }
        }
        // The table's stacks stay behind, out of sight, until New Game clears them
        for stack in stacks {
            stack?.view.isHidden = true
        }
        // Between Undo and the "..." button, or the safe area when they're in iPhone Duo's strip
        let top = self.undoButton.superview === self.view ? self.undoButton.frame.maxY + 8 : self.view.safeAreaInsets.top + 8
        let bottom = self.menuButton.superview === self.view ? self.menuButton.frame.minY - 8 : self.view.bounds.height - self.view.safeAreaInsets.bottom - 8
        let table = CGRect(x: 0, y: top, width: self.view.bounds.width, height: max(0, bottom - top))
        let victory = VictoryView(frame: self.view.bounds, rows: rows, table: table, safeArea: self.view.safeAreaInsets) { [unowned self] in
            self.startNewGameWithSender(sender: self)
        }
        victory.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(victory)
        self.victoryView = victory
        self.keepControlsInFront()
        self.updateAccessibility()
        victory.play()
    }

    func endCelebration() {
        self.victoryView?.removeFromSuperview()
        self.victoryView = nil
    }
}

class VictoryView: UIView {
    struct Flyer {
        let image: UIImage?
        let frame: CGRect
        let cornerRadius: CGFloat
    }

    // The cards resting in their rows sit under the ones flying off, so a card launched later passes behind those
    // already on their way (and nearer the player)
    private let resting = UIView()
    private let flying  = UIView()
    private var rows    = [[UIImageView]]()
    private var launched = Set<UIView>()
    private let table: CGRect
    private let safeArea: UIEdgeInsets
    private let ending = UIStackView()
    private let onNewGame: () -> Void
    private var skipped = false
    private lazy var playedSize = self.bounds.size
    private let tick = UIImpactFeedbackGenerator(style: .light)

    // How far away the player's eye is: the smaller, the more the cards grow as they come out of the table
    static let eyeDistance: CGFloat = 700
    static let rowsDuration: TimeInterval = 0.7
    static let burstDelay: TimeInterval   = 1.5
    static let rankInterval: TimeInterval = 0.16
    static let flightDuration: TimeInterval = 1.15
    static let gold = UIColor(red: 1, green: 0.82, blue: 0.3, alpha: 1)

    init(frame: CGRect, rows flyers: [[Flyer]], table: CGRect, safeArea: UIEdgeInsets, onNewGame: @escaping () -> Void) {
        self.table     = table
        self.safeArea  = safeArea
        self.onNewGame = onNewGame
        super.init(frame: frame)
        for layer in [self.resting, self.flying] {
            layer.frame = self.bounds
            layer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.addSubview(layer)
        }
        // Perspective from the middle of the table, so cards coming toward the player also spread out from it
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / VictoryView.eyeDistance
        self.flying.layer.sublayerTransform = perspective
        self.rows = flyers.map { row in
            row.map { flyer in
                let view = UIImageView(image: flyer.image)
                view.frame = flyer.frame
                view.layer.cornerRadius  = flyer.cornerRadius
                view.layer.borderWidth   = 0.5
                view.layer.borderColor   = Card.outlineColor.cgColor
                view.layer.shadowColor   = UIColor.black.cgColor
                view.layer.shadowOpacity = Card.shadowOpacity
                view.layer.shadowRadius  = 1.5
                view.layer.shadowOffset  = .zero
                view.layer.shadowPath    = UIBezierPath(roundedRect: view.bounds, cornerRadius: flyer.cornerRadius).cgPath
                view.isAccessibilityElement = false
                self.resting.addSubview(view)
                return view
            }
        }
        self.buildEnding()
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
        self.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.flicked)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var cardViews: [UIImageView] {
        self.rows.flatMap { $0 }
    }

    var accessibleViews: [UIView] {
        self.ending.arrangedSubviews
    }

    var endingIsShowing: Bool {
        self.ending.alpha > 0
    }

    // "You Won!", the winnings, and a big New Game button, in the middle of the table once the cards have gone
    private func buildEnding() {
        let shadow = NSShadow()
        shadow.shadowColor      = UIColor.black.withAlphaComponent(0.35)
        shadow.shadowOffset     = CGSize(width: 0, height: 2)
        shadow.shadowBlurRadius = 6
        let big = min(self.table.width / 7, 64)
        func label(_ text: String, font: String, size: CGFloat, color: UIColor) -> UILabel {
            let label = UILabel()
            label.attributedText = NSAttributedString(string: text, attributes: [
                .font: UIFont(name: font, size: size) ?? .boldSystemFont(ofSize: size),
                .foregroundColor: color,
                .shadow: shadow])
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
            return label
        }
        let title    = label("You Won!", font: "Futura-Bold", size: big, color: .white)
        let winnings = label("+$250", font: "Futura-Medium", size: big * 0.6, color: VictoryView.gold)
        title.accessibilityTraits = .header

        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .prominentGlass()
        }
        else {
            config = .filled()
            config.cornerStyle = .capsule
        }
        config.title = "New Game"
        config.image = UIImage(systemName: "arrow.triangle.2.circlepath")
        config.imagePadding = 10
        config.buttonSize   = .large
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont(name: "Futura-Medium", size: 22) ?? .systemFont(ofSize: 22, weight: .semibold)
            return attributes
        }
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 28, bottom: 14, trailing: 28)
        let newGame = UIButton(configuration: config)
        newGame.tintColor = UIColor(red: 0.13, green: 0.42, blue: 0.2, alpha: 1)
        newGame.addAction(UIAction { [unowned self] _ in self.onNewGame() }, for: .primaryActionTriggered)

        let stack = self.ending
        stack.axis      = .vertical
        stack.alignment = .center
        stack.spacing   = 8
        for view in [title, winnings, newGame] {
            stack.addArrangedSubview(view)
        }
        stack.setCustomSpacing(28, after: winnings)
        stack.alpha = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: self.widthAnchor, constant: -32),
        ])
    }

    // Where each card goes in the rows: each suit fanned to fit the table's width, the rows filling its height
    private func rowFrames() -> [[CGRect]] {
        guard let size = self.rows.first?.first?.bounds.size else {
            return []
        }
        let left  = max(16, self.safeArea.left + 8)
        let right = self.bounds.width - max(16, self.safeArea.right + 8)
        let step  = min(size.width * 0.735, (right - left - size.width) / 12)
        let rowWidth = size.width + 12 * step
        let gap   = min(size.height + 8, (self.table.height - size.height) / 3)
        let top   = self.table.minY + max(0, (self.table.height - 3 * gap - size.height) / 2)
        let x0    = left + (right - left - rowWidth) / 2
        return self.rows.indices.map { row in
            self.rows[row].indices.map { i in
                CGRect(origin: CGPoint(x: x0 + CGFloat(i) * step, y: top + CGFloat(row) * gap), size: size)
            }
        }
    }

    func play() {
        self.playedSize = self.bounds.size
        if UIAccessibility.isReduceMotionEnabled {
            self.fadeAway()
            return
        }
        let frames = self.rowFrames()
        for (row, views) in self.rows.enumerated() {
            for (i, view) in views.enumerated() {
                self.resting.bringSubviewToFront(view)
                UIView.animate(withDuration: VictoryView.rowsDuration, delay: 0.1 + Double(i) * 0.025 + Double(row) * 0.04,
                               usingSpringWithDamping: 0.75, initialSpringVelocity: 0, options: [.allowUserInteraction]) {
                    view.frame = frames[row][i]
                }
            }
        }
        // Then a rank at a time, Aces first, the cards come off the table
        for rank in 0..<13 {
            DispatchQueue.main.asyncAfter(deadline: .now() + VictoryView.burstDelay + Double(rank) * VictoryView.rankInterval) { [weak self] in
                guard let self, !self.skipped, self.window != nil else {
                    return
                }
                self.launchRank(rank, intensity: 0.35 + CGFloat(rank) * 0.04)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + VictoryView.burstDelay + 12 * VictoryView.rankInterval + 0.55) { [weak self] in
            self?.showEnding()
        }
        self.tick.prepare()
    }

    private func launchRank(_ rank: Int, intensity: CGFloat) {
        var any = false
        for row in self.rows where rank < row.count {
            any = self.launch(row[rank], delay: Double.random(in: 0...0.05)) || any
        }
        if any {
            self.tick.impactOccurred(intensity: intensity)
        }
    }

    // Sends a card off the table toward the player, tumbling as it comes and fading as it passes.  The direction is
    // away from the middle of the table, or the way it was flicked.  Returns false if it had already gone.
    @discardableResult
    private func launch(_ view: UIView, delay: TimeInterval = 0, velocity: CGPoint? = nil, duration: TimeInterval = VictoryView.flightDuration) -> Bool {
        guard !self.launched.contains(view) else {
            return false
        }
        self.launched.insert(view)
        // Take over from the slide into the rows wherever it's got to
        let current = view.layer.presentation()?.frame ?? view.frame
        view.layer.removeAllAnimations()
        view.frame = current
        // Under the cards already flying, which are nearer the player
        self.flying.insertSubview(view, at: 0)

        let center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        var direction = velocity.map { CGVector(dx: $0.x, dy: $0.y) } ??
            CGVector(dx: view.center.x - center.x, dy: view.center.y - center.y)
        let length = max(hypot(direction.dx, direction.dy), 1)
        direction = CGVector(dx: direction.dx / length, dy: direction.dy / length)
        // The perspective spreads them out from the middle as they come closer, so they need little push of their own
        let reach = max(self.bounds.width, self.bounds.height) * (velocity == nil ? 0.12 : 0.6)
        // Toward the player, short of the eye so they grow to several times their size
        let depth = VictoryView.eyeDistance * CGFloat.random(in: 0.8...0.88)
        var flight = CATransform3DMakeTranslation(direction.dx * reach + CGFloat.random(in: -40...40),
                                                  direction.dy * reach + CGFloat.random(in: -40...40), depth)
        flight = CATransform3DRotate(flight, CGFloat.random(in: 0.8...1.6) * .pi * (Bool.random() ? 1 : -1),
                                     CGFloat.random(in: -1...1), CGFloat.random(in: -1...1), CGFloat.random(in: 0.3...1))

        let move = CABasicAnimation(keyPath: "transform")
        move.fromValue = CATransform3DIdentity
        move.toValue   = flight
        // Coming at a steady speed, they grow faster and faster as they near the eye
        move.timingFunction = CAMediaTimingFunction(name: .linear)
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values   = [1, 1, 0]
        fade.keyTimes = [0, 0.7, 1]
        let group = CAAnimationGroup()
        group.animations = [move, fade]
        group.duration   = duration
        group.beginTime  = CACurrentMediaTime() + delay
        group.fillMode   = .backwards
        CATransaction.begin()
        CATransaction.setCompletionBlock { view.removeFromSuperview() }
        view.layer.add(group, forKey: "flight")
        CATransaction.commit()
        view.layer.transform = flight
        view.layer.opacity   = 0
        return true
    }

    // Reduce Motion: the rows aren't laid out, and the cards fade where they are
    private func fadeAway() {
        UIView.animate(withDuration: 0.6, delay: 0.3) {
            self.resting.alpha = 0
        } completion: { _ in
            self.showEnding()
        }
    }

    private func showEnding() {
        guard self.ending.alpha == 0 else {
            return
        }
        self.ending.transform = UIAccessibility.isReduceMotionEnabled ? .identity : CGAffineTransform(scaleX: 0.6, y: 0.6)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: [.allowUserInteraction]) {
            self.ending.alpha = 1
            self.ending.transform = .identity
        }
        UIAccessibility.post(notification: .layoutChanged, argument: self.ending.arrangedSubviews.last)
    }

    // A tap sends everything still on the table off at once
    @objc private func tapped() {
        self.skip()
    }

    func skip() {
        guard !self.skipped else {
            return
        }
        self.skipped = true
        if UIAccessibility.isReduceMotionEnabled {
            self.resting.layer.removeAllAnimations()
            self.resting.alpha = 0
        }
        else {
            for (i, view) in self.cardViews.enumerated() {
                self.launch(view, delay: Double(i) * 0.008, duration: 0.8)
            }
            self.tick.impactOccurred(intensity: 0.8)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (UIAccessibility.isReduceMotionEnabled ? 0 : 0.35)) { [weak self] in
            self?.showEnding()
        }
    }

    // A card still on the table can be flicked off it early, in the direction it was flicked
    @objc private func flicked(_ pan: UIPanGestureRecognizer) {
        guard pan.state == .began || pan.state == .changed, !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        let point = pan.location(in: self.resting)
        guard let view = self.resting.subviews.last(where: { ($0.layer.presentation()?.frame ?? $0.frame).contains(point) }) else {
            return
        }
        let velocity = pan.velocity(in: self)
        if self.launch(view, velocity: hypot(velocity.x, velocity.y) > 50 ? velocity : nil, duration: 0.9) {
            self.tick.impactOccurred(intensity: 0.6)
        }
    }

    // A change of size, such as a rotation, leaves the rows where they no longer fit, so skip to the end
    override func layoutSubviews() {
        super.layoutSubviews()
        if self.bounds.size != self.playedSize {
            self.playedSize = self.bounds.size
            self.skip()
        }
    }
}
