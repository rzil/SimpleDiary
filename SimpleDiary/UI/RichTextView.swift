import SwiftUI
import Combine

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct RichTextView: View {
    @Binding private var text: String
    private var highlights: [NSRange]
    @Binding private var selectedRange: NSRange?

    private var font: Font = .system(size: 17)

    public init(text: Binding<String>, highlights: [NSRange] = [], selectedRange: Binding<NSRange?> = .constant(nil)) {
        self._text = text
        self.highlights = highlights
        self._selectedRange = selectedRange
    }

    public var body: some View {
        Representable(text: $text, highlights: highlights, selectedRange: $selectedRange, font: font)
            .environment(\.font, font)
    }
}

public extension RichTextView {
    func font(_ font: Font) -> RichTextView {
        var copy = self
        copy.font = font
        return copy
    }
}

private extension RichTextView {
    #if os(iOS) || os(tvOS)
    struct Representable: UIViewRepresentable {
        @Binding var text: String
        let highlights: [NSRange]
        @Binding var selectedRange: NSRange?
        var font: Font

        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }

        func makeUIView(context: Context) -> UITextView {
            let tv = UITextView()
            tv.delegate = context.coordinator
            tv.isEditable = true
            tv.isSelectable = true
            tv.isScrollEnabled = true
            tv.alwaysBounceVertical = true
            tv.backgroundColor = .clear
            tv.textContainerInset = .zero
            tv.textContainer.lineFragmentPadding = 0

            tv.smartDashesType = .no
            tv.smartQuotesType = .no
            tv.autocorrectionType = .yes
            tv.spellCheckingType = .yes

            tv.keyboardDismissMode = .interactive

            tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            // Initial font setup
            updateFont(tv, font: font)

            // Set initial text with highlights applied
            updateText(tv, text: text, highlights: highlights, font: font)

            return tv
        }

        func updateUIView(_ uiView: UITextView, context: Context) {
            context.coordinator.parent = self

            // Update font if changed
            updateFont(uiView, font: font)

            // Synchronize text if changed, preserving selection and marked text
            if uiView.text != text {
                // try to preserve selectedRange and range of marked text
                if let markedRange = uiView.markedTextRange {
                    // There is active composition, update underlying text but do not reset textView text to avoid breaking IME
                    // We still sync binding text with what's typed by user so ignore updating textView text here
                } else {
                    // No active composition, update attributedText with highlights and font, preserving selection
                    // Save selection
                    let origSelectedRange = uiView.selectedRange

                    updateText(uiView, text: text, highlights: highlights, font: font)

                    // Restore selection if valid
                    if let selected = selectedRange, NSLocationInRange(selected.location, NSRange(location: 0, length: uiView.text.count)) && NSLocationInRange(selected.location + selected.length, NSRange(location: 0, length: uiView.text.count+1)) {
                        uiView.selectedRange = selected
                    } else {
                        // Restore previous selection if possible
                        uiView.selectedRange = origSelectedRange
                    }
                }
            } else {
                // Text unchanged, but highlights or font may have changed
                // Rebuild attributed string if needed preserving selection and marked text state
                // We rebuild attributed string only if highlights or font changed (always do for simplicity)
                if let markedRange = uiView.markedTextRange {
                    // Don't touch text while IME composing
                } else {
                    let origSelectedRange = uiView.selectedRange
                    updateText(uiView, text: text, highlights: highlights, font: font)
                    uiView.selectedRange = origSelectedRange
                }
            }

            // Handle programmatic selectedRange from binding
            if let sel = selectedRange {
                let validRange = NSRange(location: 0, length: uiView.text.count)
                if NSLocationInRange(sel.location, validRange), NSLocationInRange(sel.location + sel.length, NSRange(location: 0, length: uiView.text.count + 1)) {
                    if uiView.markedTextRange == nil {
                        if uiView.selectedRange != sel {
                            uiView.selectedRange = sel
                            uiView.scrollRangeToVisible(sel)
                        }
                    }
                }
            }
        }

        private func updateFont(_ tv: UITextView, font: Font) {
            let uiFont = font.toUIFont()
            guard let uiFont = uiFont else { return }
            if tv.font != uiFont {
                tv.font = uiFont
            }
            // Update typingAttributes with font
            var attr = tv.typingAttributes
            attr[.font] = uiFont
            tv.typingAttributes = attr
        }

        private func updateText(_ tv: UITextView, text: String, highlights: [NSRange], font: Font) {
            let uiFont = font.toUIFont() ?? UIFont.systemFont(ofSize: 17)
            let attrString = NSMutableAttributedString(string: text, attributes: [.font: uiFont])
            let fullRange = NSRange(location: 0, length: attrString.length)
            // Clear existing background colors in range
            attrString.removeAttribute(.backgroundColor, range: fullRange)
            // Apply highlights with subtle yellow background
            for range in highlights {
                if NSIntersectionRange(range, fullRange).length == range.length {
                    attrString.addAttribute(.backgroundColor, value: UIColor(red: 1, green: 1, blue: 0, alpha: 0.3), range: range)
                }
            }

            // Preserve selectedRange and markedTextRange as much as possible
            let selectedRangeBefore = tv.selectedRange
            let markedRangeBefore = tv.markedTextRange

            // Only update if attributedText is different to prevent caret jump
            if tv.attributedText != attrString {
                tv.attributedText = attrString
                // Restore selection
                tv.selectedRange = selectedRangeBefore
                // Marked text cannot be restored here as setting attributedText clears it
            }
        }

        final class Coordinator: NSObject, UITextViewDelegate {
            var parent: Representable

            init(parent: Representable) {
                self.parent = parent
            }

            func textViewDidChange(_ textView: UITextView) {
                if let markedRange = textView.markedTextRange, textView.position(from: markedRange.start, offset: 0) != nil {
                    // IME composing, do not update text binding yet
                    return
                }
                if parent.text != textView.text {
                    DispatchQueue.main.async {
                        self.parent.text = textView.text
                    }
                }
            }

            func textViewDidChangeSelection(_ textView: UITextView) {
                if textView.markedTextRange != nil {
                    // IME composing; do not update selection binding
                    return
                }

                let currentSelected = textView.selectedRange
                if parent.selectedRange != currentSelected {
                    DispatchQueue.main.async {
                        self.parent.selectedRange = currentSelected
                    }
                }
            }

            func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
                // Disabling smart dashes and quotes already set on the UITextView
                return true
            }
        }
    }
    #elseif os(macOS)
    struct Representable: NSViewRepresentable {
        @Binding var text: String
        let highlights: [NSRange]
        @Binding var selectedRange: NSRange?
        var font: Font

        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }

        func makeNSView(context: Context) -> NSScrollView {
            let textView = NSTextView()
            textView.delegate = context.coordinator
            textView.isEditable = true
            textView.isSelectable = true
            textView.isRichText = false
            textView.importsGraphics = false
            textView.allowsUndo = true
            textView.usesFindPanel = true
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isContinuousSpellCheckingEnabled = true
            textView.textContainerInset = .zero
            textView.textContainer?.lineFragmentPadding = 0

            let scrollView = NSScrollView()
            scrollView.documentView = textView
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.drawsBackground = false
            scrollView.autohidesScrollers = true
            scrollView.borderType = .noBorder

            updateFont(textView, font: font)
            updateText(textView, text: text, highlights: highlights, font: font)

            return scrollView
        }

        func updateNSView(_ nsView: NSScrollView, context: Context) {
            context.coordinator.parent = self
            guard let textView = nsView.documentView as? NSTextView else { return }

            updateFont(textView, font: font)

            if textView.string != text {
                if !textView.hasMarkedText() {
                    let origSelectedRange = textView.selectedRange()
                    updateText(textView, text: text, highlights: highlights, font: font)
                    if let sel = selectedRange {
                        let validRange = NSRange(location: 0, length: textView.string.count)
                        if NSLocationInRange(sel.location, validRange), NSLocationInRange(sel.location + sel.length, NSRange(location: 0, length: textView.string.count + 1)) {
                            textView.setSelectedRange(sel)
                        } else {
                            textView.setSelectedRange(origSelectedRange)
                        }
                    } else {
                        textView.setSelectedRange(origSelectedRange)
                    }
                }
            } else {
                // Text unchanged: rebuild attributed string if highlights or font changed preserving selection
                if !textView.hasMarkedText() {
                    let origSelectedRange = textView.selectedRange()
                    updateText(textView, text: text, highlights: highlights, font: font)
                    textView.setSelectedRange(origSelectedRange)
                }
            }

            if let sel = selectedRange {
                let validRange = NSRange(location: 0, length: textView.string.count)
                if NSLocationInRange(sel.location, validRange), NSLocationInRange(sel.location + sel.length, NSRange(location: 0, length: textView.string.count + 1)) {
                    if !textView.hasMarkedText() {
                        if textView.selectedRange() != sel {
                            textView.setSelectedRange(sel)
                            scrollRangeToVisible(textView: textView, range: sel)
                        }
                    }
                }
            }
        }

        private func scrollRangeToVisible(textView: NSTextView, range: NSRange) {
            textView.scrollRangeToVisible(range)
            if let scrollView = textView.enclosingScrollView {
                let rect = textView.boundingRect(for: range)
                scrollView.contentView.scrollToVisible(rect)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }

        private func updateFont(_ textView: NSTextView, font: Font) {
            let nsFont = font.toNSFont()
            guard let nsFont = nsFont else { return }
            if textView.font != nsFont {
                textView.font = nsFont
            }
            var typingAttributes = textView.typingAttributes
            typingAttributes[.font] = nsFont
            textView.typingAttributes = typingAttributes
        }

        private func updateText(_ textView: NSTextView, text: String, highlights: [NSRange], font: Font) {
            let nsFont = font.toNSFont() ?? NSFont.systemFont(ofSize: 17)
            let attrString = NSMutableAttributedString(string: text, attributes: [.font: nsFont])
            let fullRange = NSRange(location: 0, length: attrString.length)
            attrString.removeAttribute(.backgroundColor, range: fullRange)

            for range in highlights {
                if NSIntersectionRange(range, fullRange).length == range.length {
                    let highlightColor = NSColor(calibratedRed: 1, green: 1, blue: 0, alpha: 0.3)
                    attrString.addAttribute(.backgroundColor, value: highlightColor, range: range)
                }
            }

            let origSelectedRange = textView.selectedRange()
            // Setting attributedString resets hasMarkedText, so avoid if user is composing
            if !textView.hasMarkedText() {
                if textView.textStorage?.string != attrString.string || textView.attributedString() != attrString {
                    textView.textStorage?.setAttributedString(attrString)
                    textView.setSelectedRange(origSelectedRange)
                }
            }
        }

        final class Coordinator: NSObject, NSTextViewDelegate {
            var parent: Representable

            init(parent: Representable) {
                self.parent = parent
            }

            func textDidChange(_ notification: Notification) {
                guard let textView = notification.object as? NSTextView else { return }
                if textView.hasMarkedText() {
                    // IME composing, do not update binding text yet
                    return
                }
                let newText = textView.string
                if parent.text != newText {
                    DispatchQueue.main.async {
                        self.parent.text = newText
                    }
                }
            }

            func textViewDidChangeSelection(_ notification: Notification) {
                guard let textView = notification.object as? NSTextView else { return }
                if textView.hasMarkedText() {
                    // IME composing; do not update selectedRange binding
                    return
                }
                let currentSel = textView.selectedRange()
                if parent.selectedRange != currentSel {
                    DispatchQueue.main.async {
                        self.parent.selectedRange = currentSel
                    }
                }
            }
        }
    }
    #endif
}

private extension Font {
    #if os(iOS) || os(tvOS)
    func toUIFont() -> UIFont? {
        // Use UIFontMetrics and UIFontDescriptor for better matching
        let uiFont: UIFont
        switch self {
        case .largeTitle:
            uiFont = UIFont.preferredFont(forTextStyle: .largeTitle)
        case .title:
            uiFont = UIFont.preferredFont(forTextStyle: .title1)
        case .title2:
            uiFont = UIFont.preferredFont(forTextStyle: .title2)
        case .title3:
            uiFont = UIFont.preferredFont(forTextStyle: .title3)
        case .headline:
            uiFont = UIFont.preferredFont(forTextStyle: .headline)
        case .subheadline:
            uiFont = UIFont.preferredFont(forTextStyle: .subheadline)
        case .callout:
            uiFont = UIFont.preferredFont(forTextStyle: .callout)
        case .caption:
            uiFont = UIFont.preferredFont(forTextStyle: .caption1)
        case .caption2:
            uiFont = UIFont.preferredFont(forTextStyle: .caption2)
        case .footnote:
            uiFont = UIFont.preferredFont(forTextStyle: .footnote)
        default:
            // Try to extract size
            let mirror = Mirror(reflecting: self)
            if let size = mirror.descendant("provider", "base", "size") as? CGFloat {
                uiFont = UIFont.systemFont(ofSize: size)
            } else {
                uiFont = UIFont.systemFont(ofSize: 17)
            }
        }
        return uiFont
    }
    #elseif os(macOS)
    func toNSFont() -> NSFont? {
        // NSFont conversions from Font are limited; use default 17 if not standard
        switch self {
        case .largeTitle:
            return NSFont.systemFont(ofSize: 34, weight: .regular)
        case .title:
            return NSFont.systemFont(ofSize: 28, weight: .regular)
        case .title2:
            return NSFont.systemFont(ofSize: 22, weight: .regular)
        case .title3:
            return NSFont.systemFont(ofSize: 20, weight: .regular)
        case .headline:
            return NSFont.systemFont(ofSize: 17, weight: .semibold)
        case .subheadline:
            return NSFont.systemFont(ofSize: 15, weight: .regular)
        case .callout:
            return NSFont.systemFont(ofSize: 16, weight: .regular)
        case .caption:
            return NSFont.systemFont(ofSize: 13, weight: .regular)
        case .caption2:
            return NSFont.systemFont(ofSize: 11, weight: .regular)
        case .footnote:
            return NSFont.systemFont(ofSize: 13, weight: .regular)
        default:
            // Try extract size
            let mirror = Mirror(reflecting: self)
            if let size = mirror.descendant("provider", "base", "size") as? CGFloat {
                return NSFont.systemFont(ofSize: size)
            }
            return NSFont.systemFont(ofSize: 17)
        }
    }
    #endif
}

#if os(macOS)
private extension NSTextView {
    func boundingRect(for range: NSRange) -> NSRect {
        guard let layoutManager = self.layoutManager,
              let textContainer = self.textContainer else {
            return .zero
        }
        var glyphRange = NSRange()
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: range, in: textContainer)
        // convert rect from text container coordinates to view coordinates
        let containerOrigin = self.textContainerOrigin
        return boundingRect.offsetBy(dx: containerOrigin.x, dy: containerOrigin.y)
    }
}
#endif
