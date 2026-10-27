import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../services/vpn_platform.dart';

class VpnScreen extends StatelessWidget {
  const VpnScreen({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final connected = controller.vpnState == VpnState.connected;
        return Scaffold(
          appBar: AppBar(
            title: const Text('PrivateVPN'),
            backgroundColor: Colors.transparent,
          ),
          body: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF22D3EE)
                      .withValues(alpha: connected ? 0.20 : 0.06),
                  Colors.transparent,
                ],
                radius: 0.8,
              ),
            ),
            child: Column(
              children: [
                const Spacer(),
                InkResponse(
                  onTap: controller.isBusy ? null : controller.toggleConnection,
                  radius: 116,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected
                          ? const Color(0xFF22D3EE).withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: connected
                            ? const Color(0xFF22D3EE)
                            : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 92,
                      color: connected
                          ? const Color(0xFF22D3EE)
                          : Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  controller.vpnState.label,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.profile?.maskedAddress ?? 'No server',
                  style: const TextStyle(color: Colors.white60),
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      controller.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.only(bottom: 22),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: Colors.white54,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'One credential per device',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
