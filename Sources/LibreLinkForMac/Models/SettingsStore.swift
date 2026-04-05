import Foundation
import Combine
import SwiftUI

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @AppStorage("libre_email") var email: String = ""
    @AppStorage("libre_region") var region: String = "eu"
    @AppStorage("polling_interval") var pollingInterval: Double = 60
    @AppStorage("hud_visible") var hudVisible: Bool = false
    @AppStorage("use_mmol") var useMmol: Bool = false
    @AppStorage("low_threshold") var lowThreshold: Double = 70
    @AppStorage("high_threshold") var highThreshold: Double = 180

    // Password stored in Keychain for security
    var password: String {
        get { KeychainHelper.get(key: "libre_password") ?? "" }
        set { KeychainHelper.set(key: "libre_password", value: newValue) }
    }

    var hasCredentials: Bool {
        !email.isEmpty && !password.isEmpty
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    private static let service = "com.albertgd.librelinkformac"

    static func set(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)

        var newItem = query
        newItem[kSecValueData as String] = data
        SecItemAdd(newItem as CFDictionary, nil)
    }

    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
