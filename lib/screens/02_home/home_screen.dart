import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/community_models.dart';
import '../05_search_results/search_results_screen.dart';
import '../06_service_list/service_list_screen.dart';
import 'home_controller.dart';

// --- Modern Color Palette ---
const _blue = Color(0xFF1959E8);
const _blueDark = Color(0xFF0D3B9E);
const _teal = Color(0xFF0891B2);
const _ink = Color(0xFF0F1E36);
const _muted = Color(0xFF64748B);
const _bg = Color(0xFFF4F7FB);
const _border = Color(0xFFE2E8F0);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenStore,
    this.onOpenMenu,
  });

  final VoidCallback? onOpenStore;
  final VoidCallback? onOpenMenu;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController c;
  late final bool _ownsController;

  bool _refreshing = false;

  @override
  void initState() {
    super.initState();

    _ownsController = !Get.isRegistered<HomeController>();

    c = _ownsController
        ? Get.put(HomeController())
        : Get.find<HomeController>();
  }

  @override
  void dispose() {
    if (_ownsController &&
        Get.isRegistered<HomeController>() &&
        identical(Get.find<HomeController>(), c)) {
      Get.delete<HomeController>();
    }

    super.dispose();
  }

  void _store() => (widget.onOpenStore ?? c.openStore)();

  void _allServices() {
    Get.to(() => const ServiceListScreen());
  }

  void _menu() => (widget.onOpenMenu ?? _allServices)();

  void _find(String query) {
    Get.to(() => SearchResultsScreen(query: query));
  }

  void _search() {
    FocusScope.of(context).unfocus();
    c.search();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;

    _refreshing = true;

    try {
      await c.refresh();
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            // Top Ambient Background Glow
            Positioned(
              top: -100,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _blue.withValues(alpha: 0.12),
                      _blue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 60,
              left: -100,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _teal.withValues(alpha: 0.08),
                      _teal.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: RefreshIndicator(
                    color: _blue,
                    backgroundColor: Colors.white,
                    onRefresh: _refresh,
                    child: ListView.builder(
                      key: const PageStorageKey('hello_dimla_home_v2'),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
                      itemCount: 9,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: switch (index) {
                            0 => _header(),
                            1 => _searchBox(),
                            2 => _hero(),
                            3 => _emergency(),
                            4 => _shortcuts(),
                            5 => _services(),
                            6 => _shopping(),
                            7 => _updates(),
                            _ => _saved(),
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 0. Header Section ---
  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Location Selector Pill
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: _border),
                  ),
                  elevation: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: c.selectArea,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Obx(
                            () => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: _blue,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: _Label(
                                c.community.selectedArea.value,
                                weight: FontWeight.w700,
                                size: 13.5,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: _muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Saved Bookmark Quick Button
            _CircleActionBtn(
              icon: Icons.bookmark_border_rounded,
              tooltip: 'সেভ করা',
              onTap: c.openSaved,
            ),
            const SizedBox(width: 8),
            // Notification Button
            Obx(
                  () => _CircleActionBtn(
                icon: Icons.notifications_none_rounded,
                tooltip: 'নোটিফিকেশন',
                badgeCount: c.community.unreadCount,
                onTap: c.openNotifications,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),

                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Text(
                        'Hello ',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -0.8,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        'Dimla',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _blue,
                          letterSpacing: -0.8,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const _Label(
                    'আপনার শহর, আপনার পাশে\n সেবা, কেনাকাটা আর দৈনন্দিন প্রয়োজন এক অ্যাপেই।',
                    color: _muted,
                    size: 13.5,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- 1. Search Box Section ---
  Widget _searchBox() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: c.searchInput,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        style: GoogleFonts.hindSiliguri(
          color: _ink,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'ডাক্তার, অ্যাম্বুলেন্স, দোকান বা পণ্য খুঁজুন...',
          hintStyle: GoogleFonts.hindSiliguri(
            color: _muted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 8),
            child: Icon(
              Icons.search_rounded,
              color: _blue,
              size: 24,
            ),
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(6),
            child: Material(
              color: _blue,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _search,
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: _blue,
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  // --- 2. Hero Banner Section ---
  Widget _hero() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2D6B),
              Color(0xFF1959E8),
              Color(0xFF088395),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _blueDark.withValues(alpha: 0.25),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative Glass Circles
            Positioned(
              right: -35,
              top: -35,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -50,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFFFFD166),
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            _Label(
                              'আমাদের ডিমলা · ডিজিটাল সেবা',
                              color: Colors.white,
                              size: 12,
                              weight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.location_city_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _Label(
                    'প্রয়োজনের সবকিছু,\nএখন এক জায়গায়।',
                    size: 26,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 6),
                  const _Label(
                    'আপনার এলাকার জরুরি সেবা, দোকানপাট ও যোগাযোগ খুঁজে নিন মুহূর্তেই।',
                    color: Color(0xFFDCEBFF),
                    size: 13.5,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _allServices,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _blueDark,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.explore_rounded,
                          size: 19,
                        ),
                        label: const _Label(
                          'সব সেবা দেখুন',
                          color: _blueDark,
                          weight: FontWeight.w700,
                          size: 13.5,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _store,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 18,
                        ),
                        label: const _Label(
                          'হ্যালো স্টোর',
                          color: Colors.white,
                          weight: FontWeight.w600,
                          size: 13.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. Emergency SOS Banner ---
  Widget _emergency() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF0F2),
            Color(0xFFFFE4E8),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFCCD5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => c.openCategory('emergency'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emergency_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label(
                        'জরুরি সাহায্য (SOS)',
                        size: 17,
                        weight: FontWeight.w700,
                        color: Color(0xFF9F1239),
                      ),
                      SizedBox(height: 2),
                      _Label(
                        'অ্যাম্বুলেন্স, ফায়ার সার্ভিস ও হাসপাতাল',
                        size: 12.5,
                        color: Color(0xFFBE123C),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Label(
                        'দেখুন',
                        size: 12,
                        weight: FontWeight.w700,
                        color: Color(0xFFE11D48),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: Color(0xFFE11D48),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 4. Quick Shortcuts Grid ---
  Widget _shortcuts() {
    final items = <(String, IconData, Color, VoidCallback)>[
      (
      'অ্যাম্বুলেন্স',
      Icons.local_hospital_rounded,
      const Color(0xFFE11D48),
          () => _find('অ্যাম্বুলেন্স'),
      ),
      (
      'অটো / ভ্যান',
      Icons.electric_rickshaw_rounded,
      const Color(0xFF0D9488),
          () => c.openCategory('local_transport'),
      ),
      (
      'ডাক্তার',
      Icons.medical_services_rounded,
      _blue,
          () => _find('ডাক্তার'),
      ),
      (
      'ফার্মেসি',
      Icons.local_pharmacy_rounded,
      const Color(0xFF7C3AED),
          () => _find('ফার্মেসি'),
      ),
      (
      'স্থানীয় দোকান',
      Icons.storefront_rounded,
      const Color(0xFFD97706),
          () => c.openCategory('local_shops'),
      ),
      (
      'খাবার',
      Icons.restaurant_rounded,
      const Color(0xFFEA580C),
          () => c.openCategory('food'),
      ),
      (
      'মিস্ত্রি',
      Icons.handyman_rounded,
      const Color(0xFF0284C7),
          () => c.openCategory('home_services'),
      ),
      (
      'সব সেবা',
      Icons.grid_view_rounded,
      const Color(0xFF4F46E5),
      _menu,
      ),
    ];

    return _panel(
      'দ্রুত সেবা',
      subtitle: 'প্রয়োজনীয় ক্যাটাগরি বেছে নিন',
      action: _menu,
      child: LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(13) > 19
              ? 2
              : 4;

          final width = (box.maxWidth - (columns - 1) * 10) / columns;

          return Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: Material(
                    color: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(
                        color: Color(0xFFEDF2F7),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: item.$4,
                      splashColor: item.$3.withValues(alpha: 0.12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 4,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TileIcon(item.$2, item.$3),
                            const SizedBox(height: 10),
                            _Label(
                              item.$1,
                              size: 12.5,
                              weight: FontWeight.w600,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // --- 5. Area Services Section ---
  Widget _services() {
    return _panel(
      'স্থানীয় সেবা',
      subtitle: 'আপনার এলাকার নির্ভরযোগ্য সেবাসমূহ',
      action: _allServices,
      child: Obx(() {
        final data = c.community;
        final services = c.areaServices.take(3).toList();

        return Column(
          children: [
            if (data.servicesLoading.value)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            if (data.servicesError.value.isNotEmpty)
              _message(
                data.servicesError.value,
                retry: true,
              ),

            if (!data.servicesLoading.value &&
                data.servicesError.value.isEmpty &&
                services.isEmpty)
              _message(
                'এই তালিকায় সেবা পাওয়া যায়নি। '
                    'সব সেবা দেখুন বা এলাকা বদলান।',
              ),

            for (final service in services)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _serviceCard(service),
              ),
          ],
        );
      }),
    );
  }

  Widget _serviceCard(ServiceSummary service) {
    final subtitleText = [
      service.subtitle,
      service.areas.take(2).join(' · '),
    ].whereType<String>().where((text) => text.isNotEmpty).join('\n');

    return Material(
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEDF2F7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => c.openService(service),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                height: 58,
                child: _Photo(
                  service.imageUrl,
                  icon: Icons.storefront_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label(
                      service.name,
                      weight: FontWeight.w700,
                      size: 15,
                      maxLines: 2,
                    ),
                    if (subtitleText.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      _Label(
                        subtitleText,
                        size: 12,
                        color: _muted,
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _border),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: _blue,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 6. Hello Store Section ---
  Widget _shopping() {
    return _panel(
      'Hello Store',
      subtitle: 'নিত্যপ্রয়োজনীয় পণ্য অর্ডার করুন ঘরে বসে',
      action: _store,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Promo Banner
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFEFF6FF),
                  Color(0xFFE0F2FE),
                ],
              ),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _store,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const _TileIcon(
                        Icons.shopping_bag_rounded,
                        _blue,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Label(
                              'আপনার কেনাকাটার ঠিকানা',
                              weight: FontWeight.w700,
                              size: 15,
                            ),
                            SizedBox(height: 2),
                            _Label(
                              'Hello Dimla-র নিজস্ব অনলাইন স্টোর',
                              size: 12,
                              color: _muted,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: _blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Obx(() {
            final data = c.community;
            final products = data.products.take(4).toList();

            return Column(
              children: [
                if (data.productsLoading.value)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),

                if (data.productsError.value.isNotEmpty)
                  _message(
                    data.productsError.value,
                    retry: true,
                  ),

                if (!data.productsLoading.value &&
                    data.productsError.value.isEmpty &&
                    products.isEmpty)
                  _message('পণ্য যোগ হলে এখানে দেখা যাবে।'),

                LayoutBuilder(
                  builder: (context, box) {
                    final columns = box.maxWidth < 260 ||
                        MediaQuery.textScalerOf(context).scale(14) > 22
                        ? 1
                        : 2;

                    final width =
                        (box.maxWidth - (columns - 1) * 12) / columns;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final product in products)
                          SizedBox(
                            width: width,
                            child: _product(product),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _product(ProductSummary product) {
    final unitText = product.unit;
    return Material(
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEDF2F7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => c.openProduct(product),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.35,
                    child: _Photo(
                      product.imageUrl,
                      icon: Icons.shopping_bag_outlined,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: product.inStock
                            ? const Color(0xFF059669).withValues(alpha: 0.9)
                            : const Color(0xFFE11D48).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _Label(
                        product.inStock ? 'স্টকে আছে' : 'স্টক নেই',
                        size: 10,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Label(
                product.name,
                weight: FontWeight.w700,
                size: 14,
                maxLines: 2,
              ),
              if (unitText != null && unitText.isNotEmpty) ...[
                const SizedBox(height: 2),
                _Label(
                  unitText,
                  size: 11.5,
                  color: _muted,
                  maxLines: 1,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Label(
                      moneyText(product.priceMinor),
                      size: 17,
                      weight: FontWeight.w700,
                      color: _blue,
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: _blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 7. News & Announcements Section ---
  Widget _updates() {
    return _panel(
      'ডিমলার খবর ও ঘোষণা',
      subtitle: 'স্থানীয় আপডেট ও জরুরি নোটিশ',
      child: Obx(() {
        final data = c.community;

        return Column(
          children: [
            if (data.updatesLoading.value)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            if (data.updatesError.value.isNotEmpty)
              _message(
                data.updatesError.value,
                retry: true,
              ),

            if (!data.updatesLoading.value &&
                data.updatesError.value.isEmpty &&
                data.updates.isEmpty)
              _message('নতুন স্থানীয় ঘোষণা এলে এখানে দেখুন।'),

            for (final update in data.updates.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: const Color(0xFFFFFBEB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFFEF3C7)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => c.openUpdate(update),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const _TileIcon(
                            Icons.campaign_rounded,
                            Color(0xFFD97706),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Label(
                                  update.title,
                                  weight: FontWeight.w700,
                                  size: 14.5,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                _Label(
                                  [
                                    update.label,
                                    dateText(update.publishedAt),
                                  ]
                                      .whereType<String>()
                                      .where((text) => text.isNotEmpty)
                                      .join(' · '),
                                  size: 12,
                                  color: const Color(0xFF92400E),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFD97706),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  // --- 8. Saved Items Card ---
  Widget _saved() {
    return _Surface(
      child: InkWell(
        onTap: c.openSaved,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              const _TileIcon(
                Icons.bookmarks_rounded,
                Color(0xFF7C3AED),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label(
                      'আপনার সেভ করা তালিকা',
                      weight: FontWeight.w700,
                      size: 16,
                    ),
                    SizedBox(height: 2),
                    _Label(
                      'পছন্দের সেবা ও পণ্যগুলো এক জায়গায় দেখুন',
                      size: 12.5,
                      color: _muted,
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF7C3AED),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Reusable Section Panel ---
  Widget _panel(
      String title, {
        String? subtitle,
        required Widget child,
        VoidCallback? action,
      }) {
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label(
                        title,
                        size: 18,
                        weight: FontWeight.w700,
                      ),
                      if (subtitle != null)
                        _Label(
                          subtitle,
                          size: 12,
                          color: _muted,
                        ),
                    ],
                  ),
                ),
                if (action != null)
                  Material(
                    color: _blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: action,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Label(
                              'সব দেখুন',
                              size: 12,
                              color: _blue,
                              weight: FontWeight.w700,
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: _blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // --- Empty / Error State Message ---
  Widget _message(
      String message, {
        bool retry = false,
      }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDF2F7)),
      ),
      child: Column(
        children: [
          Icon(
            retry ? Icons.error_outline_rounded : Icons.inbox_outlined,
            color: _muted,
            size: 28,
          ),
          const SizedBox(height: 6),
          _Label(
            message,
            color: _muted,
            size: 13,
            textAlign: TextAlign.center,
          ),
          if (retry) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(
                Icons.refresh_rounded,
                color: _blue,
                size: 18,
              ),
              label: const _Label(
                'আবার চেষ্টা করুন',
                color: _blue,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Top Bar Circular Button ---
class _CircleActionBtn extends StatelessWidget {
  const _CircleActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(
        side: BorderSide(color: _border),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Badge(
          isLabelVisible: badgeCount > 0,
          backgroundColor: const Color(0xFFE11D48),
          label: Text(
            badgeCount > 99 ? '99+' : '$badgeCount',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          child: Icon(
            icon,
            color: _ink,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// --- Typography Helper ---
class _Label extends StatelessWidget {
  const _Label(
      this.text, {
        this.size = 14,
        this.color = _ink,
        this.weight = FontWeight.w400,
        this.maxLines,
        this.textAlign,
      });

  final String text;
  final double size;
  final Color color;
  final FontWeight weight;
  final int? maxLines;
  final TextAlign? textAlign;

  static final _styles = <FontWeight, TextStyle>{
    FontWeight.w400: GoogleFonts.hindSiliguri(
      fontWeight: FontWeight.w400,
    ),
    FontWeight.w600: GoogleFonts.hindSiliguri(
      fontWeight: FontWeight.w600,
    ),
    FontWeight.w700: GoogleFonts.hindSiliguri(
      fontWeight: FontWeight.w700,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      textAlign: textAlign,
      style: (_styles[weight] ?? _styles[FontWeight.w400]!).copyWith(
        fontSize: size,
        color: color,
        height: 1.38,
      ),
    );
  }
}



// --- Elevated Card Surface ---
class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F1E36),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}



// --- Modern Gradient Tile Icon ---
class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: 25,
      ),
    );
  }
}



// --- Network Photo with Fallback ---
class _Photo extends StatelessWidget {
  const _Photo(
      this.url, {
        required this.icon,
      });

  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFFEBF1F9),
      child: Center(
        child: Icon(
          icon,
          color: const Color(0xFF7894BB),
          size: 28,
        ),
      ),
    );

    final uri = Uri.tryParse(url);

    final valid = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: valid
          ? Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: 600,
        excludeFromSemantics: true,
        frameBuilder: (_, child, frame, synchronous) {
          return synchronous || frame != null ? child : fallback;
        },
        errorBuilder: (_, error, trace) => fallback,
      )
          : fallback,
    );



  }
}