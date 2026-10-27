import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_vpn/src/models/subscription_profile.dart';
import 'package:private_vpn/src/services/subscription_client.dart';

void main() {
  const vless =
      'vless://12345678-abcd-abcd-abcd-123456789abc@example.com:443'
      '?encryption=none&security=reality#Kazakhstan';
  const amnezia = '''
[Interface]
PrivateKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
Address = 10.8.1.2/32
Jc = 4
Jmin = 40
Jmax = 70
S1 = 20
S2 = 20
H1 = 123456
H2 = 234567
H3 = 345678
H4 = 456789

[Peer]
PublicKey = BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 203.0.113.10:51820
''';

  test('resolves a direct VLESS link', () async {
    final profile = await SubscriptionClient().resolve(vless);

    expect(profile.engine, VpnEngine.xray);
    expect(profile.name, 'Kazakhstan');
    expect(profile.maskedAddress, 'example.com');
  });

  test('resolves a direct AmneziaWG profile', () async {
    final profile = await SubscriptionClient().resolve(amnezia);

    expect(profile.engine, VpnEngine.amneziaWg);
    expect(profile.maskedAddress, '203.0.113.10:51820');
  });

  test('decodes a provider envelope and honors preferred transport', () async {
    final envelope = jsonEncode({
      'preferred': 'awg',
      'profiles': [
        {'type': 'vless', 'name': 'Primary', 'config': vless},
        {'type': 'awg', 'name': 'Fallback', 'config': amnezia},
      ],
    });
    final profile = await SubscriptionClient().resolve(envelope);

    expect(profile.engine, VpnEngine.amneziaWg);
    expect(profile.name, 'Fallback');
  });

  test('round-trips a profile without exposing the subscription token', () {
    final original = SubscriptionProfile(
      engine: VpnEngine.xray,
      configuration: vless,
      name: 'Primary',
      subscriptionUri: Uri.parse('https://sub.example.com/api/sub/secret'),
    );

    final restored = SubscriptionProfile.deserialize(original.serialize());
    expect(restored.engine, VpnEngine.xray);
    expect(restored.configuration, vless);
    expect(restored.maskedAddress, 'sub.example.com/••••••••');
  });

  test('rejects unsupported input', () async {
    expect(
      () => SubscriptionClient().resolve('not a profile'),
      throwsFormatException,
    );
  });
}
