import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenStore, this.onOpenMenu});

  final VoidCallback? onOpenStore;
  final VoidCallback? onOpenMenu;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const blue = Color(0xFF1959FF);
  static const navy = Color(0xFF111D38);
  static const muted = Color(0xFF788190);
  static const background = Color(0xFFFAFCFF);

  late final HomeController c;
  late final bool ownsController;

  bool imagePrepared = false;

  VoidCallback get store => widget.onOpenStore ?? c.openStore;
  VoidCallback get menu =>
      widget.onOpenMenu ?? () => c.openCategory('all');

  TextStyle text(
      double size, {
        Color color = navy,
        FontWeight weight = FontWeight.w500,
      }) {
    return GoogleFonts.hindSiliguri(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.35,
    );
  }

  @override
  void initState() {
    super.initState();

    ownsController = !Get.isRegistered<HomeController>();
    c = ownsController
        ? Get.put(HomeController())
        : Get.find<HomeController>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!imagePrepared) {
      imagePrepared = true;
      precacheImage(
        const AssetImage('assets/images/home_reference.png'),
        context,
        onError: (error, stackTrace) {},
      );
    }
  }

  @override
  void dispose() {
    if (ownsController &&
        Get.isRegistered<HomeController>() &&
        identical(Get.find<HomeController>(), c)) {
      Get.delete<HomeController>();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: RefreshIndicator(
              color: blue,
              onRefresh: c.refresh,
              child: ListView(
                key: const PageStorageKey('smooth_dimla_home'),
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                children: [
                  header(),
                  const SizedBox(height: 9),
                  Text(
                    'আপনার দিন, সহজ হোক।',
                    style: text(25, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 13),
                  searchField(),
                  const SizedBox(height: 12),
                  emergency(),
                  const SizedBox(height: 19),
                  servicePanel(),
                  const SizedBox(height: 15),
                  storePanel(),
                  const SizedBox(height: 18),
                  Text(
                    'ডিমলা আপডেট',
                    style: text(18, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  updates(),
                  const SizedBox(height: 13),
                  TextButton.icon(
                    onPressed: c.openSaved,
                    style: TextButton.styleFrom(
                      foregroundColor: blue,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.bookmark_border, size: 19),
                    label: Text(
                      'সেভ করা সেবা ও পণ্য',
                      style: text(13, color: blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget header() {
    return Row(
      children: [
        Expanded(child: logo(21)),
        Flexible(
          child: TextButton(
            onPressed: c.selectArea,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(48, 48),
              foregroundColor: blue,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 4),
                Flexible(
                  child: Obx(() {
                    final area = c.community.selectedArea.value;
                    return Text(
                      area == 'সব এলাকা' ? 'ডিমলা' : area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text(12),
                    );
                  }),
                ),
                const Icon(Icons.expand_more, size: 16),
              ],
            ),
          ),
        ),
        Obx(() {
          final count = c.community.unreadCount;

          return IconButton(
            tooltip: 'নোটিফিকেশন',
            onPressed: c.openNotifications,
            color: navy,
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text(count > 99 ? '99+' : '$count'),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 23,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget logo(double size, {bool shopping = false}) {
    return Text.rich(
      TextSpan(children: [
        const TextSpan(
          text: 'Hello ',
          style: TextStyle(color: navy),
        ),
        TextSpan(
          text: shopping ? 'Store' : 'Dimla',
          style: const TextStyle(color: blue),
        ),
      ]),
      style: GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
    );
  }

  Widget searchField() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    );

    return TextField(
      controller: c.searchInput,
      cursorColor: blue,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => search(),
      style: text(14),
      decoration: InputDecoration(
        hintText: 'সেবা বা পণ্য খুঁজুন',
        hintStyle: text(13, color: muted),
        fillColor: const Color(0xFFEDF2F8),
        filled: true,
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: navy,
          size: 21,
        ),
        suffixIcon: IconButton(
          tooltip: 'খুঁজুন',
          onPressed: search,
          icon: const Icon(
            Icons.arrow_forward_rounded,
            color: blue,
            size: 18,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 14,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: blue,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  void search() {
    FocusScope.of(context).unfocus();
    c.search();
  }

  Widget emergency() {
    return Material(
      color: const Color(0xFFFFE7EC),
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => c.openCategory('emergency'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: Color(0xFFF12C40),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'জরুরি সাহায্য',
                style: text(
                  16,
                  color: const Color(0xFFEF293C),
                  weight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFEF293C),
              size: 21,
            ),
          ]),
        ),
      ),
    );
  }

  Widget servicePanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText =
            MediaQuery.textScalerOf(context).scale(14) > 19;

        final artworkWidth = constraints.maxWidth * 0.36;

        return Stack(
          children: [
            if (!largeText)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: artworkWidth,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  child: const _ReferenceCrop(
                    // Ends before the shopping leaves begin.
                    source: Rect.fromLTWH(188, 173, 100, 167),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                right: largeText ? 0 : artworkWidth - 6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'সেবা খুঁজে নিন',
                    style: text(19, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ডিমলার আপনার প্রয়োজনীয় সেবা',
                    style: text(11, color: muted),
                  ),
                  const SizedBox(height: 8),
                  serviceRow(
                    'স্বাস্থ্য',
                    Icons.monitor_heart_rounded,
                        () => c.openCategory('health'),
                  ),
                  serviceRow(
                    'যাতায়াত',
                    Icons.directions_bus_rounded,
                        () => c.openCategory('local_transport'),
                  ),
                  serviceRow(
                    'দোকান',
                    Icons.storefront_rounded,
                        () => c.openCategory('local_shops'),
                  ),
                  serviceRow(
                    'সব সেবা',
                    Icons.grid_view_rounded,
                    menu,
                    last: true,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget serviceRow(
      String title,
      IconData icon,
      VoidCallback onTap, {
        bool last = false,
      }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 2,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: blue, size: 25),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title, style: text(16)),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: muted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!last)
          const Divider(
            height: 1,
            color: Color(0xFFE6ECF4),
          ),
      ],
    );
  }

  Widget storePanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText =
            MediaQuery.textScalerOf(context).scale(14) > 19;

        final artworkWidth = constraints.maxWidth * 0.43;

        return Material(
          color: const Color(0xFFECF4FF),
          borderRadius: BorderRadius.circular(23),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: store,
            child: Stack(
              children: [
                if (!largeText)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: artworkWidth,
                    child: const _ReferenceCrop(
                      source: Rect.fromLTWH(168, 344, 119, 112),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    18,
                    largeText ? 16 : artworkWidth,
                    17,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      logo(25, shopping: true),
                      const SizedBox(height: 5),
                      Text(
                        'দৈনন্দিন বাজার, এক জায়গায়',
                        style: text(12),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: store,
                        style: FilledButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'কেনাকাটা করুন',
                                style: text(
                                  13,
                                  color: Colors.white,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget updates() {
    return Obx(() {
      final data = c.community;

      if (data.updatesLoading.value) {
        return const Padding(
          padding: EdgeInsets.all(18),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: blue,
                strokeWidth: 2,
              ),
            ),
          ),
        );
      }

      if (data.updatesError.value.isNotEmpty) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(
            data.updatesError.value,
            style: text(13, color: muted),
          ),
          trailing: IconButton(
            tooltip: 'আবার চেষ্টা করুন',
            onPressed: () => c.refresh(),
            icon: const Icon(Icons.refresh_rounded, color: blue),
          ),
        );
      }

      if (data.updates.isEmpty) {
        return updateCard(
          'স্থানীয় ঘোষণা ও তথ্য',
          subtitle: 'নতুন ঘোষণা এলে এখানে দেখুন',
        );
      }

      return Column(
        children: [
          for (final update in data.updates.take(3))
            updateCard(
              update.title,
              subtitle: update.label.isEmpty ? null : update.label,
              onTap: () => c.openUpdate(update),
            ),
        ],
      );
    });
  }

  Widget updateCard(
      String title, {
        String? subtitle,
        VoidCallback? onTap,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: Color(0xFFE7EDF5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: const SizedBox(
                    width: 105,
                    height: 76,
                    child: _ReferenceCrop(
                      source: Rect.fromLTWH(34, 491, 116, 42),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text(14, weight: FontWeight.w600),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          style: text(11, color: muted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: navy,
                      size: 19,
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

/// Reuses the same cached asset without stretching its aspect ratio.
class _ReferenceCrop extends StatelessWidget {
  const _ReferenceCrop({required this.source});

  final Rect source;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: source.width,
              height: source.height,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: -source.left,
                    top: -source.top,
                    width: 309,
                    height: 548,
                    child: Image.asset(
                      'assets/images/home_reference.png',
                      width: 309,
                      height: 548,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, error, stackTrace) {
                        return const ColoredBox(
                          color: Color(0xFFECF4FF),
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: Color(0xFF1959FF),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}