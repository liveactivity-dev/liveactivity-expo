import ExpoModulesCore

// Runs on every launch, including background launches caused by a push-to-start,
// before any JS exists, so tokens and new activities get reported.
public class LACAppDelegateSubscriber: ExpoAppDelegateSubscriber {
  public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    LACClient.shared.startObserving()
    return true
  }

  // Called when the app (e.g. through expo-notifications) registers for remote notifications: the fallback alert's token.
  public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    LACClient.shared.setDeviceToken(deviceToken)
  }
}
