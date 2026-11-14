import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/service_api.dart';
import '../../data/models/community_models.dart';
import '../04_menu/menu_screen.dart';
import 'home_controller.dart';

const _blue = Color(0xFF1959E8);
const _ink = Color(0xFF0F1E36);
const _muted = Color(0xFF64748B);
const _bg = Color(0xFFF4F7FB);
const _border = Color(0xFFE2E8F0);
const _tile = Color(0xFFF8FAFC);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenStore, this.onOpenMenu});

  final VoidCallback? onOpenStore;
  final VoidCallback? onOpenMenu;

  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  late final HomeController c;
  late final bool owns;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    owns = !Get.isRegistered<HomeController>();
    c = owns ? Get.put(HomeController()) : Get.find<HomeController>();

    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted ||
          !TickerMode.of(context) ||
          ModalRoute.of(context)?.isCurrent == false ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      unawaited(c.refreshInBackground());
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    if (owns &&
        Get.isRegistered<HomeController>() &&
        identical(c, Get.find<HomeController>())) {
      Get.delete<HomeController>();
    }
    super.dispose();
  }

  void menu() {
    if (widget.onOpenMenu != null) {
      widget.onOpenMenu!();
    } else {
      Get.to(() => const MenuScreen());
    }
  }

  void store() => (widget.onOpenStore ?? c.openStore)();

  void search() {
    FocusScope.of(context).unfocus();
    c.search();
  }

  BorderRadius radius(double n) => BorderRadius.circular(n);

  Widget label(
      String text, {
        double size = 14,
        Color color = _ink,
        FontWeight weight = FontWeight.w400,
        int? lines,
      }) {
    return Text(
      text,
      maxLines: lines,
      overflow: lines == null ? null : TextOverflow.ellipsis,
      style: GoogleFonts.hindSiliguri(
        fontSize: size,
        height: 1.38,
        color: color,
        fontWeight: weight,
      ),
    );
  }

  Widget surface(Widget child, {Color color = Colors.white, double r = 22}) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: radius(r),
        side: const BorderSide(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget action(IconData icon, String tip, VoidCallback tap, {int count = 0}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: _border)),
      child: IconButton(
        tooltip: tip,
        onPressed: tap,
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          child: Icon(icon, color: _ink),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget Function()>[
      header,
      searchBox,
      hero,
      quick,
      shopping,
      news,
      saved,
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            for (final glow in [
              (Alignment.topRight, _blue),
              (Alignment.topLeft, const Color(0xFF0891B2)),
            ])
              Align(
                alignment: glow.$1,
                child: IgnorePointer(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [
                        glow.$2.withValues(alpha: .09),
                        glow.$2.withValues(alpha: 0),
                      ]),
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
                    onRefresh: c.refresh,
                    child: ListView.separated(
                      key: const PageStorageKey('hello_dimla_home_v2'),
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: sections.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 18),
                      itemBuilder: (_, index) => sections[index](),
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

  Widget header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: surface(
              InkWell(
                onTap: c.selectArea,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_on_rounded,
                        color: _blue, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Obx(() => label(
                        c.community.selectedArea.value,
                        weight: FontWeight.w700,
                        lines: 1,
                      )),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  ]),
                ),
              ),
              r: 30,
            ),
          ),
        ),
        action(Icons.bookmark_border_rounded, 'সেভ করা', c.openSaved),
        const SizedBox(width: 8),
        Obx(() => action(
          Icons.notifications_none_rounded,
          'নোটিফিকেশন',
          c.openNotifications,
          count: c.community.unreadCount,
        )),
      ]),
      const SizedBox(height: 10),
      Text.rich(
        const TextSpan(text: 'Hello ', children: [
          TextSpan(text: 'Dimla', style: TextStyle(color: _blue)),
        ]),
        style: GoogleFonts.poppins(
          fontSize: 28, fontWeight: FontWeight.w800,
          color: _ink, height: 1.15,
        ),
      ),
      const SizedBox(height: 4),
      label(
        'আপনার শহর, আপনার পাশে\nসেবা, কেনাকাটা আর দৈনন্দিন প্রয়োজন এক অ্যাপেই।',
        size: 13.5, color: _muted,
      ),
    ],
  );

  Widget searchBox() => surface(
    TextField(
      controller: c.searchInput,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => search(),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: 'ডাক্তার, অ্যাম্বুলেন্স, দোকান বা পণ্য খুঁজুন...',
        hintStyle: GoogleFonts.hindSiliguri(fontSize: 14, color: _muted),
        prefixIcon: const Icon(Icons.search, color: _blue),
        suffixIcon: Padding(
          padding: const EdgeInsets.all(5),
          child: IconButton.filled(
            onPressed: search,
            style: IconButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(borderRadius: radius(14)),
            ),
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
          ),
        ),
      ),
    ),
    r: 20,
  );

  Widget hero() => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: radius(26),
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF0F2D6B), _blue, Color(0xFF088395)],
      ),
      boxShadow: [
        BoxShadow(
          color: _blue.withValues(alpha: .2),
          blurRadius: 22, offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Stack(children: [
      for (final p in [(-35.0, -35.0), (30.0, 185.0)])
        Positioned(
          right: p.$1, top: p.$2,
          child: Container(
            width: 145, height: 145,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: radius(30),
                  ),
                  child: label('✨ আমাদের ডিমলা · ডিজিটাল সেবা',
                      color: Colors.white, size: 12),
                ),
              ),
              const Spacer(),
              const Icon(Icons.location_city_rounded,
                  color: Colors.white, size: 32),
            ]),
            const SizedBox(height: 18),
            label('প্রয়োজনের সবকিছু,\nএখন এক জায়গায়।',
                size: 26, color: Colors.white, weight: FontWeight.w700),
            const SizedBox(height: 6),
            label('আপনার এলাকার জরুরি সেবা, দোকানপাট ও যোগাযোগ খুঁজে নিন মুহূর্তেই।',
                color: const Color(0xFFDCEBFF), size: 13.5),
            const SizedBox(height: 18),
            Wrap(spacing: 10, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: menu,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: _blue,
                  shape: RoundedRectangleBorder(borderRadius: radius(14)),
                ),
                icon: const Icon(Icons.explore, size: 18),
                label: const Text('সব সেবা দেখুন'),
              ),
              OutlinedButton.icon(
                onPressed: store,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  shape: RoundedRectangleBorder(borderRadius: radius(14)),
                ),
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('হ্যালো স্টোর'),
              ),
            ]),
          ],
        ),
      ),
    ]),
  );

  Widget panel(String title, String subtitle, Widget body, {VoidCallback? more}) {
    return surface(Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 4, height: 22,
            decoration: BoxDecoration(color: _blue, borderRadius: radius(4)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              label(title, size: 18, weight: FontWeight.w700),
              label(subtitle, size: 12, color: _muted),
            ]),
          ),
          if (more != null)
            TextButton(
              onPressed: more,
              child: label('সব দেখুন ›', size: 12, color: _blue,
                  weight: FontWeight.w700),
            ),
        ]),
        const SizedBox(height: 16),
        body,
      ]),
    ));
  }

  Widget feed<T>(
      HomeFeed<T> data,
      String emptyText,
      Widget Function(List<T>) content, {
        bool grid = false,
      }) {
    return Obx(() {
      final rows = data.items.toList();
      final error = data.error.value;
      final loading = data.loading.value;

      if (loading && rows.isEmpty) {
        return grid
            ? const Row(children: [
          Expanded(child: SizedBox(height: 130, child: _Sweep())),
          SizedBox(width: 12),
          Expanded(child: SizedBox(height: 130, child: _Sweep())),
        ])
            : const SizedBox(height: 52, child: _Sweep());
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (error.isNotEmpty)
          TextButton.icon(
            onPressed: c.refresh,
            icon: const Icon(Icons.refresh),
            label: Text('$error আবার চেষ্টা করুন'),
          ),
        if (rows.isNotEmpty)
          content(rows)
        else if (error.isEmpty)
          surface(
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Icon(Icons.inbox_outlined, color: _muted),
                const SizedBox(height: 5),
                label(emptyText, size: 13, color: _muted),
              ]),
            ),
            color: _tile, r: 14,
          ),
      ]);
    });
  }

  Widget photo(String rawUrl, IconData fallbackIcon) {
    final fallback = ColoredBox(
      color: const Color(0xFFEBF1F9),
      child: Center(child: Icon(fallbackIcon, color: const Color(0xFF7894BB))),
    );

    final url = Uri.tryParse(rawUrl);
    if (url == null ||
        !{'http', 'https'}.contains(url.scheme) ||
        url.host.isEmpty) {
      return fallback;
    }

    return Image.network(
      url.toString(), fit: BoxFit.cover, cacheWidth: 480,
      frameBuilder: (_, child, frame, loaded) =>
      loaded || frame != null ? child : const _Sweep(),
      errorBuilder: (_, __, ___) => fallback,
    );
  }
  Widget quick() {
    const navy = Color(0xFF162947);
    const blue = Color(0xFF2157CA);

    const labels = <String, String>{
      'ambulance': 'অ্যাম্বুলেন্স',
      'ambulance service': 'অ্যাম্বুলেন্স',
      'blood donation': 'রক্তদান',
      'blood donations': 'রক্তদান',
      'blood donor': 'রক্তদাতা',
      'blood donors': 'রক্তদাতা',
      'doctor': 'ডাক্তার',
      'pharmacy': 'ফার্মেসি',
      'van': 'ভ্যান',
      'auto': 'অটো',
    };

    Widget tile({
      required String title,
      required String? imageUrl,
      required VoidCallback onTap,
    }) {
      final isBlood = title.contains('রক্ত');
      final accent = isBlood ? const Color(0xFFAE3650) : blue;
      final fallback = Icon(
        isBlood
            ? Icons.bloodtype_rounded
            : title.contains('অ্যাম্বুলেন্স')
            ? Icons.local_hospital_rounded
            : Icons.grid_view_rounded,
        color: accent,
        size: 28,
      );

      return Material(
        color: isBlood ? const Color(0xFFFFF6F7) : const Color(0xFFF3F7FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isBlood ? const Color(0xFFF2D9DE) : const Color(0xFFD9E5FA),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: imageUrl == null
                        ? fallback
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => fallback,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDFE7F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: blue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'দ্রুত সেবা',
                  style: TextStyle(
                    color: navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: menu,
                child: const Text(
                  'সব মেনু ›',
                  style: TextStyle(color: blue, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          feed(c.quick, 'এখনো কোনো সেবা যোগ করা হয়নি।', (rows) {
            return LayoutBuilder(
              builder: (context, box) {
                const gap = 8.0;
                final largeText =
                    MediaQuery.textScalerOf(context).scale(15) > 21;
                final width = largeText || box.maxWidth < 250
                    ? box.maxWidth
                    : (box.maxWidth - gap) / 2;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: rows.map<Widget>((m) {
                    final raw = homeText(m['title']).trim();
                    final title = labels[raw.toLowerCase()] ??
                        (raw.isEmpty ? 'স্থানীয় সেবা' : raw);

                    return SizedBox(
                      width: width,
                      child: tile(
                        title: title,
                        imageUrl: homeFlag(m['hasIcon'])
                            ? ServiceApi.menuIcon(
                          homeInt(m['id']),
                          revision: homeInt(m['rev']),
                        ).toString()
                            : null,
                        onTap: () => c.openMenu(m),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          }),
        ],
      ),
    );
  }
  Widget shopping() => panel(
    'Hello Store',
    'আপনার এলাকার কেনাকাটা',
    feed<RowData>(
      c.products,
      'এই এলাকায় এখনো কোনো পণ্য পাওয়া যাচ্ছে না।',
          (rows) => LayoutBuilder(builder: (context, bounds) {
        final columns = bounds.maxWidth < 260 ||
            MediaQuery.textScalerOf(context).scale(14) > 22
            ? 1
            : 2;
        final width = (bounds.maxWidth - (columns - 1) * 12) / columns;

        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final p in rows)
            SizedBox(
              key: ValueKey('home-product-${p['product']}'),
              width: width,
              child: product(p),
            ),
        ]);
      }),
      grid: true,
    ),
    more: store,
  );

  Widget product(RowData p) {
    final inStock = homeInt(p['stock']) > 0;
    final price = double.tryParse('${p['price']}');
    final pack = homeText(p['label']);

    return surface(
      InkWell(
        onTap: () => c.openProduct(p),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              AspectRatio(
                aspectRatio: 1.35,
                child: ClipRRect(
                  borderRadius: radius(14),
                  child: photo(homeText(p['photo']), Icons.shopping_bag_outlined),
                ),
              ),
              Positioned(
                top: 6, left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: inStock ? const Color(0xFF047857) : const Color(0xFFBE123C),
                    borderRadius: radius(12),
                  ),
                  child: label(inStock ? 'স্টকে আছে' : 'স্টক নেই',
                      size: 10, color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            label(homeText(p['name']), weight: FontWeight.w700, lines: 2),
            if (pack.isNotEmpty) label(pack, size: 12, color: _muted, lines: 1),
            Row(children: [
              Expanded(child: label(
                price == null || !price.isFinite
                    ? 'দাম দেওয়া নেই'
                    : moneyText((price * 100).round()),
                size: 17, weight: FontWeight.w700, color: _blue,
              )),
              const Icon(Icons.chevron_right, color: _blue),
            ]),
          ]),
        ),
      ),
      color: _tile, r: 18,
    );
  }

  Widget rowCard(String title, String sub, IconData icon, Color accent,
      VoidCallback open, {Color color = _tile}) {
    return surface(
      InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .1), borderRadius: radius(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label(title, size: 15, weight: FontWeight.w700, lines: 2),
                if (sub.isNotEmpty) label(sub, size: 12, color: _muted, lines: 2),
              ],
            )),
            const Icon(Icons.chevron_right_rounded, color: _blue),
          ]),
        ),
      ),
      color: color, r: 16,
    );
  }

  Widget news() => panel(
    'ডিমলার খবর ও ঘোষণা',
    'স্থানীয় আপডেট ও জরুরি নোটিশ',
    feed<LocalUpdate>(c.news, 'নতুন স্থানীয় ঘোষণা এলে এখানে দেখুন।',
            (rows) => Column(children: [
          for (final u in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: rowCard(
                u.title,
                [u.label, dateText(u.publishedAt)]
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                Icons.campaign_rounded,
                const Color(0xFFD97706),
                    () => c.openUpdate(u),
                color: const Color(0xFFFFFBEB),
              ),
            ),
        ])),
  );

  Widget saved() => rowCard(
    'আপনার সেভ করা তালিকা',
    'পছন্দের সেবা ও পণ্যগুলো এক জায়গায় দেখুন',
    Icons.bookmarks_rounded,
    const Color(0xFF7C3AED),
    c.openSaved,
    color: Colors.white,
  );
}

class _Sweep extends StatefulWidget {
  const _Sweep();

  @override
  State<_Sweep> createState() => _SweepState();
}

class _SweepState extends State<_Sweep> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context)) {
      controller.stop();
    } else if (!controller.isAnimating) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final x = -2 + controller.value * 4;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment(x - 1, -.2),
                end: Alignment(x + 1, .2),
                colors: const [
                  Color(0xFFE8EEF5),
                  Color(0xFFF9FBFE),
                  Color(0xFFE8EEF5),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}