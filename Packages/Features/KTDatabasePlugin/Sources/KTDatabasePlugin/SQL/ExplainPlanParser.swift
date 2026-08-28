import Foundation

public struct ExplainNode: Identifiable, Equatable {
    public let id: Int
    public let text: String
    public var children: [ExplainNode]

    public init(id: Int, text: String, children: [ExplainNode] = []) {
        self.id = id
        self.text = text
        self.children = children
    }
}

// Dựng cây từ text-plan một cột (MySQL FORMAT=TREE, Postgres EXPLAIN): độ sâu theo số khoảng trắng đầu dòng.
// Trả nil khi kết quả không phải một cột text (vd EXPLAIN dạng bảng nhiều cột) để UI hiển thị lưới thô.
public enum ExplainPlanParser {
    public static func parse(_ result: QueryResult) -> [ExplainNode]? {
        guard result.columns.count == 1 else { return nil }
        let lines = result.rows
            .compactMap { $0.first?.displayText }
            .flatMap { $0.components(separatedBy: "\n") }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return nil }
        return build(lines)
    }

    private static func build(_ lines: [String]) -> [ExplainNode] {
        var roots: [ExplainNode] = []
        var stack: [(indent: Int, id: Int)] = []
        var nodesByID: [Int: ExplainNode] = [:]
        var nextID = 0

        for line in lines {
            let indent = leadingSpaces(line)
            let node = ExplainNode(id: nextID, text: clean(line))
            nodesByID[node.id] = node

            while let last = stack.last, last.indent >= indent { stack.removeLast() }
            if let parent = stack.last {
                nodesByID[parent.id]?.children.append(node)
            } else {
                roots.append(node)
            }
            stack.append((indent, node.id))
            nextID += 1
        }
        // children đã gắn vào bản sao trong nodesByID; ráp lại cây từ gốc.
        return roots.map { assemble($0.id, from: nodesByID) }
    }

    private static func assemble(_ id: Int, from nodes: [Int: ExplainNode]) -> ExplainNode {
        guard let node = nodes[id] else { return ExplainNode(id: id, text: "") }
        return ExplainNode(id: id, text: node.text, children: node.children.map { assemble($0.id, from: nodes) })
    }

    private static func leadingSpaces(_ line: String) -> Int {
        line.prefix { $0 == " " || $0 == "\t" }.count
    }

    private static func clean(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("->") { text.removeFirst(2) }
        return text.trimmingCharacters(in: .whitespaces)
    }
}
