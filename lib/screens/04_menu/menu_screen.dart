import 'package:flutter/material.dart' hide MenuController;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'menu_controller.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  // --- Modern Color Palette ---
  static const blue = Color(0xFF1959E8);
  static const blueDark = Color(0xFF0F2D6B);
  static const navy = Color(0xFF0F1E36);
  static const muted = Color(0xFF64748B);
  static const bg = Color(0xFFF4F7FB);
  static const border = Color(0xFFE2E8F0);

  static const accents = [
    Color(0xFF1959E8), // Royal Blue
    Color(0xFF0D9488), // Teal
    Color(0xFFD97706), // Amber
    Color(0xFF7C3AED), // Violet
    Color(0xFFE11D48), // Rose
    Color(0xFF0284C7), // Sky Blue
    Color(0xFFEA580C), // Orange
    Color(0xFF4F46E5), // Indigo
  ];

  // --- Cached Base Font Styles for 120fps Smooth Scrolling ---
  static final Map<FontWeight, TextStyle> _baseFonts = {
    FontWeight.w400: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w400),
    FontWeight.w500: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w500),
    FontWeight.w600: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
    FontWeight.w700: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
  };

  static TextStyle text(
      double size, {
        Color color = navy,
        FontWeight weight = FontWeight.w500,
        double height = 1.38,
      }) {
    final base = _baseFonts[weight] ?? _baseFonts[FontWeight.w500]!;
    return base.copyWith(
      fontSize: size,
      color: color,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = screenWidth > 640 ? 640.0 : screenWidth;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
    final crossAxisCount = largeText ? 1 : (contentWidth >= 520 ? 3 : 2);

    return GetBuilder<MenuController>(
      init: MenuController(),
      builder: (c) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: bg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 18,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x1A1959E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'সব সেবা ও মেনু',
                    style: text(22, weight: FontWeight.w700),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(
                      side: BorderSide(color: border),
                    ),
                    child: IconButton(
                      tooltip: 'নোটিফিকেশন',
                      onPressed: c.openNotifications,
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: navy,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: CustomScrollView(
                  key: const PageStorageKey('dimla_menu_scroll'),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  cacheExtent: 600,
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    // --- Top Static Content ---
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const RepaintBoundary(
                              child: _DirectoryBanner(),
                            ),
                            const SizedBox(height: 16),
                            RepaintBoundary(
                              child: _SearchBox(controller: c),
                            ),
                            const SizedBox(height: 16),
                            RepaintBoundary(
                              child: _ShortcutsDock(controller: c),
                            ),
                            const SizedBox(height: 24),
                            _SectionHeader(controller: c),
                          ],
                        ),
                      ),
                    ),

                    // --- Reactive Sliver Grid / Empty State ---
                    Obx(() {
                      final items = c.filteredCategories;

                      if (items.isEmpty) {
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 36),
                          sliver: SliverToBoxAdapter(
                            child: _EmptyState(onReset: c.clearSearch),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 36),
                        sliver: SliverGrid.builder(
                          itemCount: items.length,
                          gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 144,
                          ),
                          itemBuilder: (context, index) {
                            final category = items[index];
                            final accent = accents[index % accents.length];

                            return RepaintBoundary(
                              child: _CategoryCard(
                                category: category,
                                accent: accent,
                                onTap: () => c.openCategory(category),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- 1. Directory Top Banner (Const & Isolated) ---
class _DirectoryBanner extends StatelessWidget {
  const _DirectoryBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MenuScreen.blueDark,
            MenuScreen.blue,
            Color(0xFF088395),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -25,
            top: -25,
            child: SizedBox(
              width: 110,
              height: 110,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x14FFFFFF),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x29FFFFFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ডিমলা সার্ভিস ডিরেক্টরি',
                          style: MenuScreen.text(
                            11,
                            color: Colors.white,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'প্রয়োজনীয় সব সেবা,\nএখন হাতের মুঠোয়।',
                        style: MenuScreen.text(
                          21,
                          color: Colors.white,
                          weight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'যেকোনো ক্যাটাগরি বেছে নিয়ে বিস্তারিত তথ্য ও যোগাযোগ দেখুন।',
                        style: MenuScreen.text(
                          12.5,
                          color: const Color(0xFFDCEBFF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0x24FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0x33FFFFFF),
                    ),
                  ),
                  child: const Icon(
                    Icons.apps_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 2. Smooth Search Box (Only Suffix Icon Rebuilds) ---
class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller});

  final MenuController controller;

  static final _defaultBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: MenuScreen.border),
  );

  static final _focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: MenuScreen.blue, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller.searchInput,
      onChanged: (value) => controller.query.value = value,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      cursorColor: MenuScreen.blue,
      style: MenuScreen.text(14.5, weight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'সেবার বিভাগ খুঁজুন (যেমন: ডাক্তার, অটো, দোকান)...',
        hintStyle: MenuScreen.text(
          13.5,
          color: MenuScreen.muted,
          weight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 12, right: 8),
          child: Icon(
            Icons.search_rounded,
            color: MenuScreen.blue,
            size: 23,
          ),
        ),
        suffixIcon: Obx(() {
          if (controller.query.value.isEmpty) {
            return const SizedBox.shrink();
          }
          return IconButton(
            tooltip: 'Search মুছুন',
            onPressed: controller.clearSearch,
            icon: const Icon(
              Icons.close_rounded,
              color: MenuScreen.muted,
              size: 20,
            ),
          );
        }),
        border: _defaultBorder,
        enabledBorder: _defaultBorder,
        focusedBorder: _focusedBorder,
      ),
    );
  }
}

// --- 3. Lightweight Quick Utility Dock (No IntrinsicHeight) ---
class _ShortcutsDock extends StatelessWidget {
  const _ShortcutsDock({required this.controller});

  final MenuController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MenuScreen.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ShortcutItem(
              title: 'সেভ করা',
              icon: Icons.bookmark_rounded,
              color: const Color(0xFF7C3AED),
              onTap: controller.openSaved,
            ),
          ),
          Container(width: 1, height: 42, color: MenuScreen.border),
          Expanded(
            child: _ShortcutItem(
              title: 'সেটিংস',
              icon: Icons.tune_rounded,
              color: MenuScreen.blue,
              onTap: controller.openSettings,
            ),
          ),
          Container(width: 1, height: 42, color: MenuScreen.border),
          Expanded(
            child: _ShortcutItem(
              title: 'সাহায্য',
              icon: Icons.support_agent_rounded,
              color: const Color(0xFF0D9488),
              onTap: controller.openHelp,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  const _ShortcutItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MenuScreen.text(12.5, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 4. Section Header ---
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.controller});

  final MenuController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSearching = controller.query.value.trim().isNotEmpty;
      final count = controller.filteredCategories.length;

      return Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: MenuScreen.blue,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isSearching ? 'খোঁজার ফলাফল' : 'সেবার বিভাগসমূহ',
              style: MenuScreen.text(19, weight: FontWeight.w700),
            ),
          ),
          if (isSearching)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: controller.clearSearch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'রিসেট',
                    style: MenuScreen.text(
                      12.5,
                      color: const Color(0xFFE11D48),
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x1A1959E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$countটি বিভাগ',
              style: MenuScreen.text(
                12,
                color: MenuScreen.blue,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    });
  }
}

// --- 5. High-Performance Bento Category Card ---
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.accent,
    required this.onTap,
  });

  final MenuCategory category;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: MenuScreen.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.1),
        highlightColor: accent.withValues(alpha: 0.04),
        child: Stack(
          children: [
            // Subtle Watermark Icon
            Positioned(
              right: -12,
              bottom: -12,
              child: Icon(
                category.icon,
                size: 72,
                color: accent.withValues(alpha: 0.05),
              ),
            ),
            // Top Accent Line Indicator
            Positioned(
              top: 0,
              left: 20,
              right: 20,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          category.icon,
                          color: accent,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          shape: BoxShape.circle,
                          border: Border.all(color: MenuScreen.border),
                        ),
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          color: accent,
                          size: 15,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MenuScreen.text(
                          15,
                          weight: FontWeight.w700,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'তালিকা দেখুন',
                        style: MenuScreen.text(
                          11.5,
                          color: MenuScreen.muted,
                          weight: FontWeight.w500,
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
}

// --- 6. Empty Search State ---
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MenuScreen.border),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0x141959E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 30,
              color: MenuScreen.blue,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'কোনো বিভাগ পাওয়া যায়নি',
            style: MenuScreen.text(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'অন্য কোনো নাম লিখে খুঁজুন অথবা সবগুলো বিভাগ দেখুন।',
            textAlign: TextAlign.center,
            style: MenuScreen.text(13.5, color: MenuScreen.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onReset,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0x1A1959E8),
              foregroundColor: MenuScreen.blue,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'সব বিভাগ দেখুন',
              style: MenuScreen.text(
                13.5,
                color: MenuScreen.blue,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}