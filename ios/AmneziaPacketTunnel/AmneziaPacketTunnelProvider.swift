import NetworkExtension
import WireGuardKit

final class AmneziaPacketTunnelProvider: NEPacketTunnelProvider {
  private lazy var adapter = WireGuardAdapter(with: self) { _, _ in
    // Do not forward backend output: VPN configuration values are credentials.
  }

  override func startTunnel(
    options: [String: NSObject]? = nil,
    completionHandler: @escaping (Error?) -> Void
  ) {
    guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol,
          let configuration = tunnelProtocol.providerConfiguration?["configuration"] as? String else {
      completionHandler(AmneziaTunnelError.missingConfiguration)
      return
    }

    do {
      let tunnel = try AmneziaConfigParser.parse(configuration, name: "PrivateVPN")
      adapter.start(tunnelConfiguration: tunnel) { error in
        completionHandler(error)
      }
    } catch {
      completionHandler(error)
    }
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    adapter.stop { _ in completionHandler() }
  }
}

private enum AmneziaTunnelError: LocalizedError {
  case missingConfiguration

  var errorDescription: String? {
    "The VPN profile does not contain an AmneziaWG configuration."
  }
}
