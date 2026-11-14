import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/network/service_api.dart';
import '../../data/models/community_models.dart';
import '../../services/community_service.dart';
import '../03_notifications/notifications_screen.dart';
import '../04_menu/menu_screen.dart';
import '../05_search_results/search_results_screen.dart';
import '../08_saved_items/saved_items_screen.dart';
import '../09_shopping_home/shopping_home_screen.dart';
import '../10_product_details/product_details_screen.dart';
import 'sheets/home_sheets.dart';

typedef RowData = Map<String, dynamic>;

int homeInt(dynamic value) => int.tryParse('$value') ?? 0;

bool homeFlag(dynamic value) => value == true || homeInt(value) == 1;

String homeText(dynamic value) => value is String ? value.trim() : '';

class HomeFeed<T> {
  final items = <T>[].obs;
  final loading = true.obs;
  final error = ''.obs;

  void begin({bool clear = false}) {
    if (clear) items.clear();
    error.value = '';
    loading.value = true;
  }

  void done(Iterable<T> values) {
    items.assignAll(values);
    error.value = '';
    loading.value = false;
  }

  void fail(String message) {
    error.value = message;
    loading.value = false;
  }
}

class HomeController extends GetxController {
  final community = Get.find<CommunityService>();
  final searchInput = TextEditingController();

  final quick = HomeFeed<RowData>();
  final products = HomeFeed<RowData>();
  final news = HomeFeed<LocalUpdate>();
  final areas = <int, String>{};

  static const newsMenuId = 0;
  static const _newsTitles = {
    'ডিমলার খবর ও ঘোষণা',
    'স্থানীয় খবর ও ঘোষণা',
    'খবর ও ঘোষণা',
    'ঘোষণা',
  };

  final _random = Random();
  late final Worker _areaWatcher;
  List<int> _featuredIds = [];
  String? _lastArea;
  int _version = 0;

  bool get busy =>
      quick.loading.value || products.loading.value || news.loading.value;

  bool _current(int version) => !isClosed && version == _version;

  @override
  void onInit() {
    super.onInit();
    _areaWatcher = ever<String>(
      community.selectedArea,
          (_) => unawaited(refresh()),
    );
    unawaited(refresh());
  }

  // হাতে রিফ্রেশ বা ইউনিয়ন বদলালে নতুন পণ্য বেছে নেওয়া হয়।
  Future<void> refresh() => _load(reshuffle: true);

  // পেছনে আপডেট হলে একই পণ্যের দাম/স্টক আপডেট হয়।
  Future<void> refreshInBackground() async {
    if (!busy) await _load(reshuffle: false);
  }

  Future<void> _load({required bool reshuffle}) async {
    final version = ++_version;
    final areaName = community.selectedArea.value;
    final areaChanged = _lastArea != areaName;
    _lastArea = areaName;

    if (areaChanged) _featuredIds = [];

    quick.begin();
    products.begin(clear: areaChanged);
    news.begin(clear: areaChanged);

    try {
      final catalog = await ServiceApi.catalog();
      if (!_current(version)) return;

      areas
        ..clear()
        ..addEntries(
          catalog.areas.map(
                (a) => MapEntry(homeInt(a['id']), homeText(a['name'])),
          ),
        );

      final pinned = catalog.menus.where((m) => homeFlag(m['home']));
      final homeMenus = pinned.isNotEmpty
          ? pinned
          : catalog.menus.where((m) => homeInt(m['parent']) == 0);

      quick.done(homeMenus.take(8));

      int zone = 0;
      if (areaName != 'সব এলাকা') {
        final matches = areas.entries.where((e) => e.value == areaName);
        if (matches.isEmpty) {
          const message = 'এই ইউনিয়নটি পাওয়া যায়নি। উপরে এলাকা বদলান।';
          products.fail(message);
          news.fail(message);
          return;
        }
        zone = matches.first.key;
      }

      final newsMenus = catalog.menus.where((menu) {
        if (menu['kind'] != 'list') return false;
        if (newsMenuId > 0) return homeInt(menu['id']) == newsMenuId;
        return _newsTitles.contains(homeText(menu['title']));
      }).toList();

      await Future.wait<void>([
        _loadProducts(zone, version, reshuffle || areaChanged),
        _loadNews(newsMenus, zone, version),
      ]);
    } catch (_) {
      if (!_current(version)) return;
      const message = 'তথ্য লোড হয়নি। আবার চেষ্টা করুন।';
      quick.fail(message);
      products.fail(message);
      news.fail(message);
    }
  }

  Future<void> _loadProducts(int zone, int version, bool reshuffle) async {
    try {
      final catalog = await _storeProducts(zone);
      if (!_current(version)) return;

      // একই পণ্যের কয়েকটি প্যাক থাকলেও হোমে একটি কার্ড দেখাবে।
      final selected = <int>[
        if (!reshuffle)
          for (final id in _featuredIds)
            if (catalog.containsKey(id)) id,
      ];

      final candidates = catalog.keys
          .where((id) => !selected.contains(id))
          .toList()
        ..shuffle(_random);

      selected.addAll(candidates.take(4 - selected.length));
      _featuredIds = selected;
      products.done(selected.map((id) => catalog[id]!));
    } catch (_) {
      if (_current(version)) products.fail('স্টোরের পণ্য লোড হয়নি।');
    }
  }

  Future<Map<int, RowData>> _storeProducts(int zone) async {
    final url = ServiceApi.menuIcon(1).resolve('mobile.php').replace(
      queryParameters: {'a': 'store', 'area': '$zone'},
    );

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);

    Future<Map<int, RowData>> read() async {
      final request = await client.getUrl(url);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: url);
      }

      final body = jsonDecode(await utf8.decoder.bind(response).join());
      if (body is! Map || body['items'] is! List) {
        throw const FormatException('Store items missing');
      }

      final byId = <int, RowData>{};

      for (final row in body['items'] as List) {
        if (row is! RowData) continue;
        final id = homeInt(row['product']);
        if (id <= 0 || homeText(row['name']).isEmpty) continue;

        final current = byId[id];
        if (current == null ||
            (homeInt(current['stock']) <= 0 && homeInt(row['stock']) > 0)) {
          byId[id] = row;
        }
      }
      return byId;
    }

    try {
      return await read().timeout(const Duration(seconds: 15));
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _loadNews(List<RowData> menus, int zone, int version) async {
    try {
      final updates = <LocalUpdate>[];
      for (final menu in menus) {
        if (!_current(version) || updates.length >= 3) break;
        final page = await ServiceApi.entries(
          menuId: homeInt(menu['id']),
          areaId: zone,
        );
        for (final row in page.items.take(3 - updates.length)) {
          updates.add(_notice(row, menu));
        }
      }
      if (_current(version)) news.done(updates);
    } catch (_) {
      if (_current(version)) news.fail('ঘোষণা লোড হয়নি।');
    }
  }

  LocalUpdate _notice(RowData row, RowData menu) {
    final fields = <String, String>{};
    final extra = row['extra'];
    if (extra is Map) {
      for (final e in extra.entries) {
        fields['${e.key}'.toLowerCase()] = homeText(e.value);
      }
      final definitions = menu['fields'];
      if (definitions is List) {
        for (final f in definitions.whereType<Map>()) {
          fields[homeText(f['label'])] = homeText(extra[f['key']]);
        }
      }
    }

    String first(List<String> keys) {
      for (final key in keys) {
        final value = fields[key] ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final body = first(['body', 'description', 'details', 'বিবরণ', 'বিস্তারিত']);
    return LocalUpdate(
      id: "mysql:${row['id']}",
      title: homeText(row['name']),
      body: body.isEmpty ? 'বিস্তারিত বিবরণ দেওয়া হয়নি।' : body,
      label: homeText(menu['title']),
      publishedAt: DateTime.tryParse(first(['published_at', 'date', 'তারিখ'])),
    );
  }

  void openProduct(RowData p) => Get.to(
        () => ProductDetailsScreen(productId: "mysql:${p['product']}"),
    arguments: {
      'source': 'mysql',
      'productId': homeInt(p['product']),
      'pack': p,
    },
  );

  void openMenu(RowData m) => Get.to(
        () => ServiceMenuScreen(menuId: "${m['id']}"),
    preventDuplicates: false,
  );

  void search() {
    final q = searchInput.text.trim();
    Get.to(() => SearchResultsScreen(query: q.isEmpty ? null : q));
  }

  void openStore() => Get.to(() => const ShoppingHomeScreen());
  void openSaved() => Get.to(() => const SavedItemsScreen());
  void openNotifications() => Get.to(() => const NotificationsScreen());

  void selectArea() => Get.bottomSheet(
    AreaSelectionSheet(directoryAreas: areas.values.toList()),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );

  void openUpdate(LocalUpdate update) => showUpdateSheet(update);

  @override
  void onClose() {
    _version++;
    _areaWatcher.dispose();
    searchInput.dispose();
    super.onClose();
  }
}