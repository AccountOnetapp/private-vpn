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

  static const _subscriptionKey = 'subscription_url';

  final FlutterSecureStorage _secureStorage;
  final SubscriptionClient _subscriptionClient;
  final VpnPlatform _vpnPlatform;

  SubscriptionProfile? profile;
  VpnState vpnState = VpnState.disconnected;
  bool isBusy = false;
  String? errorMessage;

  Future<void> restore() async {
    try {
      final stored = await _secureStorage.read(key: _subscriptionKey);
      if (stored != null) profile = SubscriptionProfile.parse(stored);
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
      final candidate = SubscriptionProfile.parse(input);
      await _subscriptionClient.validate(candidate.subscriptionUri);
      await _secureStorage.write(
        key: _subscriptionKey,
        value: candidate.subscriptionUri.toString(),
      );
      await _vpnPlatform.configure(candidate.subscriptionUri.toString());
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
    await _secureStorage.delete(key: _subscriptionKey);
    profile = null;
    vpnState = VpnState.disconnected;
    errorMessage = null;
    notifyListeners();
  }
}
