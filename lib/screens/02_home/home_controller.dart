import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/community_models.dart';
import '../../services/community_service.dart';
import '../03_notifications/notifications_screen.dart';
import '../05_search_results/search_results_screen.dart';
import '../06_service_list/service_list_screen.dart';
import '../07_service_details/service_details_screen.dart';
import '../08_saved_items/saved_items_screen.dart';
import '../09_shopping_home/shopping_home_screen.dart';
import '../10_product_details/product_details_screen.dart';
import 'sheets/home_sheets.dart';

class HomeController extends GetxController {
  final community = Get.find<CommunityService>();

  final searchInput = TextEditingController();

  List<ServiceSummary> get areaServices {
    final area = community.selectedArea.value;

    if (area == 'সব এলাকা') {
      return community.services.toList();
    }

    return community.services
        .where((service) => service.areas.contains(area))
        .toList();
  }

  void search() {
    final query = searchInput.text.trim();

    Get.to(
          () => SearchResultsScreen(
        query: query.isEmpty ? null : query,
      ),
    );
  }

  void openCategory(String categoryId) {
    Get.to(
          () => ServiceListScreen(categoryId: categoryId),
    );
  }

  void openService(ServiceSummary service) {
    Get.to(
          () => ServiceDetailsScreen(serviceId: service.id),
    );
  }

  void openProduct(ProductSummary product) {
    Get.to(
          () => ProductDetailsScreen(productId: product.id),
    );
  }

  void openStore() {
    Get.to(() => const ShoppingHomeScreen());
  }

  void openSaved() {
    Get.to(() => const SavedItemsScreen());
  }

  void openNotifications() {
    Get.to(() => const NotificationsScreen());
  }

  void selectArea() {
    Get.bottomSheet(
      const AreaSelectionSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void openUpdate(LocalUpdate update) {
    showUpdateSheet(update);
  }

  Future<void> refresh() {
    return community.start();
  }

  @override
  void onClose() {
    searchInput.dispose();
    super.onClose();
  }
}