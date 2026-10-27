# Client architecture

```text
Flutter UI and product state
  -> secure storage: subscription credential
  -> MethodChannel: configure / connect / disconnect / status
      -> iOS: NETunnelProviderManager -> Packet Tunnel extension
      -> Android: VpnService adapter (next milestone)
      -> desktop: native TUN adapter (later milestone)
          -> audited transport core (next milestone)
              -> PrivateVPN gateways
```

Flutter owns the reusable onboarding, settings, subscription validation, and
connection-state UI. Platform code owns VPN permissions, lifecycle, and packet
interfaces. The eventual transport core must fit the iOS extension memory
limit, expose no subscription secrets to logs, and support the server profile
published by the PrivateVPN control plane.

## Current boundary

- Implemented: shared Flutter app for five platforms, secure credential
  storage, HTTPS subscription validation, platform-channel contract, iOS
  system VPN profile management, Packet Tunnel target, Android bridge, debug
  simulation, and unit tests.
- Not implemented: Remnawave payload parsing, Xray/sing-box integration,
  Android `VpnService`, desktop TUN, DNS interception, split routing, failover,
  and production telemetry.
- Required externally: Apple Network Extension provisioning and at least one
  deployed gateway.

## Why Flutter

VPN packet handling is native regardless of UI framework. Flutter keeps the
product surface common without hiding the native extension boundary. It also
aligns with the architecture used by Hiddify App, which is a useful upstream
reference for subscription and tunnel lifecycle design.

## Transport integration gate

Compare a minimal Xray mobile bridge, a sing-box mobile library, and the cost of
forking an upstream client. The selected option must pass license review,
device compilation, extension-memory measurement, leak tests, and field tests.
The extension continues to fail closed until that gate is complete.
