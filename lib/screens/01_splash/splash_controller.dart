import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/main_shell.dart';
import '../../services/community_service.dart';

class SplashController extends GetxController {
  final errorMessage = ''.obs;
  final busy = false.obs;

  bool _navigated = false;

  @override
  void onReady() {
    super.onReady();
    unawaited(prepare());
  }

  Future<void> prepare() async {
    if (busy.value || _navigated || isClosed) return;

    busy.value = true;
    errorMessage.value = '';

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      if (isClosed) return;

      if (!Get.isRegistered<CommunityService>()) {
        final preferences = SharedPreferencesAsync();

        final area =
        await preferences.getString('selected_area');

        final order =
        await preferences.getBool('order_notices_enabled');

        final updates =
        await preferences.getBool('update_notices_enabled');

        if (isClosed) return;

        final community = CommunityService(preferences);

        community.selectedArea.value = area ?? 'সব এলাকা';
        community.orderNoticesEnabled.value = order ?? true;
        community.updateNoticesEnabled.value = updates ?? true;

        Get.put(community, permanent: true);
      }

      if (isClosed) return;

      // Network content loads without holding the splash open.
      unawaited(Get.find<CommunityService>().start());

      _navigated = true;

      Get.offAll(
            () => const MainShell(),
        transition: Get.context != null &&
            MediaQuery.disableAnimationsOf(Get.context!)
            ? Transition.noTransition
            : Transition.fadeIn,
        duration: const Duration(milliseconds: 250),
      );
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('Startup failed: $error');
        debugPrintStack(stackTrace: stack);
      }

      if (!isClosed) {
        errorMessage.value =
        'অ্যাপ চালু করা যায়নি। আবার চেষ্টা করুন। '
            'সমস্যা থাকলে Firebase configuration ও '
            'ফোনের খালি জায়গা পরীক্ষা করুন।';
      }
    } finally {
      if (!isClosed) {
        busy.value = false;
      }
    }
  }
}