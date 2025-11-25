import SwiftUI
#if os(iOS)
import UIKit
#endif

struct LinedTextEditor: View {
    @Binding var text: String
    var fontSize: CGFloat
    var lineSpacing: CGFloat

    var body: some View {
        #if os(iOS)
        LinedTextViewRepresentable(text: $text, font: .systemFont(ofSize: fontSize), lineSpacing: lineSpacing)
        #else
        TextEditor(text: $text)
            .font(.system(size: fontSize))
        #endif
    }
}

#if os(iOS)
struct LinedTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont
    var lineSpacing: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.textContainerInset = .zero
        textView.contentInset = .zero
        textView.autocorrectionType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no

        applyAttributes(to: text, textView: textView)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let fontChanged = context.coordinator.lastAppliedFont != font
        let lineSpacingChanged = context.coordinator.lastAppliedLineSpacing != lineSpacing

        if uiView.text != text || fontChanged || lineSpacingChanged {
            let selectedRange = uiView.selectedRange
            applyAttributes(to: text, textView: uiView)
            uiView.selectedRange = selectedRange
        }

        // Ensure typingAttributes updated if font or line spacing changed
        if fontChanged || lineSpacingChanged {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = lineSpacing
            uiView.typingAttributes = [
                .font: font,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: UIColor.label
            ]
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: LinedTextViewRepresentable
        var lastAppliedFont: UIFont
        var lastAppliedLineSpacing: CGFloat

        init(parent: LinedTextViewRepresentable) {
            self.parent = parent
            self.lastAppliedFont = parent.font
            self.lastAppliedLineSpacing = parent.lineSpacing
        }

        func textViewDidChange(_ textView: UITextView) {
            if parent.text != textView.text {
                parent.text = textView.text
            }
        }
    }

    private func applyAttributes(to text: String, textView: UITextView) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: style,
            .foregroundColor: UIColor.label
        ]
        textView.attributedText = NSAttributedString(string: text, attributes: attributes)
        textView.typingAttributes = attributes

        if let coordinator = textView.delegate as? Coordinator {
            coordinator.lastAppliedFont = font
            coordinator.lastAppliedLineSpacing = lineSpacing
        }
    }
}
#endif
