import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var model: LauncherModel
    @ObservedObject private var clipboard: ClipboardMonitor
    @State private var query: String
    @State private var selectedID: UUID?
    @FocusState private var searchFocused: Bool

    init(model: LauncherModel) {
        self.model = model
        _clipboard = ObservedObject(wrappedValue: model.clipboard)
        _query = State(initialValue: "")
        _selectedID = State(initialValue: nil)
    }

    private var matches: [ClipboardEntry] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return clipboard.entries }
        return clipboard.entries.filter { Fuzzy.score(String($0.text.prefix(500)), for: text) != nil }
    }

    private var selected: ClipboardEntry? { matches.first { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { model.goBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Image(systemName: "doc.on.clipboard").foregroundStyle(.tint)
                Text("Clipboard History").font(.system(size: 19, weight: .semibold))
                Spacer()
                Text("esc  Back").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22).padding(.top, 2).padding(.bottom, 16)
            Divider()
            HStack(spacing: 11) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search clipboard history…", text: $query)
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
                            Text("RECENT COPIES  \(matches.count)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .tracking(1).foregroundStyle(.secondary)
                                .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 8)
                            ForEach(matches) { entry in
                                Button { selectedID = entry.id } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.on.clipboard")
                                            .font(.system(size: 12)).frame(width: 18)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(String(String(entry.text.prefix(200))
                                                .replacingOccurrences(of: "\n", with: " ").prefix(55)))
                                                .lineLimit(1)
                                            Text(entry.date.formatted(date: .omitted, time: .shortened))
                                                .font(.system(size: 10))
                                                .foregroundStyle(entry.id == selectedID ? .white.opacity(0.75) : .secondary)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10).padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(entry.id == selectedID ? .white : .primary)
                                    .background(entry.id == selectedID ? Color.accentColor : .clear,
                                                in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .accessibilityValue(entry.id == selectedID ? "Selected" : "")
                                .id(entry.id)
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
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Copied \(selected.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                            Text(String(selected.text.prefix(10_000)))
                                .font(.system(size: 13))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .padding(14)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                    }
                } else {
                    ContentUnavailableView(query.isEmpty ? "History is empty" : "No matching copies",
                                           systemImage: "doc.on.clipboard",
                                           description: Text(query.isEmpty ?
                                                             "Copied text appears here while Glint is running." :
                                                             "Try a different search."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider()
            HStack(spacing: 15) {
                Button("Clear History") { clipboard.clear() }.buttonStyle(.plain)
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
                if model.page == .clipboard { searchFocused = true }
            }
        }
        .onChange(of: query) { _, _ in selectedID = matches.first?.id }
        .onChange(of: clipboard.entries.map(\.id)) { _, ids in
            if selectedID.map({ !ids.contains($0) }) ?? true { selectedID = matches.first?.id }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glintNavigate)) { notification in
            guard let direction = notification.object as? LauncherNavigation.Direction else { return }
            let next = LauncherNavigation.nextID(selectedID?.uuidString,
                                                 in: matches.map { $0.id.uuidString }, moving: direction)
            selectedID = next.flatMap(UUID.init(uuidString:))
        }
        .onReceive(NotificationCenter.default.publisher(for: .glintClipboardAction)) { notification in
            if let paste = notification.object as? Bool { activate(paste: paste) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glintBack)) { _ in model.goBack() }
    }

    private func activate(paste: Bool) {
        guard let selected else { return }
        model.copyText(selected.text, paste: paste)
    }
}
