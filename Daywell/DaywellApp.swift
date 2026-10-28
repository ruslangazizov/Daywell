import SwiftUI
import AppRootFeature
import Dependencies
import Sharing

@main
struct DaywellApp: App {
    private static let store = AppBootstrap.makeStore()

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
        }
    }

    init() {
        if ProcessInfo.processInfo.environment["IS_UI_TESTING"] == "true" {
            let testSuiteName = "ui-test-\(UUID().uuidString)"
            guard let testDefaults = UserDefaults(suiteName: testSuiteName) else { return }

            prepareDependencies {
                $0.defaultAppStorage = testDefaults
            }
        }
    }
}
