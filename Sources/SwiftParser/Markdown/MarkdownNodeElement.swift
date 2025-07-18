import Foundation

// MARK: - Markdown Node Element Definition
public enum MarkdownNodeElement: String, CaseIterable, CodeNodeElement {
    // MARK: - Document Structure
    case document = "document"
    
    // MARK: - Block Elements (CommonMark)
    case paragraph = "paragraph"
    case heading = "heading"
    case thematicBreak = "thematic_break"
    case blockquote = "blockquote"
    case orderedList = "ordered_list"
    case unorderedList = "unordered_list"
    case listItem = "list_item"
    case blankLine = "blank_line"
    case codeBlock = "code_block"
    case htmlBlock = "html_block"
    case imageBlock = "image_block"
    
    // MARK: - Inline Elements (CommonMark)
    case text = "text"
    case code = "code"
    case link = "link"
    case image = "image"
    case html = "html"
    case lineBreak = "line_break"
    
    // MARK: - Components
    case comment = "comment"

    // MARK: - GFM Extensions
    case table = "table"
    case taskList = "task_list"
    case taskListItem = "task_list_item"
    case reference = "reference"
    case footnote = "footnote"
    
    // MARK: - Math Elements (LaTeX/TeX)
    case formula = "formula"
    case formulaBlock = "formula_block"
}