import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/controllers/directory_controller.dart';
import '../../data/models/public_service_phone.dart';
import '../../services/saved_items_store.dart';

const serviceReportReasons = <String, String>{
  'wrong_phone': 'ফোন নম্বর ভুল',
  'closed': 'সেবা বন্ধ / আর চালু নেই',
  'wrong_address': 'ঠিকানা বা এলাকা ভুল',
  'incorrect_information': 'অন্যান্য তথ্য ভুল',
  'privacy': 'ব্যক্তিগত তথ্য / সম্মতির সমস্যা',
  'other': 'অন্য কারণ',
};

class ServiceDetail {
  ServiceDetail(this.item, this.data);

  final DirectoryItem item;
  final Map<String, dynamic> data;

  String text(String key) {
    final value = data[key];
    return value is String ? value.trim() : '';
  }

  String get address => text('address');
  String get openingHours => text('openingHours');

  String get description => text('description').isNotEmpty
      ? text('description')
      : item.description;

  String get sourceName => text('sourceName');

  bool get governmentInformation =>
      data['isGovernmentInformation'] == true;

  List<PublicServicePhone> get phones => publicServicePhones(data);

  Uri? get sourceUri {
    final uri = Uri.tryParse(text('sourceUrl'));

    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }
}

class ServiceDetailsController extends GetxController {
  ServiceDetailsController({required this.serviceId});

  final String? serviceId;

  final loading = true.obs;
  final missing = false.obs;
  final error = ''.obs;
  final detail = Rxn<ServiceDetail>();
  final reporting = false.obs;

  SavedItemsStore get saved => SavedItemsStore.instance;

  bool get isSaved =>
      serviceId != null && saved.serviceIds.contains(serviceId);

  @override
  void onInit() {
    super.onInit();
    unawaited(saved.load());
    unawaited(load());
  }

  Future<void> load() async {
    if (isClosed) return;

    final id = serviceId?.trim() ?? '';

    if (id.isEmpty || id.contains('/')) {
      loading.value = false;
      missing.value = true;
      return;
    }

    loading.value = true;
    missing.value = false;
    error.value = '';
    detail.value = null;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('published', isEqualTo: true)
          .where(FieldPath.documentId, isEqualTo: id)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));

      if (isClosed) return;

      if (snapshot.docs.isEmpty) {
        missing.value = true;
        return;
      }

      final doc = snapshot.docs.first;
      final item = DirectoryItem.fromDoc(doc, product: false);

      if (item.name.isEmpty) {
        missing.value = true;
        return;
      }

      detail.value = ServiceDetail(item, doc.data());
    } catch (_) {
      if (!isClosed) {
        error.value = 'বিস্তারিত তথ্য লোড হয়নি। আবার চেষ্টা করুন।';
      }
    } finally {
      if (!isClosed) loading.value = false;
    }
  }

  Future<void> toggleSaved() async {
    final value = detail.value;
    if (value == null) return;

    await saved.toggle(
      id: value.item.id,
      product: false,
      snapshot: DirectoryCatalog.reference(value.item),
    );
  }

  Future<void> call(PublicServicePhone phone) async {
    if (isClosed) return;

    try {
      final opened = await launchUrl(
        Uri(scheme: 'tel', path: phone.number),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) throw StateError('Dialer unavailable');
    } catch (_) {
      Get.snackbar(
        'Dialer খোলা যায়নি',
        'নম্বর: ${phone.number}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> openSource() async {
    final uri = detail.value?.sourceUri;
    if (uri == null) return;

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) throw StateError('Browser unavailable');
    } catch (_) {
      Get.snackbar(
        'Link খোলা যায়নি',
        'আবার চেষ্টা করুন।',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> share(Rect origin) async {
    final value = detail.value;
    if (value == null) return;

    final text = [
      value.item.name,
      value.item.categoryTitle,
      if (value.item.typeTitle != value.item.categoryTitle)
        value.item.typeTitle,
      if (value.address.isNotEmpty) 'ঠিকানা: ${value.address}',
      if (value.item.areas.isNotEmpty)
        'সেবার এলাকা: ${value.item.areas.join(', ')}',
      if (value.openingHours.isNotEmpty)
        'সময়: ${value.openingHours}',
      ...value.phones.map((phone) => '${phone.label}: ${phone.number}'),
      if (value.sourceUri != null) 'উৎস: ${value.sourceUri}',
      'Hello Dimla',
      if (value.governmentInformation)
        'Hello Dimla একটি স্বাধীন app; সরকারি প্রতিষ্ঠানের প্রতিনিধি নয়।',
    ].join('\n');

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: value.item.name,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      Get.snackbar(
        'Share খোলা যায়নি',
        'আবার চেষ্টা করুন।',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<String?> submitReport(
      String reason,
      String description,
      ) async {
    final value = detail.value;

    if (value == null ||
        reporting.value ||
        !serviceReportReasons.containsKey(reason)) {
      return null;
    }

    final message = description.trim();

    if (message.length > 500) return null;

    reporting.value = true;

    try {
      var user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        final result = await FirebaseAuth.instance
            .signInAnonymously()
            .timeout(const Duration(seconds: 20));

        user = result.user;
      }

      if (user == null) throw StateError('Guest identity unavailable');

      final reference = FirebaseFirestore.instance
          .collection('service_reports')
          .doc(value.item.id)
          .collection('submissions')
          .doc(user.uid);

      final previous = await reference
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));

      if (previous.exists) {
        return 'এই সেবার জন্য আপনার রিপোর্ট আগেই জমা হয়েছে।';
      }

      await reference.set({
        'userId': user.uid,
        'serviceId': value.item.id,
        'reason': reason,
        'description': message,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 20));

      return 'রিপোর্ট জমা হয়েছে। Admin যাচাই করবেন।';
    } catch (_) {
      Get.snackbar(
        'জমার নিশ্চিতকরণ পাওয়া যায়নি',
        'আবার চেষ্টা করুন।',
        snackPosition: SnackPosition.BOTTOM,
      );

      return null;
    } finally {
      if (!isClosed) reporting.value = false;
    }
  }
}