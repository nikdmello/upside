import Foundation

enum AppTestingConfiguration {
    #if DEBUG
    static let bypassOnboarding: Bool = flag(named: "UPSIDE_BYPASS_ONBOARDING")
    static let enableDemoMode: Bool = flag(named: "UPSIDE_ENABLE_DEMO_MODE")

    static let bypassRole: UserRole = {
        let rawValue = ProcessInfo.processInfo.environment["UPSIDE_DEBUG_ROLE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return UserRole(rawValue: rawValue ?? "") ?? .brand
    }()
    #else
    static let bypassOnboarding = false
    static let enableDemoMode = false
    static let bypassRole: UserRole = .brand
    #endif

    private static func flag(named key: String) -> Bool {
        let rawValue = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return rawValue == "1" || rawValue == "true" || rawValue == "yes"
    }
}
