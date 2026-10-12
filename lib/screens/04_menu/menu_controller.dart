import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../03_notifications/notifications_screen.dart';
import '../06_service_list/service_list_screen.dart';
import '../08_saved_items/saved_items_screen.dart';
import '../21_settings/settings_screen.dart';
import '../22_help_policies/help_policies_screen.dart';

class MenuCategory {
  const MenuCategory(
      this.id,
      this.title,
      this.icon,
      this.keywords,
      );

  final String id;
  final String title;
  final IconData icon;
  final String keywords;
}

class MenuController extends GetxController {
  final searchInput = TextEditingController();
  final query = ''.obs;

  static const categories = <MenuCategory>[
    MenuCategory(
      'emergency',
      'জরুরি সেবা',
      Icons.emergency_rounded,
      'emergency ambulance police fire রক্ত অ্যাম্বুলেন্স পুলিশ',
    ),
    MenuCategory(
      'local_transport',
      'অটো, ভ্যান ও রিকশা',
      Icons.electric_rickshaw_rounded,
      'auto van rickshaw transport যাতায়াত ইজিবাইক',
    ),
    MenuCategory(
      'vehicle_rental',
      'গাড়ি ও মালবাহী পরিবহন',
      Icons.local_shipping_outlined,
      'car truck pickup cargo rent গাড়ি ট্রাক পিকআপ ভাড়া',
    ),
    MenuCategory(
      'long_distance_transport',
      'বাস ও দূরপাল্লার যাতায়াত',
      Icons.directions_bus_outlined,
      'bus coach travel transport বাস কাউন্টার',
    ),
    MenuCategory(
      'health',
      'ডাক্তার ও স্বাস্থ্যসেবা',
      Icons.medical_services_outlined,
      'doctor hospital clinic pharmacy ডাক্তার হাসপাতাল ফার্মেসি',
    ),
    MenuCategory(
      'local_shops',
      'মুদি ও স্থানীয় দোকান',
      Icons.storefront_outlined,
      'shop grocery market shopping দোকান মুদি বাজার',
    ),
    MenuCategory(
      'food',
      'খাবার ও রেস্টুরেন্ট',
      Icons.restaurant_outlined,
      'food restaurant cafe খাবার হোটেল চা',
    ),
    MenuCategory(
      'home_services',
      'বাড়ির কাজ ও মিস্ত্রি',
      Icons.handyman_outlined,
      'electrician plumber mason ইলেকট্রিশিয়ান প্লাম্বার মিস্ত্রি',
    ),
    MenuCategory(
      'repair',
      'মোবাইল ও যন্ত্র মেরামত',
      Icons.build_outlined,
      'repair mobile computer mechanic মেরামত কম্পিউটার',
    ),
    MenuCategory(
      'agriculture',
      'কৃষিসেবা',
      Icons.agriculture_outlined,
      'agriculture farming seed fertilizer কৃষি বীজ সার',
    ),
    MenuCategory(
      'livestock',
      'পশু ও প্রাণিসম্পদ',
      Icons.pets_outlined,
      'animal livestock veterinary গরু ছাগল পশু চিকিৎসা',
    ),
    MenuCategory(
      'education',
      'শিক্ষা ও প্রশিক্ষণ',
      Icons.school_outlined,
      'education school coaching training স্কুল কোচিং প্রশিক্ষণ',
    ),
    MenuCategory(
      'jobs_workers',
      'চাকরি ও কর্মী',
      Icons.work_outline_rounded,
      'job worker labour চাকরি কাজ শ্রমিক কর্মী',
    ),
    MenuCategory(
      'rent_property',
      'বাসা ও দোকান ভাড়া',
      Icons.home_work_outlined,
      'house shop property rent বাসা দোকান ভাড়া জমি',
    ),
    MenuCategory(
      'courier_documents',
      'কুরিয়ার ও অনলাইন সেবা',
      Icons.inventory_2_outlined,
      'courier parcel printing documents কুরিয়ার পার্সেল কাগজপত্র',
    ),
    MenuCategory(
      'financial_directory',
      'ব্যাংক ও আর্থিক যোগাযোগ',
      Icons.account_balance_outlined,
      'bank atm agent finance ব্যাংক এটিএম এজেন্ট',
    ),
    MenuCategory(
      'civic_information',
      'সরকারি ও নাগরিক তথ্য',
      Icons.assured_workload_outlined,
      'government citizen union সরকারি নাগরিক ইউনিয়ন পরিষদ',
    ),
    MenuCategory(
      'events',
      'অনুষ্ঠান ও আয়োজন',
      Icons.celebration_outlined,
      'event wedding decoration photography অনুষ্ঠান বিয়ে সাজসজ্জা',
    ),
    MenuCategory(
      'tourism',
      'দর্শনীয় স্থান',
      Icons.landscape_outlined,
      'tourism travel place park দর্শনীয় ভ্রমণ পার্ক',
    ),
    MenuCategory(
      'local_updates',
      'স্থানীয় খবর ও ঘোষণা',
      Icons.campaign_outlined,
      'news update announcement খবর ঘোষণা আপডেট',
    ),
  ];

  List<MenuCategory> get filteredCategories {
    final words = query.value
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return categories;

    return categories.where((category) {
      final searchable =
      '${category.title} ${category.keywords} ${category.id}'
          .toLowerCase();

      return words.every(searchable.contains);
    }).toList();
  }

  void clearSearch() {
    searchInput.clear();
    query.value = '';
  }

  void openCategory(MenuCategory category) {
    FocusManager.instance.primaryFocus?.unfocus();

    Get.to(
          () => ServiceListScreen(categoryId: category.id),
    );
  }

  void openSaved() => Get.to(() => const SavedItemsScreen());

  void openNotifications() =>
      Get.to(() => const NotificationsScreen());

  void openSettings() => Get.to(() => const SettingsScreen());

  void openHelp() => Get.to(() => const HelpPoliciesScreen());

  @override
  void onClose() {
    searchInput.dispose();
    super.onClose();
  }
}