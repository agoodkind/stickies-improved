import Foundation
import Observation
import Sparkle

@Observable
@MainActor
public final class AppUpdater {
    private let controller: SPUStandardUpdaterController?

    public init(enabled: Bool = true) {
        if enabled {
            self.controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            self.controller = nil
        }
    }

    public func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
