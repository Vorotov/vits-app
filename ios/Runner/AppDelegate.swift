import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications: without this delegate neither
    // foreground presentation (a reminder that fires while the app is open) nor
    // the tap callback works at all. Asserted by test/platform_config_test.dart.
    //
    // Deliberately NOT added: FlutterLocalNotificationsPlugin's
    // setPluginRegistrantCallback. That exists for the background/action
    // isolate; this app defines no notification action buttons and "tapping
    // opens Сьогодні" is a foreground concern.
    //
    // Nothing goes in Info.plist either: local notifications need no key, no
    // entitlement and no UIBackgroundModes. Do not add one defensively —
    // platform_config_test.dart asserts UIBackgroundModes stays absent.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
