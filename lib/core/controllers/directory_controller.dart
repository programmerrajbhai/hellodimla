import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/public_service_phone.dart';
import '../../services/community_service.dart';
import '../../screens/07_service_details/service_details_screen.dart';
import '../../screens/10_product_details/product_details_screen.dart';
import '../../services/saved_items_store.dart';

enum DirectoryKind { all, services, products }

enum ProductSort { name, priceLow, priceHigh }

const directoryCategories = <String, String>{
  'emergency': 'জরুরি সেবা',
  'local_transport': 'অটো, ভ্যান ও রিকশা',
  'vehicle_rental': 'গাড়ি ও মালবাহী পরিবহন',
  'long_distance_transport': 'বাস ও দূরপাল্লার যাতায়াত',
  'health': 'ডাক্তার ও স্বাস্থ্যসেবা',
  'local_shops': 'মুদি ও স্থানীয় দোকান',
  'food': 'খাবার ও রেস্টুরেন্ট',
  'home_services': 'বাড়ির কাজ ও মিস্ত্রি',
  'repair': 'মোবাইল ও যন্ত্র মেরামত',
  'agriculture': 'কৃষিসেবা',
  'livestock': 'পশু ও প্রাণিসম্পদ',
  'education': 'শিক্ষা ও প্রশিক্ষণ',
  'jobs_workers': 'চাকরি ও কর্মী',
  'rent_property': 'বাসা ও দোকান ভাড়া',
  'courier_documents': 'কুরিয়ার ও অনলাইন সেবা',
  'financial_directory': 'ব্যাংক ও আর্থিক যোগাযোগ',
  'civic_information': 'সরকারি ও নাগরিক তথ্য',
  'events': 'অনুষ্ঠান ও আয়োজন',
  'tourism': 'দর্শনীয় স্থান',
  'local_updates': 'স্থানীয় খবর ও ঘোষণা',
};

const directorySubtypes = <String, Map<String, String>>{
  'local_transport': {
    'auto': 'অটো / ইজিবাইক',
    'van': 'ভ্যান',
    'rickshaw': 'রিকশা',
    'cargo': 'মালবাহী গাড়ি',
  },
  'emergency': {
    'ambulance': 'অ্যাম্বুলেন্স',
    'emergency_hospital': 'জরুরি হাসপাতাল',
    'fire_service': 'ফায়ার সার্ভিস',
    'police': 'পুলিশ',
    'blood_donor': 'রক্তদাতা',
    'night_pharmacy': 'রাতের ফার্মেসি',
    'electricity': 'বিদ্যুৎ অভিযোগ',
    'disaster': 'দুর্যোগ সহায়তা',
    'national_hotline': 'জাতীয় hotline',
  },
};

String directoryDigits(String text) {
  const bangla = '০১২৩৪৫৬৭৮৯';

  for (var i = 0; i < bangla.length; i++) {
    text = text.replaceAll(bangla[i], '$i');
  }

  return text;
}

String directoryNormalize(String text) {
  return directoryDigits(text)
      .toLowerCase()
      .replaceAll(RegExp(r'[\u200B\u200C\u200D]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String directoryMoney(int minor) {
  final whole = minor ~/ 100;
  final fraction = minor % 100;

  return fraction == 0
      ? '৳$whole'
      : '৳$whole.${fraction.toString().padLeft(2, '0')}';
}

int? directoryParsePrice(String text) {
  final value = directoryDigits(text).trim();

  if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(value)) {
    return null;
  }

  final parts = value.split('.');
  final whole = int.tryParse(parts.first);

  if (whole == null) return null;

  final fraction = parts.length == 2
      ? int.parse(parts[1].padRight(2, '0'))
      : 0;

  return whole * 100 + fraction;
}

class DirectoryItem {
  const DirectoryItem({
    required this.id,
    required this.product,
    required this.name,
    required this.categoryId,
    required this.subtypeId,
    required this.subtypeLabel,
    required this.description,
    required this.areas,
    required this.keywords,
    required this.phone,
    required this.imageUrl,
    required this.unit,
    required this.priceMinor,
    required this.inStock,
    required this.verifiedAt,
    required this.verificationSource,
  });

  final String id;
  final bool product;
  final String name;
  final String categoryId;
  final String subtypeId;
  final String subtypeLabel;
  final String description;
  final List<String> areas;
  final List<String> keywords;
  final String phone;
  final String imageUrl;
  final String unit;
  final int? priceMinor;
  final bool? inStock;
  final DateTime? verifiedAt;
  final String verificationSource;

  String get categoryTitle =>
      directoryCategories[categoryId] ?? 'স্থানীয় সেবা';

  String get typeTitle {
    if (subtypeLabel.isNotEmpty) return subtypeLabel;

    return directorySubtypes[categoryId]?[subtypeId] ?? categoryTitle;
  }

  bool get verified =>
      verifiedAt != null && verificationSource.trim().isNotEmpty;

  String get searchable => directoryNormalize([
    name,
    description,
    product ? 'পণ্য product shop store $unit' : categoryTitle,
    typeTitle,
    ...areas,
    ...keywords,
  ].join(' '));

  String? get dialNumber {
    final value = directoryDigits(phone)
        .replaceAll(RegExp(r'[\s()\-]'), '');

    return RegExp(r'^\+?\d{3,15}$').hasMatch(value) ? value : null;
  }

  factory DirectoryItem.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc, {
        required bool product,
      }) {
    final data = doc.data();

    String text(String key) {
      final value = data[key];
      return value is String ? value.trim() : '';
    }

    List<String> strings(String key) {
      final value = data[key];
      if (value is! List) return [];

      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
    }

    final price = data['priceMinor'];
    final date = data['verifiedAt'];
    final verificationEnabled = data['verified'] == true;

    return DirectoryItem(
      id: doc.id,
      product: product,
      name: text('name'),
      categoryId: text('categoryId'),
      subtypeId: text('subtypeId'),
      subtypeLabel: text('subtypeLabel'),
      description: text('subtitle').isNotEmpty
          ? text('subtitle')
          : text('description'),
      areas: strings('areas'),
      keywords: strings('keywords'),


      phone: publicServicePhones(data).isEmpty
          ? ''
          : publicServicePhones(data).first.number,

      imageUrl: text('imageUrl'),
      unit: text('unit'),
      priceMinor: price is int && price >= 0 ? price : null,
      inStock: data['inStock'] is bool ? data['inStock'] as bool : null,
      verifiedAt: verificationEnabled && date is Timestamp
          ? date.toDate()
          : null,
      verificationSource:
      verificationEnabled ? text('verificationSource') : '',
    );
  }
}

/// One catalog cache for the running app session.
/// Public catalog is read only. Saved service IDs stay on this device.
class DirectoryCatalog extends GetxService {
  static const savedKey = 'hello_dimla_saved_service_ids_v1';

  final services = <DirectoryItem>[].obs;
  final products = <DirectoryItem>[].obs;

  final servicesLoading = false.obs;
  final productsLoading = false.obs;
  final servicesError = ''.obs;
  final productsError = ''.obs;

  SavedItemsStore get _saved => SavedItemsStore.instance;

  RxList<String> get savedIds => _saved.serviceIds;
  RxList<String> get savedProductIds => _saved.productIds;
  RxBool get savedReady => _saved.ready;
  RxBool get saving => _saved.saving;
  RxString get savedError => _saved.error;

  bool _servicesReady = false;
  bool _productsReady = false;

  Future<void>? _serviceTask;
  Future<void>? _productTask;
  Future<void>? _firebaseTask;

  static Map<String, dynamic> reference(DirectoryItem item) {
    return {
      'name': item.name,
      'imageUrl': item.imageUrl,
      'type': item.product ? 'Hello Store' : item.typeTitle,
      'priceMinor': item.priceMinor,
      'unit': item.unit,
      'inStock': item.inStock,
      'storedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _firebase() async {
    if (Firebase.apps.isNotEmpty) return;

    _firebaseTask ??= Firebase.initializeApp().then<void>((_) {});

    try {
      await _firebaseTask;
    } catch (_) {
      _firebaseTask = null;
      if (Firebase.apps.isEmpty) rethrow;
    }
  }

  Future<List<DirectoryItem>> _read(
      String collection, {
        required bool product,
      }) async {
    await _firebase();

    final result = <DirectoryItem>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;

    while (true) {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection(collection)
          .where('published', isEqualTo: true)
          .orderBy(FieldPath.documentId)
          .limit(100);

      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      final snapshot = await query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));

      for (final doc in snapshot.docs) {
        final item = DirectoryItem.fromDoc(doc, product: product);
        if (item.name.isNotEmpty) result.add(item);
      }

      if (snapshot.docs.length < 100) break;
      cursor = snapshot.docs.last;
    }

    return result;
  }

  String _error(Object error) {
    if (error is TimeoutException) {
      return 'তালিকা লোড হতে সময় লাগছে। আবার চেষ্টা করুন।';
    }

    if (error is FirebaseException &&
        error.code == 'permission-denied') {
      return 'তালিকা পড়ার অনুমতি পাওয়া যায়নি। Support-এ জানান।';
    }

    return 'তালিকা লোড হয়নি। আবার চেষ্টা করুন।';
  }

  Future<void> loadServices({bool force = false}) async {
    if (_serviceTask != null) {
      await _serviceTask;
      return;
    }

    if (_servicesReady && !force) return;

    final task = _loadServices();
    _serviceTask = task;

    try {
      await task;
    } finally {
      _serviceTask = null;
    }
  }

  Future<void> _loadServices() async {
    servicesLoading.value = true;
    servicesError.value = '';

    try {
      services.assignAll(await _read('services', product: false));
      _servicesReady = true;
    } catch (error) {
      servicesError.value = _error(error);
    } finally {
      servicesLoading.value = false;
    }
  }

  Future<void> loadProducts({bool force = false}) async {
    if (_productTask != null) {
      await _productTask;
      return;
    }

    if (_productsReady && !force) return;

    final task = _loadProducts();
    _productTask = task;

    try {
      await task;
    } finally {
      _productTask = null;
    }
  }

  Future<void> _loadProducts() async {
    productsLoading.value = true;
    productsError.value = '';

    try {
      products.assignAll(await _read('products', product: true));
      _productsReady = true;
    } catch (error) {
      productsError.value = _error(error);
    } finally {
      productsLoading.value = false;
    }
  }

  Future<void> loadSaved() => _saved.load();

  Future<void> toggleSaved(String id) async {
    DirectoryItem? found;

    for (final item in services) {
      if (item.id == id) {
        found = item;
        break;
      }
    }

    await _saved.toggle(
      id: id,
      product: false,
      snapshot: found == null ? null : reference(found),
    );
  }

  Future<void> toggleProductSaved(DirectoryItem item) async {
    await _saved.toggle(
      id: item.id,
      product: true,
      snapshot: reference(item),
    );
  }
}

class DirectoryController extends GetxController {
  DirectoryController({
    String? initialQuery,
    this.fixedCategory,
    this.servicesOnly = false,
  }) {
    searchInput.text = initialQuery?.trim() ?? '';
    query.value = searchInput.text;
    category.value = fixedCategory ?? '';

    if (servicesOnly) {
      kind.value = DirectoryKind.services;
    }
  }

  final String? fixedCategory;
  final bool servicesOnly;

  final searchInput = TextEditingController();

  final query = ''.obs;
  final category = ''.obs;
  final subtype = ''.obs;
  final area = 'সব এলাকা'.obs;
  final kind = DirectoryKind.all.obs;
  final sort = ProductSort.name.obs;
  final minimumPrice = Rxn<int>();
  final maximumPrice = Rxn<int>();
  final visibleLimit = 20.obs;

  Timer? _searchTimer;

  late final DirectoryCatalog catalog;

  String get title => servicesOnly
      ? directoryCategories[fixedCategory] ?? 'স্থানীয় সেবা'
      : 'সেবা ও পণ্য খুঁজুন';

  bool get loading => servicesOnly
      ? catalog.servicesLoading.value
      : catalog.servicesLoading.value || catalog.productsLoading.value;

  List<String> get errors => [
    if (catalog.servicesError.value.isNotEmpty)
      'সেবা: ${catalog.servicesError.value}',
    if (!servicesOnly && catalog.productsError.value.isNotEmpty)
      'পণ্য: ${catalog.productsError.value}',
    if (catalog.savedError.value.isNotEmpty)
      catalog.savedError.value,
  ];

  List<String> get areas {
    final values = <String>{'সব এলাকা', area.value};

    if (Get.isRegistered<CommunityService>()) {
      values.addAll(Get.find<CommunityService>().availableAreas);
    }

    for (final item in catalog.services) {
      values.addAll(item.areas);
    }

    return values.where((value) => value.trim().isNotEmpty).toList();
  }

  Map<String, String> get subtypes {
    final result = <String, String>{
      ...?directorySubtypes[category.value],
    };

    for (final item in catalog.services) {
      if (item.categoryId == category.value && item.subtypeId.isNotEmpty) {
        result.putIfAbsent(item.subtypeId, () => item.typeTitle);
      }
    }

    return result;
  }

  List<DirectoryItem> get filtered {
    final words = directoryNormalize(query.value)
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    bool matches(DirectoryItem item) {
      if (!words.every(item.searchable.contains)) return false;

      if (!item.product) {
        if (category.value.isNotEmpty &&
            item.categoryId != category.value) {
          return false;
        }

        if (subtype.value.isNotEmpty &&
            item.subtypeId != subtype.value) {
          return false;
        }

        if (area.value != 'সব এলাকা' &&
            !item.areas.any(
                  (value) =>
              directoryNormalize(value) ==
                  directoryNormalize(area.value),
            )) {
          return false;
        }
      } else {
        final price = item.priceMinor;
        final min = minimumPrice.value;
        final max = maximumPrice.value;

        if ((min != null || max != null) && price == null) return false;
        if (min != null && price! < min) return false;
        if (max != null && price! > max) return false;
      }

      return true;
    }

    int byName(DirectoryItem a, DirectoryItem b) {
      final comparison =
      directoryNormalize(a.name).compareTo(directoryNormalize(b.name));

      return comparison != 0 ? comparison : a.id.compareTo(b.id);
    }

    final serviceResults = catalog.services.where(matches).toList()
      ..sort(byName);

    final productResults = catalog.products.where(matches).toList()
      ..sort((a, b) {
        if (sort.value == ProductSort.name) return byName(a, b);

        final first = a.priceMinor;
        final second = b.priceMinor;

        if (first == null && second == null) return byName(a, b);
        if (first == null) return 1;
        if (second == null) return -1;

        final comparison = sort.value == ProductSort.priceLow
            ? first.compareTo(second)
            : second.compareTo(first);

        return comparison != 0 ? comparison : byName(a, b);
      });

    return switch (kind.value) {
      DirectoryKind.services => serviceResults,
      DirectoryKind.products => productResults,
      DirectoryKind.all => [...serviceResults, ...productResults],
    };
  }

  @override
  void onInit() {
    super.onInit();

    catalog = Get.isRegistered<DirectoryCatalog>()
        ? Get.find<DirectoryCatalog>()
        : Get.put(DirectoryCatalog(), permanent: true);

    if (Get.isRegistered<CommunityService>()) {
      area.value = Get.find<CommunityService>().selectedArea.value;
    }

    unawaited(reload());
  }

  Future<void> reload({bool force = false}) async {
    await Future.wait<void>([
      catalog.loadServices(force: force),
      if (!servicesOnly) catalog.loadProducts(force: force),
      catalog.loadSaved(),
    ]);
  }

  void search(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 220), () {
      query.value = value;
      visibleLimit.value = 20;
    });
  }

  void reset() {
    _searchTimer?.cancel();
    searchInput.clear();
    query.value = '';
    category.value = fixedCategory ?? '';
    subtype.value = '';
    area.value = 'সব এলাকা';
    minimumPrice.value = null;
    maximumPrice.value = null;
    sort.value = ProductSort.name;
    visibleLimit.value = 20;
  }

  void changeKind(DirectoryKind value) {
    kind.value = value;
    visibleLimit.value = 20;
  }

  void changeCategory(String value) {
    category.value = value;
    subtype.value = '';
    visibleLimit.value = 20;
  }

  void changeSubtype(String value) {
    subtype.value = value;
    visibleLimit.value = 20;
  }

  void changeArea(String value) {
    area.value = value;
    visibleLimit.value = 20;
  }

  void applyPrice(int? min, int? max, ProductSort value) {
    minimumPrice.value = min;
    maximumPrice.value = max;
    sort.value = value;
    visibleLimit.value = 20;
  }

  void open(DirectoryItem item) {
    FocusManager.instance.primaryFocus?.unfocus();

    if (item.product) {
      Get.to(() => ProductDetailsScreen(productId: item.id));
    } else {
      Get.to(() => ServiceDetailsScreen(serviceId: item.id));
    }
  }

  Future<void> call(DirectoryItem item) async {
    final number = item.dialNumber;
    if (number == null) return;

    try {
      final opened = await launchUrl(
        Uri(scheme: 'tel', path: number),
        mode: LaunchMode.externalApplication,
      );

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
    _searchTimer?.cancel();
    searchInput.dispose();
    super.onClose();
  }
}