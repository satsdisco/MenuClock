import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService.mainApp (macOS 13+).
/// Tracks the observed status and exposes a simple toggle.
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var lastError: String? = nil

    private let service = SMAppService.mainApp

    private init() {
        refreshStatus()
    }

    /// Re-read the current registration status from the system.
    func refreshStatus() {
        isEnabled = (service.status == .enabled)
    }

    /// Turn on or off. Safe to call repeatedly; no-op when already in sync.
    func setEnabled(_ wanted: Bool) {
        lastError = nil
        do {
            if wanted {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
        refreshStatus()
    }
}
