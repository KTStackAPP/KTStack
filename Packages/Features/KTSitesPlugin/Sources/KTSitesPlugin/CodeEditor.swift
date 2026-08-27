import Foundation

enum CodeEditor: String, CaseIterable, Identifiable {
    case vscode = "com.microsoft.VSCode"
    case cursor = "com.todesktop.230313mzl4w4u92"
    case phpstorm = "com.jetbrains.PhpStorm"
    case zed = "dev.zed.Zed"
    case sublime = "com.sublimetext.4"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vscode: "VS Code"
        case .cursor: "Cursor"
        case .phpstorm: "PhpStorm"
        case .zed: "Zed"
        case .sublime: "Sublime Text"
        }
    }

    var symbol: String {
        switch self {
        case .vscode, .cursor: "chevron.left.forwardslash.chevron.right"
        case .phpstorm: "hammer"
        case .zed: "bolt"
        case .sublime: "text.cursor"
        }
    }
}

struct CodeEditorCatalog {
    static let preferredKey = "KTStack.preferredEditor"

    let installed: [CodeEditor]
    private let locate: (String) -> URL?
    private let defaults: UserDefaults

    init(locate: @escaping (String) -> URL?, defaults: UserDefaults = .standard) {
        self.locate = locate
        self.defaults = defaults
        installed = CodeEditor.allCases.filter { locate($0.rawValue) != nil }
    }

    func preferred() -> CodeEditor? {
        if let stored = defaults.string(forKey: Self.preferredKey),
           let editor = CodeEditor(rawValue: stored),
           installed.contains(editor) {
            return editor
        }
        return installed.first
    }

    func setPreferred(_ editor: CodeEditor) {
        defaults.set(editor.rawValue, forKey: Self.preferredKey)
    }

    func appURL(_ editor: CodeEditor) -> URL? {
        locate(editor.rawValue)
    }
}
