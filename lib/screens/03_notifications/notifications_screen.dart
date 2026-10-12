import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/community_widgets.dart';
import '../../data/models/community_models.dart';
import 'notifications_controller.dart';
import 'sheets/notification_preferences_sheet.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(NotificationsController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<NotificationsController>() &&
        identical(Get.find<NotificationsController>(), controller)) {
      Get.delete<NotificationsController>();
    }

    super.dispose();
  }

  void openPreferences() {
    Get.bottomSheet(
      const NotificationPreferencesSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Future<void> clearHistory() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('নোটিফিকেশন পরিষ্কার করবেন?'),
        content: const Text(
          'বর্তমানে দেখানো নোটিফিকেশন এই ডিভাইসের '
              'history থেকে সরবে। আপনার অর্ডার মুছবে না।',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('না'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('পরিষ্কার করুন'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.community.clearVisibleHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = controller.community;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'নোটিফিকেশন',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'নোটিফিকেশন পছন্দ',
            onPressed: openPreferences,
            icon: const Icon(Icons.tune_rounded),
          ),
          Obx(
                () => IconButton(
              tooltip: 'History পরিষ্কার করুন',
              onPressed: community.saving.value ||
                  community.visibleNotices.isEmpty
                  ? null
                  : clearHistory,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.pine,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: AppColors.yellow,
                          size: 36,
                        ),
                        const SizedBox(width: 17),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'প্রয়োজনীয় আপডেট,\nএক জায়গায়।',
                                style: TextStyle(
                                  color: AppColors.cream,
                                  fontSize: 22,
                                  height: 1.4,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Obx(
                                    () => Text(
                                  '${community.unreadCount}টি অপঠিত নোটিস',
                                  style: const TextStyle(
                                    color: AppColors.mint,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Obx(
                        () => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip(
                          'সব',
                          InboxFilter.all,
                        ),
                        _filterChip(
                          'অর্ডার',
                          InboxFilter.orders,
                        ),
                        _filterChip(
                          'স্থানীয় আপডেট',
                          InboxFilter.updates,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Obx(
                          () => TextButton.icon(
                        onPressed: community.saving.value ||
                            community.unreadCount == 0
                            ? null
                            : () => community.markAllRead(),
                        icon: const Icon(
                          Icons.done_all_rounded,
                          size: 18,
                        ),
                        label: const Text('সব পড়া হয়েছে'),
                      ),
                    ),
                  ),
                  Obx(
                        () => controller.opening.value
                        ? const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(),
                    )
                        : const SizedBox.shrink(),
                  ),
                  Obx(() {
                    final notices = controller.filteredNotices;

                    return ContentState(
                      loading: community.noticesLoading.value,
                      error: community.noticesError.value,
                      empty: notices.isEmpty,
                      emptyTitle: 'এই তালিকায় কোনো নোটিস নেই',
                      emptyMessage: 'নতুন আপডেট এলে এখানে দেখা যাবে।',
                      onRetry: () => controller.refresh(),
                      child: Column(
                        children: [
                          for (final notice in notices)
                            _NoticeCard(
                              notice: notice,
                              unread: !community.readIds.contains(notice.id),
                              onTap: controller.opening.value ||
                                  community.saving.value
                                  ? null
                                  : () => controller.openNotice(notice),
                            ),
                        ],
                      ),
                    );
                  }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String title, InboxFilter filter) {
    return ChoiceChip(
      label: Text(title),
      selected: controller.selectedFilter.value == filter,
      selectedColor: AppColors.yellow,
      showCheckmark: false,
      onSelected: (_) {
        controller.selectedFilter.value = filter;
      },
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.unread,
    required this.onTap,
  });

  final InboxNotice notice;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isOrder = notice.kind == NoticeKind.order;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: unread ? const Color(0xFFEEF2E5) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOrder
                        ? const Color(0xFFF3E8C2)
                        : const Color(0xFFDDEADF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isOrder
                        ? Icons.shopping_bag_outlined
                        : Icons.campaign_outlined,
                    size: 23,
                    color: AppColors.pine,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          fontWeight:
                          unread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notice.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 5,
                        children: [
                          Text(
                            isOrder ? 'অর্ডার' : 'স্থানীয় আপডেট',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.pine,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            dateText(notice.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: AppColors.pine,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}