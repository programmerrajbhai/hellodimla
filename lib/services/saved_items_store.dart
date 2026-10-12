import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedItemsStore extends GetxService {
  static const _key = 'hello_dimla_saved_items_v2';
  static const _legacyKey = 'hello_dimla_saved_service_ids_v1';

  static SavedItemsStore get instance {
    if (Get.isRegistered<SavedItemsStore>()) {
      return Get.find<SavedItemsStore>();
    }

    return Get.put(SavedItemsStore(), permanent: true);
  }

  final serviceIds = <String>[].obs;
  final productIds = <String>[].obs;

  final references = <String, Map<String, dynamic>>{}.obs;

  final ready = false.obs;
  final saving = false.obs;
  final error = ''.obs;

  final _preferences = SharedPreferencesAsync();
  Future<void>? _loadTask;

  static String itemKey(String id, bool product) =>
      '${product ? 'p' : 's'}:$id';

  Map<String, dynamic> reference(String id, bool product) {
    return references[itemKey(id, product)] ?? {};
  }

  bool contains(String id, bool product) {
    return (product ? productIds : serviceIds).contains(id);
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    if (ready.value) return;

    if (_loadTask != null) {
      await _loadTask;
      return;
    }

    final task = _load();
    _loadTask = task;

    try {
      await task;
    } finally {
      _loadTask = null;
    }
  }

  Future<void> _load() async {
    error.value = '';

    try {
      final raw = await _preferences.getString(_key);

      if (raw == null) {
        final legacy =
            await _preferences.getStringList(_legacyKey) ?? [];

        serviceIds.assignAll(
          legacy.where((id) => id.isNotEmpty).toSet(),
        );
      } else {
        final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);

        List<String> ids(String key) {
          return (data[key] as List)
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
        }

        final cached = <String, Map<String, dynamic>>{};
        final rawReferences = data['references'];

        if (rawReferences is Map) {
          for (final entry in rawReferences.entries) {
            if (entry.key is String && entry.value is Map) {
              cached[entry.key as String] =
              Map<String, dynamic>.from(entry.value as Map);
            }
          }
        }

        serviceIds.assignAll(ids('services'));
        productIds.assignAll(ids('products'));
        references.assignAll(cached);
      }

      ready.value = true;
    } catch (_) {
      error.value = 'সেভ করা তথ্য পড়া যায়নি। আবার চেষ্টা করুন।';
    }
  }

  Future<bool> _commit(
      List<String> services,
      List<String> products,
      Map<String, Map<String, dynamic>> cached,
      ) async {
    if (!ready.value || saving.value) return false;

    saving.value = true;

    try {
      final allowedKeys = {
        ...services.map((id) => itemKey(id, false)),
        ...products.map((id) => itemKey(id, true)),
      };

      final cleanReferences = <String, Map<String, dynamic>>{
        for (final entry in cached.entries)
          if (allowedKeys.contains(entry.key)) entry.key: entry.value,
      };

      await _preferences.setString(
        _key,
        jsonEncode({
          'services': services,
          'products': products,
          'references': cleanReferences,
        }),
      );

      references.assignAll(cleanReferences);

      if (!listEquals(serviceIds.toList(), services)) {
        serviceIds.assignAll(services);
      }

      if (!listEquals(productIds.toList(), products)) {
        productIds.assignAll(products);
      }

      return true;
    } catch (_) {
      Get.snackbar(
        'পরিবর্তন সেভ হয়নি',
        'আবার চেষ্টা করুন।',
        snackPosition: SnackPosition.BOTTOM,
      );

      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> toggle({
    required String id,
    required bool product,
    Map<String, dynamic>? snapshot,
  }) async {
    await load();

    if (!ready.value || saving.value) return false;

    final services = serviceIds.toList();
    final products = productIds.toList();
    final cached = Map<String, Map<String, dynamic>>.from(references);

    final ids = product ? products : services;

    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);

      if (snapshot != null) {
        cached[itemKey(id, product)] = snapshot;
      }
    }

    return _commit(services, products, cached);
  }

  Future<bool> remove(String id, bool product) async {
    await load();

    if (!contains(id, product)) return true;

    return toggle(id: id, product: product);
  }

  Future<bool> remember(
      Map<String, Map<String, dynamic>> snapshots,
      ) async {
    await load();

    if (!ready.value || saving.value) return false;

    return _commit(
      serviceIds.toList(),
      productIds.toList(),
      {...references, ...snapshots},
    );
  }

  Future<bool> clear() async {
    await load();

    return _commit([], [], {});
  }
}