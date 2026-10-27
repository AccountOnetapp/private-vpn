import 'package:flutter/material.dart';

import 'src/app_controller.dart';
import 'src/private_vpn_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  runApp(PrivateVpnApp(controller: controller));
  controller.restore();
}
