import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  Future<void> configure(String subscriptionUrl) async {
    try {
      await _channel.invokeMethod<void>('configure', {
        'subscriptionURL': subscriptionUrl,
      });
    } on MissingPluginException {
      if (!kDebugMode) rethrow;
    }
  }

  Future<VpnState> connect() async {
    try {
      final value = await _channel.invokeMethod<String>('connect');
      return _parse(value);
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
