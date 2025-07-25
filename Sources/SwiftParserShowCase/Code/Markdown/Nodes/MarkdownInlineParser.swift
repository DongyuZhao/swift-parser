import Foundation
import SwiftParser

/// Simple inline parser used by block builders to parse inline Markdown syntax.
/// Handles emphasis, links, images, inline code and other span level elements.
struct MarkdownInlineParser {
    /// Parse inline content until one of the `stopAt` tokens is encountered.
    /// - Parameters:
    ///   - context: Construction context providing tokens and current state.
    ///   - stopAt: Tokens that terminate inline parsing.
    /// - Returns: Array of parsed inline nodes.
    static func parseInline(
        _ context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>,
        stopAt: Set<MarkdownTokenElement> = [.newline, .eof]
    ) -> [MarkdownNodeBase] {
        var nodes: [MarkdownNodeBase] = []
        var delimiters: [Delimiter] = []

        while context.consuming < context.tokens.count {
            guard let token = context.tokens[context.consuming] as? MarkdownToken else { break }
            if stopAt.contains(token.element) { break }

            switch token.element {
            case .asterisk, .underscore, .tilde:
                let marker = token.element
                var count = 0
                while context.consuming < context.tokens.count,
                      let t = context.tokens[context.consuming] as? MarkdownToken,
                      t.element == marker {
                    count += 1
                    context.consuming += 1
                }
                if marker == .tilde && count < 2 {
                    let text = String(repeating: "~", count: count)
                    nodes.append(TextNode(content: text))
                } else {
                    handleDelimiter(marker: marker, count: count, nodes: &nodes, stack: &delimiters)
                }
            case .inlineCode:
                nodes.append(InlineCodeNode(code: trimBackticks(token.text)))
                context.consuming += 1
            case .formula:
                nodes.append(FormulaNode(expression: trimFormula(token.text)))
                context.consuming += 1
            case .htmlTag, .htmlBlock, .htmlUnclosedBlock, .htmlEntity:
                nodes.append(HTMLNode(content: token.text))
                context.consuming += 1
            case .exclamation:
                if let image = parseImage(&context) {
                    nodes.append(image)
                } else {
                    nodes.append(TextNode(content: token.text))
                    context.consuming += 1
                }
            case .leftBracket:
                if let link = parseLinkOrFootnote(&context) {
                    nodes.append(link)
                } else {
                    nodes.append(TextNode(content: token.text))
                    context.consuming += 1
                }
            case .autolink, .url:
                let url = trimAutolink(token.text)
                let link = LinkNode(url: url, title: url)
                nodes.append(link)
                context.consuming += 1
            default:
                let shouldMerge: Bool
                if let lastIndex = nodes.indices.last,
                   let _ = nodes[lastIndex] as? TextNode,
                   !delimiters.contains(where: { $0.index == lastIndex }) {
                    shouldMerge = true
                } else {
                    shouldMerge = false
                }

                if shouldMerge, let last = nodes.last as? TextNode {
                    last.content += token.text
                } else {
                    nodes.append(TextNode(content: token.text))
                }
                context.consuming += 1
            }
        }

        return nodes
    }


    private struct Delimiter {
        var marker: MarkdownTokenElement
        var count: Int
        var index: Int
    }

    private static func handleDelimiter(
        marker: MarkdownTokenElement,
        count: Int,
        nodes: inout [MarkdownNodeBase],
        stack: inout [Delimiter]
    ) {
        var remaining = count

        while remaining > 0, let openIdx = stack.lastIndex(where: { $0.marker == marker }) {
            let open = stack.remove(at: openIdx)
            var closeCount = min(open.count, remaining)
            if marker == .tilde {
                guard open.count >= 2 && remaining >= 2 else {
                    stack.append(open)
                    break
                }
                closeCount = 2
            }

            let start = open.index + 1
            let removedCount = nodes.count - open.index
            let content = Array(nodes[start..<nodes.count])
            nodes.removeSubrange(open.index..<nodes.count)
            for i in 0..<stack.count {
                if stack[i].index >= open.index {
                    stack[i].index -= removedCount - 1
                }
            }

            let node: MarkdownNodeBase
            if marker == .tilde {
                node = StrikeNode(content: "")
            } else {
                node = (closeCount >= 2) ? StrongNode(content: "") : EmphasisNode(content: "")
            }
            for child in content { node.append(child) }
            nodes.append(node)

            remaining -= closeCount
        }

        if remaining > 0 {
            let text = String(repeating: marker.rawValue, count: remaining)
            nodes.append(TextNode(content: text))
            stack.append(Delimiter(marker: marker, count: remaining, index: nodes.count - 1))
        }
    }

    private static func parseLinkOrFootnote(_ context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> MarkdownNodeBase? {
        let start = context.consuming
        context.consuming += 1
        // Footnote reference [^id] or citation [@id]
        if context.consuming < context.tokens.count,
           let caret = context.tokens[context.consuming] as? MarkdownToken,
           caret.element == .caret {
            context.consuming += 1
            var ident = ""
            while context.consuming < context.tokens.count,
                  let t = context.tokens[context.consuming] as? MarkdownToken,
                  t.element != .rightBracket {
                ident += t.text
                context.consuming += 1
            }
            guard context.consuming < context.tokens.count,
                  let rb = context.tokens[context.consuming] as? MarkdownToken,
                  rb.element == .rightBracket else { context.consuming = start; return nil }
            context.consuming += 1
            return FootnoteNode(identifier: ident, content: "", referenceText: nil, range: rb.range)
        } else if context.consuming < context.tokens.count,
                  let at = context.tokens[context.consuming] as? MarkdownToken,
                  at.element == .text, at.text == "@" {
            context.consuming += 1
            var ident = ""
            while context.consuming < context.tokens.count,
                  let t = context.tokens[context.consuming] as? MarkdownToken,
                  t.element != .rightBracket {
                ident += t.text
                context.consuming += 1
            }
            guard context.consuming < context.tokens.count,
                  let rb = context.tokens[context.consuming] as? MarkdownToken,
                  rb.element == .rightBracket else { context.consuming = start; return nil }
            context.consuming += 1
            return CitationReferenceNode(identifier: ident)
        }

        let textNodes = parseInline(&context, stopAt: [.rightBracket])
        guard context.consuming < context.tokens.count,
              let rb = context.tokens[context.consuming] as? MarkdownToken,
              rb.element == .rightBracket else { context.consuming = start; return nil }
        context.consuming += 1

        // Inline link [text](url)
        if context.consuming < context.tokens.count,
           let lp = context.tokens[context.consuming] as? MarkdownToken,
           lp.element == .leftParen {
            context.consuming += 1
            var url = ""
            while context.consuming < context.tokens.count,
                  let t = context.tokens[context.consuming] as? MarkdownToken,
                  t.element != .rightParen {
                url += t.text
                context.consuming += 1
            }
            guard context.consuming < context.tokens.count,
                  let rp = context.tokens[context.consuming] as? MarkdownToken,
                  rp.element == .rightParen else { context.consuming = start; return nil }
            context.consuming += 1
            let link = LinkNode(url: url, title: "")
            for child in textNodes { link.append(child) }
            return link
        }

        // Reference link [text][id]
        if context.consuming < context.tokens.count,
           let lb = context.tokens[context.consuming] as? MarkdownToken,
           lb.element == .leftBracket {
            context.consuming += 1
            var id = ""
            while context.consuming < context.tokens.count,
                  let t = context.tokens[context.consuming] as? MarkdownToken,
                  t.element != .rightBracket {
                id += t.text
                context.consuming += 1
            }
            guard context.consuming < context.tokens.count,
                  let rb2 = context.tokens[context.consuming] as? MarkdownToken,
                  rb2.element == .rightBracket else { context.consuming = start; return nil }
            context.consuming += 1
            let ref = ReferenceNode(identifier: id, url: "", title: "")
            for child in textNodes { ref.append(child) }
            return ref
        }

        context.consuming = start
        return nil
    }

    private static func parseImage(_ context: inout CodeConstructContext<MarkdownNodeElement, MarkdownTokenElement>) -> MarkdownNodeBase? {
        guard context.consuming + 1 < context.tokens.count,
              let lb = context.tokens[context.consuming + 1] as? MarkdownToken,
              lb.element == .leftBracket else { return nil }
        context.consuming += 2
        let altNodes = parseInline(&context, stopAt: [.rightBracket])
        guard context.consuming < context.tokens.count,
              let rb = context.tokens[context.consuming] as? MarkdownToken,
              rb.element == .rightBracket else { context.consuming -= 2; return nil }
        context.consuming += 1
        guard context.consuming < context.tokens.count,
              let lp = context.tokens[context.consuming] as? MarkdownToken,
              lp.element == .leftParen else { context.consuming -= 3; return nil }
        context.consuming += 1
        var url = ""
        while context.consuming < context.tokens.count,
              let t = context.tokens[context.consuming] as? MarkdownToken,
              t.element != .rightParen {
            url += t.text
            context.consuming += 1
        }
        guard context.consuming < context.tokens.count,
              let rp = context.tokens[context.consuming] as? MarkdownToken,
              rp.element == .rightParen else { context.consuming -= 4; return nil }
        context.consuming += 1
        let alt = altNodes.compactMap { ($0 as? TextNode)?.content }.joined()
        return ImageNode(url: url, alt: alt)
    }

    private static func trimBackticks(_ text: String) -> String {
        var t = text
        while t.hasPrefix("`") { t.removeFirst() }
        while t.hasSuffix("`") { t.removeLast() }
        return t
    }

    private static func trimFormula(_ text: String) -> String {
        var t = text
        if t.hasPrefix("$") { t.removeFirst() }
        if t.hasSuffix("$") { t.removeLast() }
        return t
    }

    private static func trimAutolink(_ text: String) -> String {
        if text.hasPrefix("<") && text.hasSuffix(">") {
            return String(text.dropFirst().dropLast())
        }
        return text
    }
}
