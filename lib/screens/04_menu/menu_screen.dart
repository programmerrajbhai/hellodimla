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

  TextStyle text(
      double size, {
        Color color = navy,
        FontWeight weight = FontWeight.w500,
        double height = 1.38,
      }) {
    return GoogleFonts.hindSiliguri(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
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
              titleSpacing: 18,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.1),
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
            body: Stack(
              children: [
                // Subtle Ambient Top Glow
                Positioned(
                  top: -80,
                  right: -60,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          blue.withValues(alpha: 0.1),
                          blue.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: CustomScrollView(
                      key: const PageStorageKey('dimla_menu_scroll'),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- 1. Directory Hero Banner ---
                                _directoryBanner(c),
                                const SizedBox(height: 16),

                                // --- 2. Search Bar ---
                                searchBox(c),
                                const SizedBox(height: 16),

                                // --- 3. Quick Utility Dock ---
                                shortcuts(c),
                                const SizedBox(height: 24),

                                // --- 4. Section Header ---
                                Obx(() {
                                  final isSearching =
                                      c.query.value.trim().isNotEmpty;
                                  return Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: blue,
                                          borderRadius:
                                          BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          isSearching
                                              ? 'খোঁজার ফলাফল'
                                              : 'সেবার বিভাগসমূহ',
                                          style: text(
                                            19,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (isSearching)
                                        Padding(
                                          padding:
                                          const EdgeInsets.only(right: 8),
                                          child: InkWell(
                                            borderRadius:
                                            BorderRadius.circular(20),
                                            onTap: c.clearSearch,
                                            child: Padding(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              child: Text(
                                                'রিসেট',
                                                style: text(
                                                  12.5,
                                                  color: const Color(0xFFE11D48),
                                                  weight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: blue.withValues(alpha: 0.1),
                                          borderRadius:
                                          BorderRadius.circular(20),
                                          border: Border.all(
                                            color: blue.withValues(alpha: 0.15),
                                          ),
                                        ),
                                        child: Text(
                                          '${c.filteredCategories.length}টি বিভাগ',
                                          style: text(
                                            12,
                                            color: blue,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ),
                        ),

                        // --- 5. Categories Bento Grid ---
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 36),
                          sliver: SliverToBoxAdapter(
                            child: Obx(() {
                              final items = c.filteredCategories;

                              if (items.isEmpty) {
                                return _emptyState(c);
                              }

                              return LayoutBuilder(
                                builder: (context, box) {
                                  final largeText =
                                      MediaQuery.textScalerOf(context)
                                          .scale(14) >
                                          19;

                                  final columns = largeText
                                      ? 1
                                      : box.maxWidth >= 500
                                      ? 3
                                      : 2;

                                  final width =
                                      (box.maxWidth - (columns - 1) * 12) /
                                          columns;

                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      for (final category in items)
                                        SizedBox(
                                          width: width,
                                          child: categoryCard(
                                            category,
                                                () => c.openCategory(category),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Directory Top Banner ---
  Widget _directoryBanner(MenuController c) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            blueDark,
            blue,
            Color(0xFF088395),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: blueDark.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            top: -25,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
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
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ডিমলা সার্ভিস ডিরেক্টরি',
                          style: text(
                            11,
                            color: Colors.white,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'প্রয়োজনীয় সব সেবা,\nএখন হাতের মুঠোয়।',
                        style: text(
                          21,
                          color: Colors.white,
                          weight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'যেকোনো ক্যাটাগরি বেছে নিয়ে বিস্তারিত তথ্য ও যোগাযোগ দেখুন।',
                        style: text(
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
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
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

  // --- Floating Search Box ---
  Widget searchBox(MenuController c) {
    final defaultBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: border),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: blue.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Obx(
            () => TextField(
          controller: c.searchInput,
          onChanged: (value) => c.query.value = value,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          cursorColor: blue,
          style: text(14.5, weight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'সেবার বিভাগ খুঁজুন (যেমন: ডাক্তার, অটো, দোকান)...',
            hintStyle: text(13.5, color: muted, weight: FontWeight.w400),
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
                color: blue,
                size: 23,
              ),
            ),
            suffixIcon: c.query.value.isEmpty
                ? null
                : IconButton(
              tooltip: 'Search মুছুন',
              onPressed: c.clearSearch,
              icon: const Icon(
                Icons.close_rounded,
                color: muted,
                size: 20,
              ),
            ),
            border: defaultBorder,
            enabledBorder: defaultBorder,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: blue, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  // --- Quick Utility Dock (Saved, Settings, Help) ---
  Widget shortcuts(MenuController c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F1E36),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: shortcut(
                'সেভ করা',
                Icons.bookmark_rounded,
                const Color(0xFF7C3AED),
                c.openSaved,
              ),
            ),
            const VerticalDivider(
              width: 1,
              indent: 10,
              endIndent: 10,
              color: border,
            ),
            Expanded(
              child: shortcut(
                'সেটিংস',
                Icons.tune_rounded,
                blue,
                c.openSettings,
              ),
            ),
            const VerticalDivider(
              width: 1,
              indent: 10,
              endIndent: 10,
              color: border,
            ),
            Expanded(
              child: shortcut(
                'সাহায্য',
                Icons.support_agent_rounded,
                const Color(0xFF0D9488),
                c.openHelp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget shortcut(
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 10,
          ),
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
                style: text(12.5, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Modern Bento Category Card with Watermark ---
  Widget categoryCard(
      MenuCategory category,
      VoidCallback onTap,
      ) {
    final index = MenuController.categories.indexOf(category);
    final safeIndex = index < 0 ? 0 : index;
    final accent = accents[safeIndex % accents.length];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F1E36),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: accent.withValues(alpha: 0.1),
          highlightColor: accent.withValues(alpha: 0.04),
          child: Stack(
            children: [
              // Subtle Background Watermark Icon
              Positioned(
                right: -14,
                bottom: -14,
                child: Icon(
                  category.icon,
                  size: 76,
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
                    color: accent.withValues(alpha: 0.55),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 138),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent.withValues(alpha: 0.16),
                                accent.withValues(alpha: 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(
                            category.icon,
                            color: accent,
                            size: 25,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            shape: BoxShape.circle,
                            border: Border.all(color: border),
                          ),
                          child: Icon(
                            Icons.arrow_outward_rounded,
                            color: accent,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text(
                            15.5,
                            weight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'তালিকা দেখুন',
                          style: text(
                            11.5,
                            color: muted,
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
      ),
    );
  }

  // --- Empty Search State ---
  Widget _emptyState(MenuController c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 32,
              color: blue,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'কোনো বিভাগ পাওয়া যায়নি',
            style: text(
              18,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'অন্য কোনো নাম লিখে খুঁজুন অথবা সবগুলো বিভাগ দেখুন।',
            textAlign: TextAlign.center,
            style: text(13.5, color: muted),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: c.clearSearch,
            style: FilledButton.styleFrom(
              backgroundColor: blue.withValues(alpha: 0.1),
              foregroundColor: blue,
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
              style: text(
                13.5,
                color: blue,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}