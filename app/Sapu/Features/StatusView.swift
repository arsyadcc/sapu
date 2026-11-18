import SwiftUI

struct StatusView: View {
    @State private var snapshot: StatusSnapshot?
    @State private var error: String?

    var body: some View {
        ScrollView {
            if let snapshot {
                content(snapshot)
                    .padding(24)
            } else if let error {
                ContentUnavailableView("Couldn't read status", systemImage: "exclamationmark.triangle", description: Text(error))
                    .padding(.top, 80)
            } else {
                ProgressView("Reading system status…")
                    .padding(.top, 120)
            }
        }
        .navigationTitle("Status")
        .task { await poll() }
    }

    private func poll() async {
        while !Task.isCancelled {
            do {
                let data = try await Engine.bundled.output(["status", "--json"])
                snapshot = try JSONDecoder.engine.decode(StatusSnapshot.self, from: data)
                error = nil
            } catch is CancellationError {
                return
            } catch {
                if snapshot == nil { self.error = error.localizedDescription }
            }
            try? await Task.sleep(for: .seconds(10))
        }
    }

    @ViewBuilder
    private func content(_ s: StatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.hardware?.model ?? s.host ?? "This Mac").font(.title2.bold())
                    Text([s.hardware?.cpuModel, s.hardware?.totalRam, s.hardware?.osVersion]
                        .compactMap { $0 }.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                    if let uptime = s.uptime {
                        Text("Up \(uptime)").foregroundStyle(.secondary).font(.callout)
                    }
                }
                Spacer()
                if let score = s.healthScore {
                    HealthBadge(score: score, message: s.healthScoreMsg)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                if let cpu = s.cpu {
                    MetricCard(title: "CPU", value: cpu.usage / 100,
                               caption: String(format: "%.0f%% · load %.1f", cpu.usage, cpu.load1 ?? 0))
                }
                if let memory = s.memory {
                    MetricCard(title: "Memory", value: memory.usedPercent / 100,
                               caption: "\(memory.used.bytes) of \(memory.total.bytes) · \(memory.pressure ?? "")")
                }
                ForEach((s.disks ?? []).filter(\.isUserVisible)) { disk in
                    MetricCard(title: disk.mount == "/" ? "Macintosh HD" : disk.mount,
                               value: disk.usedPercent / 100,
                               caption: "\((disk.total - disk.used).bytes) free of \(disk.total.bytes)")
                }
                if let battery = s.batteries?.first {
                    MetricCard(title: "Battery", value: Double(battery.percent) / 100,
                               caption: [battery.status, battery.cycleCount.map { "\($0) cycles" }, battery.health]
                                   .compactMap { $0 }.joined(separator: " · "))
                }
            }

            if let processes = s.topProcesses, !processes.isEmpty {
                GroupBox("Top processes") {
                    Table(processes) {
                        TableColumn("Name", value: \.name)
                        TableColumn("CPU") { Text(String(format: "%.1f%%", $0.cpu)).monospacedDigit() }
                            .width(70)
                        TableColumn("Memory") { Text(($0.memoryBytes ?? 0).bytes).monospacedDigit() }
                            .width(90)
                    }
                    .frame(height: 180)
                }
            }
        }
    }
}

private struct HealthBadge: View {
    let score: Int
    let message: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(score)")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(score >= 80 ? .green : score >= 60 ? .orange : .red)
            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: Double
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Gauge(value: min(max(value, 0), 1)) { EmptyView() }
                .gaugeStyle(.linearCapacity)
                .tint(value > 0.9 ? .red : value > 0.75 ? .orange : .accentColor)
            Text(caption).font(.callout).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
    }
}

extension Int64 {
    var bytes: String { formatted(.byteCount(style: .file)) }
}
