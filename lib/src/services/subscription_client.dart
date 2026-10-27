import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/subscription_profile.dart';

class SubscriptionClient {
  static const _maximumBytes = 1024 * 1024;
  static const _demoVless =
      'vless://12345678-abcd-abcd-abcd-123456789abc@127.0.0.1:443'
      '?encryption=none&security=none#Development';

  Future<SubscriptionProfile> resolve(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Paste a subscription or VPN profile.');
    }

    final source = Uri.tryParse(trimmed);
    if (source?.scheme.toLowerCase() == 'https' && source!.host.isNotEmpty) {
      final payload = kDebugMode && source.host == 'sub.example.com'
          ? _demoVless
          : await _download(source);
      return _parsePayload(payload, source);
    }
    return _parsePayload(trimmed, null);
  }

  Future<String> _download(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'PrivateVPN/0.2';
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SubscriptionException(
          'Subscription server returned HTTP ${response.statusCode}.',
        );
      }

      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > _maximumBytes) {
          throw const SubscriptionException(
            'Subscription response exceeds the 1 MB safety limit.',
          );
        }
      }
      return utf8.decode(bytes, allowMalformed: false);
    } on TimeoutException {
      throw const SubscriptionException('Subscription server timed out.');
    } on FormatException {
      throw const SubscriptionException('Subscription is not valid UTF-8.');
    } finally {
      client.close(force: true);
    }
  }

  SubscriptionProfile _parsePayload(String payload, Uri? source) {
    var text = payload.trim();
    if (text.startsWith('{')) {
      final envelope = _tryEnvelope(text, source);
      if (envelope != null) return envelope;
      if (_looksLikeXrayJson(text)) {
        return SubscriptionProfile(
          engine: VpnEngine.xray,
          configuration: text,
          name: source?.host ?? 'Xray',
          subscriptionUri: source,
        );
      }
    }

    if (!_looksLikeVless(text) && !_looksLikeAmnezia(text)) {
      final decoded = _tryBase64(text);
      if (decoded != null) text = decoded.trim();
    }

    final vless = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where(_looksLikeVless)
        .firstOrNull;
    if (vless != null) {
      final uri = Uri.parse(vless);
      return SubscriptionProfile(
        engine: VpnEngine.xray,
        configuration: vless,
        name: uri.fragment.isEmpty
            ? (source?.host ?? uri.host)
            : Uri.decodeComponent(uri.fragment),
        subscriptionUri: source,
      );
    }

    if (_looksLikeAmnezia(text)) {
      return SubscriptionProfile(
        engine: VpnEngine.amneziaWg,
        configuration: text,
        name: source?.host ?? 'AmneziaWG',
        subscriptionUri: source,
      );
    }

    throw const FormatException(
      'No supported VLESS or AmneziaWG profile was found.',
    );
  }

  SubscriptionProfile? _tryEnvelope(String text, Uri? source) {
    try {
      final value = jsonDecode(text);
      if (value is! Map<String, dynamic>) return null;
      final profiles = value['profiles'];
      if (profiles is! List || profiles.isEmpty) return null;
      final preferred = value['preferred'] as String?;
      final candidates = profiles.whereType<Map>().map(
        (item) => Map<String, dynamic>.from(item),
      );
      final ordered = [
        ...candidates.where((item) => item['type'] == preferred),
        ...candidates.where((item) => item['type'] != preferred),
      ];
      for (final item in ordered) {
        final config = item['config'] as String?;
        final type = (item['type'] as String?)?.toLowerCase();
        if (config == null) continue;
        if ((type == 'xray' || type == 'vless') &&
            (_looksLikeVless(config) || _looksLikeXrayJson(config))) {
          return SubscriptionProfile(
            engine: VpnEngine.xray,
            configuration: config.trim(),
            name: item['name'] as String? ?? source?.host ?? 'Xray',
            subscriptionUri: source,
          );
        }
        if ((type == 'amneziawg' || type == 'awg') &&
            _looksLikeAmnezia(config)) {
          return SubscriptionProfile(
            engine: VpnEngine.amneziaWg,
            configuration: config.trim(),
            name: item['name'] as String? ?? source?.host ?? 'AmneziaWG',
            subscriptionUri: source,
          );
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  bool _looksLikeVless(String value) =>
      value.trimLeft().toLowerCase().startsWith('vless://');

  bool _looksLikeAmnezia(String value) {
    final lower = value.toLowerCase();
    return lower.contains('[interface]') &&
        lower.contains('privatekey') &&
        lower.contains('[peer]') &&
        lower.contains('publickey');
  }

  bool _looksLikeXrayJson(String value) {
    try {
      final json = jsonDecode(value);
      return json is Map && json['outbounds'] is List;
    } on FormatException {
      return false;
    }
  }

  String? _tryBase64(String value) {
    try {
      final normalized = base64.normalize(value.replaceAll(RegExp(r'\s'), ''));
      return utf8.decode(base64.decode(normalized));
    } on Object {
      return null;
    }
  }
}

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
