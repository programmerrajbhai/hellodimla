import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/hello_dimla_app.dart';
import 'services/community_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final community = Get.put(
    CommunityService(SharedPreferencesAsync()),
    permanent: true,
  );
  runApp(const HelloDimlaApp());
  unawaited(community.start());
}