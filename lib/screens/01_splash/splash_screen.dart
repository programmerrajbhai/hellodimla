import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'splash_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final SplashController controller;
  late final bool ownsController;

  @override
  void initState() {
    super.initState();

    ownsController = !Get.isRegistered<SplashController>();

    controller = ownsController
        ? Get.put(SplashController())
        : Get.find<SplashController>();
  }

  @override
  void dispose() {
    if (ownsController &&
        Get.isRegistered<SplashController>() &&
        identical(Get.find<SplashController>(), controller)) {
      Get.delete<SplashController>();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF081C50),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF081C50),
        body: SizedBox.expand(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1256DB),
                  Color(0xFF10378F),
                  Color(0xFF081C50),
                ],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final compact = bounds.maxHeight < 600;

                  final logoSize = math.min(
                    compact ? 170.0 : 240.0,
                    math.max(0.0, bounds.maxWidth - 64),
                  );

                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: bounds.maxHeight,
                        minWidth: bounds.maxWidth,
                        maxWidth: bounds.maxWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ডিমলা • নীলফামারী',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFC6DBFF),
                                fontSize: 14,
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 32,
                              ),
                              child: Column(
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: 0.96,
                                      end: 1,
                                    ),
                                    duration: Duration(
                                      milliseconds:
                                      reduceMotion ? 0 : 500,
                                    ),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, scale, child) {
                                      return Transform.scale(
                                        scale: scale,
                                        child: child,
                                      );
                                    },
                                    child: Semantics(
                                      label: 'Smart Dimla',
                                      image: true,
                                      child: ExcludeSemantics(
                                        child: Container(
                                          width: logoSize,
                                          height: logoSize,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            BorderRadius.circular(
                                              36,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color:
                                                Color(0x4005133A),
                                                blurRadius: 32,
                                                offset:
                                                Offset(0, 16),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                            BorderRadius.circular(
                                              36,
                                            ),
                                            child: Image.asset(
                                              'assets/images/app_logo.png',
                                              fit: BoxFit.cover,
                                              cacheWidth: 960,
                                              errorBuilder:
                                                  (_, error, stack) {
                                                return const ColoredBox(
                                                  color:
                                                  Color(0xFF1558EC),
                                                  child: Center(
                                                    child: Text(
                                                      'Smart Dimla',
                                                      style: TextStyle(
                                                        color:
                                                        Colors.white,
                                                        fontSize: 24,
                                                        fontWeight:
                                                        FontWeight
                                                            .w800,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 32),

                                  const Text(
                                    'আপনার ডিমলা,\nএখন আরও কাছে।',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 25,
                                      height: 1.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  const Text(
                                    'সেবা  •  শপিং  •  ব্যবসার খাতা',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFC6DBFF),
                                      fontSize: 14,
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Obx(() {
                              final error =
                                  controller.errorMessage.value;

                              if (error.isEmpty) {
                                return const Text(
                                  'স্বাগতম, স্মার্ট ডিমলায়',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFB6CDF8),
                                    fontSize: 13,
                                  ),
                                );
                              }

                              return Column(
                                children: [
                                  Text(
                                    error,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      height: 1.6,
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor:
                                      const Color(0xFF10378F),
                                      minimumSize:
                                      const Size(160, 48),
                                    ),
                                    onPressed: controller.busy.value
                                        ? null
                                        : () => controller.prepare(),
                                    child: const Text(
                                      'আবার চেষ্টা করুন',
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),

                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}