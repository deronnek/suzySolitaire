//
//  ViewController+Swipes.swift
//  Suze Solitaire
//

import UIKit

// Shortcuts for the buttons: swiping in from the left edge of the screen to the middle undoes, as the Undo button does,
// and swiping in from the right edge to the middle shows a hint, as Hint in the "..." menu does.  A pill in the middle
// of the table grows as the finger comes in and lights up, with a tick, once letting go would do it; going back toward
// the edge before letting go calls it off.
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
                if armed != self.swipeArmed {
                    self.swipeArmed = armed
                    self.styleSwipePill(pill, fromLeft: fromLeft, available: available, armed: armed)
                    if armed {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
                self.placeSwipePill(pill, near: point, progress: progress)
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

    func makeSwipePill(fromLeft: Bool, available: Bool) -> UIButton {
        let pill = self.cornerButton(symbol: fromLeft ? "arrow.uturn.backward" : "lightbulb")
        pill.isUserInteractionEnabled = false
        pill.configuration?.imagePadding = 8
        pill.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 20)
        self.styleSwipePill(pill, fromLeft: fromLeft, available: available, armed: false)
        self.view.addSubview(pill)
        return pill
    }

    func styleSwipePill(_ pill: UIButton, fromLeft: Bool, available: Bool, armed: Bool) {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = armed ? .prominentGlass() : .glass()
        }
        else {
            config = armed ? .filled() : .gray()
            config.cornerStyle = .capsule
        }
        if let old = pill.configuration {
            config.image = old.image
            config.imagePadding = old.imagePadding
            config.contentInsets = old.contentInsets
        }
        config.title = fromLeft ? (available ? "Undo" : "Nothing to Undo") : "Hint"
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        pill.configuration = config
        pill.alpha = available ? 1 : 0.6
    }

    // In the middle of the table, a little above the finger so it stays in sight, and smaller the further the finger is
    // from the middle
    func placeSwipePill(_ pill: UIButton, near point: CGPoint, progress: CGFloat) {
        let size = pill.systemLayoutSizeFitting(CGSize(width: 0, height: self.cornerButtonSize))
        let safe = self.view.bounds.inset(by: self.view.safeAreaInsets)
        let y = min(max(point.y - 80, safe.minY + size.height / 2 + 8), safe.maxY - size.height / 2 - 8)
        pill.bounds = CGRect(origin: .zero, size: CGSize(width: size.width, height: self.cornerButtonSize))
        pill.center = CGPoint(x: self.view.bounds.midX, y: y)
        let scale = 0.6 + 0.4 * progress
        pill.transform = CGAffineTransform(scaleX: scale, y: scale)
        pill.layer.opacity = Float(0.25 + 0.75 * progress)
    }

    // Pops the pill when the swipe did its job, and fades it either way
    func dismissSwipePill(done: Bool) {
        guard let pill = self.swipePill else {
            return
        }
        self.swipePill = nil
        self.swipeArmed = false
        let grow = done && !UIAccessibility.isReduceMotionEnabled
        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState]) {
            pill.alpha = 0
            pill.transform = grow ? CGAffineTransform(scaleX: 1.2, y: 1.2) : CGAffineTransform(scaleX: 0.6, y: 0.6)
        } completion: { _ in
            pill.removeFromSuperview()
        }
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
