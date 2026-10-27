# Client architecture

```text
Flutter UI and product state
  -> secure storage: selected profile and subscription URL
  -> MethodChannel: configure / connect / disconnect / status
      -> iOS NETunnelProviderManager
          -> PacketTunnel process: libXray -> Xray-core TUN -> VLESS
          -> AmneziaPacketTunnel process: WireGuardKit -> AmneziaWG Go
      -> Android VpnService adapter (next milestone)
      -> desktop native TUN adapter (later milestone)
```

Flutter owns onboarding, settings, subscription validation, and connection
state. Platform code owns VPN permission, lifecycle, and packet interfaces.
The selected raw profile is stored in the platform keychain and copied into
the matching `NETunnelProviderProtocol` configuration; it is not logged.

## Why two iOS extensions

Both libXray and AmneziaWG embed a Go runtime. Go does not support two
independently compiled runtimes inside one process. Combining both archives in
one Packet Tunnel could fail during linking or crash during initialization.
Two Network Extension processes keep the runtimes isolated while presenting a
single app and system VPN lifecycle.

## Xray path

`PacketTunnelProvider` accepts either a direct VLESS share link or Xray JSON.
libXray converts share links into validated outbounds. The extension creates a
minimal Xray configuration with DNS, a TUN inbound, routing, and the chosen
outbound. After iOS supplies the `utun` file descriptor, it is passed through
the root `env` key `xray.tun.fd` before `runXray` starts.

## AmneziaWG path

`AmneziaConfigParser` maps WireGuard keys and Amnezia options (`Jc`, `Jmin`,
`Jmax`, `S1`-`S4`, `H1`-`H4`, `I1`-`I5`, and advanced timing fields) into
WireGuardKit models. `WireGuardAdapter` then creates the iOS network settings
and starts the official AmneziaWG Go backend.

## Current verification boundary

- Verified: Dart formatting, analysis, parser tests, Xray and AmneziaWG
  extension builds for simulator and arm64 iPhone, complete Runner simulator
  build, extension embedding, install, and app launch.
- Not yet verified: real packet flow, DNS behavior, reconnect behavior, memory
  pressure, and throughput on a physical iPhone.
- Required externally: Apple Network Extension provisioning and a gateway with
  VLESS/REALITY and/or AmneziaWG test credentials.

## Subsequent platform work

Android needs a real `VpnService` adapter and compatible native artifacts.
macOS, Windows, and Linux need their platform TUN lifecycle. Those targets can
reuse subscription parsing and product state but cannot reuse iOS Network
Extension code.
