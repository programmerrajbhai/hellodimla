import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import 'splash_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late final Animation<double> _entrance;
  late final SplashController _controller;

  bool _started = false;

  @override
  void initState() {
    super.initState();

    _controller = Get.put(SplashController());

    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _entrance = CurvedAnimation(
      parent: _animation,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) return;
    _started = true;

    if (MediaQuery.of(context).disableAnimations) {
      _animation.value = 1;
    } else {
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();

    // The screen owns this controller.
    if (Get.isRegistered<SplashController>() &&
        identical(Get.find<SplashController>(), _controller)) {
      Get.delete<SplashController>();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.deepPine,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.deepPine,
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.pine,
                      AppColors.deepPine,
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BackdropPainter(),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _TopLabel(),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: FadeTransition(
                                opacity: _entrance,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.08),
                                    end: Offset.zero,
                                  ).animate(_entrance),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Semantics(
                                        label: 'Dimla: river, homes and sunshine',
                                        image: true,
                                        child: const SizedBox(
                                          width: 220,
                                          height: 220,
                                          child: CustomPaint(
                                            painter: _DimlaMarkPainter(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      const Text(
                                        'HELLO',
                                        style: TextStyle(
                                          color: AppColors.mint,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 7,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Dimla',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.cream,
                                          fontSize: 66,
                                          height: 1.12,
                                          letterSpacing: -3,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'আপনার ডিমলা, আপনার হাতেই।',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.mint,
                                          fontSize: 17,
                                          height: 1.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const _BottomLabel(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopLabel extends StatelessWidget {
  const _TopLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'নীলফামারী',
          style: TextStyle(
            color: AppColors.mint,
            fontSize: 13,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.mint),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text(
            'LOCAL LIFE',
            style: TextStyle(
              color: AppColors.mint,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomLabel extends StatelessWidget {
  const _BottomLabel();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int index = 0; index < 3; index++) ...[
              if (index > 0) const SizedBox(width: 7),
              Container(
                width: index == 1 ? 24 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == 1
                      ? AppColors.yellow
                      : AppColors.mint,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'সেবা  •  শপিং  •  ব্যবসার খাতা',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.mint,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x186BB394)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int index = 0; index < 4; index++) {
      final shift = index * 30.0;

      final path = Path()
        ..moveTo(-80, size.height * 0.58 + shift)
        ..cubicTo(
          size.width * 0.45,
          size.height * 0.32 + shift,
          size.width * 0.2,
          size.height * 0.95 + shift,
          size.width + 100,
          size.height * 0.7 + shift,
        );

      canvas.drawPath(path, paint);
    }

    canvas.drawCircle(
      Offset(size.width - 12, 64),
      100,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width - 12, 64),
      128,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}

class _DimlaMarkPainter extends CustomPainter {
  const _DimlaMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 220, size.height / 220);

    final fill = Paint()..isAntiAlias = true;

    canvas.drawCircle(
      const Offset(110, 110),
      104,
      fill..color = AppColors.yellow,
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(
        const Rect.fromLTWH(6, 6, 208, 208),
      ),
    );

    canvas.drawCircle(
      const Offset(151, 61),
      23,
      fill..color = AppColors.cream,
    );

    final land = Path()
      ..moveTo(0, 142)
      ..quadraticBezierTo(55, 102, 118, 134)
      ..quadraticBezierTo(170, 155, 220, 110)
      ..lineTo(220, 220)
      ..lineTo(0, 220)
      ..close();

    canvas.drawPath(
      land,
      fill..color = AppColors.pine,
    );

    final river = Path()
      ..moveTo(161, 123)
      ..cubicTo(97, 145, 163, 169, 77, 220)
      ..lineTo(143, 220)
      ..cubicTo(197, 165, 137, 150, 179, 121)
      ..close();

    canvas.drawPath(
      river,
      fill..color = AppColors.river,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(53, 102, 43, 36),
        const Radius.circular(3),
      ),
      fill..color = AppColors.cream,
    );

    final roof = Path()
      ..moveTo(45, 104)
      ..lineTo(74.5, 78)
      ..lineTo(104, 104)
      ..close();

    canvas.drawPath(
      roof,
      fill..color = AppColors.deepPine,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(69, 115, 12, 23),
        const Radius.circular(2),
      ),
      fill..color = AppColors.pine,
    );

    canvas.drawRect(
      const Rect.fromLTWH(28, 110, 5, 36),
      fill..color = AppColors.deepPine,
    );

    canvas.drawOval(
      const Rect.fromLTWH(15, 81, 31, 39),
      fill..color = AppColors.mint,
    );

    final bird = Paint()
      ..color = AppColors.pine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      Path()
        ..moveTo(76, 55)
        ..quadraticBezierTo(83, 48, 90, 55)
        ..quadraticBezierTo(97, 48, 104, 55),
      bird,
    );

    canvas.restore();

    canvas.drawCircle(
      const Offset(110, 110),
      109,
      Paint()
        ..color = const Color(0x55B6D4BD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DimlaMarkPainter oldDelegate) => false;
}