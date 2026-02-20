import Foundation
@testable import Beacon

// MARK: - Test Helpers

var totalTests = 0
var passedTests = 0

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", file: String = #file, line: Int = #line) {
    totalTests += 1
    guard a == b else {
        print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)")
        return
    }
    passedTests += 1
    print("PASS: \(msg)")
}

func assertTrue(_ condition: Bool, _ msg: String = "", file: String = #file, line: Int = #line) {
    totalTests += 1
    guard condition else {
        print("FAIL [\(file):\(line)] \(msg) — expected true")
        return
    }
    passedTests += 1
    print("PASS: \(msg)")
}

// MARK: - StatusLevel Tests

func testStatusLevelComparison() {
    print("\n--- StatusLevel Tests ---")
    assertTrue(StatusLevel.normal < StatusLevel.warning, "normal < warning")
    assertTrue(StatusLevel.warning < StatusLevel.critical, "warning < critical")
    assertTrue(StatusLevel.normal < StatusLevel.critical, "normal < critical")
    assertEqual(StatusLevel.normal, StatusLevel.normal, "normal == normal")
}

// MARK: - CPU Metrics Tests

func testCPUStatus() {
    print("\n--- CPU Status Tests ---")
    let low = CPUMetrics(totalUsage: 30, perCore: [30, 30])
    assertEqual(low.status, .normal, "CPU 30% = normal")

    let med = CPUMetrics(totalUsage: 75, perCore: [75, 75])
    assertEqual(med.status, .warning, "CPU 75% = warning")

    let high = CPUMetrics(totalUsage: 95, perCore: [95, 95])
    assertEqual(high.status, .critical, "CPU 95% = critical")

    let boundary70 = CPUMetrics(totalUsage: 70, perCore: [])
    assertEqual(boundary70.status, .normal, "CPU 70% = normal (boundary)")

    let boundary71 = CPUMetrics(totalUsage: 70.1, perCore: [])
    assertEqual(boundary71.status, .warning, "CPU 70.1% = warning (boundary)")

    let boundary90 = CPUMetrics(totalUsage: 90, perCore: [])
    assertEqual(boundary90.status, .warning, "CPU 90% = warning (boundary)")

    let boundary91 = CPUMetrics(totalUsage: 90.1, perCore: [])
    assertEqual(boundary91.status, .critical, "CPU 90.1% = critical (boundary)")
}

// MARK: - Memory Metrics Tests

func testMemoryMetrics() {
    print("\n--- Memory Metrics Tests ---")
    let mem = MemoryMetrics(used: 8_000_000_000, total: 16_000_000_000, pressure: "nominal")
    assertEqual(mem.usagePercent, 50.0, "Memory 50% usage")
    assertEqual(mem.status, .normal, "Memory 50% = normal")

    let highMem = MemoryMetrics(used: 14_000_000_000, total: 16_000_000_000, pressure: "warn")
    assertTrue(highMem.usagePercent > 80, "Memory >80%")
    assertEqual(highMem.status, .warning, "Memory 87.5% = warning")

    let critMem = MemoryMetrics(used: 15_500_000_000, total: 16_000_000_000, pressure: "critical")
    assertTrue(critMem.usagePercent > 95, "Memory >95%")
    assertEqual(critMem.status, .critical, "Memory 96.9% = critical")

    let zeroMem = MemoryMetrics(used: 0, total: 0, pressure: "nominal")
    assertEqual(zeroMem.usagePercent, 0.0, "Memory 0/0 = 0%")
}

// MARK: - Disk Metrics Tests

func testDiskMetrics() {
    print("\n--- Disk Metrics Tests ---")
    let disk = DiskMetrics(used: 200_000_000_000, total: 500_000_000_000)
    assertEqual(disk.usagePercent, 40.0, "Disk 40% usage")
    assertEqual(disk.available, 300_000_000_000, "Disk available = 300GB")
    assertEqual(disk.status, .normal, "Disk 40% = normal")

    let fullDisk = DiskMetrics(used: 460_000_000_000, total: 500_000_000_000)
    assertTrue(fullDisk.usagePercent > 90, "Disk >90%")
    assertEqual(fullDisk.status, .warning, "Disk 92% = warning")
}

// MARK: - Network Metrics Tests

func testNetworkMetrics() {
    print("\n--- Network Metrics Tests ---")
    let up = NetworkMetrics(isUp: true, latencyMs: 12.5)
    assertEqual(up.status, .normal, "Network up with low latency = normal")

    let slow = NetworkMetrics(isUp: true, latencyMs: 250.0)
    assertEqual(slow.status, .warning, "Network up with high latency = warning")

    let down = NetworkMetrics(isUp: false, latencyMs: nil)
    assertEqual(down.status, .critical, "Network down = critical")
}

// MARK: - ByteFormatter Tests

func testByteFormatter() {
    print("\n--- ByteFormatter Tests ---")
    assertEqual(ByteFormatter.format(UInt64(0)), "0 B", "0 bytes")
    assertEqual(ByteFormatter.format(UInt64(512)), "512 B", "512 bytes")
    assertEqual(ByteFormatter.format(UInt64(1024)), "1.0 KB", "1 KB")
    assertEqual(ByteFormatter.format(UInt64(1536)), "1.5 KB", "1.5 KB")
    assertEqual(ByteFormatter.format(UInt64(1_048_576)), "1.0 MB", "1 MB")
    assertEqual(ByteFormatter.format(UInt64(1_073_741_824)), "1.0 GB", "1 GB")
    assertEqual(ByteFormatter.format(UInt64(1_099_511_627_776)), "1.0 TB", "1 TB")
}

// MARK: - Uptime Formatting Tests

func testUptimeFormatting() {
    print("\n--- Uptime Formatting Tests ---")
    assertEqual(formatUptime(0), "0m", "0 seconds")
    assertEqual(formatUptime(300), "5m", "5 minutes")
    assertEqual(formatUptime(3660), "1h 1m", "1 hour 1 minute")
    assertEqual(formatUptime(90061), "1d 1h 1m", "1 day 1 hour 1 minute")
    assertEqual(formatUptime(172800), "2d 0h 0m", "2 days")
}

// MARK: - Overall Status Tests

func testOverallStatus() {
    print("\n--- Overall Status Tests ---")
    let normal = SystemSnapshot(
        cpu: CPUMetrics(totalUsage: 30, perCore: []),
        memory: MemoryMetrics(used: 4_000_000_000, total: 16_000_000_000, pressure: "nominal"),
        disk: DiskMetrics(used: 100_000_000_000, total: 500_000_000_000),
        network: NetworkMetrics(isUp: true, latencyMs: 10),
        battery: .empty,
        uptime: 3600
    )
    assertEqual(normal.overallStatus, .normal, "All normal = normal overall")

    let oneWarning = SystemSnapshot(
        cpu: CPUMetrics(totalUsage: 80, perCore: []),
        memory: MemoryMetrics(used: 4_000_000_000, total: 16_000_000_000, pressure: "nominal"),
        disk: DiskMetrics(used: 100_000_000_000, total: 500_000_000_000),
        network: NetworkMetrics(isUp: true, latencyMs: 10),
        battery: .empty,
        uptime: 3600
    )
    assertEqual(oneWarning.overallStatus, .warning, "One warning = warning overall")

    let critical = SystemSnapshot(
        cpu: CPUMetrics(totalUsage: 30, perCore: []),
        memory: MemoryMetrics(used: 4_000_000_000, total: 16_000_000_000, pressure: "nominal"),
        disk: DiskMetrics(used: 100_000_000_000, total: 500_000_000_000),
        network: NetworkMetrics(isUp: false, latencyMs: nil),
        battery: .empty,
        uptime: 3600
    )
    assertEqual(critical.overallStatus, .critical, "Network down = critical overall")
}

// MARK: - Run All

@main
struct ModelTestRunner {
    static func main() {
        print("=== Beacon Model Tests ===")

        testStatusLevelComparison()
        testCPUStatus()
        testMemoryMetrics()
        testDiskMetrics()
        testNetworkMetrics()
        testByteFormatter()
        testUptimeFormatting()
        testOverallStatus()

        // Service tests
        runServiceTests()

        print("\n=== Results: \(passedTests)/\(totalTests) passed ===")
        if passedTests < totalTests {
            print("SOME TESTS FAILED")
        } else {
            print("ALL TESTS PASSED")
        }
    }
}
