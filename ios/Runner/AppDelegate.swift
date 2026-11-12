import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushDeviceChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VantaPushDevice") {
      let channel = FlutterMethodChannel(name: "exchange.vanta.app/push", binaryMessenger: registrar.messenger())
      pushDeviceChannel = channel
      channel.setMethodCallHandler { call, result in
        guard call.method == "device" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let bundle = Bundle.main
        let signingEnvironment = bundle.object(forInfoDictionaryKey: "VantaPushEnvironment") as? String
        let environment: String?
        switch signingEnvironment {
        case "development": environment = "sandbox"
        case "production": environment = "production"
        default: environment = nil
        }
        guard let appId = bundle.bundleIdentifier,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let environment = environment else {
          result(FlutterError(code: "push_metadata_unavailable", message: "Push configuration unavailable", details: nil))
          return
        }
        result([
          "platform": "ios",
          "app_id": appId,
          "app_version": version,
          "environment": environment,
        ])
      }
    }
  }
}
