import Foundation
import LibXray
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
  private let core = XrayCore()

  override func startTunnel(
    options: [String: NSObject]? = nil,
    completionHandler: @escaping (Error?) -> Void
  ) {
    guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol,
          let configuration = tunnelProtocol.providerConfiguration?["configuration"] as? String,
          !configuration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      completionHandler(PacketTunnelError.missingConfiguration)
      return
    }

    let settings = makeNetworkSettings(
      remoteAddress: tunnelProtocol.serverAddress ?? "PrivateVPN"
    )
    setTunnelNetworkSettings(settings) { [weak self] error in
      if let error {
        completionHandler(error)
        return
      }
      guard let self else {
        completionHandler(PacketTunnelError.providerReleased)
        return
      }
      guard let fileDescriptor = self.findTunnelFileDescriptor() else {
        completionHandler(PacketTunnelError.tunnelDescriptorUnavailable)
        return
      }

      do {
        let xrayJSON = try self.core.makeTunnelConfiguration(
          from: configuration,
          tunnelFileDescriptor: fileDescriptor
        )
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            try self.core.start(configuration: xrayJSON)
            completionHandler(nil)
          } catch {
            completionHandler(error)
          }
        }
      } catch {
        completionHandler(error)
      }
    }
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    DispatchQueue.global(qos: .utility).async { [core] in
      try? core.stop()
      completionHandler()
    }
  }

  private func makeNetworkSettings(remoteAddress: String) -> NEPacketTunnelNetworkSettings {
    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: remoteAddress)
    let ipv4 = NEIPv4Settings(
      addresses: ["172.19.0.1"],
      subnetMasks: ["255.255.255.252"]
    )
    ipv4.includedRoutes = [.default()]
    settings.ipv4Settings = ipv4

    let ipv6 = NEIPv6Settings(
      addresses: ["fdfe:dcba:9876::1"],
      networkPrefixLengths: [64]
    )
    ipv6.includedRoutes = [.default()]
    settings.ipv6Settings = ipv6

    let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
    dns.matchDomains = [""]
    settings.dnsSettings = dns
    settings.mtu = 1500
    return settings
  }

  private func findTunnelFileDescriptor() -> Int32? {
    for descriptor in Int32(0)...Int32(1024) {
      var interfaceName = [CChar](repeating: 0, count: Int(IFNAMSIZ))
      var length = socklen_t(interfaceName.count)
      let result = getsockopt(
        descriptor,
        2, // SYSPROTO_CONTROL
        2, // UTUN_OPT_IFNAME
        &interfaceName,
        &length
      )
      if result == 0, String(cString: interfaceName).hasPrefix("utun") {
        return descriptor
      }
    }
    return nil
  }
}

private final class XrayCore {
  func makeTunnelConfiguration(
    from source: String,
    tunnelFileDescriptor: Int32
  ) throws -> String {
    let root: [String: Any]
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("{") {
      let data = Data(trimmed.utf8)
      guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            object["outbounds"] is [[String: Any]] else {
        throw PacketTunnelError.invalidXrayConfiguration
      }
      root = object
    } else {
      let response = try invoke(
        method: "convertShareLinksToXrayJson",
        payload: ["text": trimmed]
      )
      guard let data = response["data"] as? [String: Any] else {
        throw PacketTunnelError.invalidXrayConfiguration
      }
      root = data
    }

    guard var outbounds = root["outbounds"] as? [[String: Any]], !outbounds.isEmpty else {
      throw PacketTunnelError.invalidXrayConfiguration
    }
    outbounds[0]["tag"] = "proxy"

    let configuration: [String: Any] = [
      "env": ["xray.tun.fd": String(tunnelFileDescriptor)],
      "log": ["loglevel": "warning"],
      "dns": [
        "queryStrategy": "UseIP",
        "servers": ["1.1.1.1", "8.8.8.8"],
      ],
      "inbounds": [[
        "tag": "tun-in",
        "protocol": "tun",
        "settings": [
          "name": "utun-privatevpn",
          "mtu": 1500,
        ],
        "sniffing": [
          "enabled": true,
          "destOverride": ["http", "tls", "quic"],
          "routeOnly": true,
        ],
      ]],
      "outbounds": outbounds,
      "routing": [
        "domainStrategy": "IPIfNonMatch",
        "rules": [],
      ],
    ]
    let data = try JSONSerialization.data(withJSONObject: configuration)
    guard let value = String(data: data, encoding: .utf8) else {
      throw PacketTunnelError.invalidXrayConfiguration
    }
    return value
  }

  func start(configuration: String) throws {
    _ = try invoke(method: "runXray", payload: ["xrayJson": configuration])
  }

  func stop() throws {
    _ = try invoke(method: "stopXray", payload: [:])
  }

  private func invoke(method: String, payload: [String: Any]) throws -> [String: Any] {
    let request: [String: Any] = [
      "apiVersion": 3,
      "method": method,
      "payload": payload,
    ]
    let requestData = try JSONSerialization.data(withJSONObject: request)
    guard let requestString = String(data: requestData, encoding: .utf8) else {
      throw PacketTunnelError.invalidXrayConfiguration
    }

    let responsePointer = requestString.withCString { pointer in
      CGoInvoke(UnsafeMutablePointer(mutating: pointer))
    }
    guard let responsePointer else {
      throw PacketTunnelError.emptyCoreResponse
    }
    defer { CGoFree(responsePointer) }

    let responseData = Data(String(cString: responsePointer).utf8)
    guard let response = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
      throw PacketTunnelError.emptyCoreResponse
    }
    guard response["success"] as? Bool == true else {
      let message = response["error"] as? String ?? "Unknown libXray error."
      throw PacketTunnelError.coreFailure(message)
    }
    return response
  }
}

private enum PacketTunnelError: LocalizedError {
  case missingConfiguration
  case invalidXrayConfiguration
  case tunnelDescriptorUnavailable
  case emptyCoreResponse
  case coreFailure(String)
  case providerReleased

  var errorDescription: String? {
    switch self {
    case .missingConfiguration:
      "The VPN profile does not contain an Xray configuration."
    case .invalidXrayConfiguration:
      "The VLESS/Xray configuration is invalid or contains no usable outbound."
    case .tunnelDescriptorUnavailable:
      "The iOS packet tunnel file descriptor is unavailable."
    case .emptyCoreResponse:
      "libXray returned an empty response."
    case .coreFailure(let message):
      "libXray could not start: \(message)"
    case .providerReleased:
      "The packet tunnel provider was released during startup."
    }
  }
}
