import Foundation

// MARK: - CommonMark Token Consumers
// These consumers implement the CommonMark specification for parsing Markdown syntax
// Each consumer handles a single token and updates the AST accordingly

// MARK: - Base Consumer Protocol
protocol MarkdownTokenConsumer: CodeTokenConsumer where Node == MarkdownNodeElement, Token == MarkdownTokenElement {
    /// Priority of the consumer (higher values are processed first)
    var priority: Int { get }
    
    /// Check if the consumer can handle the current token and context
    func canConsume(context: CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool
}

// MARK: - Hash Token Consumer
/// Consumes hash tokens (#) - used for headings
public struct HashTokenConsumer: MarkdownTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    
    public let priority: Int = 100
    
    public init() {}
    
    public func canConsume(context: CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        return token.element == .hash
    }
    
    public func consume(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        guard canConsume(context: context, token: token) else { return false }
        
        // Check if we're already in a heading context
        if let currentHeading = findCurrentHeading(from: context.current) as? HeaderNode {
            // Add another hash to increase heading level
            currentHeading.value += token.text
            currentHeading.level = min(currentHeading.level + 1, 6) // Max level 6
            currentHeading.text = currentHeading.value
            
            return true
        }
        
        // Check if we're at the start of a line
        if isAtLineStart(context: context) {
            // Start a new heading
            let headingNode = HeaderNode(level: 1, text: token.text, range: token.range)
            context.current.append(headingNode)
            context.current = headingNode
            return true
        }
        
        // Not at line start, treat as regular text
        return false
    }
    
    private func findCurrentHeading(from node: CodeNode<MarkdownNodeElement>) -> MarkdownNodeBase? {
        var current: CodeNode<MarkdownNodeElement>? = node
        
        while let currentNode = current {
            if currentNode.element == .heading {
                return currentNode as? MarkdownNodeBase
            }
            current = currentNode.parent
        }
        
        return nil
    }

    
    private func isHeading(_ element: MarkdownNodeElement) -> Bool {
        return element == .heading
    }
    
    private func isAtLineStart(context: CodeContext<MarkdownNodeElement>) -> Bool {
        // Simplified check - in a real implementation we'd track position
        return context.current.element == .document || 
               context.current.element == .lineBreak ||
               (context.current.parent?.element == .document)
    }
}

// MARK: - Text Token Consumer
/// Consumes text tokens and creates text nodes
public struct TextTokenConsumer: MarkdownTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    
    public let priority: Int = 10 // Lower priority to let other consumers handle first
    
    public init() {}
    
    public func canConsume(context: CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        // Text consumer can handle text and number tokens, and also various punctuation that other consumers don't handle
        switch token.element {
        case .text, .number:
            return true
        case .dot, .comma, .question, .exclamation, .colon, .semicolon, .quote, .singleQuote, .ampersand, .forwardSlash:
            return true
        case .leftParen, .rightParen, .leftBrace, .rightBrace, .leftBracket, .rightBracket:
            return true
        case .plus, .equals, .tilde, .caret, .pipe, .gt, .lt:
            return true
        // Don't handle these - let specialized consumers handle them first
        // case .dash, .asterisk, .underscore, .backtick: 
        // Don't handle whitespace - let WhitespaceTokenConsumer handle them
        // case .space, .tab:
        default:
            return false
        }
    }
    
    public func consume(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        guard canConsume(context: context, token: token) else { return false }
        
        // Check if we're already in a text context
        if let currentTextNode = context.current as? TextNode {
            // Append to existing text
            currentTextNode.text += token.text
            currentTextNode.value += token.text
            return true
        }
        
        // Check if we're in a paragraph context
        if context.current.element == .paragraph {
            // Create a text node within the paragraph
            let textNode = TextNode(text: token.text, range: token.range)
            context.current.append(textNode)
            context.current = textNode
            return true
        }
        
        // Create a new paragraph and text node
        let paragraphNode = ParagraphNode(range: token.range)
        let textNode = TextNode(text: token.text, range: token.range)
        
        context.current.append(paragraphNode)
        paragraphNode.append(textNode)
        context.current = textNode
        
        return true
    }
}

// MARK: - Asterisk Token Consumer
/// Consumes asterisk tokens (*) - used for emphasis, strong emphasis, lists, and thematic breaks
public struct AsteriskTokenConsumer: MarkdownTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    
    public let priority: Int = 80
    
    public init() {}
    
    public func canConsume(context: CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        return token.element == .asterisk
    }
    
    public func consume(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        guard canConsume(context: context, token: token) else { return false }
        
        // Check context to determine what this asterisk represents
        
        // If we're at the beginning of a line, it could be a list item or thematic break
        if isAtLineStart(context: context) {
            return handleListItem(context: &context, token: token)
        }
        
        // If we're in text context, handle emphasis
        return handleEmphasis(context: &context, token: token)
    }
    
    private func handleListItem(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        // Check if we're already in a list - if so, add to existing list
        if let existingList = findNearestList(from: context.current) {
            let listItemNode = ListItemNode(marker: token.text, range: token.range)
            existingList.append(listItemNode)
            context.current = listItemNode
            return true
        }
        
        // Create new unordered list
        let listNode = UnorderedListNode(marker: token.text, range: token.range)
        let listItemNode = ListItemNode(marker: token.text, range: token.range)
        
        context.current.append(listNode)
        listNode.append(listItemNode)
        context.current = listItemNode
        return true
    }
    
    private func handleEmphasis(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        // Look for existing text nodes to see if we're closing emphasis
        if let currentTextNode = findCurrentTextNode(context: context) {
            // Check if we're closing emphasis
            if currentTextNode.bold {
                // Close the bold emphasis - move context back to parent
                context.current = currentTextNode.parent ?? context.current
                return true
            }
            if currentTextNode.italic {
                // Close the italic emphasis - move context back to parent
                context.current = currentTextNode.parent ?? context.current
                return true
            }
            // If we're in a regular text node, we need to start emphasis
            // Check if we have consecutive asterisks for bold
            if currentTextNode.text.hasSuffix("*") {
                // This is the second asterisk, make it bold
                currentTextNode.text = String(currentTextNode.text.dropLast()) // Remove the first asterisk
                currentTextNode.bold = true
                return true
            }
            // Single asterisk - start italic
            let emphasisNode = TextNode(text: "", range: token.range)
            emphasisNode.italic = true
            context.current.append(emphasisNode)
            context.current = emphasisNode
            return true
        }
        
        // If we're not in a text node context, start new emphasis
        // First asterisk - create a text node with the asterisk
        let textNode = TextNode(text: "*", range: token.range)
        context.current.append(textNode)
        context.current = textNode
        
        return true
    }
    
    private func findCurrentTextNode(context: CodeContext<MarkdownNodeElement>) -> TextNode? {
        // Check if current node is a text node
        if let textNode = context.current as? TextNode {
            return textNode
        }
        
        // Check if the last child is a text node
        if let lastChild = context.current.children.last as? TextNode {
            return lastChild
        }
        
        return nil
    }
    
    private func findNearestList(from node: CodeNode<MarkdownNodeElement>) -> MarkdownNodeBase? {
        var current: CodeNode<MarkdownNodeElement>? = node
        
        while let currentNode = current {
            if currentNode.element == .unorderedList || currentNode.element == .orderedList {
                return currentNode as? MarkdownNodeBase
            }
            current = currentNode.parent
        }
        
        return nil
    }
    
    private func isAtLineStart(context: CodeContext<MarkdownNodeElement>) -> Bool {
        return context.current.element == .document || 
               context.current.element == .lineBreak ||
               (context.current.parent?.element == .document) ||
               (context.current.element == .paragraph && context.current.children.isEmpty)
    }
}

// MARK: - Underscore Token Consumer
/// Consumes underscore tokens (_) - used for emphasis and strong emphasis
public struct UnderscoreTokenConsumer: MarkdownTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    
    public let priority: Int = 80
    
    public init() {}
    
    public func canConsume(context: CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        return token.element == .underscore
    }
    
    public func consume(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        guard canConsume(context: context, token: token) else { return false }
        
        // Look for existing italic text to close
        if let currentTextNode = context.current as? TextNode, currentTextNode.italic {
            // Close the italic - move context back to parent
            context.current = currentTextNode.parent ?? context.current
            return true
        }
        
        // Start new italic text
        let textNode = TextNode(text: "", italic: true, range: token.range)
        context.current.append(textNode)
        context.current = textNode
        
        return true
    }
}

// MARK: - Inline Code Token Consumer
/// Consumes code tokens (inline code, fenced code blocks, indented code blocks)
public struct InlineCodeTokenConsumer: MarkdownTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    
    public let priority: Int = 90
    
    public init() {}
    
    public func canConsume(context: CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        return token.element == .inlineCode || token.element == .fencedCodeBlock || token.element == .indentedCodeBlock
    }
    
    public func consume(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        guard canConsume(context: context, token: token) else { return false }
        
        // Handle complete fenced code blocks
        if token.element == .fencedCodeBlock {
            let codeBlockNode = CodeBlockNode(type: .fenced, source: token.text, range: token.range)
            context.current.append(codeBlockNode)
            // Don't change context - code blocks are complete
            return true
        }
        
        // Handle complete indented code blocks
        if token.element == .indentedCodeBlock {
            let codeBlockNode = CodeBlockNode(type: .indented, source: token.text, range: token.range)
            context.current.append(codeBlockNode)
            // Don't change context - code blocks are complete
            return true
        }
        
        // Handle complete inline code
        if token.element == .inlineCode {
            // Remove backticks from the content
            let codeContent = token.text.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            let inlineCodeNode = InlineCodeNode(code: codeContent, range: token.range)
            
            // Find the paragraph parent by traversing up the context
            var targetParent = context.current
            while targetParent.element != .paragraph && targetParent.element != .document {
                if let parent = targetParent.parent {
                    targetParent = parent
                } else {
                    break
                }
            }
            
            // If we're at document level, create a paragraph
            if targetParent.element == .document {
                let paragraphNode = ParagraphNode(range: token.range)
                targetParent.append(paragraphNode)
                targetParent = paragraphNode
            }
            
            targetParent.append(inlineCodeNode)
            
            // Update context to stay at paragraph level
            context.current = targetParent
            return true
        }
        
        return false
    }
}

// MARK: - Dash Token Consumer
/// Consumes dash tokens (-) - used for lists, thematic breaks, and text
public struct DashTokenConsumer: MarkdownTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    
    public let priority: Int = 75
    
    public init() {}
    
    public func canConsume(context: CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        return token.element == .dash
    }
    
    public func consume(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        guard canConsume(context: context, token: token) else { return false }
        
        // Check if we're at the beginning of a line or at the start of the document
        if isAtLineStart(context: context) {
            return handleListItem(context: &context, token: token)
        }
        
        // If not at line start, treat as regular text
        return false
    }
    
    private func handleListItem(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        // Look for existing unordered list to add to
        if let existingList = findNearestUnorderedList(from: context.current) {
            let listItemNode = ListItemNode(marker: token.text, range: token.range)
            existingList.append(listItemNode)
            context.current = listItemNode
            return true
        }
        
        // Create new unordered list
        let listNode = UnorderedListNode(marker: token.text, range: token.range)
        let listItemNode = ListItemNode(marker: token.text, range: token.range)
        
        context.current.append(listNode)
        listNode.append(listItemNode)
        context.current = listItemNode
        return true
    }
    
    private func findNearestUnorderedList(from node: CodeNode<MarkdownNodeElement>) -> MarkdownNodeBase? {
        var current: CodeNode<MarkdownNodeElement>? = node
        
        while let currentNode = current {
            if currentNode.element == .unorderedList {
                return currentNode as? MarkdownNodeBase
            }
            // Don't cross into other block elements
            if currentNode.element == .orderedList || currentNode.element == .blockquote {
                break
            }
            current = currentNode.parent
        }
        
        return nil
    }
    
    private func isAtLineStart(context: CodeContext<MarkdownNodeElement>) -> Bool {
        // Consider we're at line start if we're at document level, after a line break, or at the start of a paragraph
        return context.current.element == .document || 
               context.current.element == .lineBreak ||
               (context.current.parent?.element == .document) ||
               (context.current.element == .paragraph && context.current.children.isEmpty)
    }
}

// MARK: - Newline Token Consumer
/// Consumes newline tokens - used for line breaks and paragraph separation
public struct NewlineTokenConsumer: MarkdownTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    
    public let priority: Int = 50
    
    public init() {}
    
    public func canConsume(context: CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        return token.element == .newline || token.element == .carriageReturn
    }
    
    public func consume(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        guard canConsume(context: context, token: token) else { return false }
        
        // Move back to document level to prepare for new block elements
        while context.current.element != .document {
            context.current = context.current.parent ?? context.current
        }
        
        // Create a line break node
        let lineBreakNode = LineBreakNode(type: .hard, range: token.range)
        context.current.append(lineBreakNode)
        
        return true
    }
}

// MARK: - Whitespace Token Consumer
/// Consumes whitespace tokens (spaces, tabs)
public struct WhitespaceTokenConsumer: MarkdownTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    
    public let priority: Int = 5 // Very low priority
    
    public init() {}
    
    public func canConsume(context: CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        return token.element == .space || token.element == .tab
    }
    
    public func consume(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        guard canConsume(context: context, token: token) else { return false }
        
        // Only add whitespace if we're in a text context
        if let currentTextNode = context.current as? TextNode {
            currentTextNode.text += token.text
            currentTextNode.value += token.text
            return true
        }
        
        // If we're in a paragraph context, preserve whitespace
        if context.current.element == .paragraph {
            // Create a text node for the whitespace
            let textNode = TextNode(text: token.text, range: token.range)
            context.current.append(textNode)
            context.current = textNode
            return true
        }
        
        // Otherwise, ignore whitespace
        return true
    }
}

// MARK: - EOF Token Consumer
/// Consumes EOF tokens - marks the end of input
public struct EOFTokenConsumer: MarkdownTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    
    public let priority: Int = 1 // Very low priority
    
    public init() {}
    
    public func canConsume(context: CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        return token.element == .eof
    }
    
    public func consume(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        guard canConsume(context: context, token: token) else { return false }
        
        // EOF token doesn't need to create nodes, just indicates end of input
        return true
    }
}

// MARK: - URL Token Consumer
/// Consumes URL tokens - used for autolinks and bare URLs
public struct URLTokenConsumer: MarkdownTokenConsumer {
    public typealias Node = MarkdownNodeElement
    public typealias Token = MarkdownTokenElement
    
    public let priority: Int = 85
    
    public init() {}
    
    public func canConsume(context: CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        return token.element == .autolink || token.element == .url || token.element == .email
    }
    
    public func consume(context: inout CodeContext<MarkdownNodeElement>, token: any CodeToken<MarkdownTokenElement>) -> Bool {
        guard canConsume(context: context, token: token) else { return false }
        
        // Handle autolinks
        if token.element == .autolink {
            let linkNode = LinkNode(url: token.text, text: token.text, range: token.range)
            context.current.append(linkNode)
            return true
        }
        
        // Handle email addresses
        if token.element == .email {
            let emailLink = LinkNode(url: "mailto:\(token.text)", text: token.text, range: token.range)
            context.current.append(emailLink)
            return true
        }
        
        // Handle bare URLs
        if token.element == .url {
            let urlLink = LinkNode(url: token.text, text: token.text, range: token.range)
            context.current.append(urlLink)
            return true
        }
        
        return false
    }
}

// MARK: - CommonMark Consumer Factory
/// Factory for creating CommonMark-compliant token consumers
public struct CommonMarkConsumerFactory {
    /// Creates all CommonMark consumers in priority order
    public static func allConsumers() -> [any CodeTokenConsumer<MarkdownNodeElement, MarkdownTokenElement>] {
        return [
            HashTokenConsumer(),
            InlineCodeTokenConsumer(),
            AsteriskTokenConsumer(),
            UnderscoreTokenConsumer(),
            DashTokenConsumer(),
            NewlineTokenConsumer(),
            TextTokenConsumer(),
            WhitespaceTokenConsumer(),
            EOFTokenConsumer(),
            URLTokenConsumer()
        ]
    }
    
    /// Creates basic CommonMark consumers (excluding extensions)
    public static func basicConsumers() -> [any CodeTokenConsumer<MarkdownNodeElement, MarkdownTokenElement>] {
        return [
            HashTokenConsumer(),
            InlineCodeTokenConsumer(),
            URLTokenConsumer(),
            AsteriskTokenConsumer(),
            UnderscoreTokenConsumer(),
            DashTokenConsumer(),
            NewlineTokenConsumer(),
            TextTokenConsumer(),
            WhitespaceTokenConsumer()
        ]
    }
    
    /// Creates inline-only consumers
    public static func inlineConsumers() -> [any CodeTokenConsumer<MarkdownNodeElement, MarkdownTokenElement>] {
        return [
            InlineCodeTokenConsumer(),
            AsteriskTokenConsumer(),
            UnderscoreTokenConsumer(),
            TextTokenConsumer(),
            WhitespaceTokenConsumer()
        ]
    }
    
    /// Creates block-only consumers
    public static func blockConsumers() -> [any CodeTokenConsumer<MarkdownNodeElement, MarkdownTokenElement>] {
        return [
            HashTokenConsumer(),
            DashTokenConsumer(),
            NewlineTokenConsumer(),
            TextTokenConsumer()
        ]
    }
}
