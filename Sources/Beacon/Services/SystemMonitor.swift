import Foundation
#if canImport(IOKit)
import IOKit.ps
#endif

actor SystemMonitor {

    // MARK: - Previous CPU ticks for delta calculation

    private var previousCPUTicks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []

    // MARK: - Public API

    func snapshot() async -> SystemSnapshot {
        async let cpu = pollCPU()
        async let memory = pollMemory()
        async let disk = pollDisk()
        async let network = pollNetwork()
        async let battery = pollBattery()
        let uptime = ProcessInfo.processInfo.systemUptime

        return await SystemSnapshot(
            cpu: cpu,
            memory: memory,
            disk: disk,
            network: network,
            battery: battery,
            uptime: uptime
        )
    }

    // MARK: - CPU via Mach host_processor_info

    private func pollCPU() -> CPUMetrics {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return .empty
        }

        defer {
            let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        let coreCount = Int(numCPUs)
        var currentTicks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []
        var perCore: [Double] = []

        for i in 0..<coreCount {
            let offset = Int32(i) * CPU_STATE_MAX
            let user = UInt64(info[Int(offset + CPU_STATE_USER)])
            let system = UInt64(info[Int(offset + CPU_STATE_SYSTEM)])
            let idle = UInt64(info[Int(offset + CPU_STATE_IDLE)])
            let nice = UInt64(info[Int(offset + CPU_STATE_NICE)])

            currentTicks.append((user: user, system: system, idle: idle, nice: nice))

            if i < previousCPUTicks.count {
                let prev = previousCPUTicks[i]
                let dUser = user - prev.user
                let dSystem = system - prev.system
                let dIdle = idle - prev.idle
                let dNice = nice - prev.nice
                let totalDelta = dUser + dSystem + dIdle + dNice
                if totalDelta > 0 {
                    let usage = Double(dUser + dSystem + dNice) / Double(totalDelta) * 100
                    perCore.append(min(100, max(0, usage)))
                } else {
                    perCore.append(0)
                }
            } else {
                // First poll — no delta available, report 0
                perCore.append(0)
            }
        }

        previousCPUTicks = currentTicks

        let totalUsage = perCore.isEmpty ? 0 : perCore.reduce(0, +) / Double(perCore.count)

        return CPUMetrics(totalUsage: totalUsage, perCore: perCore)
    }

    // MARK: - Memory via host_statistics64

    private func pollMemory() -> MemoryMetrics {
        let totalBytes = UInt64(ProcessInfo.processInfo.physicalMemory)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryMetrics(used: 0, total: totalBytes, pressure: "unknown")
        }

        let pageSize = UInt64(getpagesize())
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        // Determine pressure level based on percentage
        let pct = Double(used) / Double(totalBytes) * 100
        let pressure: String
        if pct > 95 {
            pressure = "critical"
        } else if pct > 80 {
            pressure = "warn"
        } else {
            pressure = "nominal"
        }

        return MemoryMetrics(used: used, total: totalBytes, pressure: pressure)
    }

    // MARK: - Disk via FileManager

    private func pollDisk() -> DiskMetrics {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = attrs[.systemSize] as? UInt64 ?? 0
            let free = attrs[.systemFreeSize] as? UInt64 ?? 0
            let used = total > free ? total - free : 0
            return DiskMetrics(used: used, total: total)
        } catch {
            return .empty
        }
    }

    // MARK: - Network via ping

    private func pollNetwork() -> NetworkMetrics {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-t", "2", "8.8.8.8"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return NetworkMetrics(isUp: false, latencyMs: nil)
        }

        guard process.terminationStatus == 0 else {
            return NetworkMetrics(isUp: false, latencyMs: nil)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Parse latency from ping output: "time=12.345 ms"
        let latency = parseLatency(from: output)

        return NetworkMetrics(isUp: true, latencyMs: latency)
    }

    private func parseLatency(from pingOutput: String) -> Double? {
        // Look for "time=XX.XX ms" in ping output
        guard let range = pingOutput.range(of: "time=") else { return nil }
        let after = pingOutput[range.upperBound...]
        guard let msRange = after.range(of: " ms") else { return nil }
        let valueStr = after[..<msRange.lowerBound]
        return Double(valueStr)
    }

    // MARK: - Battery via pmset

    private func pollBattery() -> BatteryMetrics {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return BatteryMetrics(percentage: 0, isCharging: false, timeRemaining: nil, hasBattery: false)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return parseBattery(from: output)
    }

    nonisolated func parseBattery(from output: String) -> BatteryMetrics {
        // pmset -g batt output example:
        // Now drawing from 'Battery Power'
        //  -InternalBattery-0 (id=...)    72%; discharging; 3:45 remaining
        let lines = output.components(separatedBy: "\n")

        guard lines.count >= 2 else {
            return BatteryMetrics(percentage: 0, isCharging: false, timeRemaining: nil, hasBattery: false)
        }

        // Check if there's battery info
        let batteryLine = lines.dropFirst().joined(separator: " ")
        guard batteryLine.contains("InternalBattery") || batteryLine.contains("%") else {
            return BatteryMetrics(percentage: 0, isCharging: false, timeRemaining: nil, hasBattery: false)
        }

        // Parse percentage
        var percentage = 0
        if let pctRange = batteryLine.range(of: #"\d{1,3}%"#, options: .regularExpression) {
            let pctStr = batteryLine[pctRange].dropLast() // drop the %
            percentage = Int(pctStr) ?? 0
        }

        let isCharging = batteryLine.contains("charging") && !batteryLine.contains("discharging")
            && !batteryLine.contains("not charging")

        // Parse time remaining
        var timeRemaining: String?
        if let timeRange = batteryLine.range(of: #"\d+:\d+ remaining"#, options: .regularExpression) {
            timeRemaining = String(batteryLine[timeRange])
        }

        return BatteryMetrics(
            percentage: percentage,
            isCharging: isCharging,
            timeRemaining: timeRemaining,
            hasBattery: true
        )
    }

    nonisolated func parseLatencyPublic(from pingOutput: String) -> Double? {
        guard let range = pingOutput.range(of: "time=") else { return nil }
        let after = pingOutput[range.upperBound...]
        guard let msRange = after.range(of: " ms") else { return nil }
        let valueStr = after[..<msRange.lowerBound]
        return Double(valueStr)
    }
}
