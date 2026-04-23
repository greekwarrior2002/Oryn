import SwiftUI
import UIKit

/// A UITextView-backed SwiftUI control that highlights date, time, and priority
/// keywords inline as the user types — visually similar to how iMessage flags
/// phone numbers and dates. Designed specifically for the Inbox-first quick
/// capture flow.
///
/// - Fully native `UITextView` so cursor, selection, autocorrect, and
///   predictive text all behave as iOS users expect.
/// - Attributes are re-applied after every change while preserving the caret
///   position and selection range.
/// - Uses `UIColor` tinting so highlight colors adapt to the current trait
///   collection (light/dark).
struct HighlightedTaskField: UIViewRepresentable {

    @Binding var text: String
    var detections: [TaskDetection]
    var onSubmit: () -> Void
    var placeholder: String = "What's on your mind?"
    var isFocused: Bool

    func makeUIView(context: Context) -> UITextView {
        let tv = PaddedTextView()
        tv.delegate = context.coordinator
        tv.font = .systemFont(ofSize: 22, weight: .regular)
        tv.textColor = UIColor.label
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.returnKeyType = .done
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainerInset = .zero
        tv.autocorrectionType = .yes
        tv.smartDashesType = .yes
        tv.smartQuotesType = .yes
        tv.adjustsFontForContentSizeCategory = true

        // Placeholder label
        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.font = tv.font
        placeholderLabel.textColor = UIColor.tertiaryLabel
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        tv.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: tv.topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: tv.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: tv.trailingAnchor),
        ])
        context.coordinator.placeholderLabel = placeholderLabel
        placeholderLabel.isHidden = !text.isEmpty

        applyText(tv, text: text, detections: detections)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Avoid stomping on edits from the user — compare by raw string.
        if uiView.text != text {
            applyText(uiView, text: text, detections: detections)
        } else {
            // Text is the same but detections may have changed — reapply attributes.
            reapplyAttributes(uiView, detections: detections)
        }
        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty

        // Focus management
        if isFocused && !uiView.isFirstResponder {
            DispatchQueue.main.async { uiView.becomeFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: Attribute application

    private func applyText(_ tv: UITextView, text: String, detections: [TaskDetection]) {
        let selected = tv.selectedRange
        tv.attributedText = Self.makeAttributed(text: text, detections: detections, font: tv.font)
        // Restore selection where possible
        let clampedLoc = min(selected.location, tv.text.utf16.count)
        tv.selectedRange = NSRange(location: clampedLoc, length: 0)
    }

    private func reapplyAttributes(_ tv: UITextView, detections: [TaskDetection]) {
        let selected = tv.selectedRange
        tv.attributedText = Self.makeAttributed(text: tv.text ?? "", detections: detections, font: tv.font)
        let clampedLoc = min(selected.location, tv.text.utf16.count)
        tv.selectedRange = NSRange(location: clampedLoc, length: 0)
    }

    static func makeAttributed(text: String, detections: [TaskDetection], font: UIFont?) -> NSAttributedString {
        let base = font ?? .systemFont(ofSize: 22, weight: .regular)
        let attr = NSMutableAttributedString(string: text, attributes: [
            .font: base,
            .foregroundColor: UIColor.label
        ])
        let ns = text as NSString
        for det in detections {
            guard det.range.location != NSNotFound,
                  det.range.location + det.range.length <= ns.length else { continue }
            let color = color(for: det.kind)
            let weight = UIFontDescriptor.SymbolicTraits.traitBold
            let boldFont: UIFont = {
                if let desc = base.fontDescriptor.withSymbolicTraits(weight) {
                    return UIFont(descriptor: desc, size: base.pointSize)
                }
                return .systemFont(ofSize: base.pointSize, weight: .semibold)
            }()
            attr.addAttributes([
                .foregroundColor: color,
                .font: boldFont
            ], range: det.range)
        }
        return attr
    }

    private static func color(for kind: TaskDetection.Kind) -> UIColor {
        switch kind {
        case .date:     return UIColor(named: "AccentColor") ?? .systemBlue
        case .time:     return UIColor.systemTeal
        case .priority: return UIColor.systemOrange
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: HighlightedTaskField
        weak var placeholderLabel: UILabel?

        init(_ parent: HighlightedTaskField) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            placeholderLabel?.isHidden = !(textView.text ?? "").isEmpty
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                parent.onSubmit()
                return false
            }
            return true
        }
    }

    // MARK: - Custom text view

    private final class PaddedTextView: UITextView {
        override var intrinsicContentSize: CGSize {
            let size = sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
            return CGSize(width: UIView.noIntrinsicMetric, height: max(size.height, 36))
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            invalidateIntrinsicContentSize()
        }
    }
}
