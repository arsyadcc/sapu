import SwiftUI

@main
struct SapuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 860, minHeight: 560)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            AboutView()
        }
    }
}

enum Pane: String, CaseIterable, Identifiable {
    case status, clean, analyze

    var id: Self { self }

    var title: String {
        switch self {
        case .status: "Status"
        case .clean: "Clean"
        case .analyze: "Disk Usage"
        }
    }

    var symbol: String {
        switch self {
        case .status: "gauge.with.dots.needle.67percent"
        case .clean: "sparkles"
        case .analyze: "chart.pie"
        }
    }
}

struct ContentView: View {
    @State private var pane: Pane? = .status

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $pane) { pane in
                Label(pane.title, systemImage: pane.symbol)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch pane ?? .status {
            case .status: StatusView()
            case .clean: CleanView()
            case .analyze: AnalyzeView()
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sapu").font(.title.bold())
            Text("A free, open-source Mac cleaner.")
            Text("Sapu is licensed under GPL-3.0. Its cleanup engine is based on Mole by tw93 (github.com/tw93/Mole), also GPL-3.0. Sapu is not affiliated with or endorsed by the Mole project.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 420)
    }
}
