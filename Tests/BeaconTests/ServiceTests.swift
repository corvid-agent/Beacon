import Foundation
@testable import Beacon

// MARK: - Service Tests (parsing logic)

func testParseBattery() {
    print("\n--- Battery Parsing Tests ---")
    let monitor = SystemMonitor()

    // Test standard battery output
    let output1 = """
    Now drawing from 'Battery Power'
     -InternalBattery-0 (id=1234567)	72%; discharging; 3:45 remaining present: true
    """
    let result1 = monitor.parseBattery(from: output1)
    assertTrue(result1.hasBattery, "Battery detected")
    assertEqual(result1.percentage, 72, "Battery 72%")
    assertEqual(result1.isCharging, false, "Not charging")
    assertEqual(result1.timeRemaining, "3:45 remaining", "Time remaining parsed")

    // Test charging output
    let output2 = """
    Now drawing from 'AC Power'
     -InternalBattery-0 (id=1234567)	85%; charging; 1:20 remaining present: true
    """
    let result2 = monitor.parseBattery(from: output2)
    assertTrue(result2.hasBattery, "Battery detected (charging)")
    assertEqual(result2.percentage, 85, "Battery 85%")
    assertEqual(result2.isCharging, true, "Is charging")

    // Test no battery (desktop Mac)
    let output3 = "Now drawing from 'AC Power'\n"
    let result3 = monitor.parseBattery(from: output3)
    assertEqual(result3.hasBattery, false, "No battery on desktop")

    // Test fully charged
    let output4 = """
    Now drawing from 'AC Power'
     -InternalBattery-0 (id=1234567)	100%; charged; not charging present: true
    """
    let result4 = monitor.parseBattery(from: output4)
    assertEqual(result4.percentage, 100, "Battery 100%")
    assertEqual(result4.isCharging, false, "Not charging when charged (contains 'not charging')")
}

func testParseLatency() {
    print("\n--- Latency Parsing Tests ---")
    let monitor = SystemMonitor()

    let output1 = """
    PING 8.8.8.8 (8.8.8.8): 56 data bytes
    64 bytes from 8.8.8.8: icmp_seq=0 ttl=117 time=12.345 ms

    --- 8.8.8.8 ping statistics ---
    1 packets transmitted, 1 packets received, 0.0% packet loss
    """
    let latency1 = monitor.parseLatencyPublic(from: output1)
    assertTrue(latency1 != nil, "Latency parsed")
    if let l = latency1 {
        assertTrue(abs(l - 12.345) < 0.001, "Latency = 12.345 ms")
    }

    let output2 = "Request timeout"
    let latency2 = monitor.parseLatencyPublic(from: output2)
    assertTrue(latency2 == nil, "No latency on timeout")
}

// If this file is compiled as part of the test runner, these functions
// are called from ModelTests.swift's @main entry point.
// For now, we define a standalone runner:

func runServiceTests() {
    print("=== Beacon Service Tests ===")
    testParseBattery()
    testParseLatency()
}
