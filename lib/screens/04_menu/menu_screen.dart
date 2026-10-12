import 'package:flutter/material.dart' hide MenuController;
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'menu_controller.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  static const blue = Color(0xFF1959FF);
  static const navy = Color(0xFF111D38);
  static const muted = Color(0xFF788190);

  static const accents = [
    Color(0xFF1959FF),
    Color(0xFF238064),
    Color(0xFFC17420),
    Color(0xFF8655B0),
    Color(0xFFD74661),
  ];

  TextStyle text(
      double size, {
        Color color = navy,
        FontWeight weight = FontWeight.w500,
      }) {
    return GoogleFonts.hindSiliguri(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: 1.4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MenuController>(
      init: MenuController(),
      builder: (c) {
        return Scaffold(
          backgroundColor: const Color(0xFFFAFCFF),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFFFAFCFF),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'সব সেবা',
              style: text(24, weight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                tooltip: 'নোটিফিকেশন',
                onPressed: c.openNotifications,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: navy,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CustomScrollView(
                key: const PageStorageKey('dimla_menu_scroll'),
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ডিমলার প্রয়োজনীয় সেবা, এক জায়গায়।',
                            style: text(14, color: muted),
                          ),
                          const SizedBox(height: 19),
                          searchBox(c),
                          const SizedBox(height: 18),
                          shortcuts(c),
                          const SizedBox(height: 23),
                          Obx(() => Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.query.value.trim().isEmpty
                                      ? 'সেবার বিভাগ'
                                      : 'খোঁজার ফলাফল',
                                  style: text(
                                    19,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEBF1FF),
                                  borderRadius:
                                  BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${c.filteredCategories.length}টি',
                                  style: text(
                                    12,
                                    color: blue,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          )),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                    sliver: SliverToBoxAdapter(
                      child: Obx(() {
                        final items = c.filteredCategories;

                        if (items.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.search_off_rounded,
                                  size: 38,
                                  color: muted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'কোনো বিভাগ পাওয়া যায়নি',
                                  style: text(
                                    17,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'অন্য নাম লিখে চেষ্টা করুন।',
                                  style: text(13, color: muted),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: c.clearSearch,
                                  child: Text(
                                    'সব বিভাগ দেখুন',
                                    style: text(13, color: blue),
                                  ),
                                ),
                              ],
                            ),
                          );
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
        );
      },
    );
  }

  Widget searchBox(MenuController c) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );

    return Obx(() => TextField(
      controller: c.searchInput,
      onChanged: (value) => c.query.value = value,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      cursorColor: blue,
      style: text(14),
      decoration: InputDecoration(
        hintText: 'সেবার বিভাগ খুঁজুন',
        hintStyle: text(13, color: muted),
        filled: true,
        fillColor: const Color(0xFFEDF2F8),
        contentPadding: const EdgeInsets.all(16),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: blue,
          size: 22,
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
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: blue),
        ),
      ),
    ));
  }

  Widget shortcuts(MenuController c) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE7EDF5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: shortcut(
              'সেভ করা',
              Icons.bookmark_border_rounded,
              c.openSaved,
            ),
          ),
          Expanded(
            child: shortcut(
              'Settings',
              Icons.tune_rounded,
              c.openSettings,
            ),
          ),
          Expanded(
            child: shortcut(
              'সাহায্য',
              Icons.help_outline_rounded,
              c.openHelp,
            ),
          ),
        ],
      ),
    );
  }

  Widget shortcut(
      String title,
      IconData icon,
      VoidCallback onTap,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 17,
          ),
          child: Column(
            children: [
              Icon(icon, color: blue, size: 25),
              const SizedBox(height: 7),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text(12, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget categoryCard(
      MenuCategory category,
      VoidCallback onTap,
      ) {
    final index = MenuController.categories.indexOf(category);
    final accent = accents[index % accents.length];

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE7EDF5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 137),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      category.icon,
                      color: accent,
                      size: 25,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_outward_rounded,
                    color: muted,
                    size: 17,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                category.title,
                style: text(15, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}