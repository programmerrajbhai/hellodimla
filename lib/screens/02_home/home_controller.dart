import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/network/service_api.dart';
import '../../data/models/community_models.dart';
import '../../services/community_service.dart';
import '../03_notifications/notifications_screen.dart';
import '../04_menu/menu_screen.dart';
import '../05_search_results/search_results_screen.dart';
import '../07_service_details/service_details_screen.dart';
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

  void begin(bool clear) {
    if (clear) items.clear();
    error.value = '';
    loading.value = true;
  }

  void done(Iterable<T> rows) {
    items.assignAll(rows);
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
  final services = HomeFeed<RowData>();
  final products = HomeFeed<RowData>();
  final news = HomeFeed<LocalUpdate>();

  final areas = <int, String>{};

  // 0 থাকলে নিচের বাংলা নামগুলো দিয়ে ঘোষণার মেনু খুঁজবে।
  // মেনুর নাম আলাদা হলে এখানে তোমার আসল list menu ID বসাও।
  static const int newsMenuId = 0;

  late final Worker _areaWorker;
  int _version = 0;
  String? _lastArea;

  bool _current(int version) => !isClosed && version == _version;

  @override
  void onInit() {
    super.onInit();
    _areaWorker = ever<String>(
      community.selectedArea,
          (_) => unawaited(refresh()),
    );
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final version = ++_version;
    final areaName = community.selectedArea.value;
    final changedArea = _lastArea != areaName;
    _lastArea = areaName;

    quick.begin(false);
    services.begin(changedArea);
    products.begin(changedArea);
    news.begin(changedArea);

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
      final shortcuts = pinned.isNotEmpty
          ? pinned
          : catalog.menus.where((m) => homeInt(m['parent']) == 0);

      quick.done(shortcuts.take(8));

      final matches = areas.keys.where((id) => areas[id] == areaName);
      if (areaName != 'সব এলাকা' && matches.isEmpty) {
        const message = 'এই এলাকা এখন তালিকায় নেই। উপরে ইউনিয়ন বদলান।';
        services.fail(message);
        products.fail(message);
        news.fail(message);
        return;
      }

      final zone = areaName == 'সব এলাকা' ? 0 : matches.first;
      final lists = catalog.menus.where((m) => m['kind'] == 'list');

      await Future.wait([
        _fill(
          services,
          version,
              () => _preview(
            lists.where((m) => !_isNews(m)).toList(),
            zone,
            version,
          ),
        ),
        _fill(products, version, () => _loadStore(zone)),
        _fill(news, version, () async {
          final rows = await _preview(
            lists.where(_isNews).toList(),
            zone,
            version,
          );
          return rows.map(_toNotice).toList();
        }),
      ]);
    } catch (_) {
      if (!_current(version)) return;

      const message = 'মেনু ও ইউনিয়ন লোড হয়নি। API সংযোগ দেখে আবার চেষ্টা করুন।';
      quick.fail(message);
      services.fail(message);
      products.fail(message);
      news.fail(message);
    }
  }

  bool _isNews(RowData menu) {
    if (newsMenuId > 0) return homeInt(menu['id']) == newsMenuId;

    return const {
      'ডিমলার খবর ও ঘোষণা',
      'স্থানীয় খবর ও ঘোষণা',
      'খবর ও ঘোষণা',
      'ঘোষণা',
    }.contains(homeText(menu['title']));
  }

  Future<void> _fill<T>(
      HomeFeed<T> feed,
      int version,
      Future<List<T>> Function() read,
      ) async {
    try {
      final rows = await read();
      if (_current(version)) feed.done(rows);
    } catch (_) {
      if (_current(version)) feed.fail('তথ্য লোড হয়নি। আবার চেষ্টা করুন।');
    }
  }

  // Home-এ ৩টি কার্ড প্রয়োজন। একসঙ্গে সর্বোচ্চ ৩টি মেনু পড়বে।
  Future<List<RowData>> _preview(
      List<RowData> menus,
      int zone,
      int version,
      ) async {
    final result = <RowData>[];

    for (var i = 0;
    i < menus.length && result.length < 3 && _current(version);
    i += 3) {
      final batch = await Future.wait(
        menus.skip(i).take(3).map((menu) async {
          final page = await ServiceApi.entries(
            menuId: homeInt(menu['id']),
            areaId: zone,
          );

          return page.items.take(3).map(
                (row) => <String, dynamic>{...row, '_menu': menu},
          );
        }),
      );

      for (final rows in batch) {
        result.addAll(rows);
      }
    }

    return result.take(3).toList();
  }

  Future<List<RowData>> _loadStore(int zone) async {
    // ServiceApi-র একই base URL ব্যবহার করে; দ্বিতীয়বার IP বসাতে হবে না।
    final uri = ServiceApi.menuIcon(1).resolve('mobile.php').replace(
      queryParameters: {'a': 'store', 'area': '$zone'},
    );

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);

    Future<List<RowData>> read() async {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('Store HTTP ${response.statusCode}');
      }

      final body = jsonDecode(await utf8.decoder.bind(response).join());
      if (body is! Map || body['items'] is! List) {
        throw const FormatException('Store items পাওয়া যায়নি');
      }

      final byProduct = <int, RowData>{};

      for (final row in body['items'] as List) {
        if (row is! RowData) throw const FormatException('Invalid pack');

        final id = homeInt(row['product']);
        if (id <= 0 || homeText(row['name']).isEmpty) continue;

        final previous = byProduct[id];

        // একই পণ্যের প্রথম প্যাকটি রাখে। সেটি stock-out হলে
        // পরের available প্যাকের দাম, unit ও stock একসঙ্গে দেখায়।
        if (previous == null ||
            (homeInt(previous['stock']) <= 0 && homeInt(row['stock']) > 0)) {
          byProduct[id] = row;
        }
      }

      return byProduct.values.take(4).toList();
    }

    try {
      return await read().timeout(const Duration(seconds: 15));
    } finally {
      client.close(force: true);
    }
  }

  LocalUpdate _toNotice(RowData row) {
    final fields = <String, String>{};
    final extra = row['extra'];

    if (extra is Map) {
      for (final e in extra.entries) {
        fields['${e.key}'.toLowerCase()] = homeText(e.value);
      }

      final spec = row['_menu']['fields'];
      if (spec is List) {
        for (final f in spec.whereType<Map>()) {
          fields[homeText(f['label'])] = homeText(extra[f['key']]);
        }
      }
    }

    String pick(List<String> keys) => keys
        .map((key) => fields[key] ?? '')
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');

    final body = pick(['body', 'description', 'details', 'বিবরণ', 'বিস্তারিত']);

    return LocalUpdate(
      id: "mysql:${row['id']}",
      title: homeText(row['name']),
      body: body.isEmpty ? 'বিস্তারিত বিবরণ দেওয়া হয়নি।' : body,
      label: homeText(row['_menu']['title']),
      publishedAt: DateTime.tryParse(pick(['published_at', 'date', 'তারিখ'])),
    );
  }

  String serviceArea(RowData row) {
    if (homeFlag(row['wide'])) return 'পুরো ডিমলা';
    final ids = row['areas'];
    if (ids is! List) return '';
    return ids.map((id) => areas[homeInt(id)]).whereType<String>().join(' · ');
  }

  String photo(RowData row) {
    if (!homeFlag(row['hasPhoto'])) return '';
    return ServiceApi.profilePhoto(
      homeInt(row['id']),
      revision: homeInt(row['rev']),
    ).toString();
  }

  void openMenu(RowData menu) => Get.to(
        () => ServiceMenuScreen(menuId: "${menu['id']}"),
    preventDuplicates: false,
  );

  void openService(RowData row) => Get.to(
        () => ServiceDetailsScreen(serviceId: "mysql:${row['id']}"),
    arguments: {
      'source': 'mysql',
      'entry': row,
      'menu': row['_menu'],
      'areaNames': Map<int, String>.of(areas),
    },
  );

  void openProduct(RowData pack) => Get.to(
        () => ProductDetailsScreen(productId: "mysql:${pack['product']}"),
    arguments: {
      'source': 'mysql',
      'productId': homeInt(pack['product']),
      'pack': pack,
    },
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
    _areaWorker.dispose();
    searchInput.dispose();
    super.onClose();
  }
}