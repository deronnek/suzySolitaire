//
//  HowToPlayViewController.swift
//  Suze Solitaire
//

import UIKit

// Shows the rules as a numbered list that wraps to the screen width and scrolls.
class HowToPlayViewController: UIViewController {

    static let rules = [
        "Cards must alternate colors in the lower four stacks and count down.",
        "Cards must be of the same suit in the upper four stacks and count up.",
        "Tap the deck to get three cards at a time.",
        "There are 13 face-up cards above the deck (the \"blind\").",
        "A King is \"below\" an Ace, and a Two is \"above\" an Ace.",
        "Upper stacks must start with the card dealt.",
        "Empty lower stacks may only be filled with cards from the blind.",
        "If the blind is empty, gaps may be filled with a card that is one below the card dealt to the upper stack.",
        "$5 is awarded for each card placed in an upper stack.",
        "Winning the game gains you $250.",
        "Auto moves any available card to an upper stack.",
        "Auto moves *cannot* be undone, unless you have Unlimited Undo.",
        "Swipe in from the left edge to the middle to undo, or from the right edge for a hint.",
    ]

    let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "How to Play"
        self.view.backgroundColor = .systemBackground

        self.textView.isEditable   = false
        self.textView.isSelectable = false
        self.textView.backgroundColor    = .clear
        self.textView.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 20, right: 20)
        self.textView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.textView)
        NSLayoutConstraint.activate([
            self.textView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.textView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.textView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
            self.textView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
        ])

        self.textView.attributedText = HowToPlayViewController.rulesText()
        // Rebuild the text if the user changes their preferred text size
        self.registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.textView.attributedText = HowToPlayViewController.rulesText()
        }
    }

    static func rulesText() -> NSAttributedString {
        let font = UIFont.preferredFont(forTextStyle: .body)

        // Hang wrapped lines under the rule text rather than under its number
        let indent = ceil(("00." as NSString).size(withAttributes: [.font: font]).width) + 10
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops         = [NSTextTab(textAlignment: .left, location: indent)]
        paragraph.headIndent       = indent
        paragraph.lineSpacing      = 2
        paragraph.paragraphSpacing = font.lineHeight * 0.6

        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: paragraph]
        let boldFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
        let text = NSMutableAttributedString()
        for (i, rule) in rules.enumerated() {
            text.append(NSAttributedString(string: (i == 0 ? "" : "\n") + "\(i + 1).\t", attributes: attributes))
            // Words between *asterisks* are shown in bold
            for (j, piece) in rule.components(separatedBy: "*").enumerated() {
                let piece = NSMutableAttributedString(string: piece, attributes: attributes)
                if j % 2 == 1 {
                    piece.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: piece.length))
                }
                text.append(piece)
            }
        }
        return text
    }
}
