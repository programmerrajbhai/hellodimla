import 'dart:async';

import 'package:get/get.dart';

import '../../app/main_shell.dart';

class SplashController extends GetxController {
  Timer? _timer;
  bool _navigated = false;

  @override
  void onReady() {
    super.onReady();

    _timer = Timer(
      const Duration(milliseconds: 1800),
      _openApp,
    );
  }

  void _openApp() {
    if (isClosed || _navigated) return;

    _navigated = true;

    Get.offAll(
          () => const MainShell(),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}