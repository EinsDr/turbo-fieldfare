import AppKit
import Foundation

/// A Markdown table carried through parsing as structured data rather than
/// flattened to text, so it can be laid out with a real `NSTextTable`.
struct MarkdownTable {
    enum Alignment { case left, center, right }
    /// Row 0 is the header.
    let rows: [[String]]
    let alignments: [Alignment]
}

/// Replaces the sentinels left by `ResponseMarkdownPreprocessor` with tables
/// built from `NSTextTable`, giving real cell borders, padding and alignment.
///
/// Requires a TextKit 1 layout stack; TextKit 2 ignores text blocks entirely.
@MainActor
enum TextTableRenderer {

    /// Cells carry inline Markdown - links, bold, code - so they are
    /// parsed rather than inserted as literal text.
    private static let cellRenderer = ResponseMarkdownRenderer()

    nonisolated static func sentinel(_ index: Int) -> String {
        "\u{E002}\(index)\u{E003}"
    }

    static func substitute(_ tables: [MarkdownTable], in text: NSMutableAttributedString) {
        guard !tables.isEmpty else { return }
        for (index, table) in tables.enumerated() {
            let range = (text.string as NSString).range(of: sentinel(index))
            guard range.location != NSNotFound else { continue }
            text.replaceCharacters(in: range, with: attributed(table))
        }
    }

    private static func attributed(_ table: MarkdownTable) -> NSAttributedString {
        let columnCount = max(table.alignments.count, 1)

        let layout = NSTextTable()
        layout.numberOfColumns = columnCount
        layout.layoutAlgorithm = .automaticLayoutAlgorithm
        layout.collapsesBorders = true
        layout.hidesEmptyCells = false

        let output = NSMutableAttributedString()

        for (rowIndex, row) in table.rows.enumerated() {
            for column in 0..<columnCount {
                let block = NSTextTableBlock(
                    table: layout,
                    startingRow: rowIndex,
                    rowSpan: 1,
                    startingColumn: column,
                    columnSpan: 1)
                block.setBorderColor(NSColor.separatorColor)
                block.setWidth(1, type: .absoluteValueType, for: .border)
                block.setWidth(7, type: .absoluteValueType, for: .padding)
                if rowIndex == 0 {
                    block.backgroundColor = NSColor.unemphasizedSelectedContentBackgroundColor
                }

                let style = NSMutableParagraphStyle()
                style.textBlocks = [block]
                style.lineSpacing = 2
                switch table.alignments[min(column, table.alignments.count - 1)] {
                case .left: style.alignment = .left
                case .center: style.alignment = .center
                case .right: style.alignment = .right
                }

                let font: NSFont = rowIndex == 0
                    ? .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
                    : .systemFont(ofSize: NSFont.systemFontSize)

                let text = column < row.count ? row[column] : ""
                let rendered = NSMutableAttributedString(
                    attributedString: cellRenderer.render(text).attributedString)
                let whole = NSRange(location: 0, length: rendered.length)
                if rendered.length > 0 {
                    rendered.addAttribute(.paragraphStyle, value: style, range: whole)
                    if rowIndex == 0 {
                        rendered.enumerateAttribute(.font, in: whole) { value, range, _ in
                            let base = (value as? NSFont)
                                ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                            rendered.addAttribute(
                                .font,
                                value: NSFontManager.shared.convert(
                                    base, toHaveTrait: .boldFontMask),
                                range: range)
                        }
                    }
                }
                rendered.append(NSAttributedString(
                    string: "\n",
                    attributes: [
                        .paragraphStyle: style,
                        .font: font,
                        .foregroundColor: NSColor.labelColor,
                    ]))
                output.append(rendered)
            }
        }
        return output
    }
}
