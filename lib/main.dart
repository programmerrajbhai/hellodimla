import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/hello_dimla_app.dart';
import 'business/business_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppStartup());
}

class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.detached) {
      return;
    }

    if (Get.isRegistered<BusinessStore>()) {
      final ledger = Get.find<BusinessStore>();

      if (!ledger.external) {
        ledger.lock();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const HelloDimlaApp();
}