import 'dart:convert';

enum VpnEngine {
  xray('Xray / VLESS'),
  amneziaWg('AmneziaWG');

  const VpnEngine(this.label);
  final String label;
}

class SubscriptionProfile {
  const SubscriptionProfile({
    required this.engine,
    required this.configuration,
    required this.name,
    this.subscriptionUri,
  });

  final VpnEngine engine;
  final String configuration;
  final String name;
  final Uri? subscriptionUri;

  String get maskedAddress {
    final source = subscriptionUri;
    if (source != null) return '${source.host}/••••••••';
    if (engine == VpnEngine.xray) {
      final uri = Uri.tryParse(configuration.trim());
      if (uri != null && uri.host.isNotEmpty) return uri.host;
    }
    final endpoint = RegExp(
      r'^\s*Endpoint\s*=\s*([^\s#]+)',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(configuration);
    return endpoint?.group(1) ?? 'Local secure profile';
  }

  String serialize() => jsonEncode({
    'engine': engine.name,
    'configuration': configuration,
    'name': name,
    'subscriptionURL': subscriptionUri?.toString(),
  });

  factory SubscriptionProfile.deserialize(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    final engineName = json['engine'] as String?;
    final engines = VpnEngine.values.where((item) => item.name == engineName);
    if (engines.isEmpty) throw const FormatException('Unknown VPN engine.');
    final engine = engines.first;
    final configuration = json['configuration'] as String?;
    if (configuration == null || configuration.trim().isEmpty) {
      throw const FormatException('Saved VPN configuration is empty.');
    }
    final source = json['subscriptionURL'] as String?;
    final savedName = (json['name'] as String?)?.trim();
    return SubscriptionProfile(
      engine: engine,
      configuration: configuration,
      name: savedName == null || savedName.isEmpty ? engine.label : savedName,
      subscriptionUri: source == null ? null : Uri.tryParse(source),
    );
  }
}
