import SwiftUI

struct CleanView: View {
    enum Phase: Equatable {
        case idle, scanning, previewed, cleaning, finished
        case failed(String)
    }

    @State private var phase: Phase = .idle
    @State private var report = CleanReport()
    @State private var log: [String] = []
    @State private var confirming = false
    @State private var job: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            switch phase {
            case .idle:
                ContentUnavailableView {
                    Label("Find reclaimable space", systemImage: "sparkles")
                } description: {
                    Text("Sapu scans caches, logs and leftovers it knows are safe to remove. Nothing is deleted until you confirm.")
                } actions: {
                    Button("Scan") { scan() }.buttonStyle(.borderedProminent).controlSize(.large)
                }
            case .failed(let message):
                ContentUnavailableView("Something went wrong", systemImage: "exclamationmark.triangle", description: Text(message))
            case .cleaning:
                LogView(lines: log)
            default:
                ReportList(report: report)
            }
        }
        .navigationTitle("Clean")
        .confirmationDialog("Clean everything in this preview?", isPresented: $confirming) {
            Button("Clean", role: .destructive) { clean() }
        } message: {
            Text("Apps rebuild their caches and logs as needed. Large items listed for reference are left untouched.")
        }
        .onDisappear { job?.cancel() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(headline).font(.headline)
                if !report.summary.isEmpty {
                    Text(report.summary.filter { !$0.hasPrefix("Detailed file list") }.joined(separator: "  ·  "))
                        .font(.callout).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            if phase == .scanning || phase == .cleaning {
                ProgressView().controlSize(.small)
                Button("Stop") { job?.cancel() }
            } else if phase != .idle {
                Button("Scan Again") { scan() }
                if phase == .previewed, report.itemCount > 0 {
                    Button("Clean…") { confirming = true }.buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(16)
    }

    private var headline: String {
        switch phase {
        case .idle: "Not scanned yet"
        case .scanning: "Scanning…"
        case .previewed: "Preview — nothing has been deleted"
        case .cleaning: "Cleaning…"
        case .finished: "Done"
        case .failed: "Failed"
        }
    }

    private func scan() {
        run(arguments: ["clean", "--dry-run"], running: .scanning, done: .previewed)
    }

    private func clean() {
        run(arguments: ["clean"], running: .cleaning, done: .finished)
    }

    private func run(arguments: [String], running: Phase, done: Phase) {
        job?.cancel()
        report = CleanReport()
        log = []
        phase = running
        job = Task {
            do {
                for try await line in Engine.bundled.lines(arguments) {
                    report.consume(line)
                    log.append(line)
                }
                phase = done
            } catch is CancellationError {
                phase = .idle
            } catch {
                phase = Task.isCancelled ? .idle : .failed(error.localizedDescription)
            }
        }
    }
}

private struct ReportList: View {
    let report: CleanReport

    var body: some View {
        List {
            if !report.preamble.isEmpty {
                Section {
                    ForEach(Array(report.preamble.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(report.sections) { section in
                Section(section.title) {
                    ForEach(section.lines) { line in
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: line.kind.symbol)
                                .foregroundStyle(line.kind.tint)
                                .frame(width: 18)
                            Text(line.title)
                            Spacer()
                            Text(line.detail)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
        }
    }
}

private struct LogView: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line).font(.system(.callout, design: .monospaced)).id(index)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: lines.count) { _, count in
                proxy.scrollTo(count - 1, anchor: .bottom)
            }
        }
    }
}

private extension CleanReport.Kind {
    var symbol: String {
        switch self {
        case .item: "circle"
        case .done: "checkmark.circle.fill"
        case .note: "exclamationmark.circle"
        case .hint: "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .item: .accentColor
        case .done: .green
        case .note: .orange
        case .hint: .secondary
        }
    }
}
