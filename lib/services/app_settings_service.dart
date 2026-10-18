import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'community_service.dart';

typedef SettingsData = Map<String, dynamic>;

const publicAppDefaults = <String, dynamic>{
  'supportEnabled': false,
  'operatorName': '',
  'operatorAddress': '',
  'supportPhone': '',
  'supportEmail': '',
  'supportHours': '',
  'policiesPublished': false,
  'policyVersion': 'draft-1',
  'policyUpdated': '',
  'privacyUrl': '',
  'privacyText': '',
  'termsUrl': '',
  'termsText': '',
  'deletionUrl': '',
  'deletionText': '',
  'aboutText': '',
  'cancellationText': '',
  'areas': ['সব এলাকা'],
  'governmentSources': [],
  'developerName': '',
  'developerWebsite': '',
};

const independentAppNotice =
    'Hello Dimla একটি স্বাধীন স্থানীয় সেবা ও কেনাকাটার app। '
    'এটি কোনো সরকারি দপ্তর বা সরকারি app নয়। '
    'সরকারি তথ্যের ক্ষেত্রে সংশ্লিষ্ট উৎস যাচাই করুন।';

String settingsDigits(String value) {
  for (var i = 0; i < 10; i++) {
    value = value.replaceAll('০১২৩৪৫৬৭৮৯'[i], '$i');
  }
  return value.trim();
}

String settingsText(
    SettingsData map,
    String key, {
      int max = 20000,
    }) {
  final value = map[key];

  return value is String && value.length <= max
      ? value.trim()
      : '';
}

void settingsRequire(bool condition, String message) {
  if (!condition) {
    throw FormatException(message);
  }
}

String settingsPhone(String value) {
  return settingsDigits(value)
      .replaceAll(RegExp(r'[\s()-]'), '');
}

bool settingsPhoneValid(String value) {
  return RegExp(r'^\+?[0-9]{7,15}$')
      .hasMatch(settingsPhone(value));
}

bool settingsEmail(String value) {
  return value.length <= 254 &&
      RegExp(
        r'^[A-Za-z0-9.!#$%&\x27*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$',
      ).hasMatch(value);
}

Uri? settingsHttps(String value) {
  final uri = Uri.tryParse(value);

  if (uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty) {
    return uri;
  }

  return null;
}

class AppSettingsService extends GetxService {
  static AppSettingsService get instance {
    if (Get.isRegistered<AppSettingsService>()) {
      return Get.find<AppSettingsService>();
    }

    return Get.put(
      AppSettingsService(),
      permanent: true,
    );
  }

  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  final config = SettingsData.from(publicAppDefaults).obs;
  final store = <String, dynamic>{}.obs;

  final profile = <String, dynamic>{
    'name': '',
    'phone': '',
    'area': '',
    'orderMessages': true,
    'localMessages': true,
  }.obs;

  final ready = false.obs;
  final busy = false.obs;
  final erasing = false.obs;

  final configExists = false.obs;
  final configCached = true.obs;
  final storeCached = true.obs;
  final deletionCached = true.obs;

  final remoteError = ''.obs;
  final localError = ''.obs;
  final uid = ''.obs;
  final version = 'পড়ছি…'.obs;

  final deletion = Rxn<SettingsData>();

  SharedPreferences? _prefs;
  Future<void>? _starting;

  final _workers = <Worker>[];
  final _asyncPrefs = SharedPreferencesAsync();

  StreamSubscription<DocumentSnapshot<SettingsData>>? _appSub;
  StreamSubscription<DocumentSnapshot<SettingsData>>? _storeSub;
  StreamSubscription<DocumentSnapshot<SettingsData>>? _deletionSub;
  StreamSubscription<User?>? _authSub;

  CommunityService? get _community {
    return Get.isRegistered<CommunityService>()
        ? Get.find<CommunityService>()
        : null;
  }

  String get prefix =>
      'dimla_settings_${db.app.options.projectId}';

  bool get supportReady {
    return config['supportEnabled'] == true &&
        (
            settingsPhoneValid(
              settingsText(config, 'supportPhone'),
            ) ||
                settingsEmail(
                  settingsText(config, 'supportEmail'),
                )
        );
  }

  bool get policiesReady {
    return config['policiesPublished'] == true &&
        settingsText(config, 'operatorName').isNotEmpty &&
        settingsText(config, 'policyVersion').isNotEmpty &&
        settingsEmail(settingsText(config, 'supportEmail')) &&
        settingsHttps(settingsText(config, 'privacyUrl')) != null &&
        settingsText(config, 'privacyText').isNotEmpty;
  }

  bool get deletionReady {
    return policiesReady &&
        settingsHttps(settingsText(config, 'deletionUrl')) != null &&
        settingsText(config, 'deletionText').isNotEmpty;
  }

  List<String> get areas {
    final raw = config['areas'];

    return <String>{
      'সব এলাকা',
      ...?_community?.availableAreas,
      if (raw is List)
        ...raw
            .whereType<String>()
            .map((value) => value.trim())
            .where(
              (value) =>
          value.isNotEmpty && value.length <= 60,
        ),
    }.toList();
  }

  List<SettingsData> get zones {
    final raw = store['deliveryZones'];

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where(
          (value) =>
      value['enabled'] == true &&
          settingsText(value, 'id').isNotEmpty &&
          settingsText(value, 'label').isNotEmpty,
    )
        .toList();
  }

  Future<void> initialize() {
    return _starting ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      final savedProfile = _prefs!.getString('$prefix.profile');

      if (savedProfile != null) {
        final raw = Map<String, dynamic>.from(
          jsonDecode(savedProfile) as Map,
        );

        profile.assignAll({
          'name': settingsText(raw, 'name', max: 80),
          'phone': settingsText(raw, 'phone', max: 16),
          'area': settingsText(raw, 'area', max: 100),
          'orderMessages': raw['orderMessages'] != false,
          'localMessages': raw['localMessages'] != false,
        });
      }

      final savedConfig = _prefs!.getString('$prefix.public');

      if (savedConfig != null) {
        config.assignAll({
          ...publicAppDefaults,
          ...Map<String, dynamic>.from(
            jsonDecode(savedConfig) as Map,
          ),
        });
      }

      final savedStore = _prefs!.getString('$prefix.store');

      if (savedStore != null) {
        store.assignAll(
          Map<String, dynamic>.from(
            jsonDecode(savedStore) as Map,
          ),
        );
      }

      await _connectPreferences();

      localError.value = '';
      ready.value = true;

      unawaited(readVersion());

      _appSub = db
          .doc('app_config/app')
          .snapshots(includeMetadataChanges: true)
          .listen(
            (doc) {
          configExists.value = doc.exists;
          configCached.value = doc.metadata.isFromCache;

          if (doc.exists) {
            config.assignAll({
              ...publicAppDefaults,
              ...doc.data()!,
            });

            unawaited(_cache('$prefix.public', config));
          } else if (!doc.metadata.isFromCache) {
            config.assignAll(publicAppDefaults);
            unawaited(_removeCache('$prefix.public'));
          }

          remoteError.value = '';
        },
        onError: (Object error) {
          remoteError.value =
          'বর্তমান তথ্য refresh হয়নি। '
              'Internet ও Firebase Rules পরীক্ষা করুন।';
        },
      );

      _storeSub = db
          .doc('app_config/store')
          .snapshots(includeMetadataChanges: true)
          .listen(
            (doc) {
          storeCached.value = doc.metadata.isFromCache;

          if (doc.exists) {
            store.assignAll(doc.data()!);
            unawaited(_cache('$prefix.store', store));
          } else if (!doc.metadata.isFromCache) {
            store.clear();
            unawaited(_removeCache('$prefix.store'));
          }
        },
        onError: (Object error) {
          remoteError.value = 'Store policy refresh হয়নি।';
        },
      );

      _authSub = auth.authStateChanges().listen(_watchIdentity);
      _watchIdentity(auth.currentUser);
    } catch (_) {
      localError.value =
      'Settings পড়া যায়নি। Data মুছবেন না; আবার চেষ্টা করুন।';
      _starting = null;
    }
  }

  Future<void> _connectPreferences() async {
    // Settings ও Community একই persisted keys ব্যবহার করবে।
    final oldArea = settingsText(profile, 'area', max: 60);

    final area =
        await _asyncPrefs.getString('selected_area') ??
            (oldArea.isEmpty ? 'সব এলাকা' : oldArea);

    final order =
        await _asyncPrefs.getBool('order_notices_enabled') ??
            (profile['orderMessages'] != false);

    final updates =
        await _asyncPrefs.getBool('update_notices_enabled') ??
            (profile['localMessages'] != false);

    await _asyncPrefs.setString('selected_area', area);
    await _asyncPrefs.setBool('order_notices_enabled', order);
    await _asyncPrefs.setBool('update_notices_enabled', updates);

    profile['area'] = area;
    profile['orderMessages'] = order;
    profile['localMessages'] = updates;

    final community = _community;
    if (community == null) return;

    community.selectedArea.value = area;
    community.orderNoticesEnabled.value = order;
    community.updateNoticesEnabled.value = updates;

    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();

    _workers.addAll([
      ever(
        community.selectedArea,
            (value) => profile['area'] = value,
      ),
      ever(
        community.orderNoticesEnabled,
            (value) => profile['orderMessages'] = value,
      ),
      ever(
        community.updateNoticesEnabled,
            (value) => profile['localMessages'] = value,
      ),
    ]);
  }

  Future<void> _cache(
      String key,
      Map<String, dynamic> data,
      ) async {
    try {
      await _prefs!.setString(key, jsonEncode(data));
    } catch (_) {
      // Remote information remains usable in this session.
    }
  }

  Future<void> _removeCache(String key) async {
    try {
      await _prefs!.remove(key);
    } catch (_) {
      // Retry on a later refresh.
    }
  }

  void _watchIdentity(User? user) {
    final next = user?.uid ?? '';

    if (uid.value == next && _deletionSub != null) return;

    uid.value = next;
    deletion.value = null;

    _deletionSub?.cancel();
    _deletionSub = null;

    if (next.isEmpty) return;

    _deletionSub = db
        .doc('data_deletion_requests/$next')
        .snapshots(includeMetadataChanges: true)
        .listen(
          (doc) {
        if (auth.currentUser?.uid != next) return;

        deletion.value = doc.data();
        deletionCached.value = doc.metadata.isFromCache;
      },
      onError: (Object error) {
        if (auth.currentUser?.uid == next) {
          deletion.value = null;
        }
      },
    );
  }

  Future<void> operation(
      Future<void> Function() action,
      ) async {
    settingsRequire(
      ready.value,
      'Settings loading শেষ হতে দিন।',
    );

    settingsRequire(
      !busy.value && !erasing.value,
      'আগের কাজটি শেষ হতে দিন।',
    );

    busy.value = true;

    try {
      await action();
    } finally {
      busy.value = false;
    }
  }

  Future<void> createPublicDefaults() {
    return operation(() async {
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }

      await db.runTransaction<void>((transaction) async {
        final ref = db.doc('app_config/app');
        final document = await transaction.get(ref);

        if (!document.exists) {
          transaction.set(ref, publicAppDefaults);
        }
      });
    });
  }

  Future<void> refresh() {
    return operation(() async {
      await Future.wait([
        db.doc('app_config/app').get(
          const GetOptions(source: Source.server),
        ),
        db.doc('app_config/store').get(
          const GetOptions(source: Source.server),
        ),
      ]);
    });
  }

  Future<void> saveProfile(
      String name,
      String phone,
      String area,
      ) {
    return operation(() async {
      final normalizedPhone = settingsPhone(phone);

      settingsRequire(
        name.trim().length <= 80 &&
            area.trim().length <= 60,
        'নাম বা এলাকা বেশি বড়।',
      );

      settingsRequire(
        normalizedPhone.isEmpty ||
            settingsPhoneValid(normalizedPhone),
        'সঠিক ফোন নম্বর দিন।',
      );

      final selected =
      area.trim().isEmpty ? 'সব এলাকা' : area.trim();

      final community = _community;

      if (community != null) {
        settingsRequire(
          await community.selectArea(selected),
          'এলাকা সংরক্ষণ হয়নি। আবার চেষ্টা করুন।',
        );
      } else {
        await _asyncPrefs.setString(
          'selected_area',
          selected,
        );
      }

      final next = <String, dynamic>{
        ...profile,
        'name': name.trim(),
        'phone': normalizedPhone,
        'area': selected,
      };

      settingsRequire(
        await _prefs!.setString(
          '$prefix.profile',
          jsonEncode(next),
        ),
        'তথ্য সংরক্ষণ হয়নি।',
      );

      profile.assignAll(next);
    });
  }

  Future<void> setPreference(String key, bool value) {
    return operation(() async {
      settingsRequire(
        ['orderMessages', 'localMessages'].contains(key),
        'অচেনা preference।',
      );

      final community = _community;

      if (community != null) {
        settingsRequire(
          await community.setNoticePreference(
            order: key == 'orderMessages',
            enabled: value,
          ),
          'Preference সংরক্ষণ হয়নি।',
        );
      } else {
        await _asyncPrefs.setBool(
          key == 'orderMessages'
              ? 'order_notices_enabled'
              : 'update_notices_enabled',
          value,
        );
      }

      profile[key] = value;
    });
  }

  Future<void> clearProfile() {
    return saveProfile('', '', '');
  }

  Future<void> requestDeletion(String description) {
    return operation(() async {
      settingsRequire(
        deletionReady,
        'Deletion policy ও public URL এখনও প্রস্তুত নয়।',
      );

      settingsRequire(
        description.length <= 1000,
        'বিবরণ সর্বোচ্চ ১০০০ অক্ষর হবে।',
      );

      final user = auth.currentUser;

      settingsRequire(
        user != null,
        'এই device-এ cloud identity নেই। '
            'Support-এর সঙ্গে যোগাযোগ করুন।',
      );

      final currentUid = user!.uid;

      await db.runTransaction<void>((transaction) async {
        final ref = db.doc(
          'data_deletion_requests/$currentUid',
        );

        final existing = await transaction.get(ref);

        if (existing.exists) return;

        final app = await transaction.get(
          db.doc('app_config/app'),
        );

        final live = app.data() ?? <String, dynamic>{};

        settingsRequire(
          live['policiesPublished'] == true &&
              settingsHttps(
                settingsText(live, 'deletionUrl'),
              ) != null,
          'বর্তমান deletion policy প্রস্তুত নয়।',
        );

        transaction.set(ref, {
          'ownerUid': currentUid,
          'type': 'account_and_cloud_data',
          'description': description.trim(),
          'policyVersion': settingsText(live, 'policyVersion'),
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    });
  }

  Future<void> openUrl(String value) async {
    final uri = settingsHttps(value);

    settingsRequire(
      uri != null,
      'সঠিক HTTPS link প্রকাশিত হয়নি।',
    );

    settingsRequire(
      await launchUrl(
        uri!,
        mode: LaunchMode.externalApplication,
      ),
      'Browser খুলতে পারেনি।',
    );
  }

  Future<void> callSupport() async {
    final phone = settingsPhone(
      settingsText(config, 'supportPhone'),
    );

    settingsRequire(
      config['supportEnabled'] == true &&
          settingsPhoneValid(phone),
      'Support নম্বর প্রকাশিত হয়নি।',
    );

    settingsRequire(
      await launchUrl(
        Uri(scheme: 'tel', path: phone),
      ),
      'Dialer খুলতে পারেনি।',
    );
  }

  Future<void> emailSupport({
    String subject = 'Hello Dimla Support',
    String body = '',
  }) async {
    final email = settingsText(config, 'supportEmail');

    settingsRequire(
      config['supportEnabled'] == true &&
          settingsEmail(email),
      'Support email প্রকাশিত হয়নি।',
    );

    final query = {
      'subject': subject,
      'body': body,
    }.entries.map((entry) {
      return '${Uri.encodeComponent(entry.key)}='
          '${Uri.encodeComponent(entry.value)}';
    }).join('&');

    settingsRequire(
      await launchUrl(
        Uri(
          scheme: 'mailto',
          path: email,
          query: query,
        ),
      ),
      'Email app খুলতে পারেনি। '
          'Email address copy করে যোগাযোগ করুন।',
    );
  }

  String policyBody(String key) {
    if (key == 'delivery' || key == 'return') {
      return settingsText(
        store,
        key == 'delivery'
            ? 'deliveryPolicy'
            : 'returnPolicy',
      );
    }

    if (!policiesReady) {
      return 'Policy এখনও প্রকাশিত হয়নি। '
          'App owner-এর প্রকাশিত policy এখানে দেখাবে।';
    }

    const fields = {
      'privacy': 'privacyText',
      'terms': 'termsText',
      'deletion': 'deletionText',
      'about': 'aboutText',
      'cancellation': 'cancellationText',
    };

    return settingsText(config, fields[key] ?? '');
  }

  Future<void> readVersion() async {
    try {
      final data =
      await const MethodChannel('hellodimla/app_info')
          .invokeMapMethod<String, dynamic>('info');

      version.value =
      '${data?['version'] ?? ''} (${data?['build'] ?? ''})';
    } catch (_) {
      version.value = 'App বন্ধ করে আবার Run করুন';
    }
  }

  Future<void> stopRemote() async {
    await _appSub?.cancel();
    await _storeSub?.cancel();
    await _deletionSub?.cancel();
    await _authSub?.cancel();

    _appSub = null;
    _storeSub = null;
    _deletionSub = null;
    _authSub = null;
  }

  Future<void> stopCloudCacheForErase() async {
    erasing.value = true;

    await stopRemote();

    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();

    if (Get.isRegistered<CommunityService>()) {
      await Get.delete<CommunityService>(force: true);
    }

    await db.terminate();
    await db.clearPersistence();
  }

  Future<void> eraseLocalPreferencesAndCache() async {
    erasing.value = true;

    await stopRemote();

    settingsRequire(
      await _prefs!.clear(),
      'Local preferences পুরো পরিষ্কার হয়নি।',
    );

    // Saved items/inbox preferences use this separate backend.
    await _asyncPrefs.clear();

    final temporaryDirectory = await getTemporaryDirectory();

    for (final item in temporaryDirectory.listSync()) {
      if (item is File &&
          item.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('dimla_')) {
        await item.delete();
      }
    }

    // SettingsScreen already closes/deletes ledger and cart databases.
    await const MethodChannel('hellodimla/app_info')
        .invokeMethod<void>('closeAfterErase');
  }

  @override
  void onClose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();

    _appSub?.cancel();
    _storeSub?.cancel();
    _deletionSub?.cancel();
    _authSub?.cancel();

    super.onClose();
  }
}