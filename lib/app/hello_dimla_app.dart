import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme/app_theme.dart';
import '../screens/01_splash/splash_screen.dart';

class HelloDimlaApp extends StatelessWidget {
  const HelloDimlaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Hello Dimla',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      home: const SplashScreen(),
    );
  }
}