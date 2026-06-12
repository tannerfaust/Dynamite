// swiftlint:disable identifier_name
//
//  AIKeychainStore.swift
//  CodeEdit
//
//  ADR-0007 §2 — API keys live in the macOS Keychain, never on disk.
//

import Foundation
import Security

/// Stores and retrieves AI provider API keys in the macOS Keychain.
///
/// Keys are scoped to the app's bundle ID so they survive app updates.
enum AIKeychainStore {

    private static let service = "com.dynamite.aiassist"

    // MARK: - Public API

    static func save(key: String, for provider: AIProviderID) throws {
        let account = provider.rawValue
        let data = Data(key.utf8)

        // Delete any existing entry first (update pattern).
        try? delete(for: provider)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load(for provider: AIProviderID) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: provider.rawValue,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(for provider: AIProviderID) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: provider.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    static func hasKey(for provider: AIProviderID) -> Bool {
        load(for: provider) != nil
    }

    // MARK: - Errors

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case deleteFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .saveFailed(let s):   return "Keychain save failed (OSStatus \(s))."
            case .deleteFailed(let s): return "Keychain delete failed (OSStatus \(s))."
            }
        }
    }
}
