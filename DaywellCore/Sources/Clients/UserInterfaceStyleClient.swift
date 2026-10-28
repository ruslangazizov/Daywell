import Dependencies
import UIKit

extension DependencyValues {
    public var userInterfaceStyleClient: UserInterfaceStyleClient {
        get { self[UserInterfaceStyleClient.self] }
        set { self[UserInterfaceStyleClient.self] = newValue }
    }
}

public nonisolated struct UserInterfaceStyleClient: Sendable {
    public var override: @Sendable (_ newStyle: UIUserInterfaceStyle) async -> Void
}

extension UserInterfaceStyleClient: DependencyKey {
    public static let liveValue = UserInterfaceStyleClient(
        override: { newStyle in
            await MainActor.run {
                UIApplication.shared.connectedScenes.forEach {
                    if let scene = $0 as? UIWindowScene {
                        scene.keyWindow?.overrideUserInterfaceStyle = newStyle
                    }
                }
            }
        }
    )
    public static let testValue = UserInterfaceStyleClient(
        override: unimplemented("UserInterfaceStyleClient.override")
    )
}
