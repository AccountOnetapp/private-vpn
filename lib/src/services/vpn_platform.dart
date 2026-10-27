import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/subscription_profile.dart';

enum VpnState {
  disconnected('Not connected'),
  connecting('Connecting'),
  connected('Protected'),
  disconnecting('Disconnecting'),
  unavailable('Transport unavailable');

  const VpnState(this.label);
  final String label;
}

class VpnPlatform {
  static const _channel = MethodChannel('com.accountonetapp.privatevpn/vpn');

  Future<void> configure(SubscriptionProfile profile) async {
    try {
      await _channel.invokeMethod<void>('configure', {
        'engine': profile.engine.name,
        'configuration': profile.configuration,
        'serverAddress': profile.maskedAddress,
      });
    } on MissingPluginException {
      if (!kDebugMode) rethrow;
    }
  }

  Future<VpnState> connect() async {
    try {
      final value = await _channel.invokeMethod<String>('connect');
      var state = _parse(value);
      for (
        var attempt = 0;
        state == VpnState.connecting && attempt < 60;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        state = _parse(await _channel.invokeMethod<String>('status'));
      }
      return state == VpnState.connecting ? VpnState.unavailable : state;
    } on MissingPluginException {
      if (kDebugMode) return VpnState.connected;
      rethrow;
    }
  }

  Future<VpnState> disconnect() async {
    try {
      final value = await _channel.invokeMethod<String>('disconnect');
      return _parse(value);
    } on MissingPluginException {
      if (kDebugMode) return VpnState.disconnected;
      rethrow;
    }
  }

  VpnState _parse(String? value) {
    return VpnState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => VpnState.unavailable,
    );
  }
}
