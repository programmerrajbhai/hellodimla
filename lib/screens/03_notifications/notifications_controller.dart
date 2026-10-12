import 'package:get/get.dart';

import '../../data/models/community_models.dart';
import '../../services/community_service.dart';
import '../02_home/sheets/home_sheets.dart';
import '../14_order_details/order_details_screen.dart';

enum InboxFilter { all, orders, updates }

class NotificationsController extends GetxController {
  final community = Get.find<CommunityService>();

  final selectedFilter = InboxFilter.all.obs;
  final opening = false.obs;

  List<InboxNotice> get filteredNotices {
    final source = community.visibleNotices;

    return switch (selectedFilter.value) {
      InboxFilter.all => source,
      InboxFilter.orders =>
          source.where((item) => item.kind == NoticeKind.order).toList(),
      InboxFilter.updates =>
          source.where((item) => item.kind == NoticeKind.update).toList(),
    };
  }

  Future<void> openNotice(InboxNotice notice) async {
    if (opening.value || community.saving.value) return;

    opening.value = true;

    try {
      if (notice.targetId.isEmpty) {
        Get.snackbar(
          'বিস্তারিত পাওয়া যায়নি',
          'এই নোটিফিকেশনের বিস্তারিত link নেই।',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      if (notice.kind == NoticeKind.order) {
        final saved = await community.markRead(notice.id);
        if (!saved) return;

        Get.to(
              () => OrderDetailsScreen(orderId: notice.targetId),
        );

        return;
      }

      final update = await community.loadUpdate(notice.targetId);

      if (update == null) {
        Get.snackbar(
          'ঘোষণাটি পাওয়া যায়নি',
          'এটি সরানো হয়েছে অথবা এখন প্রকাশিত নেই।',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final saved = await community.markRead(notice.id);
      if (!saved) return;

      showUpdateSheet(update);
    } catch (_) {
      Get.snackbar(
        'বিস্তারিত আনা যায়নি',
        'সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      opening.value = false;
    }
  }

  Future<void> refresh() {
    return community.start();
  }
}