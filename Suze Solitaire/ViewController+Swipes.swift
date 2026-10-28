//
//  ViewController+Swipes.swift
//  Suze Solitaire
//

import UIKit

// Shortcuts for the buttons: swiping in from the left edge of the screen to the middle undoes, as the Undo button does,
// and swiping in from the right edge to the middle shows a hint, as Hint in the "..." menu does.  A pill across the top
// of the table fills from the side the swipe came from as the finger comes in, and lights up, with a tick, once letting
// go would do it; going back toward the edge before letting go calls it off.
extension ViewController {

    // How close to the middle the finger has to come
    static let swipeSlack: CGFloat = 24

    func setUpEdgeSwipes() {
        for edge in [UIRectEdge.left, .right] {
            let swipe = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(self.edgeSwiped))
            swipe.edges = edge
            swipe.delegate = self
            self.view.addGestureRecognizer(swipe)
        }
    }

    @objc func edgeSwiped(_ swipe: UIScreenEdgePanGestureRecognizer) {
        self.edgeSwipe(from: swipe.edges, state: swipe.state, at: swipe.location(in: self.view))
    }

    // Whether an edge swipe can start: not while the cards celebrate a win, or over an alert or the menu
    func edgeSwipeCanBegin() -> Bool {
        !self.justWon && self.presentedViewController == nil
    }

    // Follows a swipe in from an edge, and undoes or hints if it ends at the middle
    func edgeSwipe(from edge: UIRectEdge, state: UIGestureRecognizer.State, at point: CGPoint) {
        let fromLeft = edge.contains(.left)
        let width = self.view.bounds.width
        // 0 at the edge, 1 at the middle
        let progress = max(0, min(1, (fromLeft ? point.x : width - point.x) / (width / 2 - ViewController.swipeSlack)))
        let available = !fromLeft || self.canUndo
        let armed = progress >= 1 && available
        switch state {
            case .began, .changed:
                let pill = self.swipePill ?? self.makeSwipePill(fromLeft: fromLeft, available: available)
                self.swipePill = pill
                pill.progress = available ? progress : 0
                if armed != self.swipeArmed {
                    self.swipeArmed = armed
                    pill.isArmed = armed
                    if armed {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
            case .ended:
                self.dismissSwipePill(done: armed)
                if armed {
                    if fromLeft {
                        self.undoMove(self)
                    }
                    else {
                        self.showHint()
                    }
                }
            default:
                self.dismissSwipePill(done: false)
        }
    }

    func makeSwipePill(fromLeft: Bool, available: Bool) -> SwipePill {
        let pill = SwipePill(fromLeft: fromLeft)
        pill.title = fromLeft ? (available ? "Undo" : "Nothing to Undo") : "Hint"
        pill.isAvailable = available
        self.view.addSubview(pill)
        self.placeSwipePill(pill)
        pill.layoutIfNeeded()
        return pill
    }

    // Across the top of the table, below the status bar and the Dynamic Island, and above the cards where there's room
    func placeSwipePill(_ pill: SwipePill) {
        let statusBar = self.view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        // The window's inset, since the view's counts the navigation bar, which the table doesn't show
        let top = max(statusBar, self.view.window?.safeAreaInsets.top ?? 0, 4)
        let stacks = ([self.fub, self.deck, self.deal] + self.suitStacks + self.cardStacks).compactMap { $0?.view }
        let cardsTop = stacks.map { $0.frame.minY }.min() ?? top + 60
        let height = SwipePill.height
        let y = cardsTop - top >= height + 8 ? (top + cardsTop) / 2 : top + 4 + height / 2
        pill.bounds = CGRect(x: 0, y: 0, width: SwipePill.width, height: height)
        pill.center = CGPoint(x: self.view.bounds.midX, y: y)
    }

    // Lights the pill up when the swipe did its job, and fades it either way
    func dismissSwipePill(done: Bool) {
        guard let pill = self.swipePill else {
            return
        }
        self.swipePill = nil
        self.swipeArmed = false
        UIView.animate(withDuration: 0.25, delay: done ? 0.15 : 0, options: [.beginFromCurrentState]) {
            pill.alpha = 0
        } completion: { _ in
            pill.removeFromSuperview()
        }
    }
}

// A capsule saying what the swipe will do, which fills from the side the swipe came from as the finger nears the middle
// of the screen, and turns solid once letting go would do it
final class SwipePill: UIView {
    static let width: CGFloat  = 200
    static let height: CGFloat = 36

    let fromLeft: Bool
    private let background: UIVisualEffectView
    private let fill = UIView()
    private let icon = UIImageView()
    private let label = UILabel()

    var title: String {
        get { self.label.text ?? "" }
        set { self.label.text = newValue }
    }
    var isAvailable = true {
        didSet { self.restyle() }
    }
    // How far the finger has come, from 0 at the edge to 1 at the middle
    var progress: CGFloat = 0 {
        didSet { self.setNeedsLayout() }
    }
    var isArmed = false {
        didSet { self.restyle() }
    }

    init(fromLeft: Bool) {
        self.fromLeft = fromLeft
        if #available(iOS 26.0, *) {
            self.background = UIVisualEffectView(effect: UIGlassEffect())
        }
        else {
            self.background = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        }
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.background.clipsToBounds = true
        self.addSubview(self.background)
        self.background.contentView.addSubview(self.fill)
        self.icon.image = UIImage(systemName: fromLeft ? "arrow.uturn.backward" : "lightbulb",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        self.icon.contentMode = .center
        self.label.font = .systemFont(ofSize: 15, weight: .semibold)
        self.label.adjustsFontSizeToFitWidth = true
        self.label.minimumScaleFactor = 0.7
        self.background.contentView.addSubview(self.icon)
        self.background.contentView.addSubview(self.label)
        self.restyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = self.bounds
        self.layer.cornerRadius = bounds.height / 2
        self.background.frame = bounds
        self.background.layer.cornerRadius = bounds.height / 2
        let width = bounds.width * max(0, min(1, self.progress))
        self.fill.frame = CGRect(x: self.fromLeft ? 0 : bounds.width - width, y: 0, width: width, height: bounds.height)
        // The symbol and title together in the middle
        let iconSize = self.icon.intrinsicContentSize
        let labelWidth = min(self.label.intrinsicContentSize.width, bounds.width - iconSize.width - 40)
        let total = iconSize.width + 6 + labelWidth
        let x = (bounds.width - total) / 2
        self.icon.frame  = CGRect(x: x, y: 0, width: iconSize.width, height: bounds.height)
        self.label.frame = CGRect(x: x + iconSize.width + 6, y: 0, width: labelWidth, height: bounds.height)
    }

    private func restyle() {
        let tint = self.tintColor ?? .systemBlue
        self.fill.backgroundColor = self.isArmed ? tint : tint.withAlphaComponent(0.35)
        let text: UIColor = self.isArmed ? .white : .label
        self.icon.tintColor = text
        self.label.textColor = text
        self.icon.alpha  = self.isAvailable ? 1 : 0.5
        self.label.alpha = self.isAvailable ? 1 : 0.5
    }
}

#if DEBUG
extension ViewController {

    // scripts/swipe-video.sh passes -DemoEdgeSwipes to deal, then play out a swipe from each edge, with a dot for the finger
    func demoEdgeSwipes() {
        let finger = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        finger.layer.cornerRadius = 22
        finger.backgroundColor = UIColor.white.withAlphaComponent(0.45)
        finger.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        finger.layer.borderWidth = 2
        finger.alpha = 0
        self.view.addSubview(finger)
        let bounds = self.view.bounds
        // A deal for the first swipe to take back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.tapDeck()
            self.finishTurn()
        }
        let steps: [(edge: UIRectEdge, start: CGFloat, y: CGFloat)] = [(.left, 1.2, bounds.height * 0.55), (.right, 4.0, bounds.height * 0.45)]
        for step in steps {
            let fromLeft = step.edge == .left
            let x = { (t: CGFloat) in fromLeft ? 4 + (bounds.midX + 6) * t : bounds.width - 4 - (bounds.midX + 6) * t }
            let frames = 45
            for i in 0...frames {
                let t = CGFloat(i) / CGFloat(frames)
                // Eased, as a finger slows toward where it stops
                let eased = 1 - pow(1 - t, 2)
                DispatchQueue.main.asyncAfter(deadline: .now() + step.start + 0.9 * Double(t)) {
                    let point = CGPoint(x: x(eased), y: step.y)
                    finger.center = point
                    finger.alpha = 1
                    self.view.bringSubviewToFront(finger)
                    self.edgeSwipe(from: step.edge, state: i == 0 ? .began : .changed, at: point)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + step.start + 1.3) {
                finger.alpha = 0
                self.edgeSwipe(from: step.edge, state: .ended, at: CGPoint(x: x(1), y: step.y))
            }
        }
    }
}
#endif
