import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class SubscriptionClient {
  static const _maximumBytes = 1024 * 1024;

  Future<void> validate(Uri uri) async {
    if (kDebugMode && uri.host == 'sub.example.com') return;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'PrivateVPN/0.1';
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

      var received = 0;
      await for (final chunk in response) {
        received += chunk.length;
        if (received > _maximumBytes) {
          throw const SubscriptionException(
            'Subscription response exceeds the 1 MB safety limit.',
          );
        }
      }
    } on TimeoutException {
      throw const SubscriptionException('Subscription server timed out.');
    } finally {
      client.close(force: true);
    }
  }
}

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}
