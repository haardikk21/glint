import SwiftUI

struct FilesView: View {
    @ObservedObject var model: LauncherModel
    @State private var selectedPath: String?
    @FocusState private var searchFocused: Bool

    init(model: LauncherModel) {
        self.model = model
        _selectedPath = State(initialValue: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { model.goBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Image(systemName: "doc.text.magnifyingglass").foregroundStyle(.tint)
                Text("Search Files").font(.system(size: 19, weight: .semibold))
                Spacer()
                Text("esc  Back").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22).padding(.top, 2).padding(.bottom, 16)
            Divider()
            HStack(spacing: 11) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search files…", text: $model.fileQuery)
                    .textFieldStyle(.plain).font(.system(size: 15))
                    .focused($searchFocused)
                    .onSubmit { activate() }
            }
            .padding(.horizontal, 21).padding(.vertical, 13)
            Divider()
            if model.searchingFiles {
                ProgressView("Searching files…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.fileResults.isEmpty {
                ContentUnavailableView(model.fileQuery.count < 2 ? "Search your files" : "No files found",
                                       systemImage: "doc.text.magnifyingglass",
                                       description: Text(model.fileQuery.count < 2 ?
                                                         "Type at least two characters." :
                                                         "Try a different name."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(model.fileResults, id: \.path) { file in
                                Button {
                                    selectedPath = file.path
                                    model.openFile(file)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                                            .resizable().scaledToFit().frame(width: 26, height: 26)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(file.lastPathComponent).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                            Text(file.deletingLastPathComponent().path)
                                                .font(.system(size: 11)).lineLimit(1)
                                                .foregroundStyle(file.path == selectedPath ? .white.opacity(0.75) : .secondary)
                                        }
                                        Spacer(minLength: 0)
                                        if file.path == selectedPath { Text("↵") }
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 9)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(file.path == selectedPath ? Color.accentColor : .clear,
                                                in: RoundedRectangle(cornerRadius: 9))
                                }
                                .buttonStyle(.plain)
                                .accessibilityValue(file.path == selectedPath ? "Selected" : "")
                                .id(file.path)
                                .padding(.horizontal, 9)
                            }
                        }
                        .padding(.top, 12).padding(.bottom, 10)
                    }
                    .onChange(of: selectedPath) { _, path in
                        if let path { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(path, anchor: .center) } }
                    }
                }
            }
            Divider()
            HStack {
                Text("Spotlight · Generated directories excluded")
                Spacer()
                Text("↑↓ Navigate  ·  ↵ Open")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .onAppear {
            selectedPath = model.fileResults.first?.path
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 80_000_000)
                if model.page == .files { searchFocused = true }
            }
        }
        .onChange(of: model.fileQuery) { _, _ in selectedPath = nil }
        .onChange(of: model.fileResults.map(\.path)) { _, paths in selectedPath = paths.first }
        .onReceive(NotificationCenter.default.publisher(for: .glintNavigate)) { notification in
            guard let direction = notification.object as? LauncherNavigation.Direction else { return }
            selectedPath = LauncherNavigation.nextID(selectedPath, in: model.fileResults.map(\.path),
                                                     moving: direction)
        }
        .onReceive(NotificationCenter.default.publisher(for: .glintFileAction)) { _ in activate() }
        .onReceive(NotificationCenter.default.publisher(for: .glintBack)) { _ in model.goBack() }
    }

    private func activate() {
        guard let selectedPath, let file = model.fileResults.first(where: { $0.path == selectedPath }) else { return }
        model.openFile(file)
    }
}
