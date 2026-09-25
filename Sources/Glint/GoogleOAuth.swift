import AppKit
import CryptoKit
import Darwin
import Foundation
import Security

struct GoogleCredentials: Codable {
    let clientID: String
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

enum GoogleKeychain {
    private static let service = "dev.haardik.glint.google-calendar"
    private static let account = "oauth"

    static func load() -> GoogleCredentials? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecAttrAccount as String: account,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(GoogleCredentials.self, from: data)
    }

    static func save(_ credentials: GoogleCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecAttrAccount as String: account]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw keychainError(addStatus) }
        } else if status != errSecSuccess { throw keychainError(status) }
    }

    static func delete() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }

    private static func keychainError(_ status: OSStatus) -> NSError {
        NSError(domain: NSOSStatusErrorDomain, code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Could not save Google credentials to Keychain (\(status))."])
    }
}

@MainActor final class GoogleOAuth {
    private let scope = "https://www.googleapis.com/auth/calendar.readonly"

    func signIn(clientID: String) async throws -> GoogleCredentials {
        guard clientID.hasSuffix(".apps.googleusercontent.com") else { throw GoogleCalendarError.missingClientID }
        let verifier = Self.random(32)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = Self.random(20)
        let (code, redirect) = try await authorizationCode(clientID: clientID, challenge: challenge, state: state)
        let response = try await Self.tokenRequest([
            "client_id": clientID, "code": code, "code_verifier": verifier,
            "redirect_uri": redirect, "grant_type": "authorization_code"
        ])
        guard let refresh = response.refreshToken else { throw GoogleCalendarError.noRefreshToken }
        guard response.scope?.split(separator: " ").contains(Substring(scope)) == true else {
            throw GoogleCalendarError.missingScope
        }
        let credentials = GoogleCredentials(clientID: clientID, accessToken: response.accessToken,
                                            refreshToken: refresh,
                                            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)))
        try GoogleKeychain.save(credentials)
        return credentials
    }

    func accessToken(for credentials: GoogleCredentials, forceRefresh: Bool = false) async throws -> GoogleCredentials {
        guard forceRefresh || credentials.expiresAt <= Date().addingTimeInterval(90) else { return credentials }
        let response = try await Self.tokenRequest([
            "client_id": credentials.clientID, "refresh_token": credentials.refreshToken,
            "grant_type": "refresh_token"
        ])
        var updated = credentials
        updated.accessToken = response.accessToken
        updated.refreshToken = response.refreshToken ?? credentials.refreshToken
        updated.expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        try GoogleKeychain.save(updated)
        return updated
    }

    private func authorizationCode(clientID: String, challenge: String, state: String) async throws -> (String, String) {
        let (socket, port) = try LoopbackReceiver.listen()
        let redirect = "http://127.0.0.1:\(port)/oauth2callback"
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        guard NSWorkspace.shared.open(components.url!) else {
            Darwin.close(socket)
            throw GoogleCalendarError.invalidCallback
        }
        let code = try await Task.detached { try LoopbackReceiver.receive(socket: socket, state: state) }.value
        return (code, redirect)
    }

    private static func tokenRequest(_ parameters: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters.sorted { $0.key < $1.key }.map { key, value in
            "\(formEncode(key))=\(formEncode(value))"
        }.joined(separator: "&").data(using: .utf8)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw GoogleCalendarError.response }
        guard (200..<300).contains(response.statusCode) else {
            let detail = (try? JSONDecoder().decode(TokenError.self, from: data))?.error ?? "HTTP \(response.statusCode)"
            throw NSError(domain: "GoogleOAuth", code: response.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Google authorization failed: \(detail)"])
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private static func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
    }

    private static func random(_ count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int
        let scope: String?
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token", refreshToken = "refresh_token", expiresIn = "expires_in", scope
        }
    }
    private struct TokenError: Decodable { let error: String }
}
