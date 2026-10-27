// SPDX-License-Identifier: MIT
// Parser behavior follows amnezia-vpn/amneziawg-apple's WireGuardKit model.

import Foundation
import WireGuardKit

enum AmneziaConfigParser {
  private enum Section { case interface, peer }

  static func parse(_ text: String, name: String) throws -> TunnelConfiguration {
    var section: Section?
    var interfaceValues = [String: String]()
    var peerValues = [[String: String]]()
    var currentPeer = [String: String]()

    for rawLine in text.split(whereSeparator: \.isNewline) {
      let uncommented = rawLine.split(separator: "#", maxSplits: 1).first ?? rawLine
      let line = uncommented.trimmingCharacters(in: .whitespacesAndNewlines)
      if line.isEmpty { continue }
      switch line.lowercased() {
      case "[interface]":
        if section != nil { throw ParseError.multipleInterfaces }
        section = .interface
      case "[peer]":
        if section == .peer, !currentPeer.isEmpty {
          peerValues.append(currentPeer)
          currentPeer.removeAll()
        }
        guard section != nil else { throw ParseError.peerBeforeInterface }
        section = .peer
      default:
        guard let separator = line.firstIndex(of: "="), let section else {
          throw ParseError.invalidLine
        }
        let key = line[..<separator]
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .lowercased()
        let value = line[line.index(after: separator)...]
          .trimmingCharacters(in: .whitespacesAndNewlines)
        if section == .interface {
          try insert(key: key, value: value, into: &interfaceValues)
        } else {
          try insert(key: key, value: value, into: &currentPeer)
        }
      }
    }
    if section == .peer, !currentPeer.isEmpty { peerValues.append(currentPeer) }

    let interface = try makeInterface(interfaceValues)
    let peers = try peerValues.map(makePeer)
    guard !peers.isEmpty else { throw ParseError.noPeers }
    return TunnelConfiguration(name: name, interface: interface, peers: peers)
  }

  private static func insert(
    key: String,
    value: String,
    into values: inout [String: String]
  ) throws {
    if let existing = values[key], ["address", "dns", "allowedips"].contains(key) {
      values[key] = existing + "," + value
    } else if values[key] != nil {
      throw ParseError.duplicateKey
    } else {
      values[key] = value
    }
  }

  private static func makeInterface(_ values: [String: String]) throws -> InterfaceConfiguration {
    guard let encodedKey = values["privatekey"],
          let privateKey = PrivateKey(base64Key: encodedKey) else {
      throw ParseError.invalidPrivateKey
    }
    var result = InterfaceConfiguration(privateKey: privateKey)
    result.addresses = try list(values["address"]).map {
      guard let value = IPAddressRange(from: $0) else { throw ParseError.invalidAddress }
      return value
    }
    for value in list(values["dns"]) {
      if let server = DNSServer(from: value) {
        result.dns.append(server)
      } else {
        result.dnsSearch.append(value)
      }
    }
    if let value = values["listenport"] {
      guard let parsed = UInt16(value) else { throw ParseError.invalidNumber }
      result.listenPort = parsed
    }
    if let value = values["mtu"] {
      guard let parsed = UInt16(value) else { throw ParseError.invalidNumber }
      result.mtu = parsed
    }

    result.junkPacketCount = try number(values["jc"])
    result.junkPacketMinSize = try number(values["jmin"])
    result.junkPacketMaxSize = try number(values["jmax"])
    result.initPacketJunkSize = try number(values["s1"])
    result.responsePacketJunkSize = try number(values["s2"])
    result.cookieReplyPacketJunkSize = try number(values["s3"])
    result.transportPacketJunkSize = try number(values["s4"])
    result.initPacketMagicHeader = values["h1"]
    result.responsePacketMagicHeader = values["h2"]
    result.underloadPacketMagicHeader = values["h3"]
    result.transportPacketMagicHeader = values["h4"]
    result.specialJunk1 = values["i1"]
    result.specialJunk2 = values["i2"]
    result.specialJunk3 = values["i3"]
    result.specialJunk4 = values["i4"]
    result.specialJunk5 = values["i5"]
    result.contentPaddingAddition = values["contentpaddingaddition"]
    result.rekeyAfterTime = values["rekeyaftertime"]
    result.rekeyTimeout = values["rekeytimeout"]
    result.rejectAfterTime = values["rejectaftertime"]
    result.keepaliveTimeout = values["keepalivetimeout"]
    result.maxHandshakeAttempts = values["maxhandshakeattempts"]
    result.randomTrailers = values["randomtrailers"]
    result.disableCookies = values["disablecookies"]
    if let encodedKey = values["headerprotectionkey"] {
      guard let key = PrivateKey(base64Key: encodedKey) else {
        throw ParseError.invalidHeaderProtectionKey
      }
      result.headerProtectionKey = key
    }
    return result
  }

  private static func makePeer(_ values: [String: String]) throws -> PeerConfiguration {
    guard let encodedKey = values["publickey"],
          let publicKey = PublicKey(base64Key: encodedKey) else {
      throw ParseError.invalidPublicKey
    }
    var result = PeerConfiguration(publicKey: publicKey)
    if let encodedKey = values["presharedkey"] {
      guard let key = PreSharedKey(base64Key: encodedKey) else {
        throw ParseError.invalidPreSharedKey
      }
      result.preSharedKey = key
    }
    result.allowedIPs = try list(values["allowedips"]).map {
      guard let value = IPAddressRange(from: $0) else { throw ParseError.invalidAllowedIP }
      return value
    }
    if let value = values["endpoint"] {
      guard let endpoint = Endpoint(from: value) else { throw ParseError.invalidEndpoint }
      result.endpoint = endpoint
    }
    result.persistentKeepAlive = values["persistentkeepalive"]
    return result
  }

  private static func list(_ value: String?) -> [String] {
    value?.split(separator: ",").map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }.filter { !$0.isEmpty } ?? []
  }

  private static func number(_ value: String?) throws -> UInt16? {
    guard let value else { return nil }
    guard let result = UInt16(value) else { throw ParseError.invalidNumber }
    return result
  }

  enum ParseError: LocalizedError {
    case invalidLine, multipleInterfaces, peerBeforeInterface, duplicateKey
    case invalidPrivateKey, invalidHeaderProtectionKey, invalidPublicKey
    case invalidPreSharedKey, invalidAddress, invalidAllowedIP, invalidEndpoint
    case invalidNumber, noPeers

    var errorDescription: String? {
      "The AmneziaWG profile is malformed (\(String(describing: self)))."
    }
  }
}
