import Foundation
import Observation
import Sparkle

@Observable
@MainActor
public final class AppUpdater {
    private let controller: SPUStandardUpdaterController?

    public init(enabled: Bool = true) {
        if enabled {
            controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            controller = nil
        }
    }

    public func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
