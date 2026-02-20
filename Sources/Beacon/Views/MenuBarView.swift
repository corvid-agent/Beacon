import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(appState.statusColor)
                    .frame(width: 8, height: 8)
                Text("beacon")
                    .font(Theme.mono)
                    .foregroundColor(Theme.text)
                Spacer()
                Text(appState.snapshot.overallStatus.rawValue.uppercased())
                    .font(Theme.monoSmall)
                    .foregroundColor(appState.statusColor)
            }
            .padding(.horizontal, Theme.padding)
            .padding(.vertical, 10)

            Divider().background(Theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // CPU Section
                    sectionHeader("CPU", icon: "cpu", status: appState.snapshot.cpu.status)
                    metricRow("Usage", value: String(format: "%.1f%%", appState.snapshot.cpu.totalUsage))
                    if !appState.snapshot.cpu.perCore.isEmpty {
                        coreGrid(appState.snapshot.cpu.perCore)
                    }

                    sectionDivider()

                    // Memory Section
                    sectionHeader("Memory", icon: "memorychip", status: appState.snapshot.memory.status)
                    metricRow("Used", value: "\(ByteFormatter.format(appState.snapshot.memory.used)) / \(ByteFormatter.format(appState.snapshot.memory.total))")
                    metricRow("Usage", value: String(format: "%.1f%%", appState.snapshot.memory.usagePercent))
                    metricRow("Pressure", value: appState.snapshot.memory.pressure)

                    sectionDivider()

                    // Disk Section
                    sectionHeader("Disk", icon: "internaldrive", status: appState.snapshot.disk.status)
                    metricRow("Used", value: "\(ByteFormatter.format(appState.snapshot.disk.used)) / \(ByteFormatter.format(appState.snapshot.disk.total))")
                    metricRow("Available", value: ByteFormatter.format(appState.snapshot.disk.available))
                    metricRow("Usage", value: String(format: "%.1f%%", appState.snapshot.disk.usagePercent))

                    sectionDivider()

                    // Network Section
                    sectionHeader("Network", icon: "network", status: appState.snapshot.network.status)
                    metricRow("Status", value: appState.snapshot.network.isUp ? "Connected" : "Down")
                    if let latency = appState.snapshot.network.latencyMs {
                        metricRow("Latency", value: String(format: "%.1f ms", latency))
                    }

                    sectionDivider()

                    // Battery Section (only if battery present)
                    if appState.snapshot.battery.hasBattery {
                        sectionHeader("Battery", icon: "battery.100", status: .normal)
                        metricRow("Level", value: "\(appState.snapshot.battery.percentage)%")
                        metricRow("State", value: appState.snapshot.battery.isCharging ? "Charging" : "On Battery")
                        if let timeRemaining = appState.snapshot.battery.timeRemaining {
                            metricRow("Remaining", value: timeRemaining)
                        }

                        sectionDivider()
                    }

                    // Uptime
                    sectionHeader("Uptime", icon: "clock", status: .normal)
                    metricRow("System", value: appState.snapshot.uptimeFormatted)
                }
                .padding(.horizontal, Theme.padding)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 420)

            Divider().background(Theme.border)

            // Footer
            HStack {
                Text("refresh: 3s")
                    .font(Theme.monoSmall)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("quit")
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.padding)
            .padding(.vertical, 8)
        }
        .frame(width: Theme.windowWidth)
        .background(Theme.background)
    }

    // MARK: - Components

    private func sectionHeader(_ title: String, icon: String, status: StatusLevel) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(status.color)
            Text(title)
                .font(Theme.mono)
                .foregroundColor(Theme.text)
            Spacer()
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private func metricRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.monoSmall)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.monoSmall)
                .foregroundColor(Theme.text)
        }
        .padding(.vertical, 1)
        .padding(.leading, 18)
    }

    private func coreGrid(_ cores: [Double]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(Array(cores.enumerated()), id: \.offset) { index, usage in
                VStack(spacing: 1) {
                    Text("\(index)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.surface)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorForUsage(usage))
                                .frame(width: geo.size.width * min(1, usage / 100))
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(.leading, 18)
        .padding(.top, 2)
    }

    private func colorForUsage(_ usage: Double) -> Color {
        if usage > 90 { return .red }
        if usage > 70 { return .yellow }
        return .green
    }

    private func sectionDivider() -> some View {
        Divider()
            .background(Theme.border)
            .padding(.vertical, 4)
    }
}
