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
    private var tokenExpireMs: Int64 = 0
    private var userId: String = ""
    private var patientId: String?
    private var region: String?
    private var apiVersion: String = "4.17.0"
    private var cancellables = Set<AnyCancellable>()
    private var pollingTimer: AnyCancellable?
    private let settings = SettingsStore.shared

    /// Dynamic base URL based on discovered region
    private var baseURL: String {
        if let region = region, !region.isEmpty {
            return "https://api-\(region).libreview.io"
        }
        // Use user-selected region as initial base
        let r = settings.region
        if r.isEmpty {
            return "https://api.libreview.io"
        }
        return "https://api-\(r).libreview.io"
    }

    /// Build standard headers matching GlucoDataHandler
    private var standardHeaders: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "product": "llu.android",
            "version": apiVersion,
            "cache-control": "no-cache",
            "Account-Id": SHA256.hash(userId),
        ]
    }

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
        tokenExpireMs = 0
        userId = ""
        patientId = nil
        region = nil
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
                // Step 1: Authenticate (login if needed)
                try await authenticate()

                // Step 2: Get connections if we don't have a patient ID
                if patientId == nil {
                    try await getConnections()
                }

                // Step 3: Fetch glucose data
                try await getGlucoseData()

                isLoading = false
            } catch {
                isLoading = false
                // If auth expired, clear and retry once
                if case APIError.authExpired = error {
                    authToken = nil
                    tokenExpireMs = 0
                    userId = ""
                    patientId = nil
                    do {
                        try await authenticate()
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

    // MARK: - Authentication (matching GlucoDataHandler flow)

    private var isTokenExpired: Bool {
        guard authToken != nil else { return true }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        return tokenExpireMs <= nowMs
    }

    private func authenticate() async throws {
        // If we have a valid token, skip login
        if authToken != nil && !isTokenExpired {
            return
        }

        // Token expired or missing — reset and re-login
        authToken = nil
        tokenExpireMs = 0
        userId = ""

        try await login()
    }

    private func login() async throws {
        let url = URL(string: "\(baseURL)/llu/auth/login")!
        var request = makeRequest(url: url, method: "POST")

        let body: [String: String] = [
            "email": settings.email,
            "password": settings.password,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle HTTP 403 — version too old (status 920)
        if httpResponse.statusCode == 403 {
            if let versionResponse = try? JSONDecoder().decode(VersionErrorResponse.self, from: data),
               versionResponse.status == 920,
               let minVersion = versionResponse.data?.minimumVersion {
                apiVersion = minVersion
                // Retry login with updated version
                return try await login()
            }
            throw APIError.httpError(403)
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.invalidCredentials
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)

        // Check for region redirect (status 0, redirect=true)
        if loginResponse.data?.redirect == true, let newRegion = loginResponse.data?.region {
            region = newRegion
            // Re-login to the correct regional server
            return try await login()
        }

        // Check for Terms of Use / Privacy Policy acceptance (status 4)
        if loginResponse.status == 4 {
            guard let ticket = loginResponse.data?.authTicket,
                  let step = loginResponse.data?.step,
                  let stepType = step.type else {
                throw APIError.termsAcceptanceFailed
            }
            // Set temporary token for TOU acceptance
            authToken = ticket.token
            if let user = loginResponse.data?.user {
                userId = user.id ?? ""
            }
            try await acceptTerms(type: stepType)
            return
        }

        // Successful login (status 0)
        guard loginResponse.status == 0 else {
            throw APIError.loginFailed(loginResponse.status)
        }

        guard let ticket = loginResponse.data?.authTicket else {
            throw APIError.noAuthTicket
        }

        authToken = ticket.token
        // expires is Unix timestamp in seconds — convert to milliseconds
        tokenExpireMs = Int64(ticket.expires) * 1000
        userId = loginResponse.data?.user?.id ?? ""
        isLoggedIn = true
    }

    /// Accept Terms of Use or Privacy Policy (chained)
    private func acceptTerms(type: String) async throws {
        let url = URL(string: "\(baseURL)/auth/continue/\(type)")!
        var request = makeRequest(url: url, method: "POST")
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        // No body needed

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.termsAcceptanceFailed
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)

        // May chain: TOU -> PP
        if loginResponse.status == 4,
           let step = loginResponse.data?.step,
           let nextType = step.type,
           nextType != type {
            if let ticket = loginResponse.data?.authTicket {
                authToken = ticket.token
            }
            try await acceptTerms(type: nextType)
            return
        }

        // Final successful response after accepting terms
        guard let ticket = loginResponse.data?.authTicket else {
            throw APIError.noAuthTicket
        }

        authToken = ticket.token
        tokenExpireMs = Int64(ticket.expires) * 1000
        userId = loginResponse.data?.user?.id ?? ""
        isLoggedIn = true
    }

    // MARK: - Data Fetching

    private func getConnections() async throws {
        guard let token = authToken else { throw APIError.authExpired }

        let url = URL(string: "\(baseURL)/llu/connections")!
        var request = makeRequest(url: url, method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)

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
        var request = makeRequest(url: url, method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)

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

    // MARK: - Helpers

    private var urlSession: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }

    private func makeRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        for (key, value) in standardHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    // MARK: - Errors

    enum APIError: LocalizedError {
        case invalidResponse
        case invalidCredentials
        case noAuthTicket
        case authExpired
        case noConnections
        case termsAcceptanceFailed
        case loginFailed(Int)
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid response from server"
            case .invalidCredentials: return "Invalid email or password"
            case .noAuthTicket: return "No auth ticket received"
            case .authExpired: return "Authentication expired, retrying..."
            case .noConnections: return "No LibreLink connections found. Ensure you have shared your data via LibreLinkUp."
            case .termsAcceptanceFailed: return "Failed to accept LibreView Terms of Use. Please accept them in the LibreLinkUp app first."
            case .loginFailed(let status): return "Login failed with status: \(status)"
            case .httpError(let code): return "HTTP error: \(code)"
            }
        }
    }
}
