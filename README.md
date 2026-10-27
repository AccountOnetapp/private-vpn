# PrivateVPN

Cross-platform Flutter client for the PrivateVPN service. The current iOS
implementation contains real packet-tunnel engines for Xray/VLESS and
AmneziaWG. Flutter owns the shared product UI; each iOS engine runs in its own
Network Extension process.

## Implemented in 0.2.0

- Direct `vless://` profiles, Xray outbound JSON, AmneziaWG configuration, and
  HTTPS subscription input with a 1 MB response limit.
- Provider envelope supporting transport preference and failover-ready profile
  delivery.
- Secure profile storage through `flutter_secure_storage`.
- Xray/VLESS packet tunnel using official XTLS `libXray` v26.10.21 and the
  Xray-core TUN inbound.
- AmneziaWG packet tunnel using official `amneziawg-apple` at commit
  `9d5ee60edefa95b933a738dd7cda671dd18021fc`.
- Separate Xray and AmneziaWG extensions so their independent Go runtimes never
  load into the same process.
- iOS manager selection, connect/disconnect/status lifecycle, unit tests, and
  simulator/device compile checks.

The native code paths compile and are embedded in the app. End-to-end Internet
traffic has not yet been verified because that requires a provisioned physical
iPhone and a reachable test gateway. Android and desktop still have only the
shared UI/platform boundary; their real tunnel adapters are subsequent work.

## Bootstrap

```bash
git submodule update --init --recursive
flutter pub get
./scripts/bootstrap_ios_cores.sh
```

The bootstrap script downloads the pinned 96.8 MB libXray Apple release and
checks SHA-256 before extracting it. The binary is intentionally not committed.
AmneziaWG is pinned as a Git submodule. Its Go bridge requires Go 1.26 or newer.
`scripts/add_ios_packet_tunnel.rb` is an idempotent maintenance helper for
repairing or regenerating the two Xcode extension targets; a normal checkout
does not need to run it.

## Run from Xcode

1. Open `ios/Runner.xcworkspace`.
2. Select the `Runner` scheme and your Apple Developer team.
3. Enable Network Extensions / Packet Tunnel Provider for the app and both
   extension identifiers:
   - `com.accountonetapp.privateVpn`
   - `com.accountonetapp.privateVpn.PacketTunnel`
   - `com.accountonetapp.privateVpn.AmneziaPacketTunnel`
4. Select a physical iPhone and press Run.
5. Paste a VLESS link, an AmneziaWG profile, or an HTTPS subscription URL.

A simulator can validate UI and compilation, but Apple does not provide a real
Packet Tunnel data path there. A signed physical-device build is required for
the connection test.

## Supported provider response

The subscription endpoint may return a direct profile, a Base64 list, or this
JSON envelope:

```json
{
  "preferred": "awg",
  "profiles": [
    {"type": "awg", "name": "KZ AWG", "config": "[Interface]\n..."},
    {"type": "vless", "name": "KZ Reality", "config": "vless://..."}
  ]
}
```

Accepted profile types are `vless`/`xray` and `awg`/`amneziawg`. Credentials
are passed to the selected extension and are never written to application logs.

## Validate

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build ios --simulator --debug --no-codesign
```

Flutter 3.47.8 has an analyzer bug when the absolute path contains Cyrillic.
Run analysis from an ASCII-path copy or use CI; native Xcode and Flutter builds
work from this repository path.

See [architecture](docs/architecture.md), [third-party components](THIRD_PARTY.md),
and the [handoff index](docs/handoffs/README.md).
