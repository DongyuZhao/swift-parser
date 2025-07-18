import XCTest
@testable import SwiftParser

final class SimpleTokenConsumerTests: XCTestCase {
    
    func testSimpleText() {
        let language = MarkdownLanguage.commonMark()
        let parser = SwiftParser<MarkdownNodeElement, MarkdownTokenElement>()
        let result = parser.parse("Hello", language: language)
        
        print("Errors: \(result.errors)")
        print("Root children count: \(result.root.children.count)")
        
        XCTAssertTrue(result.errors.isEmpty, "Should not have errors")
    }
}
