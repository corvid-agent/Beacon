import Foundation

enum ByteFormatter {
    private static let units = ["B", "KB", "MB", "GB", "TB"]

    static func format(_ bytes: UInt64) -> String {
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(bytes) B"
        }

        return String(format: "%.1f %@", value, units[unitIndex])
    }

    static func format(_ bytes: Int64) -> String {
        format(UInt64(max(0, bytes)))
    }
}
