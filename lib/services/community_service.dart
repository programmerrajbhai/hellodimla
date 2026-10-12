import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/community_models.dart';

class CommunityService extends GetxService {
  CommunityService(this.preferences);

  final SharedPreferencesAsync preferences;

  // Location preferences
  final selectedArea = 'সব এলাকা'.obs;
  final availableAreas = <String>[].obs;

  // Published content
  final services = <ServiceSummary>[].obs;
  final products = <ProductSummary>[].obs;
  final updates = <LocalUpdate>[].obs;

  // Private notification inbox
  final notices = <InboxNotice>[].obs;

  // Loading states
  final servicesLoading = true.obs;
  final productsLoading = true.obs;
  final updatesLoading = true.obs;
  final noticesLoading = true.obs;

  // Error states
  final servicesError = ''.obs;
  final productsError = ''.obs;
  final updatesError = ''.obs;
  final noticesError = ''.obs;

  // In-app notification preferences
  final orderNoticesEnabled = true.obs;
  final updateNoticesEnabled = true.obs;

  // Locally saved notification state
  final readIds = <String>[].obs;
  final hiddenIds = <String>[].obs;

  final saving = false.obs;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  FirebaseFirestore? _database;
  String? _uid;

  bool _starting = false;

  String get _readKey => 'inbox_read_${_uid ?? "none"}';

  String get _hiddenKey => 'inbox_hidden_${_uid ?? "none"}';

  List<InboxNotice> get visibleNotices {
    return notices.where((notice) {
      if (hiddenIds.contains(notice.id)) {
        return false;
      }

      if (notice.kind == NoticeKind.order) {
        return orderNoticesEnabled.value;
      }

      return updateNoticesEnabled.value;
    }).toList();
  }

  int get unreadCount {
    return visibleNotices
        .where((notice) => !readIds.contains(notice.id))
        .length;
  }

  Future<void> start() async {
    if (_starting || isClosed) {
      return;
    }

    _starting = true;

    try {
      await _cancelSubscriptions();

      servicesLoading.value = true;
      productsLoading.value = true;
      updatesLoading.value = true;
      noticesLoading.value = true;

      servicesError.value = '';
      productsError.value = '';
      updatesError.value = '';
      noticesError.value = '';

      await _loadPreferences();

      // Android configuration comes from google-services.json.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      if (isClosed) {
        return;
      }

      _database = FirebaseFirestore.instance;

      // Public content is available independently of anonymous auth.
      _listenToPublicContent();

      await _connectInbox();
    } catch (_) {
      if (isClosed) {
        return;
      }

      const message = 'সংযোগ করা যায়নি। আবার চেষ্টা করুন।';

      servicesLoading.value = false;
      productsLoading.value = false;
      updatesLoading.value = false;
      noticesLoading.value = false;

      servicesError.value = message;
      productsError.value = message;
      updatesError.value = message;
      noticesError.value = message;
    } finally {
      _starting = false;
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final area =
          await preferences.getString('selected_area') ?? 'সব এলাকা';

      final orderEnabled =
          await preferences.getBool('order_notices_enabled') ?? true;

      final updateEnabled =
          await preferences.getBool('update_notices_enabled') ?? true;

      if (isClosed) {
        return;
      }

      selectedArea.value = area;
      orderNoticesEnabled.value = orderEnabled;
      updateNoticesEnabled.value = updateEnabled;
    } catch (_) {
      // Preference failure must not block Firebase content.
    }
  }

  void _listenToPublicContent() {
    final db = _database;

    if (db == null || isClosed) {
      return;
    }

    // Services
    _subscriptions.add(
      db
          .collection('services')
          .where('published', isEqualTo: true)
          .limit(12)
          .snapshots()
          .listen(
            (snapshot) {
          if (isClosed) {
            return;
          }

          services.assignAll(
            snapshot.docs.map(ServiceSummary.fromDoc),
          );

          servicesLoading.value = false;
          servicesError.value = '';
        },
        onError: (Object error) {
          if (isClosed) {
            return;
          }

          servicesLoading.value = false;
          servicesError.value = 'সেবার তথ্য আনা যায়নি।';
        },
      ),
    );

    // Products
    _subscriptions.add(
      db
          .collection('products')
          .where('published', isEqualTo: true)
          .limit(8)
          .snapshots()
          .listen(
            (snapshot) {
          if (isClosed) {
            return;
          }

          products.assignAll(
            snapshot.docs.map(ProductSummary.fromDoc),
          );

          productsLoading.value = false;
          productsError.value = '';
        },
        onError: (Object error) {
          if (isClosed) {
            return;
          }

          productsLoading.value = false;
          productsError.value = 'পণ্যের তথ্য আনা যায়নি।';
        },
      ),
    );

    // Published local updates
    _subscriptions.add(
      db
          .collection('updates')
          .where('published', isEqualTo: true)
          .orderBy('publishedAt', descending: true)
          .limit(5)
          .snapshots()
          .listen(
            (snapshot) {
          if (isClosed) {
            return;
          }

          updates.assignAll(
            snapshot.docs.map(LocalUpdate.fromDoc),
          );

          updatesLoading.value = false;
          updatesError.value = '';
        },
        onError: (Object error) {
          if (isClosed) {
            return;
          }

          updatesLoading.value = false;
          updatesError.value = 'ঘোষণার তথ্য আনা যায়নি।';
        },
      ),
    );

    // Optional published location configuration
    _subscriptions.add(
      db.collection('app_config').doc('locations').snapshots().listen(
            (snapshot) {
          if (isClosed) {
            return;
          }

          final rawAreas = snapshot.data()?['areas'];

          availableAreas.assignAll(
            rawAreas is List
                ? rawAreas
                .whereType<String>()
                .map((area) => area.trim())
                .where((area) => area.isNotEmpty)
                .toSet()
                .toList()
                : <String>[],
          );
        },
        onError: (Object error) {
          // Manual area selection remains available.
        },
      ),
    );
  }

  Future<void> _connectInbox() async {
    try {
      final auth = FirebaseAuth.instance;

      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }

      if (isClosed) {
        return;
      }

      final nextUid = auth.currentUser?.uid;

      if (nextUid == null) {
        throw StateError('Missing Firebase identity');
      }

      // Never retain another identity's inbox in memory.
      if (_uid != nextUid) {
        notices.clear();
        readIds.clear();
        hiddenIds.clear();
      }

      _uid = nextUid;

      readIds.assignAll(
        await preferences.getStringList(_readKey) ?? <String>[],
      );

      hiddenIds.assignAll(
        await preferences.getStringList(_hiddenKey) ?? <String>[],
      );

      if (isClosed) {
        return;
      }

      final db = _database;

      if (db == null) {
        throw StateError('Firestore is not initialized');
      }

      _subscriptions.add(
        db
            .collection('users')
            .doc(nextUid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots()
            .listen(
              (snapshot) {
            if (isClosed) {
              return;
            }

            notices.assignAll(
              snapshot.docs.map(InboxNotice.fromDoc),
            );

            noticesLoading.value = false;
            noticesError.value = '';
          },
          onError: (Object error) {
            if (isClosed) {
              return;
            }

            noticesLoading.value = false;
            noticesError.value = 'নোটিফিকেশন আনা যায়নি।';
          },
        ),
      );
    } catch (_) {
      if (isClosed) {
        return;
      }

      notices.clear();
      noticesLoading.value = false;
      noticesError.value = 'আপনার নোটিফিকেশন সংযোগ করা যায়নি।';
    }
  }

  Future<bool> selectArea(String value) async {
    final cleaned = value.trim();

    if (cleaned.isEmpty || cleaned.length > 60) {
      return false;
    }

    return _save(() async {
      await preferences.setString('selected_area', cleaned);

      if (!isClosed) {
        selectedArea.value = cleaned;
      }
    });
  }

  Future<bool> markRead(String id) async {
    if (_uid == null || id.isEmpty) {
      return false;
    }

    if (readIds.contains(id)) {
      return true;
    }

    return _save(() async {
      final next = {...readIds, id}.toList();

      await preferences.setStringList(_readKey, next);

      if (!isClosed) {
        readIds.assignAll(next);
      }
    });
  }

  Future<bool> markAllRead() async {
    if (_uid == null) {
      return false;
    }

    return _save(() async {
      final next = {
        ...readIds,
        ...visibleNotices.map((notice) => notice.id),
      }.toList();

      await preferences.setStringList(_readKey, next);

      if (!isClosed) {
        readIds.assignAll(next);
      }
    });
  }

  Future<bool> clearVisibleHistory() async {
    if (_uid == null) {
      return false;
    }

    return _save(() async {
      final next = {
        ...hiddenIds,
        ...visibleNotices.map((notice) => notice.id),
      }.toList();

      await preferences.setStringList(_hiddenKey, next);

      if (!isClosed) {
        hiddenIds.assignAll(next);
      }
    });
  }

  Future<bool> setNoticePreference({
    required bool order,
    required bool enabled,
  }) async {
    return _save(() async {
      final key = order
          ? 'order_notices_enabled'
          : 'update_notices_enabled';

      await preferences.setBool(key, enabled);

      if (isClosed) {
        return;
      }

      if (order) {
        orderNoticesEnabled.value = enabled;
      } else {
        updateNoticesEnabled.value = enabled;
      }
    });
  }

  Future<LocalUpdate?> loadUpdate(String id) async {
    final db = _database;

    if (db == null || id.isEmpty || isClosed) {
      return null;
    }

    final snapshot = await db.collection('updates').doc(id).get();
    final data = snapshot.data();

    if (data == null || data['published'] != true) {
      return null;
    }

    return LocalUpdate.fromMap(snapshot.id, data);
  }

  Future<bool> _save(Future<void> Function() action) async {
    if (saving.value || isClosed) {
      return false;
    }

    saving.value = true;

    try {
      await action();
      return true;
    } catch (_) {
      if (!isClosed) {
        Get.snackbar(
          'সংরক্ষণ হয়নি',
          'আবার চেষ্টা করুন।',
          snackPosition: SnackPosition.BOTTOM,
        );
      }

      return false;
    } finally {
      if (!isClosed) {
        saving.value = false;
      }
    }
  }

  Future<void> _cancelSubscriptions() async {
    final subscriptions = List<StreamSubscription<dynamic>>.of(
      _subscriptions,
    );

    _subscriptions.clear();

    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
  }

  @override
  void onClose() {
    unawaited(_cancelSubscriptions());
    super.onClose();
  }
}