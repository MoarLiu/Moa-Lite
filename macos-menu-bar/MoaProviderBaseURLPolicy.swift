import Foundation

struct MoaProviderBaseURLValidation: Equatable {
    let url: URL
    let normalizedString: String
    let usesLoopbackHTTP: Bool
}

enum MoaProviderBaseURLError: LocalizedError, Equatable {
    case empty
    case invalid(String)
    case insecureHTTP(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            return MoaL10n.text("Fill API Base URL first.")
        case .invalid(let value):
            return String(format: MoaL10n.text("API Base URL is invalid: %@. Use https://; only localhost, 127.0.0.1, and ::1 may use http://."), value)
        case .insecureHTTP(let value):
            return String(format: MoaL10n.text("API Base URL is insecure: %@. Remote providers must use https://; only localhost, 127.0.0.1, and ::1 may use http://."), value)
        }
    }
}

enum MoaProviderBaseURLPolicy {
    static var visibleGuidance: String {
        MoaL10n.text("Remote APIs must use https://. Only localhost, 127.0.0.1, and ::1 may use http://; local HTTP sends API keys in plaintext, so connect only to trusted local services.")
    }

    static func validate(_ raw: String) throws -> MoaProviderBaseURLValidation {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MoaProviderBaseURLError.empty
        }

        guard
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            let host = url.host,
            !host.isEmpty
        else {
            throw MoaProviderBaseURLError.invalid(trimmed)
        }

        if scheme == "https" {
            return MoaProviderBaseURLValidation(url: url, normalizedString: trimmed, usesLoopbackHTTP: false)
        }

        if scheme == "http", isLoopback(host: host) {
            return MoaProviderBaseURLValidation(url: url, normalizedString: trimmed, usesLoopbackHTTP: true)
        }

        if scheme == "http" {
            throw MoaProviderBaseURLError.insecureHTTP(trimmed)
        }

        throw MoaProviderBaseURLError.invalid(trimmed)
    }

    static func warningMessage(for raw: String) -> String? {
        guard let validation = try? validate(raw), validation.usesLoopbackHTTP else {
            return nil
        }

        return MoaL10n.text("Current local http:// address sends API keys in plaintext; use it only for trusted local services.")
    }

    static func errorMessage(for raw: String) -> String {
        do {
            _ = try validate(raw)
            return ""
        } catch {
            return error.localizedDescription
        }
    }

    private static func isLoopback(host: String) -> Bool {
        let normalized = host
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .lowercased()
        return normalized == "localhost"
            || normalized == "127.0.0.1"
            || normalized == "::1"
    }
}
