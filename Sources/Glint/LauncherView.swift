import SwiftUI

struct LauncherView: View {
    @ObservedObject var model: LauncherModel
    @State private var selectedID: String?
    @FocusState private var searchFocused: Bool

    init(model: LauncherModel) {
        self.model = model
        _selectedID = State(initialValue: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 22, weight: .medium)).foregroundStyle(.tint)
                TextField("Search apps, files, commands, or convert…", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 21))
                    .focused($searchFocused)
                    .onSubmit { activate() }
                    .onMoveCommand { direction in
                        if direction == .down { navigate(.down) }
                        if direction == .up { navigate(.up) }
                    }
                if !model.query.isEmpty {
                    Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 22).padding(.top, 2).padding(.bottom, 19)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                            if index == 0 || result.section != model.results[index - 1].section {
                                Text(result.section.uppercased())
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .tracking(1.1).foregroundStyle(.secondary)
                                    .padding(.leading, 19).padding(.top, index == 0 ? 14 : 16).padding(.bottom, 5)
                            }
                            Button {
                                selectedID = result.id
                                model.execute(result)
                            } label: {
                                HStack(spacing: 13) {
                                    resultIcon(result)
                                        .frame(width: 30, height: 26)
                                        .foregroundStyle(result.id == selectedID ? .white : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                                        Text(result.subtitle).font(.system(size: 11)).lineLimit(1)
                                            .foregroundStyle(result.id == selectedID ? .white.opacity(0.75) : .secondary)
                                    }
                                    Spacer()
                                    if result.id == selectedID {
                                        Text("↵").font(.system(size: 16)).foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(result.id == selectedID ? Color.accentColor : .clear,
                                            in: RoundedRectangle(cornerRadius: 9))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(result.id == selectedID ? .isSelected : [])
                            .accessibilityValue(result.id == selectedID ? "Selected" : "")
                            .id(result.id)
                            .padding(.horizontal, 9)
                        }
                        if model.results.isEmpty {
                            ContentUnavailableView(model.query.isEmpty ? "Start typing" : "No results",
                                                   systemImage: "magnifyingglass",
                                                   description: Text(model.query.isEmpty ?
                                                                     "Search apps, files, conversions or paste a hash" :
                                                                     "Try a different search"))
                                .frame(maxWidth: .infinity).padding(.top, 65)
                        }
                    }
                    .padding(.bottom, 12)
                }
                .onChange(of: selectedID) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .center) } }
                }
                .onChange(of: model.results.first?.id) { _, id in
                    if let id, selectedID == nil { proxy.scrollTo(id, anchor: .top) }
                }
                .onChange(of: model.presentationID) { _, _ in
                    selectedID = nil
                    if let id = model.results.first?.id { proxy.scrollTo(id, anchor: .top) }
                    searchFocused = true
                }
            }
            Divider()
            HStack {
                Text(model.message ?? "⌥ Space to toggle · ↑↓ to navigate")
                Spacer()
                Button("Settings  ⌘,") { model.openSettings?(); model.hide?() }
                    .buttonStyle(.plain)
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .frame(width: 660, height: 490)
        .background(.regularMaterial)
        .onAppear { searchFocused = true }
        .onChange(of: model.query) { _, value in selectedID = value.isEmpty ? nil : model.results.first?.id }
        .onChange(of: model.results.map(\.id)) { _, ids in
            if !model.query.isEmpty && (selectedID.map { !ids.contains($0) } ?? true) {
                selectedID = ids.first
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glintNavigate)) { notification in
            if let direction = notification.object as? LauncherNavigation.Direction { navigate(direction) }
        }
        .onExitCommand { model.hide?() }
        .background(KeyboardCommandView(onSettings: { model.openSettings?(); model.hide?() }))
    }

    private func activate() {
        guard let selectedID, let result = model.results.first(where: { $0.id == selectedID }) else { return }
        model.execute(result)
    }

    private func navigate(_ direction: LauncherNavigation.Direction) {
        selectedID = LauncherNavigation.nextID(selectedID, in: model.results.map(\.id), moving: direction)
    }

    @ViewBuilder private func resultIcon(_ result: SearchResult) -> some View {
        switch result.kind {
        case .application(let url), .file(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable().scaledToFit().frame(width: 25, height: 25)
        default:
            Image(systemName: result.symbol).font(.system(size: 18))
        }
    }
}

private struct KeyboardCommandView: View {
    let onSettings: () -> Void
    var body: some View {
        Button("Settings", action: onSettings).keyboardShortcut(",", modifiers: .command).hidden()
    }
}
