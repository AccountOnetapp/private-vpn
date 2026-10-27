# Handoff: real Xray/VLESS and AmneziaWG cores on iOS

- **Author / task:** Codex; replace the iOS placeholder tunnel with real
  Xray/VLESS and AmneziaWG implementations while keeping the Flutter app
  runnable from Xcode.
- **Result:** direct VLESS, Xray JSON, AmneziaWG, Base64 subscription, and
  provider-envelope parsing; official libXray/Xray-core TUN integration;
  official AmneziaWG WireGuardKit/Go integration; two isolated Packet Tunnel
  extensions; native manager selection and status polling; pinned dependency
  bootstrap; CI setup; version `0.2.0+2`; architecture and license notes.
- **Branch and commits:** `main`; implementation commit `ac6891e`. This handoff
  and its index are committed separately and identified in the final task
  report.
- **Checks:** Dart formatting; `flutter analyze` from an ASCII-path copy due the
  documented Flutter 3.47.8 Cyrillic-path analyzer bug; 5 Flutter tests;
  `PacketTunnel`/libXray builds for iOS Simulator and generic arm64 iOS;
  `AmneziaPacketTunnel`/AmneziaWG builds for iOS Simulator and generic arm64
  iOS; complete `flutter build ios --simulator --debug --no-codesign`;
  embedded-extension inspection; simulator install and launch; libXray
  `CGoInvoke` runtime conversion of a VLESS share link; plist, shell/Ruby
  syntax, diff, and Xcode-generator idempotency checks.
- **Published:** nothing new was pushed or deployed. The public GitHub
  repository remains <https://github.com/AccountOnetapp/private-vpn> at its
  previously pushed revision. No TestFlight/App Store build and no VPN gateway
  deployment were performed.
- **Limitations:** real packet flow is not verified without a provisioned
  physical iPhone and reachable gateway. Apple Network Extension capabilities
  must be enabled for the app and both extensions. The unsigned simulator build
  cannot validate Keychain behavior or establish a system VPN. Android and
  desktop still lack native tunnel engines. AmneziaWG's upstream Swift package
  emits a harmless stale relative library-search-path warning; the app target
  supplies the correct absolute path and links successfully.
- **Next steps:** provision the three Apple identifiers, deploy one test gateway
  with VLESS/REALITY and AmneziaWG, run DNS/IPv4/IPv6/reconnect/leak/throughput
  tests on a physical iPhone, then prepare TestFlight. Implement Android
  `VpnService` after the iOS end-to-end gate passes.
