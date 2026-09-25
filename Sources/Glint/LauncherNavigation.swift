import AppKit

enum LauncherNavigation {
    enum Direction { case up, down }
    enum GridDirection { case left, right, up, down }

    static func direction(for keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Direction? {
        guard modifiers.intersection([.command, .option, .control]).isEmpty else { return nil }
        switch keyCode {
        case 126: return .up
        case 125: return .down
        default: return nil
        }
    }

    static func snippetPaste(for keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool? {
        guard keyCode == 36 || keyCode == 76,
              modifiers.intersection([.command, .option, .control]).isEmpty else { return nil }
        return modifiers.contains(.shift)
    }

    static func gridDirection(for keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> GridDirection? {
        guard modifiers.intersection([.command, .option, .control]).isEmpty else { return nil }
        switch keyCode {
        case 123: return .left
        case 124: return .right
        case 125: return .down
        case 126: return .up
        default: return nil
        }
    }

    static func nextEmojiID(_ selectedID: String?, in ids: [String], columns: Int,
                            moving direction: GridDirection) -> String? {
        guard !ids.isEmpty, columns > 0 else { return nil }
        guard let selectedID, let current = ids.firstIndex(of: selectedID) else { return ids[0] }
        let next: Int
        switch direction {
        case .left: next = max(0, current - 1)
        case .right: next = min(ids.count - 1, current + 1)
        case .up: next = max(0, current - columns)
        case .down: next = current + columns < ids.count ? current + columns : current
        }
        return ids[next]
    }

    static func nextID(_ selectedID: String?, in ids: [String], moving direction: Direction) -> String? {
        guard !ids.isEmpty else { return nil }
        guard let selectedID, let current = ids.firstIndex(of: selectedID) else { return ids[0] }
        switch direction {
        case .up: return ids[max(0, current - 1)]
        case .down: return ids[min(ids.count - 1, current + 1)]
        }
    }
}

extension Notification.Name {
    static let glintNavigate = Notification.Name("dev.haardik.glint.navigate")
    static let glintSnippetAction = Notification.Name("dev.haardik.glint.snippet-action")
    static let glintEmojiAction = Notification.Name("dev.haardik.glint.emoji-action")
    static let glintEmojiNavigate = Notification.Name("dev.haardik.glint.emoji-navigate")
    static let glintFileAction = Notification.Name("dev.haardik.glint.file-action")
    static let glintBack = Notification.Name("dev.haardik.glint.back")
}
