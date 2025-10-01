import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  // One shared engine for the whole app
  lazy var flutterEngine = FlutterEngine(name: "flutter_engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Start the engine before showing any Flutter UI
    flutterEngine.run()
    // Register plugins into this engine
    GeneratedPluginRegistrant.register(with: flutterEngine)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
