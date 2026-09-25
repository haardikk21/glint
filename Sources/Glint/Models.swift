import AppKit
import Foundation

struct ScriptCommand: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var script: String
    var keyCode: UInt32?
    var modifiers: UInt32?
}

struct Snippet: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var content: String
}

struct ClipboardEntry: Identifiable {
    let id = UUID()
    let text: String
    let date = Date()
}

enum LauncherPage { case search, snippets, emoji, files }

enum ResultKind {
    case application(URL)
    case file(URL)
    case conversion(String)
    case clipboard(String)
    case snippet(String)
    case snippetsApplet
    case emojiApplet
    case fileSearchApplet
    case terminalCommand(TerminalCommand)
    case script(ScriptCommand)
    case meeting(URL)
    case explorer(URL)
    case info
    case action(() -> Void)
}

struct SearchResult: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let kind: ResultKind
    var section: String
}
