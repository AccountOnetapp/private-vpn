# PrivateVPN

Cross-platform Flutter client for the PrivateVPN service. One Dart UI targets
iOS, Android, macOS, Windows, and Linux; platform-specific tunnel adapters live
behind a small method-channel boundary.

## Current milestone

- Flutter onboarding, connection, and settings UI.
- HTTPS subscription validation with a 1 MB response limit.
- Subscription credentials stored with `flutter_secure_storage`.
- iOS `NETunnelProviderManager` bridge and Packet Tunnel extension target.
- Android method-channel boundary ready for `VpnService`.
- Debug simulation on platforms whose packet engine is not linked yet.
- Unit tests and an iOS simulator build.

The repository does **not** claim a working production tunnel yet. Real device
builds fail closed until an audited Xray-compatible packet engine is linked.

## Run from Xcode

1. Install Flutter (`brew install --cask flutter`).
2. In this folder run `flutter pub get`.
3. Open `ios/Runner.xcworkspace` in Xcode.
4. Select the `Runner` scheme and an iPhone simulator.
5. Press Run, then choose **Use development demo**.

The workspace includes both `Runner` and `PacketTunnel`. A physical-device VPN
build additionally needs an Apple Developer team and the Network Extension /
Packet Tunnel capability for both bundle identifiers.

## Other platforms

```bash
flutter run -d android
flutter run -d macos
flutter run -d windows
flutter run -d linux
```

The shared UI runs on all generated platforms. Android and desktop packet
engines are explicitly tracked as subsequent milestones.

## Validate

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build ios --simulator --debug
```

On the current machine Flutter 3.47.8 has an analyzer bug when the absolute
project path contains Cyrillic; CI and ASCII-path copies are unaffected. Xcode
build and simulator launch work from the requested folder.

See [architecture](docs/architecture.md) and the [handoff](docs/handoffs/README.md).
