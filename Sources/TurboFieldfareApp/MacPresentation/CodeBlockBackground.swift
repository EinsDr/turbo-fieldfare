import AppKit
import Foundation

/// Gives each fenced code block a single full-width tinted panel instead of a
/// ragged highlight that stops at the end of each line.
///
/// A contiguous run of code paragraphs must share one `NSTextBlock` instance,
/// otherwise every line draws its own panel with seams between them.
@MainActor
enum CodeBlockBackground {

    static func apply(to text: NSMutableAttributedString) {
        var ranges: [NSRange] = []
        text.enumerateAttribute(
            .paragraphStyle,
            in: NSRange(location: 0, length: text.length)
        ) { value, range, _ in
            guard let style = value as? NSParagraphStyle,
                  style.firstLineHeadIndent == 10,
                  style.headIndent == 10 else { return }
            if let last = ranges.last, last.upperBound == range.location {
                ranges[ranges.count - 1] = NSRange(
                    location: last.location,
                    length: last.length + range.length)
            } else {
                ranges.append(range)
            }
        }

        for range in ranges {
            let panel = NSTextBlock()
            panel.backgroundColor = tint
            panel.setWidth(10, type: .absoluteValueType, for: .padding)
            panel.setWidth(6, type: .absoluteValueType, for: .margin)
            panel.setWidth(1, type: .absoluteValueType, for: .border)
            panel.setBorderColor(NSColor.separatorColor)

            text.enumerateAttribute(.paragraphStyle, in: range) { value, sub, _ in
                guard let existing = value as? NSParagraphStyle,
                      let style = existing.mutableCopy() as? NSMutableParagraphStyle
                else { return }
                style.textBlocks = [panel]
                style.firstLineHeadIndent = 0
                style.headIndent = 0
                style.tailIndent = 0
                style.paragraphSpacing = 0
                style.paragraphSpacingBefore = 0
                text.addAttribute(.paragraphStyle, value: style, range: sub)
            }
        }
    }

    private static var tint: NSColor {
        NSColor.textBackgroundColor.blended(withFraction: 0.10, of: NSColor.labelColor)
            ?? NSColor.controlBackgroundColor
    }
}
