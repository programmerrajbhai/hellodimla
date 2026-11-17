import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;

typedef ServiceJson = Map<String, dynamic>;

typedef ServiceCatalog = ({
List<ServiceJson> menus,
List<ServiceJson> areas,
});

typedef ServicePage = ({
List<ServiceJson> items,
int? nextAfter,
});

class ServiceApiException implements Exception {
  const ServiceApiException(this.message, [this.status]);

  final String message;
  final int? status;

  @override
  String toString() => message;
}

abstract final class ServiceApi {
  // Android Emulator → Mac-এর XAMPP।
  // এখানে api.php নয়, যে ফোল্ডারে api.php আছে তার URL দেবে।
  static const baseUrl = String.fromEnvironment(
    'DIMLA_API',
    defaultValue: 'https://programmerraj.site/smart_dimla_admin/',
  );

  static Uri _url(
      String action, [
        Map<String, String> params = const {},
      ]) {
    final base = Uri.tryParse(baseUrl.trim());

    if (base == null ||
        base.host.isEmpty ||
        !{'http', 'https'}.contains(base.scheme) ||
        base.hasQuery ||
        base.hasFragment ||
        base.userInfo.isNotEmpty ||
        (kReleaseMode && base.scheme != 'https')) {
      throw const ServiceApiException(
        'DIMLA_API ঠিক করুন। Release-এ HTTPS দিন।',
      );
    }

    final dir = base.path.endsWith('/') ? base.path : '${base.path}/';

    return base.replace(
      path: '${dir}api.php',
      queryParameters: {'a': action, ...params},
    );
  }

  /// প্রকাশিত মেনু, সাবমেনু ও ইউনিয়ন একই অনুরোধে আনে।
  static Future<ServiceCatalog> catalog() async {
    final data = await _request(_url('catalog'));

    return (
    menus: _rows(data['menus']),
    areas: _rows(data['areas']),
    );
  }

  /// menuId হবে তালিকা ধরনের মেনুর ID।
  /// areaId = 0 মানে সব ইউনিয়ন। প্রথম পাতার জন্য after = 0।
  static Future<ServicePage> entries({
    required int menuId,
    int areaId = 0,
    int after = 0,
  }) async {
    if (menuId < 1 || areaId < 0 || after < 0) {
      throw ArgumentError('menuId, areaId বা after সঠিক নয়।');
    }

    final data = await _request(
      _url('list', {
        'menu': '$menuId',
        'area': '$areaId',
        'after': '$after',
      }),
    );

    final items = _rows(data['items']);
    final more = data['more'];

    if (more is! bool) {
      throw const FormatException('Invalid pagination flag');
    }

    final last = items.isEmpty
        ? null
        : int.tryParse('${items.last['id']}');

    if (more && (last == null || last <= after)) {
      throw const FormatException('Invalid pagination cursor');
    }

    return (items: items, nextAfter: more ? last : null);
  }

  /// মেনুর hasIcon = 1 হলে ব্যবহার করবে। revision হিসেবে rev দেবে।
  static Uri menuIcon(int id, {int revision = 0}) =>
      _url('icon', {'id': '$id', 'v': '$revision'});

  /// সেবার hasPhoto = 1 হলে ব্যবহার করবে।
  static Uri profilePhoto(int id, {int revision = 0}) =>
      _url('photo', {'id': '$id', 'v': '$revision'});

  /// তথ্য জমা দেয়। সফল হলে নতুন entry ID ফেরত দেয়।
  /// জমা হওয়া মানেই প্রকাশিত নয়; প্রকাশ করবে অ্যাডমিন।
  static Future<int> submit({
    required int menuId,
    required String name,
    required String phone,
    required List<int> areaIds,
    required bool consent,
    Map<String, String> extra = const {},
    String? photoBase64,
    String address = '',
  }) async {
    final areas = areaIds.toSet().toList();

    if (menuId < 1 ||
        areas.isEmpty ||
        areas.length > 30 ||
        areas.any((id) => id < 1)) {
      throw const ServiceApiException('মেনু ও সেবার ইউনিয়ন নির্বাচন করুন।');
    }

    if (!consent) {
      throw const ServiceApiException('তথ্য প্রকাশের সম্মতি প্রয়োজন।');
    }

    final data = await _request(_url('submit'), body: {
      'menu': menuId,
      'name': name.trim(),
      'phone': phone.trim(),
      'areas': areas,
      'consent': consent,
      'extra': extra,
      if (photoBase64 != null) 'profilePhoto': photoBase64,
      if (address.trim().isNotEmpty)
        'profileFields': [
          {'label': 'ঠিকানা', 'value': address.trim()},
        ],
    });

    final id = int.tryParse('${data['id']}');
    if (data['ok'] != true || id == null || id < 1) {
      throw const ServiceApiException('আবেদন জমার স্বীকৃতি পাওয়া যায়নি।');
    }
    return id;
  }




  static List<ServiceJson> _rows(dynamic value) {
    if (value is! List || value.any((row) => row is! ServiceJson)) {
      throw const FormatException('Invalid service list');
    }

    return List<ServiceJson>.from(value);
  }

  static Future<ServiceJson> _request(
      Uri uri, {
        ServiceJson? body,
      }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);

    Future<ServiceJson> send() async {
      final req = await client.openUrl(
        body == null ? 'GET' : 'POST',
        uri,
      );

      req.followRedirects = false;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');

      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
      }

      final res = await req.close();
      final raw = await utf8.decoder.bind(res).join();

      dynamic data;
      try {
        data = jsonDecode(raw);
      } on FormatException {
        throw ServiceApiException(
          'API থেকে JSON পাওয়া যায়নি (HTTP ${res.statusCode})।',
          res.statusCode,
        );
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final msg = data is ServiceJson ? data['error'] : null;

        throw ServiceApiException(
          msg is String ? msg : 'অনুরোধ ব্যর্থ (HTTP ${res.statusCode})।',
          res.statusCode,
        );
      }

      if (data is! ServiceJson) {
        throw const FormatException('Invalid API response');
      }

      return data;
    }

    try {
      return await send().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ServiceApiException('সার্ভার সময়মতো উত্তর দেয়নি।');
    } on SocketException {
      throw const ServiceApiException(
        'সার্ভারে পৌঁছানো যায়নি। API ঠিকানা ও সংযোগ দেখুন।',
      );
    } finally {
      client.close(force: true);
    }
  }
}