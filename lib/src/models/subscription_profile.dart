class SubscriptionProfile {
  const SubscriptionProfile({required this.subscriptionUri});

  final Uri subscriptionUri;

  factory SubscriptionProfile.parse(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      throw const FormatException('Use a valid HTTPS subscription link.');
    }
    return SubscriptionProfile(subscriptionUri: uri);
  }

  String get name => subscriptionUri.host;
  String get maskedAddress => '${subscriptionUri.host}/••••••••';
}
