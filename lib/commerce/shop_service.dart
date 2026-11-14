import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

import '../core/network/service_api.dart';
import '../services/community_service.dart';
import 'shop_models.dart';
import 'shop_service_base.dart' as old;

typedef _Row = Map<String, dynamic>;

class ShopService extends old.ShopService {
  static ShopService get instance {
    if (Get.isRegistered<ShopService>()) {
      return Get.find<ShopService>();
    }
    return Get.put(ShopService(), permanent: true);
  }

  static String message(Object error) => old.ShopService.message(error);

  Worker? _areaWorker;
  Future<void>? _catalogRequest;

  String? _requestedArea;
  String? _loadedArea;
  int _loadedZone = 0;
  int _version = 0;

  CommunityService? get _community {
    if (!Get.isRegistered<CommunityService>()) return null;
    return Get.find<CommunityService>();
  }

  String get _areaName =>
      _community?.selectedArea.value.trim() ?? 'সব এলাকা';

  @override
  void onInit() {
    super.onInit();

    final community = _community;
    if (community == null) return;

    _areaWorker = ever<String>(community.selectedArea, (_) {
      if (_requestedArea != null) {
        unawaited(loadCatalog());
      }
    });
  }

  @override
  void onClose() {
    _version++;
    _areaWorker?.dispose();
    super.onClose();
  }

  @override
  Future<void> loadCatalog() {
    final name = _areaName;
    final running = _catalogRequest;

    // একই এলাকার জন্য একই সময়ে একাধিক request পাঠাবে না।
    if (_requestedArea == name && running != null) {
      return running;
    }

    final changedArea = _requestedArea != name;
    final version = ++_version;
    _requestedArea = name;

    if (changedArea) {
      products.clear();
      _loadedArea = null;
    }

    final task = _loadCatalogFromApi(name, version).whenComplete(() {
      if (version == _version) {
        _catalogRequest = null;
      }
    });

    _catalogRequest = task;
    return task;
  }

  Future<int> _resolveZone(String name) async {
    if (name.isEmpty || name == 'সব এলাকা') return 0;

    final directory = await ServiceApi.catalog();

    for (final area in directory.areas) {
      if (_text(area['name']) == name) {
        return _intValue(area['id']);
      }
    }

    throw StateError(
      'নির্বাচিত ইউনিয়ন এখন তালিকায় নেই। Home থেকে এলাকা বদলান।',
    );
  }

  Future<void> _loadCatalogFromApi(String name, int version) async {
    loading.value = true;
    error.value = '';

    try {
      final zone = await _resolveZone(name);
      if (version != _version) return;

      final data = await _fetchStore(zone);
      final result = _parseProducts(data);
      final settings = object(data['settings']);
      final zones = _rows(data['zones']);

      final deliveryZones = <Map<String, dynamic>>[
        for (final z in zones)
          {
            'id': '${z['id']}',
            'label': _text(z['name']),
            'enabled': true,
            'chargeMinor': _moneyToMinor(z['fee']),
          },
      ];

      if (version != _version) return;

      _loadedArea = name;
      _loadedZone = zone;

      config.value = StoreConfig({

        'categories': _rows(data['categories']),
        'shelves': _rows(data['shelves'] ?? []),
        'shelfItems': _rows(data['shelfItems'] ?? []),
        'name': 'Hello Store',
        'demoMode': false,
        'enabled': deliveryZones.isNotEmpty,
        'bannerSubtitle': 'স্মার্ট ডিমলার নিজস্ব অনলাইন স্টোর',
        'supportPhone': _text(settings['phone']),
        'deliveryZones': deliveryZones,
        'deliveryPolicy': deliveryZones.isEmpty
            ? 'বর্তমানে কোনো ডেলিভারি ইউনিয়ন চালু নেই।'
            : deliveryZones.map((z) {
          final fee = money(z['chargeMinor'] as int);
          return "${z['label']} · $fee";
        }).join('\n'),
        if (_text(settings['returns_text']).isNotEmpty)
          'returnPolicy': _text(settings['returns_text']),
      });

      // আগের UI এই একই observable তালিকা থেকেই কার্ড তৈরি করে।
      products.assignAll(result);
    } catch (e) {
      if (version == _version) {
        error.value = message(e);
      }
    } finally {
      if (version == _version) {
        loading.value = false;
      }
    }
  }

  // Home থেকে "mysql:12" এবং সরাসরি "12" — দুই ধরনের ID-ই নেয়।
  @override
  Future<ShopProduct?> product(String id) async {
    final rawId = id.startsWith('mysql:') ? id.substring(6) : id;
    final numericId = int.tryParse(rawId);
    if (numericId == null || numericId <= 0) return null;

    final name = _areaName;
    final zone = _loadedArea == name
        ? _loadedZone
        : await _resolveZone(name);

    final result = _parseProducts(await _fetchStore(zone));

    if (name != _areaName) {
      throw StateError('এলাকা বদলেছে। পণ্যটি আবার খুলুন।');
    }

    for (final item in result) {
      if (item.id == 'mysql:$numericId') return item;
    }

    return null;
  }

  static List<ShopProduct> _parseProducts(_Row data) {
    final categories = <int, String>{
      for (final c in _rows(data['categories']))
        _intValue(c['id']): _text(c['name']),
    };

    final featuredIds = <int>{
      for (final item in _rows(data['shelfItems'] ?? []))
        _intValue(item['product_id']),
    };

    // API প্রতি প্যাকের জন্য একটি row দেয়।
    // একই জুতার একাধিক সাইজ থাকলেও তালিকায় একটি কার্ড হবে।
    final grouped = <int, List<_Row>>{};

    for (final row in _rows(data['items'])) {
      final productId = _intValue(row['product']);
      grouped.putIfAbsent(productId, () => <_Row>[]).add(row);
    }

    return grouped.entries.map((entry) {
      final first = entry.value.first;
      final categoryId = _intValue(first['category_id']);
      final image = _text(first['photo']);

      final packs = entry.value.map((row) {
        final regularPrice = row['regular_price'];
        final unit = _text(row['label']);

        return ShopVariant(
          id: '${_intValue(row['pack'])}',
          name: unit,
          unit: unit,
          image: image,
          price: _moneyToMinor(row['price']),
          originalPrice: regularPrice == null || '$regularPrice'.isEmpty
              ? 0
              : _moneyToMinor(regularPrice),
          stock: _intValue(row['stock']),
          enabled: true,
        );
      }).toList();

      return ShopProduct(
        id: 'mysql:${entry.key}',
        name: _text(first['name']),
        categoryId: '$categoryId',
        categoryName: categories[categoryId] ?? 'অন্যান্য',
        description: _text(first['description']),
        images: image.isEmpty ? <String>[] : [image],
        variants: packs,
        base: packs.first,
        featured: featuredIds.contains(entry.key),
      );
    }).toList();
  }

  static Future<_Row> _fetchStore(int zone) async {
    // আগের ServiceApi config ব্যবহার করে। এখানে নতুন IP দিতে হবে না।
    final uri = ServiceApi.menuIcon(1).resolve('mobile.php').replace(
      queryParameters: {'a': 'store', 'area': '$zone'},
    );

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);

    Future<_Row> send() async {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw StateError(
          'Store API: HTTP ${response.statusCode}। mobile.php দেখুন।',
        );
      }

      final raw = await utf8.decoder.bind(response).join();
      final dynamic data;

      try {
        data = jsonDecode(raw);
      } on FormatException {
        throw StateError(
          'mobile.php থেকে JSON পাওয়া যায়নি। ব্রাউজারে Store API খুলে দেখুন।',
        );
      }

      if (data is! _Row || data['items'] is! List) {
        throw StateError('Store API-এর উত্তরে items তালিকা নেই।');
      }

      return data;
    }

    try {
      return await send().timeout(const Duration(seconds: 15));
    } on SocketException {
      throw StateError('Store API-তে পৌঁছানো যায়নি। XAMPP ও API ঠিকানা দেখুন।');
    } on TimeoutException {
      throw StateError('Store API সময়মতো উত্তর দেয়নি। আবার চেষ্টা করুন।');
    } finally {
      client.close(force: true);
    }
  }

  static String _text(dynamic value) =>
      value is String ? value.trim() : '';

  static int _intValue(dynamic value) => int.parse('$value');

  static List<_Row> _rows(dynamic value) {
    if (value is! List || value.any((item) => item is! _Row)) {
      throw const FormatException('Store API তালিকার format ঠিক নেই।');
    }
    return value.cast<_Row>();
  }

  // MySQL-এর "2000.00" টাকা → Flutter মডেলের 200000 পয়সা।
  static int _moneyToMinor(dynamic value) {
    final text = '$value'.trim();

    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text)) {
      throw const FormatException('Store API-তে দামের format ঠিক নেই।');
    }

    final parts = text.split('.');
    final taka = int.parse(parts.first);
    final paisa = parts.length == 1
        ? 0
        : int.parse(parts.last.padRight(2, '0'));

    return taka * 100 + paisa;
  }
}