import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/community_service.dart';

class NotificationPreferencesSheet extends StatelessWidget {
  const NotificationPreferencesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final community = Get.find<CommunityService>();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Obx(
                () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'নোটিফিকেশন পছন্দ',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'বন্ধ করুন',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'App-এর inbox-এ কোন ধরনের নোটিস দেখবেন '
                      'তা নির্বাচন করুন।',
                  style: TextStyle(
                    color: AppColors.muted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 18),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('অর্ডারের নোটিস'),
                  subtitle: const Text('অর্ডার ও delivery-এর আপডেট'),
                  value: community.orderNoticesEnabled.value,
                  onChanged: community.saving.value
                      ? null
                      : (enabled) {
                    community.setNoticePreference(
                      order: true,
                      enabled: enabled,
                    );
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('স্থানীয় আপডেট'),
                  subtitle: const Text('প্রকাশিত খবর ও ঘোষণা'),
                  value: community.updateNoticesEnabled.value,
                  onChanged: community.saving.value
                      ? null
                      : (enabled) {
                    community.setNoticePreference(
                      order: false,
                      enabled: enabled,
                    );
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'এগুলো বন্ধ করলে আপনার অর্ডার বা অন্য তথ্য মুছবে না।',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}