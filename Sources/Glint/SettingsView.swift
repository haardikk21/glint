import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: LauncherModel
    @ObservedObject private var calendar: CalendarService
    @State private var scriptName: String
    @State private var scriptBody: String
    @State private var shortcutCode: UInt32?
    @State private var shortcutModifiers: UInt32?
    @State private var shortcutLabel: String
    @State private var snippetName: String
    @State private var snippetBody: String

    init(model: LauncherModel) {
        self.model = model
        _calendar = ObservedObject(wrappedValue: model.calendar)
        _scriptName = State(initialValue: "")
        _scriptBody = State(initialValue: "")
        _shortcutLabel = State(initialValue: "")
        _snippetName = State(initialValue: "")
        _snippetBody = State(initialValue: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $model.settingsTab) {
                Text("General").tag(0)
                Text("Scripts").tag(1)
                Text("Snippets").tag(2)
            }
            .pickerStyle(.segmented)
            if model.settingsTab == 0 { general }
            if model.settingsTab == 1 { scripts }
            if model.settingsTab == 2 { snippets }
            Spacer(minLength: 0)
        }
        .padding(24).frame(width: 540, height: 520)
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle("Launch Glint at login", isOn: Binding(
                get: { model.preferences.startsWithMac },
                set: { model.preferences.setLaunchAtLogin($0) }
            ))
            if let error = model.preferences.loginError { Text(error).foregroundStyle(.red).font(.caption) }
            LabeledContent("Open launcher", value: "⌥ Space")
            Divider()
            Text("Calendar").font(.headline)
            Text("Use your macOS calendars, including synced Google accounts. Glint shows a join link from two minutes before a meeting starts until it ends.")
                .font(.caption).foregroundStyle(.secondary)
            if calendar.authorized {
                Label("Calendar access enabled", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("Allow Calendar Access") {
                    Task { await calendar.requestAccess() }
                }
            }
            if let status = calendar.status { Text(status).font(.caption).foregroundStyle(.secondary) }
            Divider()
            Button("Clear clipboard history") { model.clipboard.clear() }
            Text("Clipboard history is kept in memory and cleared when Glint quits.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scripts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run a bash command from search or a global shortcut").font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("Command name", text: $scriptName)
                ShortcutRecorder { code, modifiers, label in
                    shortcutCode = code
                    shortcutModifiers = modifiers
                    shortcutLabel = label
                }.frame(width: 210, height: 30)
            }
            TextEditor(text: $scriptBody).font(.system(.body, design: .monospaced))
                .frame(height: 100).overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            HStack {
                if !shortcutLabel.isEmpty { Text("Shortcut: \(shortcutLabel)").font(.caption) }
                Spacer()
                Button("Add command") {
                    model.preferences.scripts.append(ScriptCommand(name: scriptName.trimmingCharacters(in: .whitespaces),
                                                                    script: scriptBody, keyCode: shortcutCode,
                                                                    modifiers: shortcutModifiers))
                    scriptName = ""; scriptBody = ""; shortcutCode = nil; shortcutModifiers = nil; shortcutLabel = ""
                }
                .disabled(scriptName.trimmingCharacters(in: .whitespaces).isEmpty || scriptBody.isEmpty)
            }
            Divider()
            ScrollView {
                ForEach(model.preferences.scripts) { command in
                    HStack {
                        Image(systemName: "terminal")
                        VStack(alignment: .leading) {
                            Text(command.name)
                            Text(command.script).lineLimit(1).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { model.preferences.scripts.removeAll { $0.id == command.id } } label: {
                            Image(systemName: "trash")
                        }.buttonStyle(.borderless)
                    }.padding(.vertical, 4)
                }
            }
            if let warning = model.message, warning.contains("shortcut unavailable") {
                Text(warning).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private var snippets: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find a snippet by name or content, then press Return to copy it.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Snippet name", text: $snippetName)
            TextEditor(text: $snippetBody).frame(height: 110)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            HStack {
                Spacer()
                Button("Add snippet") {
                    model.preferences.snippets.append(Snippet(name: snippetName.trimmingCharacters(in: .whitespaces),
                                                              content: snippetBody))
                    snippetName = ""; snippetBody = ""
                }.disabled(snippetName.trimmingCharacters(in: .whitespaces).isEmpty || snippetBody.isEmpty)
            }
            Divider()
            ScrollView {
                ForEach(model.preferences.snippets) { snippet in
                    HStack {
                        Image(systemName: "text.quote")
                        VStack(alignment: .leading) {
                            Text(snippet.name)
                            Text(snippet.content).lineLimit(1).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { model.preferences.snippets.removeAll { $0.id == snippet.id } } label: {
                            Image(systemName: "trash")
                        }.buttonStyle(.borderless)
                    }.padding(.vertical, 4)
                }
            }
        }
    }
}
