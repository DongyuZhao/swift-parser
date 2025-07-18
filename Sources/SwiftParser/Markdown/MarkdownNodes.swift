import Foundation

// MARK: - Markdown Node Base Class
/// Base class for all Markdown nodes, extending CodeNode with semantic properties
public class MarkdownNodeBase: CodeNode<MarkdownNodeElement> {
    
    public override init(element: MarkdownNodeElement, value: String = "", range: Range<String.Index>? = nil) {
        super.init(element: element, value: value, range: range)
    }
    
    /// Convenience method to append a MarkdownNodeBase child
    public func append(_ child: MarkdownNodeBase) {
        super.append(child)
    }
    
    /// Convenience method to get children as MarkdownNodeBase
    public var markdownChildren: [MarkdownNodeBase] {
        return children.compactMap { $0 as? MarkdownNodeBase }
    }
    
    /// Convenience method to get parent as MarkdownNodeBase
    public var markdownParent: MarkdownNodeBase? {
        return parent as? MarkdownNodeBase
    }
}

// MARK: - Document Structure
public class DocumentNode: MarkdownNodeBase {
    public var title: String?
    public var metadata: [String: Any] = [:]
    
    public init(title: String? = nil, range: Range<String.Index>? = nil) {
        self.title = title
        super.init(element: .document, range: range)
    }
}

// MARK: - Block Elements
public class ParagraphNode: MarkdownNodeBase {
    public init(range: Range<String.Index>? = nil) {
        super.init(element: .paragraph, range: range)
    }
}

public class HeaderNode: MarkdownNodeBase {
    public var level: Int
    public var text: String
    
    public init(level: Int, text: String, range: Range<String.Index>? = nil) {
        self.level = level
        self.text = text
        super.init(element: .heading, value: text, range: range)
    }
    
    public var isValid: Bool {
        return level >= 1 && level <= 6
    }
}

public class ThematicBreakNode: MarkdownNodeBase {
    public var marker: String
    
    public init(marker: String = "---", range: Range<String.Index>? = nil) {
        self.marker = marker
        super.init(element: .thematicBreak, value: marker, range: range)
    }
}

public class BlockquoteNode: MarkdownNodeBase {
    public var level: Int
    
    public init(level: Int = 1, range: Range<String.Index>? = nil) {
        self.level = level
        super.init(element: .blockquote, range: range)
    }
}

public class ListNode: MarkdownNodeBase {
    public var level: Int
    public var marker: String
    
    public init(element: MarkdownNodeElement, level: Int = 1, marker: String, range: Range<String.Index>? = nil) {
        self.level = level
        self.marker = marker
        super.init(element: element, range: range)
    }
}

public class OrderedListNode: ListNode {
    public var startNumber: Int
    
    public init(startNumber: Int = 1, level: Int = 1, marker: String, range: Range<String.Index>? = nil) {
        self.startNumber = startNumber
        super.init(element: .orderedList, level: level, marker: marker, range: range)
    }
}

public class UnorderedListNode: ListNode {
    public init(level: Int = 1, marker: String, range: Range<String.Index>? = nil) {
        super.init(element: .unorderedList, level: level, marker: marker, range: range)
    }
}

public class ListItemNode: MarkdownNodeBase {
    public var marker: String
    public var isChecked: Bool?
    public var title: String?
    
    public init(marker: String, isChecked: Bool? = nil, title: String? = nil, range: Range<String.Index>? = nil) {
        self.marker = marker
        self.isChecked = isChecked
        self.title = title
        super.init(element: .listItem, value: marker, range: range)
    }
    
    public var isTaskItem: Bool {
        return isChecked != nil
    }
}

public class CodeBlockNode: MarkdownNodeBase {
    public enum CodeBlockType {
        case fenced
        case indented
    }
    
    public var type: CodeBlockType
    public var language: String?
    public var source: String
    public var mode: String
    
    public init(type: CodeBlockType, language: String? = nil, source: String, mode: String = "code", range: Range<String.Index>? = nil) {
        self.type = type
        self.language = language
        self.source = source
        self.mode = mode
        super.init(element: .codeBlock, value: source, range: range)
    }
}

public class HTMLBlockNode: MarkdownNodeBase {
    public var content: String
    public var tagName: String?
    
    public init(content: String, tagName: String? = nil, range: Range<String.Index>? = nil) {
        self.content = content
        self.tagName = tagName
        super.init(element: .htmlBlock, value: content, range: range)
    }
}

public class ImageBlockNode: MarkdownNodeBase {
    public var url: String
    public var alt: String
    public var title: String?
    
    public init(url: String, alt: String, title: String? = nil, range: Range<String.Index>? = nil) {
        self.url = url
        self.alt = alt
        self.title = title
        super.init(element: .imageBlock, value: alt, range: range)
    }
}

// MARK: - Inline Elements
public class TextNode: MarkdownNodeBase {
    public var text: String
    public var bold: Bool
    public var italic: Bool
    public var highlight: Bool
    public var striked: Bool
    public var underlined: Bool
    
    public init(text: String, bold: Bool = false, italic: Bool = false, highlight: Bool = false, striked: Bool = false, underlined: Bool = false, range: Range<String.Index>? = nil) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.highlight = highlight
        self.striked = striked
        self.underlined = underlined
        super.init(element: .text, value: text, range: range)
    }
    
    /// Convenience property to check if text has any styling
    public var hasStyle: Bool {
        return bold || italic || highlight || striked || underlined
    }
    
    /// Convenience property to check if text is plain (no styling)
    public var isPlain: Bool {
        return !hasStyle
    }
    
    /// Returns a string representation of the applied styles
    public var styleDescription: String {
        var styles: [String] = []
        if bold { styles.append("bold") }
        if italic { styles.append("italic") }
        if highlight { styles.append("highlight") }
        if striked { styles.append("striked") }
        if underlined { styles.append("underlined") }
        return styles.isEmpty ? "plain" : styles.joined(separator: ", ")
    }
}

public class InlineCodeNode: MarkdownNodeBase {
    public var code: String
    
    public init(code: String, range: Range<String.Index>? = nil) {
        self.code = code
        super.init(element: .code, value: code, range: range)
    }
}

public class LinkNode: MarkdownNodeBase {
    public var url: String
    public var title: String?
    public var text: String
    
    public init(url: String, title: String? = nil, text: String, range: Range<String.Index>? = nil) {
        self.url = url
        self.title = title
        self.text = text
        super.init(element: .link, value: text, range: range)
    }
}

public class ImageNode: MarkdownNodeBase {
    public var url: String
    public var alt: String
    public var title: String?
    
    public init(url: String, alt: String, title: String? = nil, range: Range<String.Index>? = nil) {
        self.url = url
        self.alt = alt
        self.title = title
        super.init(element: .image, value: alt, range: range)
    }
}

public class HTMLNode: MarkdownNodeBase {
    public var content: String
    public var tagName: String?
    
    public init(content: String, tagName: String? = nil, range: Range<String.Index>? = nil) {
        self.content = content
        self.tagName = tagName
        super.init(element: .html, value: content, range: range)
    }
}

public class LineBreakNode: MarkdownNodeBase {
    public var type: LineBreakType
    
    public enum LineBreakType {
        case soft
        case hard
    }
    
    public init(type: LineBreakType = .soft, range: Range<String.Index>? = nil) {
        self.type = type
        super.init(element: .lineBreak, value: type == .hard ? "\n" : " ", range: range)
    }
}

// MARK: - Components
public class CommentNode: MarkdownNodeBase {
    public var content: String
    
    public init(content: String, range: Range<String.Index>? = nil) {
        self.content = content
        super.init(element: .comment, value: content, range: range)
    }
}

// MARK: - GFM Extensions
public class TableNode: MarkdownNodeBase {
    public enum Alignment {
        case left
        case center
        case right
        case none
    }
    
    public var headers: [String]
    public var alignments: [Alignment]
    public var rows: [[String]]
    
    public init(headers: [String], alignments: [Alignment], rows: [[String]] = [], range: Range<String.Index>? = nil) {
        self.headers = headers
        self.alignments = alignments
        self.rows = rows
        super.init(element: .table, range: range)
    }
}

public class TaskListNode: MarkdownNodeBase {
    public init(range: Range<String.Index>? = nil) {
        super.init(element: .taskList, range: range)
    }
}

public class TaskListItemNode: MarkdownNodeBase {
    public var isChecked: Bool
    public var title: String
    
    public init(isChecked: Bool, title: String, range: Range<String.Index>? = nil) {
        self.isChecked = isChecked
        self.title = title
        super.init(element: .taskListItem, value: title, range: range)
    }
}

public class ReferenceNode: MarkdownNodeBase {
    public var identifier: String
    public var url: String
    public var title: String?
    
    public init(identifier: String, url: String, title: String? = nil, range: Range<String.Index>? = nil) {
        self.identifier = identifier
        self.url = url
        self.title = title
        super.init(element: .reference, value: identifier, range: range)
    }
}

public class FootnoteNode: MarkdownNodeBase {
    public var identifier: String
    public var content: String
    public var referenceText: String?
    
    public init(identifier: String, content: String, referenceText: String? = nil, range: Range<String.Index>? = nil) {
        self.identifier = identifier
        self.content = content
        self.referenceText = referenceText
        super.init(element: .footnote, value: content, range: range)
    }
}

// MARK: - Math Elements
public class MathNode: MarkdownNodeBase {
    public enum MathType {
        case inline
        case block
    }
    
    public var type: MathType
    public var expression: String
    
    public init(type: MathType, expression: String, range: Range<String.Index>? = nil) {
        self.type = type
        self.expression = expression
        super.init(element: type == .inline ? .formula : .formulaBlock, value: expression, range: range)
    }
}

// MARK: - Node Type Checking Extensions
public extension MarkdownNodeBase {
    var isBlockElement: Bool {
        switch element {
        case .paragraph, .heading, .thematicBreak, .blockquote, .orderedList, .unorderedList, .listItem, .codeBlock, .htmlBlock, .imageBlock, .table, .taskList, .taskListItem, .formulaBlock:
            return true
        default:
            return false
        }
    }
    
    var isInlineElement: Bool {
        switch element {
        case .text, .code, .link, .image, .html, .lineBreak, .formula:
            return true
        default:
            return false
        }
    }
    
    var isHeaderElement: Bool {
        return element == .heading
    }
    
    var isListElement: Bool {
        return element == .orderedList || element == .unorderedList
    }
    
    var isOrderedList: Bool {
        return element == .orderedList
    }
    
    var isUnorderedList: Bool {
        return element == .unorderedList
    }
    
    var isCodeElement: Bool {
        return element == .code || element == .codeBlock
    }
    
    var isTextElement: Bool {
        return element == .text || element == .code
    }
}
