import 'package:flutter_test/flutter_test.dart';
import 'package:private_vpn/src/models/subscription_profile.dart';

void main() {
  test('accepts an HTTPS subscription URL', () {
    final profile = SubscriptionProfile.parse(
      '  https://sub.example.com/api/sub/device-token  ',
    );

    expect(profile.subscriptionUri.host, 'sub.example.com');
    expect(profile.maskedAddress, 'sub.example.com/••••••••');
  });

  test('rejects HTTP subscription URLs', () {
    expect(
      () => SubscriptionProfile.parse('http://example.com/token'),
      throwsFormatException,
    );
  });

  test('rejects plain text', () {
    expect(
      () => SubscriptionProfile.parse('not a link'),
      throwsFormatException,
    );
  });
}
