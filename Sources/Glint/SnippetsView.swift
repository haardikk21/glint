import SwiftUI

struct SnippetsView: View {
    @ObservedObject var model: LauncherModel
    @ObservedObject private var preferences: Preferences
    @State private var query: String
    @State private var selectedID: UUID?
    @FocusState private var searchFocused: Bool

    init(model: LauncherModel) {
        self.model = model
        _preferences = ObservedObject(wrappedValue: model.preferences)
        _query = State(initialValue: "")
        _selectedID = State(initialValue: nil)
    }

    private var matches: [Snippet] { SnippetSearch.matches(preferences.snippets, query: query) }
    private var selected: Snippet? { matches.first { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { model.page = .search } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Image(systemName: "text.quote").foregroundStyle(.tint)
                Text("Snippets").font(.system(size: 19, weight: .semibold))
                Spacer()
                Text("esc  Back").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22).padding(.top, 2).padding(.bottom, 16)
            Divider()
            HStack(spacing: 11) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search snippets…", text: $query)
                    .textFieldStyle(.plain).font(.system(size: 15))
                    .focused($searchFocused)
                    .onSubmit { activate(paste: false) }
            }
            .padding(.horizontal, 21).padding(.vertical, 13)
            Divider()
            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            Text("SAVED SNIPPETS  \(matches.count)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .tracking(1).foregroundStyle(.secondary)
                                .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 8)
                            ForEach(matches) { snippet in
                                Button { selectedID = snippet.id } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: "text.quote")
                                            .font(.system(size: 12)).frame(width: 18)
                                        Text(snippet.name).lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 10).padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(snippet.id == selectedID ? .white : .primary)
                                    .background(snippet.id == selectedID ? Color.accentColor : .clear,
                                                in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .accessibilityValue(snippet.id == selectedID ? "Selected" : "")
                                .id(snippet.id)
                                .padding(.horizontal, 7)
                            }
                        }
                        .padding(.bottom, 10)
                    }
                    .onChange(of: selectedID) { _, id in
                        if let id { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
                .frame(width: 225)
                .background(Color.primary.opacity(0.025))
                Divider()
                if let selected {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 17) {
                            Text(selected.name).font(.system(size: 17, weight: .semibold))
                            Text(selected.content)
                                .font(.system(size: 13, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .padding(14)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                    }
                } else {
                    ContentUnavailableView(query.isEmpty ? "No snippets yet" : "No matching snippets",
                                           systemImage: "text.quote",
                                           description: Text(query.isEmpty ?
                                                             "Add a snippet in Settings to use it here." :
                                                             "Try a different search."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider()
            HStack(spacing: 16) {
                Button("Manage Snippets") { model.openSnippetSettings?(); model.hide?() }
                    .buttonStyle(.plain)
                Spacer()
                Text("↵  Copy")
                Text("⇧↵  Copy & Paste")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .onAppear {
            selectedID = matches.first?.id
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 80_000_000)
                if model.page == .snippets { searchFocused = true }
            }
        }
        .onChange(of: query) { _, _ in selectedID = matches.first?.id }
        .onChange(of: preferences.snippets.map(\.id)) { _, ids in
            if selectedID.map({ !ids.contains($0) }) ?? true { selectedID = matches.first?.id }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glintNavigate)) { notification in
            guard let direction = notification.object as? LauncherNavigation.Direction else { return }
            let next = LauncherNavigation.nextID(selectedID?.uuidString,
                                                 in: matches.map { $0.id.uuidString }, moving: direction)
            selectedID = next.flatMap(UUID.init(uuidString:))
        }
        .onReceive(NotificationCenter.default.publisher(for: .glintSnippetAction)) { notification in
            if let paste = notification.object as? Bool { activate(paste: paste) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glintBack)) { _ in model.page = .search }
    }

    private func activate(paste: Bool) {
        guard let selected else { return }
        model.copyText(selected.content, paste: paste)
    }
}
