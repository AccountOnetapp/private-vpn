import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
  override func startTunnel(
    options: [String: NSObject]? = nil,
    completionHandler: @escaping (Error?) -> Void
  ) {
    guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol,
          let subscriptionURL = tunnelProtocol.providerConfiguration?["subscriptionURL"] as? String,
          !subscriptionURL.isEmpty else {
      completionHandler(PacketTunnelError.missingConfiguration)
      return
    }

    // Fail closed until an audited Xray-compatible packet engine is linked.
    // Reporting a fake connection here would capture and black-hole traffic.
    completionHandler(PacketTunnelError.transportNotLinked)
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}

private enum PacketTunnelError: LocalizedError {
  case missingConfiguration
  case transportNotLinked

  var errorDescription: String? {
    switch self {
    case .missingConfiguration:
      "The VPN profile does not contain a subscription URL."
    case .transportNotLinked:
      "The packet transport core has not been linked in this development build."
    }
  }
}
