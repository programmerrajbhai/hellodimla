import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/controllers/directory_controller.dart';
import '../../screens/07_service_details/service_details_screen.dart';
import '../../screens/10_product_details/product_details_screen.dart';
import '../../services/saved_items_store.dart';

class SavedItemsController extends GetxController {
  final searchInput = TextEditingController();

  final query = ''.obs;
  final productTab = false.obs;
  final loading = false.obs;
  final errors = <String>[].obs;

  final current = <String, DirectoryItem>{}.obs;
  final freshKeys = <String>[].obs;
  final missingKeys = <String>[].obs;

  final saved = SavedItemsStore.instance;

  final _workers = <Worker>[];
  Timer? _refreshTimer;
  bool _repeatRefresh = false;

  String key(String id, bool product) =>
      SavedItemsStore.itemKey(id, product);

  List<String> get visibleIds {
    final ids = productTab.value ? saved.productIds : saved.serviceIds;
    final words = directoryNormalize(query.value)
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    return ids.where((id) {
      final item = current[key(id, productTab.value)];
      final reference = saved.reference(id, productTab.value);

      final text = directoryNormalize([
        item?.name ?? reference['name'] ?? '',
        item?.typeTitle ?? reference['type'] ?? '',
      ].join(' '));

      return words.every(text.contains);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();

    void changed() {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(
        const Duration(milliseconds: 180),
            () => refreshItems(),
      );
    }

    _workers.add(ever(saved.serviceIds, (_) => changed()));
    _workers.add(ever(saved.productIds, (_) => changed()));

    unawaited(refreshItems());
  }

  Future<void> refreshItems() async {
    if (isClosed) return;

    if (loading.value) {
      _repeatRefresh = true;
      return;
    }

    loading.value = true;
    errors.clear();
    freshKeys.clear();
    missingKeys.clear();

    try {
      await saved.load();

      if (!saved.ready.value || isClosed) return;

      final serviceIds = saved.serviceIds.toList();
      final productIds = saved.productIds.toList();

      if (serviceIds.isEmpty && productIds.isEmpty) return;

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final next = Map<String, DirectoryItem>.from(current);
      final fresh = <String>[];
      final missing = <String>[];
      final failures = <String>{};
      final snapshots = <String, Map<String, dynamic>>{};

      for (final product in [false, true]) {
        final ids = product ? productIds : serviceIds;

        for (var offset = 0; offset < ids.length; offset += 10) {
          if (isClosed) return;

          final group = ids.sublist(
            offset,
            math.min(offset + 10, ids.length),
          );

          try {
            final result = await FirebaseFirestore.instance
                .collection(product ? 'products' : 'services')
                .where('published', isEqualTo: true)
                .where(FieldPath.documentId, whereIn: group)
                .get(const GetOptions(source: Source.server))
                .timeout(const Duration(seconds: 20));

            if (isClosed) return;

            final foundIds = <String>{};

            for (final doc in result.docs) {
              final item = DirectoryItem.fromDoc(
                doc,
                product: product,
              );

              if (item.name.isEmpty) continue;

              final itemKey = key(item.id, product);

              foundIds.add(item.id);
              next[itemKey] = item;
              fresh.add(itemKey);
              snapshots[itemKey] = DirectoryCatalog.reference(item);
            }

            for (final id in group) {
              if (!foundIds.contains(id)) {
                final itemKey = key(id, product);
                missing.add(itemKey);
                next.remove(itemKey);
              }
            }
          } catch (_) {
            failures.add(
              product
                  ? 'কিছু পণ্যের বর্তমান তথ্য refresh হয়নি।'
                  : 'কিছু সেবার বর্তমান তথ্য refresh হয়নি।',
            );
          }
        }
      }

      if (isClosed) return;

      current.assignAll(next);
      freshKeys.assignAll(fresh);
      missingKeys.assignAll(missing);
      errors.assignAll(failures);

      if (snapshots.isNotEmpty) {
        await saved.remember(snapshots);
      }
    } catch (_) {
      if (!isClosed) {
        errors.assignAll(['বর্তমান তথ্য refresh হয়নি। আবার চেষ্টা করুন।']);
      }
    } finally {
      if (!isClosed) {
        loading.value = false;

        if (_repeatRefresh) {
          _repeatRefresh = false;
          unawaited(refreshItems());
        }
      }
    }
  }

  Future<void> remove(String id, bool product) =>
      saved.remove(id, product).then<void>((_) {});

  void open(String id, bool product) {
    FocusManager.instance.primaryFocus?.unfocus();

    if (product) {
      Get.to(() => ProductDetailsScreen(productId: id));
    } else {
      Get.to(() => ServiceDetailsScreen(serviceId: id));
    }
  }

  Future<void> call(String id) async {
    final itemKey = key(id, false);
    final item = current[itemKey];

    if (!freshKeys.contains(itemKey) ||
        item == null ||
        item.dialNumber == null) {
      return;
    }

    // Uses the same dialer behavior as Search/Service List.
    final number = item.dialNumber!;

    try {
      final opened = await launchDirectoryDialer(number);
      if (!opened) throw StateError('Dialer unavailable');
    } catch (_) {
      Get.snackbar(
        'Dialer খোলা যায়নি',
        'নম্বর: $number',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();

    for (final worker in _workers) {
      worker.dispose();
    }

    searchInput.dispose();
    super.onClose();
  }
}


Future<bool> launchDirectoryDialer(String number) {
  return launchUrl(
    Uri(scheme: 'tel', path: number),
    mode: LaunchMode.externalApplication,
  );
}