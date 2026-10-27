import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF10324A), Color(0xFF07111F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      size: 92,
                      color: Color(0xFF22D3EE),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'PrivateVPN',
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Paste a subscription link, VLESS link, or AmneziaWG profile.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 34),
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 5,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Subscription or profile',
                        hintText: 'https://…  •  vless://…  •  [Interface]…',
                        prefixIcon: Icon(Icons.link_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: state.isBusy
                            ? null
                            : () => state.activate(_urlController.text),
                        icon: state.isBusy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          state.isBusy ? 'Checking…' : 'Activate device',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 17),
                        ),
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: state.isBusy
                            ? null
                            : () {
                                _urlController.text =
                                    'https://sub.example.com/api/sub/demo';
                                state.activate(_urlController.text);
                              },
                        child: const Text('Use development demo'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'Credentials are stored in platform-secure storage and are never written to logs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
