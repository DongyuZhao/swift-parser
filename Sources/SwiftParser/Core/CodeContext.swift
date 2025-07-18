import Foundation

public struct CodeContext<Node: CodeNodeElement> {
    public var current: CodeNode<Node>
    public var errors: [CodeError] = []

    public init(current: CodeNode<Node>) {
        self.current = current
    }
}
