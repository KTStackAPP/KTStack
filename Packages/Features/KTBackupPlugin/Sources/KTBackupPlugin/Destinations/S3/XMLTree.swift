import Foundation

public final class XMLTree: @unchecked Sendable {
    public let name: String
    public internal(set) var text: String
    public internal(set) var children: [XMLTree]

    init(name: String) {
        self.name = name
        text = ""
        children = []
    }

    public func child(_ name: String) -> XMLTree? {
        children.first { $0.name == name }
    }

    public func children(_ name: String) -> [XMLTree] {
        children.filter { $0.name == name }
    }

    public func value(_ name: String) -> String? {
        child(name)?.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func parse(_ data: Data) -> XMLTree? {
        let builder = XMLTreeBuilder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        parser.shouldProcessNamespaces = true
        return parser.parse() ? builder.root : nil
    }
}

private final class XMLTreeBuilder: NSObject, XMLParserDelegate {
    var root: XMLTree?
    private var stack: [XMLTree] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let node = XMLTree(name: elementName)
        stack.last?.children.append(node)
        if root == nil { root = node }
        stack.append(node)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        stack.removeLast()
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.text += string
    }
}
