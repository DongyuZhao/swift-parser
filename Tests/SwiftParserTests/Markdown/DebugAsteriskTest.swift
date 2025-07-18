import XCTest
@testable import SwiftParser

final class DebugAsteriskTest: XCTestCase {
    
    func testSimpleBold() {
        let language = MarkdownLanguage.commonMark()
        let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        
        let result = parser.parse("**bold**", language: language)
        
        print("\n=== Simple Bold Test ===")
        printAST(result.root)
        
        let textNodes = findTextNodes(in: result.root)
        let boldNodes = textNodes.filter { $0.bold }
        print("Found \(boldNodes.count) bold nodes")
        
        XCTAssertTrue(boldNodes.count >= 1, "Should have at least one bold node")
    }
    
    func testListWithBold() {
        let language = MarkdownLanguage.commonMark()
        let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        
        let result = parser.parse("- Item with **bold** text", language: language)
        
        print("\n=== List with Bold Test ===")
        printAST(result.root)
        
        let textNodes = findTextNodes(in: result.root)
        let boldNodes = textNodes.filter { $0.bold }
        print("Found \(boldNodes.count) bold nodes")
        
        XCTAssertTrue(boldNodes.count >= 1, "Should have at least one bold node in list")
    }
    
    // Helper functions
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
