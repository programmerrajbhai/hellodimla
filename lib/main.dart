import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/hello_dimla_app.dart';
import 'business/business_store.dart';
import 'services/community_service.dart';

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
  late Future<void> _startup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startup = _initialize();
  }

  Future<void> _initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    if (!Get.isRegistered<CommunityService>()) {
      final preferences = SharedPreferencesAsync();

      final area = await preferences.getString('selected_area');
      final order =
      await preferences.getBool('order_notices_enabled');
      final updates =
      await preferences.getBool('update_notices_enabled');

      final community = CommunityService(preferences);

      community.selectedArea.value = area ?? 'সব এলাকা';
      community.orderNoticesEnabled.value = order ?? true;
      community.updateNoticesEnabled.value = updates ?? true;

      Get.put(community, permanent: true);
    }

    // Network requests must not block the offline ledger.
    unawaited(Get.find<CommunityService>().start());
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
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const HelloDimlaApp();
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: snapshot.hasError
                    ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'App চালু করা যায়নি। Firebase configuration ও '
                          'device-এর খালি জায়গা পরীক্ষা করে আবার চেষ্টা করুন।',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _startup = _initialize();
                        });
                      },
                      child: const Text('আবার চেষ্টা করুন'),
                    ),
                  ],
                )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
        );
      },
    );
  }
}