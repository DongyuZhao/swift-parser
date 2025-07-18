import Foundation

/// Consumes a token and optionally updates the AST if it is recognized.
public protocol CodeTokenConsumer<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    associatedtype Node: CodeNodeElement
    associatedtype Token: CodeTokenElement

    func consume(context: inout CodeContext<Node>, token: any CodeToken<Token>) -> Bool
}
