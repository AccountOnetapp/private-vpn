import Flutter
import NetworkExtension
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let vpnBridge = VPNBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.accountonetapp.privatevpn/vpn",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.vpnBridge.handle(call, result: result)
    }
  }
}

private final class VPNBridge {
  private let providerBundleIdentifier = "com.accountonetapp.privateVpn.PacketTunnel"
  private var manager: NETunnelProviderManager?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configure":
      guard let arguments = call.arguments as? [String: Any],
            let subscriptionURL = arguments["subscriptionURL"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing subscriptionURL", details: nil))
        return
      }
      configure(subscriptionURL: subscriptionURL, result: result)
    case "connect":
      connect(result: result)
    case "disconnect":
      manager?.connection.stopVPNTunnel()
      result("disconnected")
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configure(subscriptionURL: String, result: @escaping FlutterResult) {
#if targetEnvironment(simulator)
    result(nil)
#else
    NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
      if let error {
        result(FlutterError(code: "LOAD_FAILED", message: error.localizedDescription, details: nil))
        return
      }

      let selected = managers?.first ?? NETunnelProviderManager()
      let tunnelProtocol = NETunnelProviderProtocol()
      tunnelProtocol.providerBundleIdentifier = self?.providerBundleIdentifier
      tunnelProtocol.serverAddress = URL(string: subscriptionURL)?.host
      tunnelProtocol.providerConfiguration = [
        "subscriptionURL": subscriptionURL,
        "configurationVersion": 1,
      ]
      selected.localizedDescription = "PrivateVPN"
      selected.protocolConfiguration = tunnelProtocol
      selected.isEnabled = true
      selected.saveToPreferences { saveError in
        if let saveError {
          result(FlutterError(code: "SAVE_FAILED", message: saveError.localizedDescription, details: nil))
          return
        }
        self?.manager = selected
        result(nil)
      }
    }
#endif
  }

  private func connect(result: @escaping FlutterResult) {
#if targetEnvironment(simulator)
    result("connected")
#else
    guard let manager else {
      result(FlutterError(code: "NOT_CONFIGURED", message: "Activate a subscription first.", details: nil))
      return
    }
    do {
      try manager.connection.startVPNTunnel()
      result("connecting")
    } catch {
      result(FlutterError(code: "CONNECT_FAILED", message: error.localizedDescription, details: nil))
    }
#endif
  }
}
