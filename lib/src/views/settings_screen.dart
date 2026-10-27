import 'package:flutter/material.dart';

import '../app_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('Connection'),
          const ListTile(title: Text('Mode'), trailing: Text('Automatic')),
          const ListTile(title: Text('Routing'), trailing: Text('RU direct')),
          const ListTile(
            title: Text('Transport'),
            trailing: Text('Core pending'),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Device'),
          ListTile(
            title: const Text('Subscription'),
            subtitle: Text(controller.profile?.maskedAddress ?? 'None'),
          ),
          const ListTile(title: Text('Version'), trailing: Text('0.1.0 (1)')),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => _confirmRemoval(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove this device'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoval(BuildContext context) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this VPN profile?'),
        content: const Text(
          'The subscription credential will be deleted from secure storage on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true) await controller.removeProfile();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: const Color(0xFF22D3EE), letterSpacing: 1.2),
      ),
    );
  }
}
