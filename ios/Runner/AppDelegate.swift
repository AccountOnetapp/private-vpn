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
  private let xrayBundleIdentifier = "com.accountonetapp.privateVpn.PacketTunnel"
  private let amneziaBundleIdentifier = "com.accountonetapp.privateVpn.AmneziaPacketTunnel"
  private var manager: NETunnelProviderManager?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configure":
      guard let arguments = call.arguments as? [String: Any],
            let engine = arguments["engine"] as? String,
            let configuration = arguments["configuration"] as? String,
            let serverAddress = arguments["serverAddress"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing VPN configuration", details: nil))
        return
      }
      configure(
        engine: engine,
        configuration: configuration,
        serverAddress: serverAddress,
        result: result
      )
    case "connect":
      connect(result: result)
    case "disconnect":
      manager?.connection.stopVPNTunnel()
      result("disconnected")
    case "status":
      result(statusName(manager?.connection.status ?? .invalid))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configure(
    engine: String,
    configuration: String,
    serverAddress: String,
    result: @escaping FlutterResult
  ) {
#if targetEnvironment(simulator)
    result(nil)
#else
    let providerBundleIdentifier: String
    switch engine {
    case "xray":
      providerBundleIdentifier = xrayBundleIdentifier
    case "amneziaWg":
      providerBundleIdentifier = amneziaBundleIdentifier
    default:
      result(FlutterError(code: "UNSUPPORTED_ENGINE", message: "Unsupported VPN engine", details: nil))
      return
    }

    NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
      if let error {
        result(FlutterError(code: "LOAD_FAILED", message: error.localizedDescription, details: nil))
        return
      }

      let selected = managers?.first(where: { manager in
        (manager.protocolConfiguration as? NETunnelProviderProtocol)?
          .providerBundleIdentifier == providerBundleIdentifier
      }) ?? NETunnelProviderManager()
      let tunnelProtocol = NETunnelProviderProtocol()
      tunnelProtocol.providerBundleIdentifier = providerBundleIdentifier
      tunnelProtocol.serverAddress = serverAddress
      tunnelProtocol.providerConfiguration = [
        "engine": engine,
        "configuration": configuration,
        "configurationVersion": 2,
      ]
      selected.localizedDescription = "PrivateVPN"
      selected.protocolConfiguration = tunnelProtocol
      selected.isEnabled = true
      selected.saveToPreferences { saveError in
        if let saveError {
          result(FlutterError(code: "SAVE_FAILED", message: saveError.localizedDescription, details: nil))
          return
        }
        selected.loadFromPreferences { loadError in
          if let loadError {
            result(FlutterError(code: "RELOAD_FAILED", message: loadError.localizedDescription, details: nil))
            return
          }
          self?.manager = selected
          result(nil)
        }
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

  private func statusName(_ status: NEVPNStatus) -> String {
    switch status {
    case .connected:
      "connected"
    case .connecting, .reasserting:
      "connecting"
    case .disconnecting:
      "disconnecting"
    case .disconnected, .invalid:
      "disconnected"
    @unknown default:
      "unavailable"
    }
  }
}
