import Foundation

public protocol CodeLanguage<Node, Token> where Node: CodeNodeElement, Token: CodeTokenElement {
    associatedtype Node: CodeNodeElement
    associatedtype Token: CodeTokenElement

    var tokenizer: any CodeTokenizer<Token> { get }
    var consumers: [any CodeTokenConsumer<Node, Token>] { get }

    func root() -> CodeNode<Node>
}
