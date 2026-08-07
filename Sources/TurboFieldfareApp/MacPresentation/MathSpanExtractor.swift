import Foundation

/// A LaTeX span lifted out of a response before Markdown parsing.
struct MathSpan {
    let latex: String
    let isDisplay: Bool
}

/// Removes LaTeX from a response before it reaches `AttributedString(markdown:)`,
/// which would otherwise mangle it - `$a_b$` reads the underscore as emphasis,
/// and backslash commands get treated as escapes. Each span is replaced by a
/// private-use sentinel that survives parsing untouched, and
/// `MathAttachmentRenderer` swaps the sentinels for rendered images afterwards.
///
/// Fenced blocks and inline code spans are left alone, so a code sample that
/// mentions `$` is never mistaken for math.
enum MathSpanExtractor {

    struct Extraction {
        let text: String
        let spans: [MathSpan]
    }

    static func sentinel(_ index: Int) -> String { "\u{E000}\(index)\u{E001}" }

    static func extract(from source: String) -> Extraction {
        guard source.contains("$") || source.contains("\\(") || source.contains("\\[") else {
            return Extraction(text: source, spans: [])
        }

        let chars = Array(source)
        var spans: [MathSpan] = []
        var output = ""
        var index = 0
        var insideInlineCode = false

        while index < chars.count {
            if isFenceStart(chars, index) {
                let end = fenceEnd(chars, from: index)
                output += String(chars[index..<end])
                index = end
                continue
            }
            if chars[index] == "`" {
                insideInlineCode.toggle()
                output.append(chars[index])
                index += 1
                continue
            }
            if insideInlineCode {
                output.append(chars[index])
                index += 1
                continue
            }
            if let match = matchMath(chars, at: index) {
                spans.append(MathSpan(latex: match.latex, isDisplay: match.isDisplay))
                output += sentinel(spans.count - 1)
                index = match.end
                continue
            }
            output.append(chars[index])
            index += 1
        }
        return Extraction(text: output, spans: spans)
    }

    private static func isFenceStart(_ chars: [Character], _ index: Int) -> Bool {
        guard index + 2 < chars.count,
              chars[index] == "`", chars[index + 1] == "`", chars[index + 2] == "`" else {
            return false
        }
        return index == 0 || chars[index - 1] == "\n"
    }

    private static func fenceEnd(_ chars: [Character], from index: Int) -> Int {
        var scan = index + 3
        while scan + 2 < chars.count {
            if chars[scan] == "`", chars[scan + 1] == "`", chars[scan + 2] == "`" {
                return min(scan + 3, chars.count)
            }
            scan += 1
        }
        return chars.count
    }

    private static func matchMath(_ chars: [Character], at index: Int)
        -> (latex: String, isDisplay: Bool, end: Int)? {

        func find(_ needle: [Character], from start: Int) -> Int? {
            var scan = start
            while scan + needle.count <= chars.count {
                var matched = true
                for offset in 0..<needle.count where chars[scan + offset] != needle[offset] {
                    matched = false
                    break
                }
                if matched { return scan }
                scan += 1
            }
            return nil
        }

        if chars[index] == "\\", index + 1 < chars.count {
            if chars[index + 1] == "[", let close = find(["\\", "]"], from: index + 2) {
                return (String(chars[(index + 2)..<close]), true, close + 2)
            }
            if chars[index + 1] == "(", let close = find(["\\", ")"], from: index + 2) {
                return (String(chars[(index + 2)..<close]), false, close + 2)
            }
            return nil
        }

        guard chars[index] == "$" else { return nil }

        if index + 1 < chars.count, chars[index + 1] == "$" {
            guard let close = find(["$", "$"], from: index + 2), close > index + 2 else {
                return nil
            }
            return (String(chars[(index + 2)..<close]), true, close + 2)
        }

        guard let close = find(["$"], from: index + 1), close > index + 1 else { return nil }
        let latex = String(chars[(index + 1)..<close])
        guard isPlausibleInlineMath(latex) else { return nil }
        guard close + 1 >= chars.count || !chars[close + 1].isNumber else { return nil }
        return (latex, false, close + 1)
    }

    /// Guards against ordinary currency: "$5 and $10" must not become math.
    private static func isPlausibleInlineMath(_ latex: String) -> Bool {
        guard !latex.isEmpty, latex.count <= 200, !latex.contains("\n"),
              let first = latex.first, let last = latex.last else { return false }
        return !first.isWhitespace && !last.isWhitespace && !first.isNumber
    }
}
