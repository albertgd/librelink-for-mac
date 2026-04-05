import Foundation

// MARK: - API Response Models

struct LoginResponse: Codable {
    let status: Int
    let data: LoginData?

    struct LoginData: Codable {
        let authTicket: AuthTicket?
        let user: User?
    }

    struct User: Codable {
        let id: String?
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
}

struct GlucoseEntry: Codable, Identifiable {
    let FactoryTimestamp: String?
    let Timestamp: String?
    let ValueInMgPerDl: Double?
    let TrendArrow: Int?
    let MeasurementColor: Int?

    var id: String { Timestamp ?? FactoryTimestamp ?? UUID().uuidString }

    var value: Double { ValueInMgPerDl ?? 0 }

    var timestamp: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy h:mm:ss a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let ts = Timestamp, let date = formatter.date(from: ts) {
            return date
        }
        if let ts = FactoryTimestamp, let date = formatter.date(from: ts) {
            return date
        }
        return nil
    }

    var trendArrow: LibreLinkForMac.TrendArrow {
        LibreLinkForMac.TrendArrow(rawValue: self.TrendArrow ?? 0) ?? .stable
    }
}

// MARK: - Trend Arrow

enum TrendArrow: Int, CaseIterable {
    case unknown = 0
    case fallingQuickly = 1
    case falling = 2
    case fallingSlowly = 3
    case stable = 4
    case risingSlowly = 5
    case rising = 6
    case risingQuickly = 7

    var sfSymbol: String {
        switch self {
        case .unknown: return "questionmark"
        case .fallingQuickly: return "arrow.down"
        case .falling: return "arrow.down.right"
        case .fallingSlowly: return "arrow.down.forward"
        case .stable: return "arrow.right"
        case .risingSlowly: return "arrow.up.forward"
        case .rising: return "arrow.up.right"
        case .risingQuickly: return "arrow.up"
        }
    }

    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .fallingQuickly: return "Falling Quickly"
        case .falling: return "Falling"
        case .fallingSlowly: return "Falling Slowly"
        case .stable: return "Stable"
        case .risingSlowly: return "Rising Slowly"
        case .rising: return "Rising"
        case .risingQuickly: return "Rising Quickly"
        }
    }
}

// MARK: - Region Configuration

enum LibreLinkRegion: String, CaseIterable, Identifiable {
    case us = "us"
    case eu = "eu"
    case de = "de"
    case fr = "fr"
    case jp = "jp"
    case ap = "ap"
    case au = "au"
    case ae = "ae"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .us: return "United States"
        case .eu: return "Europe"
        case .de: return "Germany"
        case .fr: return "France"
        case .jp: return "Japan"
        case .ap: return "Asia Pacific"
        case .au: return "Australia"
        case .ae: return "UAE"
        }
    }

    var baseURL: String {
        switch self {
        case .us: return "https://api-us.libreview.io"
        case .eu: return "https://api-eu.libreview.io"
        case .de: return "https://api-de.libreview.io"
        case .fr: return "https://api-fr.libreview.io"
        case .jp: return "https://api-jp.libreview.io"
        case .ap: return "https://api-ap.libreview.io"
        case .au: return "https://api-au.libreview.io"
        case .ae: return "https://api-ae.libreview.io"
        }
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
