import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'views/activation_screen.dart';
import 'views/main_shell.dart';

class PrivateVpnApp extends StatelessWidget {
  const PrivateVpnApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrivateVPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF22D3EE),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF07111F),
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => controller.profile == null
            ? ActivationScreen(controller: controller)
            : MainShell(controller: controller),
      ),
    );
  }
}
