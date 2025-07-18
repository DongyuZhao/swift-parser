import Foundation

public final class CodeParser {
    private var consumers: [CodeTokenConsumer]
    private let tokenizer: CodeTokenizer

    // Registered state is now reset for each parse run

    public init(language: CodeLanguage) {
        self.tokenizer = language.tokenizer
        self.consumers = language.consumers
    }



    public func parse(_ input: String, rootNode: CodeNode) -> (node: CodeNode, context: CodeContext) {
        let tokens = tokenizer.tokenize(input)
        var context = CodeContext(tokens: tokens, currentNode: rootNode, errors: [])

        // Infinite loop protection: track token count progression
        var lastCount = context.tokens.count + 1

        while let token = context.tokens.first {
            // Infinite loop detection - if token count hasn't decreased, terminate parsing immediately
            if context.tokens.count == lastCount {
                context.errors.append(CodeError("Infinite loop detected: parser stuck at token \(token.kindDescription). Terminating parse to prevent hang.", range: token.range))
                break
            }
            lastCount = context.tokens.count

            if token.kindDescription == "eof" {
                break
            }
            var matched = false
            for consumer in consumers {
                if consumer.consume(context: &context, token: token) {
                    matched = true
                    break
                }
            }

            if !matched {
                context.errors.append(CodeError("Unrecognized token \(token.kindDescription)", range: token.range))
                context.tokens.removeFirst()
            }
        }

        return (rootNode, context)
    }
}
