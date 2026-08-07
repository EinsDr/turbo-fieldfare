import Foundation

/// Rewrites Markdown that `AttributedString(markdown:)` cannot represent into
/// equivalents it can, so a single unsupported element no longer forces the
/// whole response back to raw text.
///
/// - Tables become aligned monospace code blocks.
/// - Images become ordinary links, preserving the alt text.
/// - Fenced code is never rewritten.
enum ResponseMarkdownPreprocessor {

    static func prepare(_ source: String) -> String {
        let lines = source.components(separatedBy: "\n")
        var output: [String] = []
        var index = 0
        var insideFence = false

        while index < lines.count {
            let line = lines[index]

            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                insideFence.toggle()
                output.append(line)
                index += 1
                continue
            }
            if insideFence {
                output.append(line)
                index += 1
                continue
            }
            if let end = tableEnd(in: lines, startingAt: index) {
                output.append(contentsOf: renderTable(Array(lines[index..<end])))
                index = end
                continue
            }
            output.append(convertImages(in: line))
            index += 1
        }
        return output.joined(separator: "\n")
    }

    /// A copy with fenced blocks and inline code spans removed, used only to
    /// test whether the remaining prose contains something unrenderable.
    static func strippingCode(_ source: String) -> String {
        var output: [String] = []
        var insideFence = false
        for line in source.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                insideFence.toggle()
                continue
            }
            guard !insideFence else { continue }
            output.append(line.replacingOccurrences(
                of: "`[^`]*`",
                with: " ",
                options: .regularExpression))
        }
        return output.joined(separator: "\n")
    }

    private static func isDelimiterRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|"), trimmed.contains("-") else { return false }
        return trimmed.range(of: "^[ \t|:-]+$", options: .regularExpression) != nil
    }

    private static func tableEnd(in lines: [String], startingAt start: Int) -> Int? {
        guard start + 1 < lines.count,
              lines[start].contains("|"),
              isDelimiterRow(lines[start + 1]) else { return nil }
        var end = start + 2
        while end < lines.count,
              lines[end].contains("|"),
              !lines[end].trimmingCharacters(in: .whitespaces).isEmpty {
            end += 1
        }
        return end
    }

    private static func cells(in line: String) -> [String] {
        var parts = line.components(separatedBy: "|")
        if let first = parts.first,
           first.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.removeFirst()
        }
        if let last = parts.last,
           last.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.removeLast()
        }
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func pad(_ text: String, to width: Int) -> String {
        text + String(repeating: " ", count: max(0, width - text.count))
    }

    private static func renderTable(_ lines: [String]) -> [String] {
        var rows: [[String]] = []
        for (offset, line) in lines.enumerated() where offset != 1 {
            rows.append(cells(in: line))
        }
        guard let columnCount = rows.map(\.count).max(), columnCount > 0 else {
            return lines
        }
        for index in rows.indices {
            while rows[index].count < columnCount { rows[index].append("") }
        }

        var widths = [Int](repeating: 0, count: columnCount)
        for row in rows {
            for (column, cell) in row.enumerated() {
                widths[column] = max(widths[column], cell.count)
            }
        }

        var result = ["```"]
        for (offset, row) in rows.enumerated() {
            var text = ""
            for (column, cell) in row.enumerated() {
                text += pad(cell, to: widths[column])
                if column < columnCount - 1 { text += "  " }
            }
            while text.hasSuffix(" ") { text.removeLast() }
            result.append(text)

            if offset == 0 {
                var rule = ""
                for (column, width) in widths.enumerated() {
                    rule += String(repeating: "-", count: width)
                    if column < columnCount - 1 { rule += "  " }
                }
                result.append(rule)
            }
        }
        result.append("```")
        return result
    }

    private static func convertImages(in line: String) -> String {
        let withoutEmptyAlt = line.replacingOccurrences(
            of: #"!\[[ \t]*\]\(([^\)]*)\)"#,
            with: "[image]($1)",
            options: .regularExpression)
        return withoutEmptyAlt.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^\)]*)\)"#,
            with: "[$1]($2)",
            options: .regularExpression)
    }
}
