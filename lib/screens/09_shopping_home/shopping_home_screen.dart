import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../commerce/shop_models.dart';
import '../../commerce/shop_service.dart';
import '../../commerce/shop_widgets.dart';
import '../10_product_details/product_details_screen.dart';
import '../11_cart/cart_screen.dart';
import '../13_my_orders/my_orders_screen.dart';

const _blue = Color(0xFF2253DC);
const _ink = Color(0xFF182743);
const _muted = Color(0xFF586980);
const _edge = Color(0xFFDFE6F1);
const _bold = TextStyle(color: _ink, fontWeight: FontWeight.w800);

class ShoppingHomeScreen extends StatefulWidget {
  const ShoppingHomeScreen({super.key});

  @override
  State<ShoppingHomeScreen> createState() => _StoreState();
}

class _StoreState extends State<ShoppingHomeScreen> {
  final shop = ShopService.instance;
  final search = TextEditingController();

  String? category;
  String query = '', sort = 'featured', loadError = '';
  bool inStock = false, refreshing = false, adding = false;
  double low = 0, high = double.infinity;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (refreshing) return;

    setState(() {
      refreshing = true;
      loadError = '';
    });

    try {
      await Future.wait([
        shop.loadLocal(),
        shop.saved.load(),
        shop.loadCatalog(),
      ]);
    } catch (e) {
      if (mounted) setState(() => loadError = ShopService.message(e));
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  void open(ShopProduct p) {
    FocusManager.instance.primaryFocus?.unfocus();
    Get.to(() => ProductDetailsScreen(productId: p.id));
  }

  void choose(String? id) {
    setState(() {
      category = id;
      search.clear();
      query = '';
      low = 0;
      high = double.infinity;
      inStock = false;
    });
  }

  Future<void> directory(
      Map<String, String> names,
      Map<String, String> parents,
      Map<String, int> counts,
      String? active,
      ) async {
    FocusManager.instance.primaryFocus?.unfocus();

    // null = sheet বন্ধ; খালি string = সব পণ্য।
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .68,
        child: Column(
          children: [
            Text('সব ক্যাটাগরি', style: _bold.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.apps_rounded),
                    title: const Text('সব পণ্য দেখুন'),
                    selected: active == null,
                    onTap: () => Navigator.pop(ctx, ''),
                  ),
                  for (final e in names.entries)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(e.value),
                      subtitle: names[parents[e.key]] == null
                          ? null
                          : Text(names[parents[e.key]]!),
                      trailing: Text('${counts[e.key] ?? 0}টি'),
                      selected: e.key == active,
                      onTap: () => Navigator.pop(ctx, e.key),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (mounted && result != null) {
      choose(result.isEmpty ? null : result);
    }
  }

  Future<void> filters() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final maximum = shop.products.fold<double>(
      1,
          (n, p) => math.max(n, p.preview.price / 100),
    ).ceilToDouble();

    var range = RangeValues(
      low.clamp(0, maximum).toDouble(),
      high.clamp(0, maximum).toDouble(),
    );
    var stock = inStock;
    var order = sort;

    final result = await shopSheet<String>(
      StatefulBuilder(
        builder: (ctx, change) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('পণ্য বাছাই', style: _bold),
            const SizedBox(height: 12),
            Text(
              'দাম: ${money((range.start * 100).round())}'
                  ' – ${money((range.end * 100).round())}',
            ),
            RangeSlider(
              values: range,
              max: maximum,
              onChanged: (v) => change(() => range = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('শুধু স্টকে থাকা পণ্য'),
              value: stock,
              onChanged: (v) => change(() => stock = v),
            ),
            DropdownButton<String>(
              isExpanded: true,
              value: order,
              items: const {
                'featured': 'নির্বাচিত',
                'new': 'নতুন আগে',
                'low': 'কম দাম আগে',
                'high': 'বেশি দাম আগে',
              }.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: (v) => change(() => order = v ?? order),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'apply'),
              child: const Text('ফলাফল দেখুন'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'clear'),
              child: const Text('ফিল্টার সরান'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      final clear = result == 'clear';
      low = clear ? 0 : range.start;
      high = clear || range.end == maximum ? double.infinity : range.end;
      sort = clear ? 'featured' : order;
      inStock = !clear && stock;
    });
  }

  Future<void> buy(ShopProduct p, ShopVariant pack) async {
    if (adding) return;

    if (p.choices.length > 1 ||
        !p.available ||
        !shop.localReady.value ||
        shop.busy.value ||
        shop.locked ||
        shop.config.value?.enabled != true) {
      open(p);
      return;
    }

    adding = true;
    try {
      final used = shop.cart
          .where((l) => l.productId == p.id && l.variantId == pack.id)
          .fold<int>(0, (n, l) => n + l.qty);

      final maximum = math.min(99, pack.stock) - used;
      if (maximum < 1) {
        throw StateError('এই প্যাকের উপলব্ধ পরিমাণ ইতিমধ্যে কার্টে আছে।');
      }

      var qty = 1;
      final count = await shopSheet<int>(
        StatefulBuilder(
          builder: (ctx, change) => Column(
            children: [
              Text(p.name, style: _bold),
              Text('${pack.unit} · ${money(pack.price)}'),
              const SizedBox(height: 12),
              QuantityControl(
                value: qty,
                max: maximum,
                onChanged: (n) => change(() => qty = n),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, qty),
                child: Text('কার্টে যোগ করুন · ${money(pack.price * qty)}'),
              ),
            ],
          ),
        ),
      );

      if (!mounted || count == null) return;
      if (shop.config.value?.enabled != true) {
        throw StateError('বর্তমানে অর্ডার নেওয়া বন্ধ।');
      }

      await shop.add(p, pack, count);
      if (mounted) {
        Get.snackbar('কার্টে যোগ হয়েছে', p.name,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      if (mounted) shopError(e);
    } finally {
      adding = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShopPage(
      title: 'Hello Store',
      actions: [
        IconButton(
          tooltip: 'আমার অর্ডার',
          icon: const Icon(Icons.receipt_long_outlined),
          onPressed: () => Get.to(() => const MyOrdersScreen()),
        ),
        Obx(() => IconButton(
          tooltip: 'কার্ট',
          onPressed: () => Get.to(() => const CartScreen()),
          icon: Badge(
            isLabelVisible: shop.units > 0,
            label: Text('${shop.units}'),
            child: const Icon(Icons.shopping_bag_outlined),
          ),
        )),
      ],
      body: Obx(() {
        final all = shop.products.toList();
        final cfg = shop.config.value;

        List<Map<String, dynamic>> meta(String key) =>
            ((cfg?.raw[key] as List?) ?? const []).map(object).toList();

        final names = <String, String>{};
        final parents = <String, String>{};
        final photos = <String, String>{};
        final counts = <String, int>{};
        final paths = <String, Set<String>>{};

        for (final c in meta('categories')) {
          final id = '${c['id']}';
          names[id] = '${c['name']}';
          parents[id] = '${c['parent_id'] ?? ''}';
        }

        Set<String> lineage(String id) {
          final keys = <String>{};
          while (id.isNotEmpty && keys.add(id)) {
            id = parents[id] ?? '';
          }
          return keys;
        }

        for (final p in all) {
          names.putIfAbsent(p.categoryId, () => p.categoryName);
          final path = paths.putIfAbsent(
            p.categoryId,
                () => lineage(p.categoryId),
          );
          for (final id in path) {
            counts[id] = (counts[id] ?? 0) + 1;
            if (p.image.isNotEmpty) photos.putIfAbsent(id, () => p.image);
          }
        }

        final active = names.containsKey(category) ? category : null;

        void showCategories() {
          directory(names, parents, counts, active);
        }

        // অ্যাডমিনের প্রকাশিত তাকগুলো প্রথম পছন্দ।
        final slides = <_Slide>[];
        final byId = {for (final p in all) p.id.split(':').last: p};
        final links = meta('shelfItems');

        for (final shelf in meta('shelves')) {
          final linked = links
              .where((x) => '${x['shelf_id']}' == '${shelf['id']}')
              .map((x) => byId['${x['product_id']}'])
              .whereType<ShopProduct>()
              .toList();

          final title = '${shelf['title'] ?? 'নির্বাচিত পণ্য'}';
          final banner = '${shelf['banner'] ?? ''}'.trim();
          final uri = Uri.tryParse(banner);
          final isPhoto = uri != null &&
              uri.hasAuthority &&
              ['https', 'http'].contains(uri.scheme);

          slides.add(_Slide(
            'দোকানের তাক',
            title,
            isPhoto || banner.isEmpty ? 'তাক দেখুন' : banner,
            isPhoto ? banner : linked.isEmpty ? '' : linked.first.image,
                () {
              shopSheet<void>(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: _bold),
                    if (linked.isEmpty)
                      const Text('এই এলাকায় এই তাকে কোনো পণ্য নেই।'),
                    for (final p in linked)
                      ListTile(
                        title: Text(p.name),
                        trailing: Text(money(p.preview.price)),
                        onTap: () {
                          Get.back();
                          open(p);
                        },
                      ),
                  ],
                ),
              );
            },
          ));
        }

        if (slides.isEmpty) {
          for (final p in all.take(4)) {
            slides.add(_Slide(
              'পণ্যের সংগ্রহ', p.name, money(p.preview.price),
              p.image, () => open(p),
            ));
          }
          slides.add(_Slide(
            'HELLO STORE', 'ক্যাটাগরি ধরে কেনাকাটা',
            'সব ক্যাটাগরি দেখুন', '', showCategories,
          ));
        }

        final rows = [for (final p in all) (p: p, v: p.preview)]
            .where((r) {
          final price = r.v.price / 100;
          return (active == null ||
              paths[r.p.categoryId]?.contains(active) == true) &&
              (!inStock || r.p.available) &&
              price >= low &&
              price <= high &&
              normalized('${r.p.name} ${r.p.categoryName} ${r.p.description}')
                  .contains(query);
        }).toList();

        int sequence(ShopProduct p) =>
            int.tryParse(p.id.split(':').last) ?? 0;

        rows.sort((a, b) {
          final n = switch (sort) {
            'low' => a.v.price.compareTo(b.v.price),
            'high' => b.v.price.compareTo(a.v.price),
            'new' => (b.p.createdAt?.millisecondsSinceEpoch ?? sequence(b.p))
                .compareTo(a.p.createdAt?.millisecondsSinceEpoch ?? sequence(a.p)),
            _ => (b.p.featured ? 1 : 0).compareTo(a.p.featured ? 1 : 0),
          };
          return n == 0 ? a.p.name.compareTo(b.p.name) : n;
        });

        final loading = shop.loading.value || refreshing;
        final error = shop.error.value.isEmpty ? loadError : shop.error.value;
        final ordering = cfg?.enabled == true;
        final cartReady =
            shop.localReady.value && !shop.busy.value && !shop.locked;
        final keys = <String?>[null, ...names.keys];
        final filtered =
            low > 0 || high.isFinite || inStock || sort != 'featured';

        return RefreshIndicator(
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: search,
                        onChanged: (s) => setState(() => query = normalized(s)),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'কোন পণ্যটি খুঁজছেন?',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: search.text.isEmpty ? null : IconButton(
                            tooltip: 'খোঁজা মুছুন',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              search.clear();
                              query = '';
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Carousel(
                        key: ValueKey(Object.hashAll(slides.map((s) => s.title))),
                        slides: slides,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => policies(cfg),
                          icon: const Icon(Icons.local_shipping_outlined, size: 16),
                          label: const Text('ডেলিভারি ও ফেরত'),
                        ),
                      ),
                      if (cfg != null && !ordering)
                        const Text(
                          'এখনও কোনো ডেলিভারি ইউনিয়ন চালু নেই।',
                          style: TextStyle(color: _muted),
                        ),
                      if (shop.localError.value.isNotEmpty)
                        Text(shop.localError.value),
                      if (shop.locked)
                        TextButton(
                          onPressed: () => Get.to(() => const CartScreen()),
                          child: const Text('আগের অর্ডারের অবস্থা দেখুন'),
                        ),
                      const SizedBox(height: 10),
                      const Text('ক্যাটাগরি', style: _bold),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final id in keys)
                              _Category(
                                title: id == null ? 'সব পণ্য' : names[id]!,
                                photo: photos[id] ?? '',
                                all: id == null,
                                selected: id == active,
                                tap: id == null ? showCategories : () => choose(id),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              active == null ? 'পণ্যের সংগ্রহ' : names[active]!,
                              style: _bold.copyWith(fontSize: 19),
                            ),
                          ),
                          Text('${rows.length}টি',
                              style: const TextStyle(color: _muted)),
                          IconButton(
                            tooltip: 'দাম, স্টক ও সাজানো',
                            onPressed: filters,
                            icon: Icon(Icons.tune_rounded,
                                color: filtered ? _blue : _muted),
                          ),
                        ],
                      ),
                      if (loading) const LinearProgressIndicator(minHeight: 2),
                      if (error.isNotEmpty) ...[
                        Text(error),
                        TextButton(
                          onPressed: loading ? null : refresh,
                          child: const Text('আবার চেষ্টা করুন'),
                        ),
                      ],
                      if (!loading && error.isEmpty && rows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(children: [
                            Text(active != null
                                ? 'এই বাছাইয়ে কোনো পণ্য নেই।'
                                : 'কোনো পণ্য পাওয়া যায়নি।'),
                            TextButton(
                              onPressed: showCategories,
                              child: const Text('সব ক্যাটাগরি দেখুন'),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                sliver: SliverLayoutBuilder(
                  builder: (ctx, constraints) {
                    final width = constraints.crossAxisExtent;
                    final largeText =
                        MediaQuery.textScalerOf(ctx).scale(14) > 20;
                    final cols = largeText || width < 272 ? 1
                        : width >= 840 ? 4 : width >= 580 ? 3 : 2;

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (ctx, row) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var col = 0; col < cols; col++) ...[
                                if (col > 0) const SizedBox(width: 10),
                                Expanded(
                                  child: Builder(builder: (_) {
                                    final i = row * cols + col;
                                    if (i >= rows.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final r = rows[i];
                                    return _Tile(
                                      p: r.p, v: r.v, shop: shop,
                                      ready: ordering && cartReady && r.p.available,
                                      open: () => open(r.p),
                                      buy: () => buy(r.p, r.v),
                                    );
                                  }),
                                ),
                              ],
                            ],
                          ),
                        ),
                        childCount: (rows.length / cols).ceil(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Slide {
  const _Slide(this.tag, this.title, this.caption, this.photo, this.tap);
  final String tag, title, caption, photo;
  final VoidCallback tap;
}

class _Carousel extends StatefulWidget {
  const _Carousel({super.key, required this.slides});
  final List<_Slide> slides;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  final pages = PageController();
  Timer? timer;
  int index = 0;
  bool touching = false;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          touching ||
          !pages.hasClients ||
          widget.slides.length < 2 ||
          !TickerMode.of(context) ||
          MediaQuery.disableAnimationsOf(context) ||
          ModalRoute.of(context)?.isCurrent == false ||
          pages.position.isScrollingNotifier.value) {
        return;
      }

      pages.animateToPage(
        (index + 1) % widget.slides.length,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tall = MediaQuery.textScalerOf(context).scale(14) > 19;

    return Column(
      children: [
        SizedBox(
          height: tall ? 160 : 108,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Listener(
              onPointerDown: (_) => touching = true,
              onPointerUp: (_) => touching = false,
              onPointerCancel: (_) => touching = false,
              child: PageView.builder(
                controller: pages,
                itemCount: widget.slides.length,
                onPageChanged: (v) => setState(() => index = v),
                itemBuilder: (_, i) {
                  final s = widget.slides[i];
                  const colors = [
                    Color(0xFF143C60),
                    Color(0xFF174F45),
                    Color(0xFF503753),
                  ];
                  return Material(
                    color: colors[i % colors.length],
                    child: InkWell(
                      onTap: s.tap,
                      child: Row(children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.tag, maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10, letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  s.title, maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _bold.copyWith(
                                      color: Colors.white, fontSize: 20),
                                ),
                                Text(
                                  s.caption, maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 94,
                          child: s.photo.isEmpty
                              ? const Icon(Icons.storefront_outlined,
                              color: Colors.white, size: 38)
                              : _Photo(s.photo),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.slides.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              '${index + 1} / ${widget.slides.length}',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _Category extends StatelessWidget {
  const _Category({
    required this.title, required this.photo, required this.all,
    required this.selected, required this.tap,
  });

  final String title, photo;
  final bool all, selected;
  final VoidCallback tap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 76,
        child: Column(children: [
          Container(
            width: 52, height: 52,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: Colors.white,
              border: Border.all(
                color: selected ? _blue : _edge,
                width: selected ? 2 : 1,
              ),
            ),
            child: ClipOval(
              child: all
                  ? const ColoredBox(
                color: Color(0xFFEAF0FF),
                child: Icon(Icons.grid_view_rounded,
                    color: _blue, size: 21),
              )
                  : _Photo(photo),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title.isEmpty ? 'অন্যান্য' : title,
            textAlign: TextAlign.center, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? _blue : _ink,
            ),
          ),
        ]),
      ),
    ),
  );
}

class _Photo extends StatelessWidget {
  const _Photo(this.url);
  final String url;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: Color(0xFFEDF1F7),
      child: Center(child: Icon(Icons.shopping_bag_outlined, color: _muted)),
    );

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority ||
        !['https', 'http'].contains(uri.scheme)) {
      return fallback;
    }

    return Image.network(
      url, width: double.infinity, height: double.infinity,
      fit: BoxFit.cover, cacheWidth: 520,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.p, required this.v, required this.ready,
    required this.open, required this.buy, required this.shop,
  });

  final ShopProduct p;
  final ShopVariant v;
  final bool ready;
  final VoidCallback open, buy;
  final ShopService shop;

  @override
  Widget build(BuildContext context) {
    final sale = v.originalPrice > v.price && v.price > 0;
    final percent = sale
        ? ((v.originalPrice - v.price) * 100 / v.originalPrice).floor()
        : 0;

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.25,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(onTap: open, child: _Photo(p.image)),
                if (percent > 0)
                  Positioned(
                    top: 8, left: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF9B3416),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        child: Text('−$percent%',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                Positioned(
                  top: 2, right: 2,
                  child: Obx(() {
                    final saved = shop.saved.productIds.contains(p.id);
                    return IconButton(
                      tooltip: saved ? 'সেভ সরান' : 'সেভ করুন',
                      onPressed: shop.saved.ready.value
                          ? () => guarded(() => shop.toggleSaved(p))
                          : null,
                      icon: CircleAvatar(
                        radius: 15, backgroundColor: Colors.white,
                        child: Icon(
                          saved ? Icons.favorite : Icons.favorite_border,
                          color: saved ? Colors.deepOrange : _ink, size: 17,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: _bold.copyWith(fontSize: 15)),
                  Text(
                    '${v.unit} · ${p.available ? 'স্টকে আছে' : 'স্টক শেষ'}',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(money(v.price), style: _bold.copyWith(fontSize: 17)),
                      if (sale)
                        Text(
                          money(v.originalPrice),
                          semanticsLabel: 'আগের দাম ${money(v.originalPrice)}',
                          style: const TextStyle(
                            color: _muted, fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                            decorationThickness: 2,
                            decorationColor: _muted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: ready ? buy : open,
            child: Text(!ready
                ? 'বিস্তারিত দেখুন'
                : p.choices.length > 1 ? 'প্যাক বাছুন' : 'কার্টে যোগ করুন'),
          ),
        ],
      ),
    );
  }
}