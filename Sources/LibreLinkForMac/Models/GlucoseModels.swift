import Foundation
import CommonCrypto

// MARK: - API Response Models

struct LoginResponse: Codable {
    let status: Int
    let data: LoginData?

    struct LoginData: Codable {
        let authTicket: AuthTicket?
        let user: User?
        let redirect: Bool?
        let region: String?
        let step: Step?
    }

    struct User: Codable {
        let id: String?
        let firstName: String?
        let lastName: String?
        let accountType: String?
        let country: String?
    }

    struct Step: Codable {
        let type: String?
        let componentName: String?
    }
}

struct AuthTicket: Codable {
    let token: String
    let expires: Int
    let duration: Int
}

struct ConnectionsResponse: Codable {
    let status: Int
    let data: [Connection]?
}

struct Connection: Codable, Identifiable {
    let id: String?
    let patientId: String
    let firstName: String?
    let lastName: String?
    let glucoseMeasurement: GlucoseEntry?

    var displayName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

struct GlucoseResponse: Codable {
    let status: Int
    let data: GlucoseData?

    struct GlucoseData: Codable {
        let connection: ConnectionGlucose?
        let graphData: [GlucoseEntry]?
    }
}

struct ConnectionGlucose: Codable {
    let glucoseMeasurement: GlucoseEntry?
    let sensor: Sensor?
}

struct Sensor: Codable {
    let deviceId: String?
    let sn: String?
    let a: Int?
}

struct GlucoseEntry: Codable, Identifiable {
    let FactoryTimestamp: String?
    let Timestamp: String?
    let ValueInMgPerDl: Double?
    let Value: Double?
    let TrendArrow: Int?
    let MeasurementColor: Int?
    let GlucoseUnits: Int?
    let isHigh: Bool?
    let isLow: Bool?

    var id: String { Timestamp ?? FactoryTimestamp ?? UUID().uuidString }

    var value: Double { ValueInMgPerDl ?? 0 }

    /// Parse timestamp - try FactoryTimestamp as UTC first, then Timestamp as local
    var timestamp: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy h:mm:ss a"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // FactoryTimestamp is UTC
        if let ts = FactoryTimestamp {
            formatter.timeZone = TimeZone(identifier: "UTC")
            if let date = formatter.date(from: ts) {
                return date
            }
        }
        // Timestamp is local time
        if let ts = Timestamp {
            formatter.timeZone = .current
            if let date = formatter.date(from: ts) {
                return date
            }
        }
        return nil
    }

    var trendArrow: LibreLinkForMac.TrendArrow {
        LibreLinkForMac.TrendArrow(rawValue: self.TrendArrow ?? 0) ?? .stable
    }
}

// MARK: - Trend Arrow (matching GlucoDataHandler: 1=falling fast, 2=falling, 3=stable, 4=rising, 5=rising fast)

enum TrendArrow: Int, CaseIterable {
    case unknown = 0
    case fallingQuickly = 1
    case falling = 2
    case stable = 3
    case rising = 4
    case risingQuickly = 5

    var sfSymbol: String {
        switch self {
        case .unknown: return "questionmark"
        case .fallingQuickly: return "arrow.down"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .rising: return "arrow.up.right"
        case .risingQuickly: return "arrow.up"
        }
    }

    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .fallingQuickly: return "Falling Quickly"
        case .falling: return "Falling"
        case .stable: return "Stable"
        case .rising: return "Rising"
        case .risingQuickly: return "Rising Quickly"
        }
    }

    /// Rate of change in mg/dL per minute
    var rate: Double {
        switch self {
        case .unknown: return 0.0
        case .fallingQuickly: return -2.0
        case .falling: return -1.0
        case .stable: return 0.0
        case .rising: return 1.0
        case .risingQuickly: return 2.0
        }
    }
}

// MARK: - Version Error Response

struct VersionErrorResponse: Codable {
    let status: Int?
    let data: VersionData?

    struct VersionData: Codable {
        let minimumVersion: String?
    }
}

// MARK: - Glucose Color Range

enum GlucoseRange {
    case low
    case normal
    case high

    static func from(value: Double) -> GlucoseRange {
        if value < 70 { return .low }
        if value > 180 { return .high }
        return .normal
    }
}

// MARK: - SHA-256 Helper

enum SHA256 {
    static func hash(_ string: String) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
