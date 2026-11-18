import AppKit
import SwiftUI

struct AnalyzeView: View {
    @State private var path = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var analysis: DiskAnalysis?
    @State private var error: String?
    @State private var loading = false
    @State private var selection: DiskAnalysis.Entry.ID?
    @State private var pendingTrash: DiskAnalysis.Entry?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if loading && analysis == nil {
                ProgressView("Measuring \(displayPath)…").frame(maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView("Couldn't scan", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if let analysis {
                list(analysis)
            }
        }
        .navigationTitle("Disk Usage")
        .task(id: path) { await load() }
        .confirmationDialog(
            "Move “\(pendingTrash?.name ?? "")” to the Trash?",
            isPresented: Binding(get: { pendingTrash != nil }, set: { if !$0 { pendingTrash = nil } }),
            presenting: pendingTrash
        ) { entry in
            Button("Move to Trash", role: .destructive) { trash(entry) }
        } message: { _ in
            Text("You can restore it from the Trash later.")
        }
    }

    private var displayPath: String {
        path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }

    private var toolbar: some View {
        HStack {
            Button { go(to: (path as NSString).deletingLastPathComponent) } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(path == "/")
            Text(displayPath).font(.headline).lineLimit(1).truncationMode(.head)
            if loading { ProgressView().controlSize(.small) }
            Spacer()
            Button("Choose Folder…") { choose() }
        }
        .padding(16)
    }

    private func list(_ analysis: DiskAnalysis) -> some View {
        let largest = max(analysis.entries.map(\.size).max() ?? 1, 1)
        return List(analysis.entries, selection: $selection) { entry in
            HStack(spacing: 10) {
                Image(systemName: entry.isDir ? "folder.fill" : "doc")
                    .foregroundStyle(entry.isDir ? Color.accentColor : .secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name).lineLimit(1)
                    GeometryReader { proxy in
                        Capsule().fill(.tint.opacity(0.35))
                            .frame(width: max(2, proxy.size.width * Double(entry.size) / Double(largest)))
                    }
                    .frame(height: 4)
                }
                Text(entry.size.bytes).monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .trailing)
            }
            .contentShape(.rect)
            .onTapGesture(count: 2) { if entry.isDir { go(to: entry.path) } }
            .contextMenu {
                if entry.isDir { Button("Open") { go(to: entry.path) } }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: entry.path)])
                }
                Divider()
                Button("Move to Trash…", role: .destructive) { pendingTrash = entry }
            }
        }
    }

    private func go(to newPath: String) {
        analysis = nil
        selection = nil
        path = newPath.isEmpty ? "/" : newPath
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            let data = try await Engine.bundled.output(["analyze", "--json", path])
            analysis = try JSONDecoder.engine.decode(DiskAnalysis.self, from: data)
        } catch is CancellationError {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = URL(filePath: path)
        if panel.runModal() == .OK, let url = panel.url { go(to: url.path) }
    }

    private func trash(_ entry: DiskAnalysis.Entry) {
        do {
            try FileManager.default.trashItem(at: URL(filePath: entry.path), resultingItemURL: nil)
            analysis?.entries.removeAll { $0.id == entry.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
