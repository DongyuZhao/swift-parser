import Foundation

public final class CodeParser<Node: CodeNodeElement, Token: CodeTokenElement> where Node: CodeNodeElement, Token: CodeTokenElement {
    private var consumers: [any CodeTokenConsumer<Node, Token>]
    private let tokenizer: any CodeTokenizer<Token>

    public init(language: any CodeLanguage<Node, Token>) {
        self.tokenizer = language.tokenizer
        self.consumers = language.consumers
    }

    public func parse(_ input: String, rootNode: CodeNode<Node>) -> (node: CodeNode<Node>, context: CodeContext<Node>) {
        let normalizedInput = normalizeInput(input)
        let tokens = tokenizer.tokenize(normalizedInput)
        var context = CodeContext(current: rootNode)

        for token in tokens {
            var matched = false
            for consumer in consumers {
                if consumer.consume(context: &context, token: token) {
                    matched = true
                    break
                }
            }

            if !matched {
                context.errors.append(CodeError("Unrecognized token \(token.element)", range: token.range))
            }
        }

        return (rootNode, context)
    }

    /// Normalizes input string to handle line ending inconsistencies and other common issues
    /// This ensures consistent behavior across different platforms and input sources
    private func normalizeInput(_ input: String) -> String {
        // Normalize line endings: Convert CRLF (\r\n) and CR (\r) to LF (\n)
        // This prevents issues with different line ending conventions
        return input
            .replacingOccurrences(of: "\r\n", with: "\n")  // Windows CRLF -> Unix LF
            .replacingOccurrences(of: "\r", with: "\n")    // Classic Mac CR -> Unix LF
    }
}
