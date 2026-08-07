import AppKit
import Foundation

/// Language-agnostic syntax colouring for fenced code blocks that have already
/// been laid out by `ResponseMarkdownRenderer`.
///
/// Rules are applied in priority order and each claims the characters it
/// covers, so a keyword inside a string or comment keeps the surrounding
/// colour instead of being recoloured.
enum CodeSyntaxHighlighter {

    private static let keywords: Set<String> = [
        "abstract", "and", "as", "assert", "async", "await", "bool", "boolean", "break",
        "case", "catch", "char", "class", "const", "constexpr", "continue", "def",
        "default", "defer", "del", "delete", "do", "double", "elif", "else", "end",
        "enum", "except", "extends", "extern", "false", "final", "finally", "float",
        "fn", "for", "from", "func", "function", "global", "goto", "guard", "if",
        "impl", "implements", "import", "in", "init", "instanceof", "int", "interface",
        "is", "lambda", "let", "long", "match", "module", "mut", "namespace", "new",
        "nil", "none", "not", "null", "or", "override", "package", "pass", "print",
        "private", "protected", "public", "raise", "return", "self", "short", "sizeof",
        "static", "str", "struct", "super", "switch", "template", "then", "this",
        "throw", "throws", "trait", "true", "try", "type", "typedef", "typeof", "union",
        "unsigned", "use", "using", "var", "void", "where", "while", "with", "yield",
    ]

    static func apply(to text: NSMutableAttributedString) {
        var blocks: [NSRange] = []
        text.enumerateAttribute(
            .paragraphStyle,
            in: NSRange(location: 0, length: text.length)
        ) { value, range, _ in
            guard let style = value as? NSParagraphStyle,
                  style.firstLineHeadIndent == 10,
                  style.headIndent == 10 else { return }
            if let last = blocks.last, last.upperBound == range.location {
                blocks[blocks.count - 1] = NSRange(
                    location: last.location,
                    length: last.length + range.length)
            } else {
                blocks.append(range)
            }
        }

        for block in blocks {
            let source = (text.string as NSString).substring(with: block)
            guard !looksLikeTable(source) else { continue }
            highlight(source, offsetBy: block.location, in: text)
        }
    }

    /// Tables are emitted as code blocks by the preprocessor; colouring their
    /// contents as if they were code would be noise.
    private static func looksLikeTable(_ source: String) -> Bool {
        source.components(separatedBy: "\n").contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 3 else { return false }
            if trimmed.contains("\u{2502}") || trimmed.contains("\u{2500}") {
                return true
            }
            return trimmed.allSatisfy { $0 == "-" || $0 == " " }
        }
    }

    private static func highlight(
        _ source: String,
        offsetBy offset: Int,
        in text: NSMutableAttributedString
    ) {
        var claimed = IndexSet()
        let rules: [(pattern: String, colour: NSColor)] = [
            (#"(?<![:/\w])(?://|#)[^\n]*"#, .systemGray),
            (#"/\*[\s\S]*?\*/"#, .systemGray),
            (#""(?:[^"\\\n]|\\.)*""#, .systemRed),
            (#"'(?:[^'\\\n]|\\.)*'"#, .systemRed),
            (#"\b\d+(?:\.\d+)?\b"#, .systemPurple),
        ]

        for rule in rules {
            paint(pattern: rule.pattern, colour: rule.colour, keywordsOnly: false,
                  source: source, offset: offset, text: text, claimed: &claimed)
        }
        paint(pattern: #"\b[A-Za-z_][A-Za-z0-9_]*\b"#, colour: .systemBlue,
              keywordsOnly: true,
              source: source, offset: offset, text: text, claimed: &claimed)
    }

    private static func paint(
        pattern: String,
        colour: NSColor,
        keywordsOnly: Bool,
        source: String,
        offset: Int,
        text: NSMutableAttributedString,
        claimed: inout IndexSet
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let ns = source as NSString
        let matches = regex.matches(
            in: source,
            range: NSRange(location: 0, length: ns.length))

        for match in matches {
            let range = match.range
            guard range.length > 0 else { continue }
            if keywordsOnly,
               !keywords.contains(ns.substring(with: range).lowercased()) {
                continue
            }
            let span = range.location..<(range.location + range.length)
            guard !claimed.intersects(integersIn: span) else { continue }
            claimed.insert(integersIn: span)
            text.addAttribute(
                .foregroundColor,
                value: colour,
                range: NSRange(location: offset + range.location, length: range.length))
        }
    }
}
