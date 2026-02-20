import SwiftUI

// MARK: - Status Level

enum StatusLevel: String, Sendable, Equatable, Comparable {
    case normal
    case warning
    case critical

    var color: Color {
        switch self {
        case .normal: return Color.green
        case .warning: return Color.yellow
        case .critical: return Color.red
        }
    }

    private var sortOrder: Int {
        switch self {
        case .normal: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }

    static func < (lhs: StatusLevel, rhs: StatusLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - CPU Metrics

struct CPUMetrics: Sendable, Equatable {
    var totalUsage: Double
    var perCore: [Double]

    var status: StatusLevel {
        if totalUsage > 90 { return .critical }
        if totalUsage > 70 { return .warning }
        return .normal
    }

    static let empty = CPUMetrics(totalUsage: 0, perCore: [])
}

// MARK: - Memory Metrics

struct MemoryMetrics: Sendable, Equatable {
    var used: UInt64
    var total: UInt64
    var pressure: String

    var usagePercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }

    var status: StatusLevel {
        let pct = usagePercent
        if pct > 95 { return .critical }
        if pct > 80 { return .warning }
        return .normal
    }

    static let empty = MemoryMetrics(used: 0, total: 0, pressure: "nominal")
}

// MARK: - Disk Metrics

struct DiskMetrics: Sendable, Equatable {
    var used: UInt64
    var total: UInt64

    var usagePercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }

    var available: UInt64 {
        total > used ? total - used : 0
    }

    var status: StatusLevel {
        if usagePercent > 90 { return .warning }
        return .normal
    }

    static let empty = DiskMetrics(used: 0, total: 0)
}

// MARK: - Network Metrics

struct NetworkMetrics: Sendable, Equatable {
    var isUp: Bool
    var latencyMs: Double?

    var status: StatusLevel {
        if !isUp { return .critical }
        if let latency = latencyMs, latency > 200 { return .warning }
        return .normal
    }

    static let empty = NetworkMetrics(isUp: false, latencyMs: nil)
}

// MARK: - Battery Metrics

struct BatteryMetrics: Sendable, Equatable {
    var percentage: Int
    var isCharging: Bool
    var timeRemaining: String?
    var hasBattery: Bool

    static let empty = BatteryMetrics(percentage: 0, isCharging: false, timeRemaining: nil, hasBattery: false)
}

// MARK: - System Snapshot

struct SystemSnapshot: Sendable, Equatable {
    var cpu: CPUMetrics
    var memory: MemoryMetrics
    var disk: DiskMetrics
    var network: NetworkMetrics
    var battery: BatteryMetrics
    var uptime: TimeInterval

    var overallStatus: StatusLevel {
        [cpu.status, memory.status, disk.status, network.status].max() ?? .normal
    }

    var uptimeFormatted: String {
        formatUptime(uptime)
    }

    static let empty = SystemSnapshot(
        cpu: .empty,
        memory: .empty,
        disk: .empty,
        network: .empty,
        battery: .empty,
        uptime: 0
    )
}

// MARK: - Uptime Formatting

func formatUptime(_ interval: TimeInterval) -> String {
    let totalSeconds = Int(interval)
    let days = totalSeconds / 86400
    let hours = (totalSeconds % 86400) / 3600
    let minutes = (totalSeconds % 3600) / 60

    if days > 0 {
        return "\(days)d \(hours)h \(minutes)m"
    } else if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else {
        return "\(minutes)m"
    }
}
