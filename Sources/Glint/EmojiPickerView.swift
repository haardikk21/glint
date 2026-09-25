import SwiftUI

struct EmojiPickerView: View {
    @ObservedObject var model: LauncherModel
    @State private var query: String
    @State private var selectedID: String?
    @FocusState private var searchFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(minimum: 44), spacing: 5), count: 9)

    init(model: LauncherModel) {
        self.model = model
        _query = State(initialValue: "")
        _selectedID = State(initialValue: nil)
    }

    private var matches: [EmojiItem] { EmojiSearch.matches(EmojiCatalog.all, query: query) }
    private var selected: EmojiItem? { matches.first { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { model.page = .search } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Image(systemName: "face.smiling").foregroundStyle(.tint)
                Text("Emoji Picker").font(.system(size: 19, weight: .semibold))
                Spacer()
                Text("esc  Back").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22).padding(.top, 2).padding(.bottom, 16)
            Divider()
            HStack(spacing: 11) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search emoji by name or keyword…", text: $query)
                    .textFieldStyle(.plain).font(.system(size: 15))
                    .focused($searchFocused)
                    .onSubmit { activate(paste: false) }
            }
            .padding(.horizontal, 21).padding(.vertical, 13)
            Divider()
            HStack {
                Text(query.isEmpty ? "ALL EMOJI" : "MATCHING EMOJI")
                    .tracking(1)
                Spacer()
                Text("\(matches.count)")
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 21).padding(.top, 14).padding(.bottom, 9)
            if matches.isEmpty {
                ContentUnavailableView("No emoji found", systemImage: "face.smiling",
                                       description: Text("Try another name or keyword."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 5) {
                            ForEach(matches) { item in
                                Button {
                                    selectedID = item.id
                                    activate(paste: false)
                                } label: {
                                    Text(item.symbol)
                                        .font(.system(size: 29))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(item.id == selectedID ? Color.accentColor.opacity(0.4) : .clear,
                                                    in: RoundedRectangle(cornerRadius: 9))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(item.name)
                                .accessibilityValue(item.id == selectedID ? "Selected" : "")
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 19).padding(.bottom, 14)
                    }
                    .onChange(of: selectedID) { _, id in
                        if let id { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
            }
            Divider()
            HStack(spacing: 12) {
                if let selected {
                    Text(selected.symbol).font(.system(size: 32)).frame(width: 45)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selected.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        Text(selected.keywords.isEmpty ? "Press Return to copy" : selected.keywords)
                            .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Text("↵ Copy  ·  ⇧↵ Copy & Paste")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
        }
        .onAppear {
            selectedID = matches.first?.id
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 80_000_000)
                if model.page == .emoji { searchFocused = true }
            }
        }
        .onChange(of: query) { _, _ in selectedID = matches.first?.id }
        .onReceive(NotificationCenter.default.publisher(for: .glintEmojiNavigate)) { notification in
            guard let direction = notification.object as? LauncherNavigation.GridDirection else { return }
            selectedID = LauncherNavigation.nextEmojiID(selectedID, in: matches.map(\.id),
                                                       columns: columns.count, moving: direction)
        }
        .onReceive(NotificationCenter.default.publisher(for: .glintEmojiAction)) { notification in
            if let paste = notification.object as? Bool { activate(paste: paste) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glintBack)) { _ in model.page = .search }
    }

    private func activate(paste: Bool) {
        guard let selected else { return }
        model.copyText(selected.symbol, paste: paste)
    }
}
