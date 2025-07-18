import XCTest
@testable import SwiftParser

final class CommonMarkComplexTests: XCTestCase {
    
    var parser: SwiftParser<MarkdownNodeElement, MarkdownTokenElement>!
    var language: MarkdownLanguage!
    
    override func setUp() {
        super.setUp()
        parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        language = MarkdownLanguage.commonMark()
    }
    
    override func tearDown() {
        parser = nil
        language = nil
        super.tearDown()
    }
    
    func testComplexDocumentStructure() {
        let markdown = """
        # Main Title
        
        This is a paragraph with **bold** and *italic* text.
        
        ## Subsection
        
        Here is a list:
        - First item with `inline code`
        - Second item
        - Third item
        
        ### Code Example
        
        ```swift
        let greeting = "Hello, World!"
        print(greeting)
        ```
        
        Another paragraph with mixed formatting: **bold _italic_ text**.
        """
        
        let result = parser.parse(markdown, language: language)
        
        XCTAssertTrue(result.errors.isEmpty, "Should not have errors: \(result.errors)")
        
        // Print the complete AST for verification
        print("\n=== Complete AST Structure ===")
        printAST(result.root)
        
        print("\n=== Text Nodes Analysis ===")
        let allTextNodes = findTextNodes(in: result.root)
        print("Found \(allTextNodes.count) text nodes")
        for (index, node) in allTextNodes.enumerated() {
            print("TextNode \(index): text='\(node.text)', bold=\(node.bold), italic=\(node.italic)")
        }
        
        let strongDebugNodes = allTextNodes.filter { $0.bold }
        print("Found \(strongDebugNodes.count) bold nodes")
        
        let emphasisDebugNodes = allTextNodes.filter { $0.italic }
        print("Found \(emphasisDebugNodes.count) italic nodes")
        
        // Verify we have various elements
        let h1Nodes = findHeadingNodes(in: result.root, level: 1)
        let h2Nodes = findHeadingNodes(in: result.root, level: 2)
        let h3Nodes = findHeadingNodes(in: result.root, level: 3)
        let textNodes = findTextNodes(in: result.root)
        let strongNodes = textNodes.filter { $0.bold }
        let emphasisNodes = textNodes.filter { $0.italic }
        let listNodes = findNodes(in: result.root, matching: .unorderedList)
        let codeNodes = findNodes(in: result.root, matching: .code)
        let blockNodes = findNodes(in: result.root, matching: .codeBlock)
        
        XCTAssertEqual(h1Nodes.count, 1, "Should have one H1")
        XCTAssertEqual(h2Nodes.count, 1, "Should have one H2")
        XCTAssertEqual(h3Nodes.count, 1, "Should have one H3")
        XCTAssertTrue(strongNodes.count >= 1, "Should have at least one strong")
        XCTAssertTrue(emphasisNodes.count >= 1, "Should have at least one emphasis")
        XCTAssertTrue(listNodes.count >= 1, "Should have at least one list")
        XCTAssertTrue(codeNodes.count >= 1, "Should have at least one inline code")
        XCTAssertTrue(blockNodes.count >= 1, "Should have at least one code block")
    }
    
    func testNestedStructures() {
        let markdown = """
        - Item 1 with **bold** text
        - Item 2 with *italic* text
        - Item 3 with `code` text
        """
        
        let result = parser.parse(markdown, language: language)
        
        XCTAssertTrue(result.errors.isEmpty, "Should not have errors: \(result.errors)")
        
        print("\n=== Nested Structure AST ===")
        printAST(result.root)
        
        let listNodes = findNodes(in: result.root, matching: .unorderedList)
        XCTAssertFalse(listNodes.isEmpty, "Should have list nodes")
        
        // Check that we have formatting within list items
        let textNodes = findTextNodes(in: result.root)
        let strongNodes = textNodes.filter { $0.bold }
        let emphasisNodes = textNodes.filter { $0.italic }
        let codeNodes = findNodes(in: result.root, matching: .code)
        
        XCTAssertTrue(strongNodes.count >= 1, "Should have strong within list")
        XCTAssertTrue(emphasisNodes.count >= 1, "Should have emphasis within list")
        XCTAssertTrue(codeNodes.count >= 1, "Should have code within list")
    }
    
    // Helper function to find nodes by element type
    func findNodes(in root: CodeNode<MarkdownNodeElement>, matching element: MarkdownNodeElement) -> [CodeNode<MarkdownNodeElement>] {
        var nodes: [CodeNode<MarkdownNodeElement>] = []
        
        if root.element == element {
            nodes.append(root)
        }
        
        for child in root.children {
            nodes.append(contentsOf: findNodes(in: child, matching: element))
        }
        
        return nodes
    }
    
    // Helper function to find heading nodes by level
    func findHeadingNodes(in root: CodeNode<MarkdownNodeElement>, level: Int) -> [HeaderNode] {
        var nodes: [HeaderNode] = []
        
        if let headerNode = root as? HeaderNode, headerNode.level == level {
            nodes.append(headerNode)
        }
        
        for child in root.children {
            nodes.append(contentsOf: findHeadingNodes(in: child, level: level))
        }
        
        return nodes
    }
    
    func findTextNodes(in root: CodeNode<MarkdownNodeElement>) -> [TextNode] {
        var nodes: [TextNode] = []
        
        if let textNode = root as? TextNode {
            nodes.append(textNode)
        }
        
        for child in root.children {
            nodes.append(contentsOf: findTextNodes(in: child))
        }
        
        return nodes
    }
    
    // Helper function to print AST structure
    func printAST(_ node: CodeNode<MarkdownNodeElement>, indent: Int = 0) {
        let indentString = String(repeating: "  ", count: indent)
        let valuePreview = String(node.value.prefix(50))
        print("\(indentString)\(node.element) - '\(valuePreview)'")
        
        if let textNode = node as? TextNode {
            print("\(indentString)  [TextNode: text='\(textNode.text)', bold=\(textNode.bold), italic=\(textNode.italic)]")
        }
        
        for child in node.children {
            printAST(child, indent: indent + 1)
        }
    }
}
