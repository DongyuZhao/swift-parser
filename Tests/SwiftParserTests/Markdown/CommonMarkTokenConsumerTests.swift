import XCTest
@testable import SwiftParser

final class CommonMarkTokenConsumerTests: XCTestCase {
    
    var language: MarkdownLanguage!
    
    override func setUp() {
        super.setUp()
        language = MarkdownLanguage.commonMark()
    }
    
    override func tearDown() {
        language = nil
        super.tearDown()
    }
    
    // MARK: - Basic Token Consumer Tests
    
    func testHashTokenConsumer() {
        let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        let result = parser.parse("# Heading", language: language)
        
        XCTAssertTrue(result.errors.isEmpty, "Should not have errors")
        XCTAssertEqual(result.root.element, .document)
        XCTAssertEqual(result.root.children.count, 1)
        
        let headingNode = result.root.children[0]
        XCTAssertEqual(headingNode.element, .heading)
        XCTAssertEqual(headingNode.value, "#")
    }
    
    func testTextTokenConsumer() {
        let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        let result = parser.parse("Hello world", language: language)
        
        XCTAssertTrue(result.errors.isEmpty, "Should not have errors")
        XCTAssertEqual(result.root.element, .document)
        XCTAssertEqual(result.root.children.count, 1)
        
        let paragraphNode = result.root.children[0]
        XCTAssertEqual(paragraphNode.element, .paragraph)
        XCTAssertEqual(paragraphNode.children.count, 1)
        
        let textNode = paragraphNode.children[0]
        XCTAssertEqual(textNode.element, .text)
        XCTAssertTrue(textNode.value.contains("Hello"))
    }
    
    func testBacktickTokenConsumer() {
        let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        let result = parser.parse("`code`", language: language)
        
        XCTAssertTrue(result.errors.isEmpty, "Should not have errors")
        XCTAssertEqual(result.root.element, .document)
        
        // Look for inline code nodes
        let codeNodes = findNodes(in: result.root, matching: .code)
        XCTAssertFalse(codeNodes.isEmpty, "Should have inline code nodes")
    }
    
    func testAsteriskTokenConsumer() {
        let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        let result = parser.parse("*emphasis*", language: language)
        
        XCTAssertTrue(result.errors.isEmpty, "Should not have errors")
        XCTAssertEqual(result.root.element, .document)
        
        // Look for emphasis nodes
        let textNodes = findTextNodes(in: result.root)
        let emphasisNodes = textNodes.filter { $0.italic }
        XCTAssertFalse(emphasisNodes.isEmpty, "Should have emphasis nodes")
    }
    
    func testDashTokenConsumer() {
        let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        let result = parser.parse("- List item", language: language)
        
        XCTAssertTrue(result.errors.isEmpty, "Should not have errors")
        XCTAssertEqual(result.root.element, .document)
        
        // Look for list nodes
        let listNodes = findNodes(in: result.root, matching: .unorderedList)
        XCTAssertFalse(listNodes.isEmpty, "Should have unordered list nodes")
        
        let listItemNodes = findNodes(in: result.root, matching: .listItem)
        XCTAssertFalse(listItemNodes.isEmpty, "Should have list item nodes")
    }
    
    func testNewlineTokenConsumer() {
        let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        let result = parser.parse("Line 1\nLine 2", language: language)
        
        XCTAssertTrue(result.errors.isEmpty, "Should not have errors")
        XCTAssertEqual(result.root.element, .document)
        
        // Look for line break nodes
        let lineBreakNodes = findNodes(in: result.root, matching: .lineBreak)
        XCTAssertFalse(lineBreakNodes.isEmpty, "Should have line break nodes")
    }
    
    func testWhitespaceTokenConsumer() {
        let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        let result = parser.parse("Hello world", language: language)
        
        XCTAssertTrue(result.errors.isEmpty, "Should not have errors")
        XCTAssertEqual(result.root.element, .document)
        
        // Whitespace should be preserved in text nodes
        let textNodes = findNodes(in: result.root, matching: .text)
        XCTAssertFalse(textNodes.isEmpty, "Should have text nodes")
    }
    
    func testCodeBlockTokenConsumer() {
        let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        let result = parser.parse("```swift\nlet x = 42\n```", language: language)
        
        XCTAssertTrue(result.errors.isEmpty, "Should not have errors")
        XCTAssertEqual(result.root.element, .document)
        
        // Look for fenced code block nodes
        let fencedCodeBlockNodes = findNodes(in: result.root, matching: .codeBlock)
        XCTAssertFalse(fencedCodeBlockNodes.isEmpty, "Should have fenced code block nodes")
        
        // Verify the code block contains the code content
        if let codeBlock = fencedCodeBlockNodes.first {
            XCTAssertTrue(codeBlock.value.contains("let x = 42"), "Code block should contain the code content")
        }
    }
    
    func testInlineCodeTokenConsumer() {
        let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        let result = parser.parse("This is `inline code` example", language: language)
        
        XCTAssertTrue(result.errors.isEmpty, "Should not have errors")
        XCTAssertEqual(result.root.element, .document)
        
        // Look for inline code nodes  
        let inlineCodeNodes = findNodes(in: result.root, matching: .code)
        XCTAssertFalse(inlineCodeNodes.isEmpty, "Should have inline code nodes")
        
        // Verify the inline code contains the code content
        if let inlineCode = inlineCodeNodes.first {
            XCTAssertEqual(inlineCode.value, "inline code", "Inline code should contain the code content")
        }
    }

    // MARK: - Helper Methods
    
    private func findNodes(in root: CodeNode<MarkdownNodeElement>, matching element: MarkdownNodeElement) -> [CodeNode<MarkdownNodeElement>] {
        var result: [CodeNode<MarkdownNodeElement>] = []
        
        func traverse(_ node: CodeNode<MarkdownNodeElement>) {
            if node.element == element {
                result.append(node)
            }
            for child in node.children {
                traverse(child)
            }
        }
        
        traverse(root)
        return result
    }
    
    private func findTextNodes(in root: CodeNode<MarkdownNodeElement>) -> [TextNode] {
        var result: [TextNode] = []
        
        func traverse(_ node: CodeNode<MarkdownNodeElement>) {
            if let textNode = node as? TextNode {
                result.append(textNode)
            }
            for child in node.children {
                traverse(child)
            }
        }
        
        traverse(root)
        return result
    }
    
    // Helper function to print AST structure
    private func printAST(_ node: CodeNode<MarkdownNodeElement>, indent: Int = 0) {
        let indentStr = String(repeating: "  ", count: indent)
        print("\(indentStr)\(node.element) - '\(node.value)'")
        
        for child in node.children {
            printAST(child, indent: indent + 1)
        }
    }
}
