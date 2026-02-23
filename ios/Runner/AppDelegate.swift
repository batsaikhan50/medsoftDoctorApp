import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let pipChannel = FlutterMethodChannel(
      name: "pip_channel",
      binaryMessenger: controller.binaryMessenger
    )

    pipChannel.setMethodCallHandler { [weak self] (call, result) in
      if #available(iOS 15.0, *) {
        switch call.method {
        case "setupPiP":
          if PiPManager.shared == nil {
            PiPManager.shared = PiPManager()
          }
          PiPManager.shared?.setup()
          result(true)

        case "startPiP":
          PiPManager.shared?.startPiP()
          result(true)

        case "stopPiP":
          PiPManager.shared?.stopPiP()
          result(true)

        case "remoteStream":
          if let args = call.arguments as? [String: Any],
             let remoteId = args["remoteId"] as? String {
            PiPManager.shared?.setRemoteTrack(trackId: remoteId)
            result(true)
          } else {
            result(FlutterError(code: "INVALID_ARGS", message: "remoteId required", details: nil))
          }

        case "dispose":
          PiPManager.shared?.disposePiP()
          PiPManager.shared = nil
          result(true)

        default:
          result(FlutterMethodNotImplemented)
        }
      } else {
        result(FlutterError(code: "UNSUPPORTED", message: "iOS 15+ required for PiP", details: nil))
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
