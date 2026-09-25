import AppKit

enum LauncherNavigation {
    enum Direction { case up, down }

    static func direction(for keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Direction? {
        guard modifiers.intersection([.command, .option, .control]).isEmpty else { return nil }
        switch keyCode {
        case 126: return .up
        case 125: return .down
        default: return nil
        }
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
}
