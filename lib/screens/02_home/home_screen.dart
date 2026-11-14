import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/service_api.dart';
import '../../data/models/community_models.dart';
import '../04_menu/menu_screen.dart';
import 'home_controller.dart';

const _blue = Color(0xff1959e8);
const _ink = Color(0xff0f1e36);
const _muted = Color(0xff64748b);
const _bg = Color(0xfff4f7fb);
const _border = Color(0xffe2e8f0);
const _tile = Color(0xfff8fafc);

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

      if (!c.quick.loading.value &&
          !c.services.loading.value &&
          !c.products.loading.value &&
          !c.news.loading.value) {
        unawaited(c.refresh());
      }
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
      String s, {
        double size = 14,
        Color color = _ink,
        FontWeight weight = FontWeight.w400,
        int? lines,
      }) => Text(
    s,
    maxLines: lines,
    overflow: lines == null ? null : TextOverflow.ellipsis,
    style: GoogleFonts.hindSiliguri(
      fontSize: size,
      height: 1.38,
      color: color,
      fontWeight: weight,
    ),
  );

  Widget surface(Widget child, {Color color = Colors.white, double r = 22}) =>
      Material(
        color: color,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius(r),
          side: const BorderSide(color: _border),
        ),
        child: child,
      );

  Widget iconTile(IconData icon, Color color) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: radius(14),
    ),
    child: Icon(icon, color: color),
  );

  Widget action(IconData icon, String tip, VoidCallback fn, {int count = 0}) =>
      Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: _border)),
        child: IconButton(
          tooltip: tip,
          onPressed: fn,
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: Icon(icon, color: _ink),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final list = ListView.builder(
      key: const PageStorageKey('hello_dimla_home_v2'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: 8,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: switch (i) {
          0 => header(),
          1 => searchBox(),
          2 => hero(),
          3 => quick(),
          4 => services(),
          5 => shopping(),
          6 => news(),
          _ => saved(),
        },
      ),
    );

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
              (Alignment.topLeft, const Color(0xff0891b2)),
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
                    onRefresh: c.refresh,
                    color: _blue,
                    child: list,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_on_rounded, color: _blue, size: 18),
                    const SizedBox(width: 6),
                    Flexible(child: Obx(() => label(
                      c.community.selectedArea.value,
                      weight: FontWeight.w700,
                      lines: 1,
                    ))),
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
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: _ink,
          height: 1.15,
        ),
      ),
      const SizedBox(height: 4),
      label(
        'আপনার শহর, আপনার পাশে\nসেবা, কেনাকাটা আর দৈনন্দিন প্রয়োজন এক অ্যাপেই।',
        size: 13.5,
        color: _muted,
      ),
    ],
  );

  Widget searchBox() => surface(
    TextField(
      controller: c.searchInput,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => search(),
      style: GoogleFonts.hindSiliguri(fontSize: 15, color: _ink),
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

  Widget hero() => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 350),
    builder: (_, value, child) => Opacity(opacity: value, child: child),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff0f2d6b), _blue, Color(0xff088395)],
        ),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: .20),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(children: [
        for (final p in [(-35.0, -35.0), (30.0, 185.0)])
          Positioned(
            right: p.$1,
            top: p.$2,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                fit: FlexFit.loose,
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: radius(30),
                  ),
                  child: label(
                    '✨  আমাদের ডিমলা · ডিজিটাল সেবা',
                    color: Colors.white,
                    size: 12,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.location_city_rounded, color: Colors.white, size: 32),
            ]),
            const SizedBox(height: 18),
            label('প্রয়োজনের সবকিছু,\nএখন এক জায়গায়।',
                size: 26, color: Colors.white, weight: FontWeight.w700),
            const SizedBox(height: 6),
            label('আপনার এলাকার জরুরি সেবা, দোকানপাট ও যোগাযোগ খুঁজে নিন মুহূর্তেই।',
                color: const Color(0xffdcebff), size: 13.5),
            const SizedBox(height: 18),
            Wrap(spacing: 10, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: menu,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _blue,
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
          ]),
        ),
      ]),
    ),
  );

  Widget panel(
      String title,
      String subtitle,
      Widget body, {
        VoidCallback? more,
      }) => surface(
    Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            height: 22,
            width: 4,
            decoration: BoxDecoration(color: _blue, borderRadius: radius(4)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label(title, size: 18, weight: FontWeight.w700),
            label(subtitle, size: 12, color: _muted),
          ])),
          if (more != null)
            TextButton(
              onPressed: more,
              style: TextButton.styleFrom(backgroundColor: _blue.withValues(alpha: .07)),
              child: label('সব দেখুন  ›', size: 12, color: _blue, weight: FontWeight.w700),
            ),
        ]),
        const SizedBox(height: 16),
        body,
      ]),
    ),
  );

  Widget feed<T>(
      HomeFeed<T> data,
      String empty,
      Widget Function(List<T>) cards, {
        bool grid = false,
      }) => Obx(() {
    final items = data.items.toList();
    final loading = data.loading.value;
    final error = data.error.value;

    if (items.isEmpty && loading) return _Skeleton(grid: grid);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (error.isNotEmpty)
        TextButton.icon(
          onPressed: c.refresh,
          icon: const Icon(Icons.refresh),
          label: Text('$error · আবার চেষ্টা করুন'),
        ),
      if (items.isNotEmpty)
        cards(items)
      else if (error.isEmpty)
        surface(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Icon(Icons.inbox_outlined, color: _muted),
              const SizedBox(height: 5),
              label(empty, size: 13, color: _muted),
            ]),
          ),
          color: _tile,
          r: 14,
        ),
    ]);
  });

  Widget quick() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: label('দ্রুত সেবা', size: 18, weight: FontWeight.w700)),
          TextButton(onPressed: menu, child: const Text('সব মেনু')),
        ]),
        feed(c.quick, 'প্রকাশিত মেনু নেই।', (rows) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in rows)
              ActionChip(
                onPressed: () => c.openMenu(m),
                label: Text(homeText(m['title'])),
                avatar: homeFlag(m['hasIcon'])
                    ? photo(
                  ServiceApi.menuIcon(
                    homeInt(m['id']),
                    revision: homeInt(m['rev']),
                  ).toString(),
                  Icons.grid_view_rounded,
                )
                    : const Icon(Icons.grid_view_rounded, color: _blue, size: 20),
              ),
          ],
        )),
      ]),
    ),
  );

  Widget photo(String url, IconData icon) {
    final fallback = ColoredBox(
      color: const Color(0xffebf1f9),
      child: Center(child: Icon(icon, color: const Color(0xff7894bb))),
    );

    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      return fallback;
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 480,
      frameBuilder: (_, child, frame, synchronous) =>
      synchronous || frame != null ? child : const _Sweep(),
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget rowCard(
      String title,
      String subtitle,
      Widget image,
      VoidCallback open, {
        Color color = _tile,
      }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: surface(
      InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ClipRRect(
              borderRadius: radius(14),
              child: SizedBox(width: 58, height: 58, child: image),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              label(title, size: 15, weight: FontWeight.w700, lines: 2),
              if (subtitle.isNotEmpty) label(subtitle, size: 12, color: _muted, lines: 2),
            ])),
            const SizedBox(width: 6),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Icon(Icons.chevron_right, color: _blue, size: 20),
            ),
          ]),
        ),
      ),
      color: color,
      r: 16,
    ),
  );

  Widget services() => panel(
    'স্থানীয় সেবা',
    'আপনার এলাকার নির্ভরযোগ্য সেবাসমূহ',
    feed(c.services, 'এই ইউনিয়নে এখনো কোনো সেবা প্রকাশিত হয়নি।',
            (rows) => Column(children: [
          for (final row in rows)
            rowCard(
              homeText(row['name']),
              [homeText(row['_menu']['title']), c.serviceArea(row)]
                  .where((s) => s.isNotEmpty).join('\n'),
              photo(c.photo(row), Icons.storefront_rounded),
                  () => c.openService(row),
            ),
        ])),
    more: menu,
  );

  Widget shopping() => panel(
    'Hello Store',
    'নিত্যপ্রয়োজনীয় পণ্য অর্ডার করুন ঘরে বসে',
    Column(children: [
      rowCard(
        'আপনার কেনাকাটার ঠিকানা',
        'Hello Dimla-র নিজস্ব অনলাইন স্টোর',
        iconTile(Icons.shopping_bag_rounded, _blue),
        store,
        color: const Color(0xffeaf3ff),
      ),
      feed(c.products, 'এই নির্বাচনে কোনো প্রকাশিত পণ্য নেই।', (rows) =>
          LayoutBuilder(builder: (context, box) {
            final columns = box.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(14) > 22
                ? 1 : 2;
            final width = (box.maxWidth - (columns - 1) * 12) / columns;

            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final p in rows) SizedBox(width: width, child: product(p)),
            ]);
          }), grid: true),
    ]),
    more: store,
  );

  Widget product(RowData p) {
    final inStock = homeInt(p['stock']) > 0;
    final price = double.tryParse('${p['price']}');

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
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: inStock ? const Color(0xff059669) : const Color(0xffe11d48),
                    borderRadius: radius(12),
                  ),
                  child: label(inStock ? 'স্টকে আছে' : 'স্টক নেই',
                      size: 10, color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            label(homeText(p['name']), weight: FontWeight.w700, lines: 2),
            label(homeText(p['label']), size: 12, color: _muted, lines: 1),
            Row(children: [
              Expanded(child: label(
                price == null ? 'দাম দেওয়া নেই' : moneyText((price * 100).round()),
                size: 17, weight: FontWeight.w700, color: _blue,
              )),
              const Icon(Icons.chevron_right, color: _blue),
            ]),
          ]),
        ),
      ),
      color: _tile,
      r: 18,
    );
  }

  Widget news() => panel(
    'ডিমলার খবর ও ঘোষণা',
    'স্থানীয় আপডেট ও জরুরি নোটিশ',
    feed(c.news, 'নতুন স্থানীয় ঘোষণা এলে এখানে দেখুন।',
            (rows) => Column(children: [
          for (final u in rows)
            rowCard(
              u.title,
              [u.label, dateText(u.publishedAt)]
                  .where((s) => s.isNotEmpty).join(' · '),
              iconTile(Icons.campaign_rounded, const Color(0xffd97706)),
                  () => c.openUpdate(u),
              color: const Color(0xfffffbeb),
            ),
        ])),
  );

  Widget saved() => rowCard(
    'আপনার সেভ করা তালিকা',
    'পছন্দের সেবা ও পণ্যগুলো এক জায়গায় দেখুন',
    iconTile(Icons.bookmarks_rounded, const Color(0xff7c3aed)),
    c.openSaved,
    color: Colors.white,
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({this.grid = false});

  final bool grid;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'লোড হচ্ছে',
    child: ExcludeSemantics(
      child: grid
          ? const Row(children: [
        Expanded(child: SizedBox(height: 128, child: _Sweep())),
        SizedBox(width: 12),
        Expanded(child: SizedBox(height: 128, child: _Sweep())),
      ])
          : const Column(children: [
        SizedBox(height: 52, width: double.infinity, child: _Sweep()),
        SizedBox(height: 8),
        SizedBox(height: 52, width: double.infinity, child: _Sweep()),
      ]),
    ),
  );
}

class _Sweep extends StatefulWidget {
  const _Sweep();

  @override
  State<_Sweep> createState() => _SweepState();
}

class _SweepState extends State<_Sweep> with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context)) {
      animation.stop();
    } else if (!animation.isAnimating) {
      animation.repeat();
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final x = -2 + animation.value * 4;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(x - 1, -.2),
              end: Alignment(x + 1, .2),
              colors: const [
                Color(0xffe8eef5),
                Color(0xfff9fbfe),
                Color(0xffe8eef5),
              ],
            ),
          ),
        );
      },
    ),
  );
}