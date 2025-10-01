import UIKit
import Flutter

@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene,
             willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {

    guard let windowScene = scene as? UIWindowScene else { return }
    window = UIWindow(windowScene: windowScene)

    // Reuse the shared engine from AppDelegate
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let flutterVC = FlutterViewController(
      engine: appDelegate.flutterEngine,
      nibName: nil,
      bundle: nil
    )

    window?.rootViewController = flutterVC
    window?.makeKeyAndVisible()
  }
}
