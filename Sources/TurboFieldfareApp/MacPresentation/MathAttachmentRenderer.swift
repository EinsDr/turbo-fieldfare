import AppKit
import Foundation
import SwiftMath

/// Replaces the sentinels left by `MathSpanExtractor` with typeset math,
/// rendered by SwiftMath into images carried as text attachments.
///
/// If an expression fails to parse, its original LaTeX source is restored
/// rather than dropped, so a malformed formula never costs you the text.
@MainActor
enum MathAttachmentRenderer {

    private static var cache: [String: NSImage] = [:]

    static func substitute(
        _ spans: [MathSpan],
        in text: NSMutableAttributedString,
        fontSize: CGFloat
    ) {
        guard !spans.isEmpty else { return }

        for (index, span) in spans.enumerated() {
            let token = MathSpanExtractor.sentinel(index)
            let range = (text.string as NSString).range(of: token)
            guard range.location != NSNotFound else { continue }

            let attributes = text.attributes(at: range.location, effectiveRange: nil)
            let replacement = attachment(for: span, fontSize: fontSize)
                ?? NSAttributedString(string: span.latex, attributes: attributes)
            text.replaceCharacters(in: range, with: replacement)
        }
    }

    private static func attachment(
        for span: MathSpan,
        fontSize: CGFloat
    ) -> NSAttributedString? {
        let math = MTMathImage(
            latex: span.latex,
            fontSize: span.isDisplay ? fontSize * 1.3 : fontSize,
            textColor: NSColor.labelColor,
            labelMode: span.isDisplay ? .display : .text,
            textAlignment: .left)

        let key = "\(span.isDisplay)|\(fontSize)|\(span.latex)"
        let cached = cache[key]
        let (error, produced) = cached == nil ? math.asImage() : (nil, cached)
        guard error == nil, let image = produced, image.size.width > 0 else { return nil }
        if cached == nil {
            if cache.count > 256 { cache.removeAll() }
            cache[key] = image
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(
            x: 0,
            y: span.isDisplay ? 0 : -(image.size.height / 2) + fontSize * 0.32,
            width: image.size.width,
            height: image.size.height)
        return NSAttributedString(attachment: attachment)
    }
}
