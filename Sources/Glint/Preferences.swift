import Foundation
import ServiceManagement

@MainActor final class Preferences: ObservableObject {
    @Published var scripts: [ScriptCommand] = [] { didSet { save(scripts, key: "scripts") } }
    @Published var snippets: [Snippet] = [] { didSet { save(snippets, key: "snippets") } }
    @Published var loginError: String?

    var startsWithMac: Bool { SMAppService.mainApp.status == .enabled }

    init() {
        scripts = load("scripts") ?? []
        snippets = load("snippets") ?? []
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch { loginError = error.localizedDescription }
        objectWillChange.send()
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
