import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/subscription_profile.dart';
import 'services/subscription_client.dart';
import 'services/vpn_platform.dart';

class AppController extends ChangeNotifier {
  AppController({
    FlutterSecureStorage? secureStorage,
    SubscriptionClient? subscriptionClient,
    VpnPlatform? vpnPlatform,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _subscriptionClient = subscriptionClient ?? SubscriptionClient(),
       _vpnPlatform = vpnPlatform ?? VpnPlatform();

  static const _profileKey = 'vpn_profile_v2';

  final FlutterSecureStorage _secureStorage;
  final SubscriptionClient _subscriptionClient;
  final VpnPlatform _vpnPlatform;

  SubscriptionProfile? profile;
  VpnState vpnState = VpnState.disconnected;
  bool isBusy = false;
  String? errorMessage;

  Future<void> restore() async {
    try {
      final stored = await _secureStorage.read(key: _profileKey);
      if (stored != null) {
        profile = SubscriptionProfile.deserialize(stored);
        await _vpnPlatform.configure(profile!);
      }
    } catch (error) {
      errorMessage = 'Could not restore the saved profile: $error';
    }
    notifyListeners();
  }

  Future<bool> activate(String input) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final candidate = await _subscriptionClient.resolve(input);
      await _vpnPlatform.configure(candidate);
      await _secureStorage.write(
        key: _profileKey,
        value: candidate.serialize(),
      );
      profile = candidate;
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> toggleConnection() async {
    if (isBusy || profile == null) return;
    isBusy = true;
    errorMessage = null;
    final disconnecting =
        vpnState == VpnState.connected || vpnState == VpnState.connecting;
    vpnState = disconnecting ? VpnState.disconnecting : VpnState.connecting;
    notifyListeners();

    try {
      vpnState = disconnecting
          ? await _vpnPlatform.disconnect()
          : await _vpnPlatform.connect();
    } catch (error) {
      vpnState = VpnState.unavailable;
      errorMessage = error.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> removeProfile() async {
    if (vpnState == VpnState.connected) await _vpnPlatform.disconnect();
    await _secureStorage.delete(key: _profileKey);
    profile = null;
    vpnState = VpnState.disconnected;
    errorMessage = null;
    notifyListeners();
  }
}
