import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  static let launchLaneKey = "flutter.ndb_launch_lane"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // Capture the tap BEFORE super.scene() starts Flutter — otherwise Dart
    // can read SharedPreferences before this write lands.
    if let response = connectionOptions.notificationResponse,
       let lane = Self.lane(
         inside: response.notification.request.content.userInfo
       ) {
      let defaults = UserDefaults.standard
      defaults.set(lane, forKey: Self.launchLaneKey)
      defaults.synchronize()
      #if DEBUG
      NSLog("[NDB.ROUTE] captured notification lane")
      #endif
    }

    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  private static func lane(
    inside payload: [AnyHashable: Any]
  ) -> String? {
    let candidates = ["deep_link", "target", "url", "deeplink", "link"]

    func firstValue(in dictionary: [AnyHashable: Any]) -> String? {
      for candidate in candidates {
        guard let value = dictionary[candidate] as? String else { continue }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
      }
      return nil
    }

    if let direct = firstValue(in: payload) { return direct }

    for container in ["payload", "data"] {
      if let nested = payload[container] as? [AnyHashable: Any],
         let value = firstValue(in: nested) {
        return value
      }
    }
    return nil
  }
}
