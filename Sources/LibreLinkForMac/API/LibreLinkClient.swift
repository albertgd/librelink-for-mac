import Foundation
import Combine

final class LibreLinkClient: ObservableObject {
    static let shared = LibreLinkClient()

    @Published var currentGlucose: GlucoseEntry?
    @Published var graphData: [GlucoseEntry] = []
    @Published var connectionName: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var lastError: String?
    @Published var isLoading: Bool = false

    private var authToken: String?
    private var tokenExpiry: Date?
    private var patientId: String?
    private var cancellables = Set<AnyCancellable>()
    private var pollingTimer: AnyCancellable?
    private let settings = SettingsStore.shared

    private let headers: [String: String] = [
        "Content-Type": "application/json",
        "Accept": "application/json",
        "product": "llu.ios",
        "version": "4.7.0",
    ]

    private var baseURL: String { settings.region.baseURL }

    // MARK: - Public API

    func startPolling() {
        stopPolling()
        fetchGlucoseData()

        pollingTimer = Timer.publish(every: settings.pollingInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchGlucoseData()
            }
    }

    func stopPolling() {
        pollingTimer?.cancel()
        pollingTimer = nil
    }

    func logout() {
        authToken = nil
        tokenExpiry = nil
        patientId = nil
        isLoggedIn = false
        currentGlucose = nil
        graphData = []
        connectionName = ""
        lastError = nil
        stopPolling()
    }

    func fetchGlucoseData() {
        guard settings.hasCredentials else {
            lastError = "Please configure your credentials in Settings"
            return
        }

        isLoading = true
        lastError = nil

        Task { @MainActor in
            do {
                // Step 1: Ensure we have a valid token
                if authToken == nil || isTokenExpired {
                    try await login()
                }

                // Step 2: Get connections if we don't have a patient ID
                if patientId == nil {
                    try await getConnections()
                }

                // Step 3: Fetch glucose data
                try await getGlucoseData()

                isLoading = false
            } catch {
                isLoading = false
                // If auth failed, clear token and retry once
                if case APIError.authExpired = error {
                    authToken = nil
                    patientId = nil
                    do {
                        try await login()
                        try await getConnections()
                        try await getGlucoseData()
                    } catch {
                        lastError = error.localizedDescription
                    }
                } else {
                    lastError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Auth Flow

    private var isTokenExpired: Bool {
        guard let expiry = tokenExpiry else { return true }
        return Date() >= expiry
    }

    private func login() async throws {
        let url = URL(string: "\(baseURL)/llu/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let body: [String: String] = [
            "email": settings.email,
            "password": settings.password,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle region redirect
        if httpResponse.statusCode == 200 {
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)

            // Check for redirect (status 4 means wrong region)
            if loginResponse.status == 4 {
                throw APIError.regionRedirect
            }

            guard let ticket = loginResponse.data?.authTicket else {
                throw APIError.noAuthTicket
            }

            authToken = ticket.token
            tokenExpiry = Date().addingTimeInterval(TimeInterval(ticket.duration))
            isLoggedIn = true
        } else if httpResponse.statusCode == 401 {
            throw APIError.invalidCredentials
        } else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }

    private func getConnections() async throws {
        guard let token = authToken else { throw APIError.authExpired }

        let url = URL(string: "\(baseURL)/llu/connections")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.authExpired
        }

        let connectionsResponse = try JSONDecoder().decode(ConnectionsResponse.self, from: data)

        guard let connections = connectionsResponse.data, let first = connections.first else {
            throw APIError.noConnections
        }

        patientId = first.patientId
        await MainActor.run {
            connectionName = first.displayName
        }
    }

    private func getGlucoseData() async throws {
        guard let token = authToken, let patientId = patientId else {
            throw APIError.authExpired
        }

        let url = URL(string: "\(baseURL)/llu/connections/\(patientId)/graph")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.authExpired
        }

        let glucoseResponse = try JSONDecoder().decode(GlucoseResponse.self, from: data)

        await MainActor.run {
            if let measurement = glucoseResponse.data?.connection?.glucoseMeasurement {
                currentGlucose = measurement
            }
            if let graph = glucoseResponse.data?.graphData {
                graphData = graph.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
            }
        }
    }

    // MARK: - Errors

    enum APIError: LocalizedError {
        case invalidResponse
        case invalidCredentials
        case noAuthTicket
        case authExpired
        case regionRedirect
        case noConnections
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid response from server"
            case .invalidCredentials: return "Invalid email or password"
            case .noAuthTicket: return "No auth ticket received"
            case .authExpired: return "Authentication expired, retrying..."
            case .regionRedirect: return "Wrong region selected. Please check your region in Settings."
            case .noConnections: return "No LibreLink connections found. Ensure you have shared your data via LibreLinkUp."
            case .httpError(let code): return "HTTP error: \(code)"
            }
        }
    }
}
