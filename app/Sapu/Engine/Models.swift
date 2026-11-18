import Foundation

// MARK: - Status (`mole status --json`)

nonisolated struct StatusSnapshot: Decodable, Sendable {
    struct Hardware: Decodable, Sendable {
        var model: String?
        var cpuModel: String?
        var totalRam: String?
        var osVersion: String?
    }

    struct CPU: Decodable, Sendable {
        var usage: Double
        var load1: Double?
        var coreCount: Int?
    }

    struct Memory: Decodable, Sendable {
        var used: Int64
        var total: Int64
        var usedPercent: Double
        var swapUsed: Int64?
        var pressure: String?
    }

    struct Disk: Decodable, Sendable, Identifiable {
        var mount: String
        var used: Int64
        var total: Int64
        var usedPercent: Double
        var external: Bool?
        var purgeable: Int64?
        var id: String { mount }

        /// The startup disk and external drives; hides system-managed volumes such as simulator runtimes.
        var isUserVisible: Bool {
            mount == "/" || (mount.hasPrefix("/Volumes/") && !mount.hasPrefix("/Library/"))
        }
    }

    struct Battery: Decodable, Sendable {
        var percent: Int
        var status: String?
        var health: String?
        var cycleCount: Int?
        var capacity: Int?
    }

    struct Process: Decodable, Sendable, Identifiable {
        var pid: Int
        var name: String
        var cpu: Double
        var memoryBytes: Int64?
        var id: Int { pid }
    }

    var host: String?
    var uptime: String?
    var hardware: Hardware?
    var healthScore: Int?
    var healthScoreMsg: String?
    var cpu: CPU?
    var memory: Memory?
    var disks: [Disk]?
    var batteries: [Battery]?
    var topProcesses: [Process]?
}

// MARK: - Analyze (`mole analyze --json <path>`)

nonisolated struct DiskAnalysis: Decodable, Sendable {
    struct Entry: Decodable, Sendable, Identifiable, Hashable {
        var name: String
        var path: String
        var size: Int64
        var isDir: Bool
        var lastAccess: Date?
        var id: String { path }
    }

    var path: String
    var scanStatus: String?
    var entries: [Entry]
}

nonisolated extension JSONDecoder {
    static let engine: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date: \(text)"))
        }
        return decoder
    }()
}

// MARK: - Clean (`mole clean [--dry-run]` text output)

nonisolated struct CleanReport: Sendable {
    enum Kind: Sendable {
        case item      // ○ reclaimable target
        case done      // ✓ cleaned / nothing to clean
        case note      // ◎ skipped or needs permission
        case hint      // ⊙ large item reported but not cleaned automatically
    }

    struct Line: Sendable, Identifiable {
        let id: Int
        var kind: Kind
        var title: String
        var detail: String
    }

    struct Section: Sendable, Identifiable {
        let id: Int
        var title: String
        var lines: [Line] = []
    }

    var sections: [Section] = []
    var preamble: [String] = []
    var summary: [String] = []
    private var counter = 0
    private var inSummary = false

    /// Feeds one line of engine output into the report.
    mutating func consume(_ raw: String) {
        let line = raw.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return }

        if line.hasPrefix("====") {
            inSummary.toggle()
            return
        }
        if inSummary {
            summary.append(line)
            return
        }
        if line.hasPrefix("➤") {
            counter += 1
            sections.append(Section(id: counter, title: String(line.dropFirst()).trimmingCharacters(in: .whitespaces)))
            return
        }

        let kinds: [(String, Kind)] = [("○", .item), ("✓", .done), ("◎", .note), ("⊙", .hint)]
        for (symbol, kind) in kinds where line.hasPrefix(symbol) {
            let body = String(line.dropFirst(symbol.count)).trimmingCharacters(in: .whitespaces)
            let parts = body.components(separatedBy: " · ")
            counter += 1
            let entry = Line(
                id: counter,
                kind: kind,
                title: parts.first ?? body,
                detail: parts.dropFirst().joined(separator: " · ")
                    .replacing(/\sdry$/, with: "")
            )
            if sections.isEmpty {
                preamble.append(body)
            } else {
                sections[sections.count - 1].lines.append(entry)
            }
            return
        }

        if sections.isEmpty {
            preamble.append(line)
        }
    }

    var itemCount: Int {
        sections.reduce(0) { $0 + $1.lines.count(where: { $0.kind == .item }) }
    }
}
