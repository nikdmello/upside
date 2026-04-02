import Foundation

enum BackendRuntimeConfiguration {
    static func configuredAuthToken(bundle: Bundle = .main) -> String? {
        let configuredToken = value(for: "BACKEND_AUTH_TOKEN", bundle: bundle)
            ?? value(for: "BACKEND_API_TOKEN", bundle: bundle)

        #if DEBUG
        let token = configuredToken ?? "upside-dev-token"
        #else
        let token = configuredToken
        #endif

        guard !token.isEmpty else {
            return nil
        }
        return token
    }

    static func value(for key: String, bundle: Bundle = .main) -> String? {
        let environment = ProcessInfo.processInfo.environment

        if
            let bundleValue = bundle.object(forInfoDictionaryKey: key) as? String,
            let normalized = normalized(bundleValue)
        {
            return normalized
        }

        if
            let envValue = environment[key],
            let normalized = normalized(envValue)
        {
            return normalized
        }

        return nil
    }

    private static func normalized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 {
            let unquoted = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            return unquoted.isEmpty ? nil : unquoted
        }

        return trimmed
    }
}
