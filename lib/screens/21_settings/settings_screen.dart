import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../business/business_store.dart';
import '../../commerce/shop_service.dart';
import '../../services/app_settings_service.dart';
import '../../services/settings_widgets.dart';
import '../03_notifications/notifications_screen.dart';
import '../20_reports/reports_screen.dart';
import '../22_help_policies/help_policies_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// আগের ProfileSettingsScreen() call-ও কাজ করবে।
class ProfileSettingsScreen extends SettingsScreen {
  const ProfileSettingsScreen({super.key});
}

class _SettingsScreenState extends State<SettingsScreen> {
  final shop = ShopService.instance;
  final ledger = BusinessStore.instance;

  @override
  void initState() {
    super.initState();
    shop.loadLocal();
    ledger.init();
  }

  Future<bool> _unlockLedger() async {
    await ledger.init();

    settingsRequire(
      ledger.ready.value,
      'খাতা পড়া যায়নি। আবার চেষ্টা করুন।',
    );

    if (ledger.book.settings?['pin'] == null ||
        !ledger.locked.value) {
      return true;
    }

    var unlocked = false;

    await settingsForm(
      'খাতা খুলুন',
      {'pin': 'বর্তমান ৬ সংখ্যার PIN'},
      {},
          (values) async {
        await ledger.unlock(settingsDigits(values['pin']!));
        unlocked = true;
      },
      hint: 'সঠিক PIN ছাড়া পুরোনো খাতা খোলা যাবে না।',
    );

    return unlocked;
  }

  Future<void> _editProfile(AppSettingsService s) {
    return settingsForm(
      'আমার তথ্য',
      {
        'name': 'নাম — ঐচ্ছিক',
        'phone': 'ফোন — ঐচ্ছিক',
      },
      {
        'name': '${s.profile['name'] ?? ''}',
        'phone': '${s.profile['phone'] ?? ''}',
      },
          (values) => s.saveProfile(
        values['name']!,
        values['phone']!,
        '${s.profile['area'] ?? ''}',
      ),
      hint: 'এই তথ্য আপনার ফোনে সংরক্ষিত থাকবে।',
    );
  }

  Future<void> _selectArea(AppSettingsService s) async {
    final selected = await Get.bottomSheet<String>(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: Get.height * .75,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                settingsHeading('আপনার ইউনিয়ন / বাজার'),
                for (final area in s.areas)
                  ListTile(
                    title: Text(area),
                    trailing: (
                        s.profile['area'] == area ||
                            area == 'সব এলাকা' &&
                                '${s.profile['area'] ?? ''}'.isEmpty
                    )
                        ? const Icon(
                      Icons.check_circle,
                      color: settingsBlue,
                    )
                        : null,
                    onTap: () => Get.back(result: area),
                  ),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('বন্ধ করুন'),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );

    if (selected == null) return;

    await s.saveProfile(
      '${s.profile['name'] ?? ''}',
      '${s.profile['phone'] ?? ''}',
      selected == 'সব এলাকা' ? '' : selected,
    );
  }

  Future<void> _changePin() async {
    await ledger.init();

    settingsRequire(
      ledger.ready.value && ledger.book.settings != null,
      'আগে ব্যবসার খাতা setup করুন।',
    );

    final hasPin = ledger.book.settings!['pin'] != null;

    await settingsForm(
      hasPin ? 'PIN পরিবর্তন' : 'PIN চালু করুন',
      {
        if (hasPin) 'oldPin': 'বর্তমান PIN',
        'pin': 'নতুন ৬ সংখ্যার PIN',
        'againPin': 'নতুন PIN আবার লিখুন',
      },
      {},
          (values) async {
        final pin = settingsDigits(values['pin']!);

        settingsRequire(
          RegExp(r'^\d{6}$').hasMatch(pin),
          'PIN অবশ্যই ৬ সংখ্যার হবে।',
        );

        settingsRequire(
          pin == settingsDigits(values['againPin']!),
          'দুটি নতুন PIN মেলেনি।',
        );

        if (hasPin) {
          ledger.lock();
          await ledger.unlock(
            settingsDigits(values['oldPin']!),
          );
        }

        await ledger.setPin(pin);
      },
      hint: 'খাতার PIN ও encrypted backup password আলাদা।',
    );
  }

  Future<void> _editBusiness() async {
    if (!await _unlockLedger()) return;

    final business = ledger.book.settings;

    settingsRequire(
      business != null,
      'আগে ব্যবসার খাতা setup করুন।',
    );

    await settingsForm(
      'ব্যবসার তথ্য',
      {
        'name': 'ব্যবসার নাম',
        'type': 'ব্যবসার ধরন',
      },
      {
        'name': '${business!['name'] ?? ''}',
        'type': '${business['type'] ?? ''}',
      },
          (values) => ledger.change((book) {
        Book.text(values['name'], 80);
        Book.text(values['type'], 60);

        book.settings!['name'] = values['name'];
        book.settings!['type'] = values['type'];
      }),
      hint: 'পুরোনো হিসাব ঠিক রাখতে এখানে opening cash '
          'ও হিসাব শুরুর তারিখ পরিবর্তন হবে না।',
    );
  }

  Future<void> _editAddress(
      AppSettingsService s, {
        int? index,
      }) async {
    await shop.loadLocal();

    settingsRequire(
      shop.localReady.value,
      'ঠিকানা পড়া যায়নি।',
    );

    settingsRequire(
      !shop.locked && !shop.busy.value,
      'আগের order attempt-এর ফল নিশ্চিত করুন।',
    );

    if (index != null) {
      settingsRequire(
        index >= 0 && index < shop.addresses.length,
        'ঠিকানার তালিকা বদলেছে। আবার খুলুন।',
      );
    }

    final zones = s.zones;

    settingsRequire(
      zones.isNotEmpty,
      'Delivery এলাকা প্রকাশিত হলে ঠিকানা যোগ করা যাবে।',
    );

    final old = index == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(shop.addresses[index]);

    final signature = jsonEncode(old);

    final zoneId = await Get.bottomSheet<String>(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: Get.height * .75,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                settingsHeading('Delivery এলাকা নির্বাচন'),
                for (final zone in zones)
                  ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: settingsBlue,
                    ),
                    title: Text('${zone['label']}'),
                    onTap: () => Get.back(
                      result: zone['id'] as String,
                    ),
                  ),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('বাতিল'),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );

    if (zoneId == null) return;

    final zone = zones.firstWhere(
          (item) => item['id'] == zoneId,
    );

    final raw = (s.store['deliveryZones'] as List?) ?? [];

    final zoneIndex = raw.indexWhere(
          (item) => item is Map && item['id'] == zoneId,
    );

    settingsRequire(
      zoneIndex >= 0,
      'Delivery এলাকা বদলেছে। আবার নির্বাচন করুন।',
    );

    await settingsForm(
      index == null ? 'নতুন ঠিকানা' : 'ঠিকানা পরিবর্তন',
      {
        'name': 'গ্রাহকের নাম',
        'phone': 'মোবাইল নম্বর',
        'address': 'পূর্ণ ঠিকানা',
        'landmark': 'চেনার জায়গা — ঐচ্ছিক',
        'note': 'Delivery note — ঐচ্ছিক',
      },
      {
        for (final key in [
          'name',
          'phone',
          'address',
          'landmark',
          'note',
        ])
          key: '${old[key] ?? ''}',
      },
          (values) async {
        if (index != null) {
          settingsRequire(
            index < shop.addresses.length &&
                jsonEncode(shop.addresses[index]) == signature,
            'ঠিকানার তালিকা বদলেছে। আবার খুলুন।',
          );
        }

        await shop.settingsSaveAddress(
          {
            ...values,
            'zoneId': zoneId,
            'zoneLabel': zone['label'],
            'zoneIndex': zoneIndex,
          },
          index: index,
        );
      },
      hint: 'এলাকা: ${zone['label']}। GPS লাগবে না। '
          'Delivery charge ও eligibility checkout-এ যাচাই হবে।',
    );
  }

  Future<void> _removeAddress(int index) async {
    settingsRequire(
      !shop.locked && !shop.busy.value,
      'আগের order attempt-এর ফল নিশ্চিত করুন।',
    );

    settingsRequire(
      index >= 0 && index < shop.addresses.length,
      'ঠিকানার তালিকা বদলেছে।',
    );

    final signature = jsonEncode(shop.addresses[index]);

    final confirmed = await settingsConfirm(
      'ঠিকানা সরাবেন?',
      'Saved address সরবে। আগের order-এর ঠিকানা বদলাবে না।',
    );

    if (!confirmed) return;

    settingsRequire(
      index < shop.addresses.length &&
          jsonEncode(shop.addresses[index]) == signature,
      'তালিকা বদলেছে। আবার খুলুন।',
    );

    await shop.deleteAddress(index);
  }

  Future<void> _eraseLedger() async {
    if (!await _unlockLedger()) return;

    final confirmed = await settingsConfirm(
      'ব্যবসার খাতা মুছবেন?',
      'এই ফোনের ব্যবসার settings, PIN, customer/supplier, '
          'products ও সব হিসাব মুছবে।\n\n'
          'বাইরে রাখা backup ও shopping order মুছবে না। '
          'প্রয়োজনে আগে encrypted backup নিন।',
    );

    if (confirmed) {
      await ledger.settingsEraseLedger();
    }
  }

  Future<void> _eraseLocal(AppSettingsService s) async {
    await shop.loadLocal();

    settingsRequire(
      shop.localReady.value &&
          !shop.busy.value &&
          !shop.locked,
      'আগের order attempt-এর ফল নিশ্চিত করে আবার চেষ্টা করুন।',
    );

    if (!await _unlockLedger()) return;

    final confirmed = await settingsConfirm(
      'Local ব্যক্তিগত data মুছবেন?',
      'খাতা, PIN, cart, saved address, saved items, '
          'profile/preferences, temporary exports ও '
          'Firestore cache মুছবে। App বন্ধ হবে।\n\n'
          'Cloud orders ও anonymous cloud identity থাকবে। '
          'Server deletion আলাদা request। '
          'App-এর বাইরে রাখা backup মুছবে না।',
    );

    if (!confirmed) return;

    s.erasing.value = true;

    try {
      await s.stopCloudCacheForErase();

      await ledger.settingsEraseLedger();
      ledger.busy.value = true;

      await shop.settingsEraseLocalDatabase();
      shop.busy.value = true;

      await s.eraseLocalPreferencesAndCache();
    } catch (_) {
      s.erasing.value = false;

      throw const FormatException(
        'পুরো পরিষ্কার শেষ হয়নি; কিছু data মুছে থাকতে পারে। '
            'App বন্ধ করে খুলুন। প্রয়োজনে backup restore করুন।',
      );
    }
  }

  Future<void> _openHelp() async {
    Get.to(() => const HelpPoliciesScreen());
  }

  Widget _item(
      IconData icon,
      String title,
      Future<void> Function() action, {
        String? subtitle,
        bool danger = false,
      }) {
    final color = danger
        ? Colors.red.shade700
        : settingsBlue;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: danger
              ? const Color(0xFFFFEBEE)
              : const Color(0xFFEAF0FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: danger ? color : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
      ),
      onTap: () => settingsAction(action),
    );
  }

  Widget _profileHeader(AppSettingsService s) {
    final name = '${s.profile['name'] ?? ''}';
    final phone = '${s.profile['phone'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF123EAD),
            Color(0xFF2878E8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty
                      ? 'Hello Dimla ব্যবহারকারী'
                      : name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone.isEmpty
                      ? 'আপনার তথ্য ও পছন্দ'
                      : phone,
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'তথ্য পরিবর্তন',
            onPressed: () => settingsAction(
                  () => _editProfile(s),
            ),
            icon: const Icon(
              Icons.edit_outlined,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _addresses(AppSettingsService s) {
    return settingsCard([
      settingsHeading('Delivery ঠিকানা'),
      FilledButton.tonalIcon(
        onPressed: () => settingsAction(
              () => _editAddress(s),
        ),
        icon: const Icon(Icons.add),
        label: const Text('ঠিকানা যোগ করুন'),
      ),
      Obx(
            () => Column(
          children: [
            if (!shop.localReady.value)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            if (shop.localReady.value && shop.addresses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'এখনও কোনো ঠিকানা সংরক্ষণ করা হয়নি',
                ),
              ),
            for (var i = 0; i < shop.addresses.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${shop.addresses[i]['name']} • '
                      '${shop.addresses[i]['phone']}',
                ),
                subtitle: Text(
                  '${shop.addresses[i]['zoneLabel']}\n'
                      '${shop.addresses[i]['address']}',
                ),
                onTap: () => settingsAction(
                      () => _editAddress(s, index: i),
                ),
                trailing: IconButton(
                  tooltip: 'ঠিকানা সরান',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => settingsAction(
                        () => _removeAddress(i),
                  ),
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'আমার তথ্য ও Settings',
      body: (s) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _profileHeader(s),

          settingsCard([
            settingsHeading('ব্যক্তিগত পছন্দ'),
            _item(
              Icons.person_outline,
              'নাম ও ফোন পরিবর্তন',
                  () => _editProfile(s),
              subtitle: 'দুটিই ঐচ্ছিক',
            ),
            _item(
              Icons.location_on_outlined,
              'পছন্দের ইউনিয়ন / বাজার',
                  () => _selectArea(s),
              subtitle: '${s.profile['area'] ?? ''}'.isEmpty
                  ? 'সব এলাকা'
                  : '${s.profile['area']}',
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.language,
                color: settingsBlue,
              ),
              title: Text('ভাষা'),
              subtitle: Text('বাংলা'),
              trailing: Icon(
                Icons.check_circle,
                color: settingsBlue,
              ),
            ),
          ]),

          _addresses(s),

          settingsCard([
            settingsHeading('Notification তালিকা'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('অর্ডারের বার্তা'),
              value: s.profile['orderMessages'] == true,
              onChanged: (value) => settingsAction(
                    () => s.setPreference(
                  'orderMessages',
                  value,
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('স্থানীয় আপডেট'),
              value: s.profile['localMessages'] == true,
              onChanged: (value) => settingsAction(
                    () => s.setPreference(
                  'localMessages',
                  value,
                ),
              ),
            ),
            const Text(
              'এগুলো app-এর তালিকার পছন্দ। '
                  'ফোনের push notification permission আলাদা।',
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
            _item(
              Icons.notifications_none,
              'বার্তাগুলো দেখুন',
                  () async {
                Get.to(
                      () => const NotificationsScreen(),
                );
              },
            ),
          ]),

          settingsCard([
            settingsHeading('ব্যবসার খাতা'),
            Obx(
                  () => Text(
                !ledger.ready.value
                    ? 'খাতা পড়া হচ্ছে…'
                    : ledger.locked.value
                    ? 'ব্যক্তিগত খাতা লক করা আছে'
                    : '${ledger.book.settings?['name'] ?? 'Setup করা হয়নি'}',
                style: const TextStyle(
                  color: Colors.black54,
                ),
              ),
            ),
            _item(
              Icons.store_outlined,
              'ব্যবসার তথ্য',
              _editBusiness,
            ),
            _item(
              Icons.password_rounded,
              'PIN চালু / পরিবর্তন',
              _changePin,
            ),
            _item(
              Icons.lock_open_outlined,
              'খাতা খুলুন',
                  () async {
                await _unlockLedger();
              },
            ),
            _item(
              Icons.backup_outlined,
              'Backup / Restore',
                  () async {
                if (await _unlockLedger()) {
                  Get.to(
                        () => const ReportsScreen(),
                  );
                }
              },
              subtitle: 'Encrypted backup ও পুনরুদ্ধার',
            ),
            _item(
              Icons.delete_outline,
              'ব্যবসার খাতা মুছুন',
              _eraseLedger,
              danger: true,
            ),
          ]),

          settingsCard([
            settingsHeading('Data control'),
            _item(
              Icons.cloud_off_outlined,
              'Server data deletion request',
              _openHelp,
              subtitle: 'Help-এর data deletion নির্দেশনা দেখুন',
            ),
            _item(
              Icons.delete_forever_outlined,
              'Local ব্যক্তিগত data মুছুন',
                  () => _eraseLocal(s),
              subtitle: 'মোছার আগে বিস্তারিত দেখানো হবে',
              danger: true,
            ),
            const Text(
              'Local খাতা ও server-এর shopping data '
                  'মোছার ব্যবস্থা আলাদা।',
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
          ]),

          settingsCard([
            _item(
              Icons.help_outline,
              'সাহায্য ও নীতিমালা',
              _openHelp,
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'Hello Dimla • ${s.version.value}',
                  style: const TextStyle(
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}