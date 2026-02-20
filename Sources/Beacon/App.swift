import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var snapshot: SystemSnapshot = .empty

    private let monitor = SystemMonitor()
    private var pollTask: Task<Void, Never>?

    var statusColor: Color {
        snapshot.overallStatus.color
    }

    init() {
        startPolling()
    }

    deinit {
        pollTask?.cancel()
    }

    private func startPolling() {
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let newSnapshot = await self.monitor.snapshot()
                self.snapshot = newSnapshot
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }
}

@main
struct BeaconApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 12))
                Text("beacon")
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundColor(appState.statusColor)
        }
        .menuBarExtraStyle(.window)
    }
}
