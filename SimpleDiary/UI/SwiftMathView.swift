import SwiftUI
import AppKit
import SwiftMath

/*
 NOTE:
 MTMathUILabel does not report a usable intrinsicContentSize on macOS
 (often returns -1,-1). SwiftUI therefore collapses the view unless an
 explicit height is provided.

 This file intentionally measures the rendered height after layout and
 feeds it back into SwiftUI via minHeight.

 Do NOT replace this with intrinsicContentSize or sizeThatFits unless
 SwiftMath changes its macOS sizing behavior.
*/

/// SwiftUI view that renders a SwiftMath display block and allocates correct height in SwiftUI.
///
/// This uses a measured-height bridge on macOS because MTMathUILabel doesn't provide a usable
/// intrinsicContentSize to SwiftUI (often reports -1/-1).
struct SwiftMathBlock: View {
    let latex: String
    var fontSize: CGFloat
    var foregroundColor: Color = .primary

    @State private var measuredHeight: CGFloat = 24

    var body: some View {
        SwiftMathMeasuredNSView(
            latex: latex,
            fontSize: fontSize,
            foregroundColor: foregroundColor,
            measuredHeight: $measuredHeight
        )
        .frame(maxWidth: .infinity, minHeight: measuredHeight, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private final class SwiftMathContainerView: NSView {
    let label = MTMathUILabel()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        label.translatesAutoresizingMaskIntoConstraints = false
//        label.backgroundColor = .clear
        label.textAlignment = .center
        label.labelMode = .display
        label.contentInsets = .zero

        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private struct SwiftMathMeasuredNSView: NSViewRepresentable {
    let latex: String
    let fontSize: CGFloat
    let foregroundColor: Color
    @Binding var measuredHeight: CGFloat

    final class Coordinator {
        var lastHeight: CGFloat = 0
        var pending = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SwiftMathContainerView {
        SwiftMathContainerView()
    }

    func updateNSView(_ nsView: SwiftMathContainerView, context: Context) {
        let label = nsView.label
        label.fontSize = fontSize
        label.textColor = NSColor(foregroundColor)
        label.latex = latex

        // Avoid scheduling multiple measurements per runloop tick.
        guard !context.coordinator.pending else { return }
        context.coordinator.pending = true

        DispatchQueue.main.async {
            context.coordinator.pending = false

            nsView.needsLayout = true
            nsView.layoutSubtreeIfNeeded()

            // Give SwiftMath a width to lay out against; first pass can be 0.
            let width = max(nsView.bounds.width, 300)

            // Ensure the label is measured with the intended width.
            label.setFrameSize(NSSize(width: width, height: 10))
            label.needsLayout = true
            label.layoutSubtreeIfNeeded()

            let newHeight = max(12, label.fittingSize.height)

            if abs(context.coordinator.lastHeight - newHeight) > 0.5 {
                context.coordinator.lastHeight = newHeight
                self.measuredHeight = newHeight
            }
        }
    }
}

extension MTEdgeInsets {
    static var zero: MTEdgeInsets { .init(top: 0, left: 0, bottom: 0, right: 0) }
}
