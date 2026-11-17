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

const _ink = Color(0xFF152840);
const _muted = Color(0xFF566981);
const _blue = Color(0xFF2154C2);
const _edge = Color(0xFFDCE5F1);
const _pale = Color(0xFFEDF3FF);
const _bold = TextStyle(color: _ink, fontWeight: FontWeight.w800);

String _s(dynamic v) => v == null ? '' : '$v'.trim();

bool _imageUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.host.isNotEmpty &&
      (uri.scheme == 'https' || uri.scheme == 'http');
}

class ShoppingHomeScreen extends StatefulWidget {
  const ShoppingHomeScreen({super.key});

  @override
  State<ShoppingHomeScreen> createState() => _ShoppingHomeScreenState();
}

class _ShoppingHomeScreenState extends State<ShoppingHomeScreen> {
  final shop = ShopService.instance;
  final search = TextEditingController();

  String query = '';
  String? category;
  String sort = 'featured';
  String localError = '';
  bool stockOnly = false;
  bool refreshing = false;
  bool adding = false;
  double low = 0;
  double high = double.infinity;

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
      localError = '';
    });
    try {
      await Future.wait([
        shop.loadLocal(),
        shop.saved.load(),
        shop.loadCatalog(),
      ]);
    } catch (e) {
      if (mounted) setState(() => localError = ShopService.message(e));
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  void openProduct(ShopProduct product) {
    FocusManager.instance.primaryFocus?.unfocus();
    Get.to(() => ProductDetailsScreen(productId: product.id));
  }

  void selectCategory(String? id) {
    setState(() {
      category = id;
      search.clear();
      query = '';
      low = 0;
      high = double.infinity;
      stockOnly = false;
    });
  }

  Future<void> openDirectory({
    required Map<String, String> names,
    required Map<String, String> parents,
    required Map<String, String> icons,
    required Map<String, int> counts,
    required String? active,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final entries = names.entries.toList();

    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .70,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Text('সব ক্যাটাগরি', style: _bold.copyWith(fontSize: 21)),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: entries.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final all = i == 0;
                  final id = all ? '' : entries[i - 1].key;
                  final parent = parents[id];
                  final parentName = parent == null ? null : names[parent];
                  final chosen = all ? active == null : active == id;

                  return ListTile(
                    selected: chosen,
                    selectedTileColor: _pale,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: _CategoryIcon(
                      photo: icons[id] ?? '',
                      all: all,
                      size: 44,
                    ),
                    title: Text(all ? 'সব পণ্য দেখুন' : names[id]!),
                    subtitle: all
                        ? null
                        : Text([
                      if (parentName != null) parentName,
                      '${counts[id] ?? 0}টি পণ্য',
                    ].join(' · ')),
                    trailing: Icon(
                      chosen ? Icons.check_circle : Icons.chevron_right,
                      color: chosen ? _blue : _muted,
                    ),
                    onTap: () => Navigator.pop(ctx, id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (mounted && result != null) {
      selectCategory(result.isEmpty ? null : result);
    }
  }

  Future<void> openFilters() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final ceiling = shop.products
        .fold<double>(1, (n, p) => math.max(n, p.preview.price / 100))
        .ceilToDouble();

    var range = RangeValues(
      low.clamp(0, ceiling).toDouble(),
      high.clamp(0, ceiling).toDouble(),
    );
    var stock = stockOnly;
    var order = sort;

    final result = await shopSheet<String>(
      StatefulBuilder(
        builder: (ctx, change) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('পণ্য বাছাই', style: _bold.copyWith(fontSize: 20)),
            const SizedBox(height: 12),
            Text(
              'দাম: ${money((range.start * 100).round())}'
                  ' – ${money((range.end * 100).round())}',
            ),
            RangeSlider(
              values: range,
              max: ceiling,
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
                'featured': 'নির্বাচিত পণ্য আগে',
                'new': 'নতুন পণ্য আগে',
                'low': 'কম দাম আগে',
                'high': 'বেশি দাম আগে',
              }.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: (v) => change(() => order = v ?? order),
            ),
            const SizedBox(height: 12),
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
    final clear = result == 'clear';
    setState(() {
      low = clear ? 0 : range.start;
      high = clear || range.end == ceiling ? double.infinity : range.end;
      stockOnly = !clear && stock;
      sort = clear ? 'featured' : order;
    });
  }

  Future<void> buy(ShopProduct p) async {
    if (adding) return;
    if (p.choices.length > 1 ||
        !p.available ||
        !shop.localReady.value ||
        shop.busy.value ||
        shop.locked ||
        shop.config.value?.enabled != true) {
      openProduct(p);
      return;
    }

    final v = p.preview;
    adding = true;
    try {
      final used = shop.cart
          .where((line) => line.productId == p.id && line.variantId == v.id)
          .fold<int>(0, (n, line) => n + line.qty);
      final maxQty = math.min(99, v.stock) - used;
      if (maxQty < 1) {
        throw StateError('এই প্যাকের উপলব্ধ পরিমাণ ইতিমধ্যে কার্টে আছে।');
      }

      var qty = 1;
      final count = await shopSheet<int>(
        StatefulBuilder(
          builder: (ctx, change) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.name, style: _bold.copyWith(fontSize: 19)),
              Text('${v.unit} · ${money(v.price)}'),
              const SizedBox(height: 12),
              QuantityControl(
                value: qty,
                max: maxQty,
                onChanged: (n) => change(() => qty = n),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, qty),
                child: Text('কার্টে যোগ করুন · ${money(v.price * qty)}'),
              ),
            ],
          ),
        ),
      );

      if (!mounted || count == null) return;
      if (shop.config.value?.enabled != true) {
        throw StateError('বর্তমানে অর্ডার নেওয়া বন্ধ আছে।');
      }
      await shop.add(p, v, count);
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

  Future<void> openShelf(_Shelf shelf) async {
    final selected = await showModalBottomSheet<ShopProduct>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .60,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Text(shelf.title, style: _bold.copyWith(fontSize: 20)),
            ),
            Expanded(
              child: shelf.products.isEmpty
                  ? const Center(child: Text('এই তাকে আপনার এলাকার কোনো পণ্য নেই।'))
                  : ListView.builder(
                itemCount: shelf.products.length,
                itemBuilder: (_, i) {
                  final p = shelf.products[i];
                  return ListTile(
                    leading: SizedBox.square(
                      dimension: 46,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _Photo(p.image),
                      ),
                    ),
                    title: Text(p.name),
                    subtitle: Text(money(p.preview.price)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(ctx, p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted && selected != null) openProduct(selected);
  }

  @override
  Widget build(BuildContext context) {
    return ShopPage(
      title: 'Hello Store',
      actions: [
        IconButton(
          tooltip: 'আমার অর্ডার',
          onPressed: () => Get.to(() => const MyOrdersScreen()),
          icon: const Icon(Icons.receipt_long_outlined),
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
        final products = shop.products.toList();
        final cfg = shop.config.value;
        List<Map<String, dynamic>> meta(String key) =>
            ((cfg?.raw[key] as List?) ?? const []).map(object).toList();

        final names = <String, String>{};
        final parents = <String, String>{};
        final icons = <String, String>{};
        final counts = <String, int>{};

        for (final c in meta('categories')) {
          final id = _s(c['id']);
          if (id.isEmpty) continue;
          names[id] = _s(c['name']);
          parents[id] = _s(c['parent_id']);
          icons[id] = _s(c['icon_url']);
        }

        Set<String> lineage(String id) {
          final path = <String>{};
          while (id.isNotEmpty && path.add(id)) {
            id = parents[id] ?? '';
          }
          return path;
        }

        final paths = <String, Set<String>>{};
        for (final p in products) {
          names.putIfAbsent(p.categoryId, () => p.categoryName);
          final path = paths.putIfAbsent(
            p.categoryId, () => lineage(p.categoryId),
          );
          for (final id in path) {
            counts[id] = (counts[id] ?? 0) + 1;
          }
        }

        final byId = {for (final p in products) p.id.split(':').last: p};
        final linked = <String, List<ShopProduct>>{};
        for (final link in meta('shelfItems')) {
          final product = byId[_s(link['product_id'])];
          if (product != null) {
            linked.putIfAbsent(_s(link['shelf_id']), () => []).add(product);
          }
        }

        final shelves = <_Shelf>[];
        for (final row in meta('shelves')) {
          final url = _s(row['banner']);
          final id = _s(row['id']);
          if (id.isEmpty || !_imageUrl(url)) continue;
          final name = _s(row['title']);
          shelves.add(_Shelf(
            id, name.isEmpty ? 'নির্বাচিত পণ্য' : name, url,
            linked[id] ?? const <ShopProduct>[],
          ));
        }

        final active = names.containsKey(category) ? category : null;
        final shown = products.where((p) {
          final price = p.preview.price / 100;
          return (active == null || paths[p.categoryId]?.contains(active) == true) &&
              (!stockOnly || p.available) &&
              price >= low &&
              price <= high &&
              normalized('${p.name} ${p.categoryName} ${p.description}')
                  .contains(query);
        }).toList();

        int sequence(ShopProduct p) =>
            p.createdAt?.millisecondsSinceEpoch ??
                int.tryParse(p.id.split(':').last) ?? 0;

        shown.sort((a, b) {
          final n = switch (sort) {
            'low' => a.preview.price.compareTo(b.preview.price),
            'high' => b.preview.price.compareTo(a.preview.price),
            'new' => sequence(b).compareTo(sequence(a)),
            _ => (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0),
          };
          return n == 0 ? a.name.compareTo(b.name) : n;
        });

        final loading = refreshing || shop.loading.value;
        final error = shop.error.value.isEmpty ? localError : shop.error.value;
        final enabled = cfg?.enabled == true;
        final ready = enabled && shop.localReady.value &&
            !shop.busy.value && !shop.locked;

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
                        textInputAction: TextInputAction.search,
                        onChanged: (v) => setState(() => query = normalized(v)),
                        decoration: InputDecoration(
                          hintText: 'কোন পণ্যটি খুঁজছেন?',
                          prefixIcon: const Icon(Icons.search_rounded),
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
                      if (shelves.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _CoverSlider(
                          key: ValueKey(shelves.map((s) => s.id).join(',')),
                          items: shelves,
                          onTap: openShelf,
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => policies(cfg),
                          icon: const Icon(Icons.local_shipping_outlined, size: 17),
                          label: const Text('ডেলিভারি ও ফেরত'),
                        ),
                      ),
                      if (cfg != null && !enabled)
                        const Text('এখনও কোনো ডেলিভারি ইউনিয়ন চালু নেই।'),
                      if (shop.localError.value.isNotEmpty)
                        Text(shop.localError.value),
                      if (shop.locked)
                        TextButton(
                          onPressed: () => Get.to(() => const CartScreen()),
                          child: const Text('আগের অর্ডারের অবস্থা দেখুন'),
                        ),
                      Text('ক্যাটাগরি', style: _bold.copyWith(fontSize: 18)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _CategoryChip(
                              title: 'সব পণ্য',
                              photo: '',
                              all: true,
                              active: active == null,
                              tap: () => openDirectory(
                                names: names, parents: parents, icons: icons,
                                counts: counts, active: active,
                              ),
                            ),
                            for (final e in names.entries)
                              _CategoryChip(
                                title: e.value,
                                photo: icons[e.key] ?? '',
                                all: false,
                                active: active == e.key,
                                tap: () => selectCategory(e.key),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: Text(
                            active == null ? 'পণ্যের সংগ্রহ' : names[active]!,
                            style: _bold.copyWith(fontSize: 19),
                          )),
                          Text('${shown.length}টি'),
                          IconButton(
                            tooltip: 'দাম, স্টক ও সাজানো',
                            onPressed: openFilters,
                            icon: const Icon(Icons.tune_rounded),
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
                      if (!loading && error.isEmpty && shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          child: Column(children: [
                            Text(products.isEmpty
                                ? 'এখনো কোনো পণ্য প্রকাশ করা হয়নি।'
                                : 'এই বাছাইয়ে কোনো পণ্য পাওয়া যায়নি।'),
                            if (products.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  selectCategory(null);
                                  setState(() => sort = 'featured');
                                },
                                child: const Text('সব পণ্য দেখুন'),
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
                  builder: (ctx, bounds) {
                    final w = bounds.crossAxisExtent;
                    final cols = w < 270 ||
                        MediaQuery.textScalerOf(ctx).scale(15) > 22
                        ? 1 : w >= 840 ? 4 : w >= 580 ? 3 : 2;

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (_, row) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int col = 0; col < cols; col++) ...[
                                if (col > 0) const SizedBox(width: 10),
                                Expanded(
                                  child: Builder(builder: (_) {
                                    final i = row * cols + col;
                                    if (i >= shown.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final p = shown[i];
                                    return _ProductTile(
                                      p: p, shop: shop,
                                      ready: ready && p.available,
                                      open: () => openProduct(p),
                                      buy: () => buy(p),
                                    );
                                  }),
                                ),
                              ],
                            ],
                          ),
                        ),
                        childCount: (shown.length / cols).ceil(),
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

class _Shelf {
  const _Shelf(this.id, this.title, this.photo, this.products);
  final String id, title, photo;
  final List<ShopProduct> products;
}

class _CoverSlider extends StatefulWidget {
  const _CoverSlider({
    super.key, required this.items, required this.onTap,
  });

  final List<_Shelf> items;
  final ValueChanged<_Shelf> onTap;

  @override
  State<_CoverSlider> createState() => _CoverSliderState();
}

class _CoverSliderState extends State<_CoverSlider> {
  final pages = PageController();
  Timer? timer;
  int index = 0;
  bool touching = false;

  @override
  void initState() {
    super.initState();
    if (widget.items.length < 2) return;

    timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || touching || !pages.hasClients ||
          !TickerMode.of(context) ||
          MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.accessibleNavigationOf(context) ||
          ModalRoute.of(context)?.isCurrent == false ||
          pages.position.isScrollingNotifier.value) return;

      pages.animateToPage(
        (index + 1) % widget.items.length,
        duration: const Duration(milliseconds: 350),
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
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 2.5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Listener(
              onPointerDown: (_) => touching = true,
              onPointerUp: (_) => touching = false,
              onPointerCancel: (_) => touching = false,
              child: PageView.builder(
                controller: pages,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => index = i),
                itemBuilder: (_, i) {
                  final shelf = widget.items[i];
                  return Semantics(
                    button: true,
                    label: '${shelf.title}। পণ্য দেখুন',
                    child: GestureDetector(
                      onTap: () => widget.onTap(shelf),
                      child: Image.network(
                        shelf.photo,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: const Color(0xFF183B62),
                          child: Center(child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              shelf.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          )),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.items.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text('${index + 1} / ${widget.items.length}',
                style: const TextStyle(color: _muted, fontSize: 12)),
          ),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo(this.url, {
    this.fit = BoxFit.cover,
    this.fallback = Icons.shopping_bag_outlined,
  });
  final String url;
  final BoxFit fit;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final missing = ColoredBox(
      color: const Color(0xFFF1F5FA),
      child: Center(child: Icon(fallback, color: _muted, size: 22)),
    );
    if (!_imageUrl(url)) return missing;
    return Image.network(
      url, width: double.infinity, height: double.infinity,
      fit: fit, cacheWidth: 480, excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => missing,
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({
    required this.photo, required this.all, required this.size,
  });
  final String photo;
  final bool all;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: size,
        child: all
            ? const ColoredBox(
          color: _pale,
          child: Icon(Icons.grid_view_rounded, size: 23, color: _blue),
        )
            : _Photo(photo, fit: BoxFit.contain, fallback: Icons.category_outlined),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.title, required this.photo, required this.all,
    required this.active, required this.tap,
  });
  final String title, photo;
  final bool all, active;
  final VoidCallback tap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: active ? _pale : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: active ? _blue : _edge),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, maxWidth: 180),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _CategoryIcon(photo: photo, all: all, size: 32),
                const SizedBox(width: 7),
                Flexible(child: Text(
                  title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: active ? _blue : _ink,
                      fontWeight: FontWeight.w700),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.p, required this.shop, required this.ready,
    required this.open, required this.buy,
  });
  final ShopProduct p;
  final ShopService shop;
  final bool ready;
  final VoidCallback open, buy;

  @override
  Widget build(BuildContext context) {
    final v = p.preview;
    final sale = v.originalPrice > v.price;
    final discount =
    sale ? ((v.originalPrice - v.price) * 100 / v.originalPrice).floor() : 0;

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
            child: Stack(fit: StackFit.expand, children: [
              GestureDetector(
                onTap: open,
                child: _Photo(p.image),
              ),
              if (discount > 0)
                Positioned(
                  top: 7, left: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFA13C1A),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Text('$discount% ছাড়',
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                ),
              Positioned(
                top: 0, right: 0,
                child: Obx(() {
                  final saved = shop.saved.productIds.contains(p.id);
                  return IconButton(
                    tooltip: saved ? 'পছন্দ থেকে সরান' : 'পছন্দে রাখুন',
                    onPressed: shop.saved.ready.value
                        ? () => guarded(() => shop.toggleSaved(p)) : null,
                    icon: CircleAvatar(
                      radius: 15, backgroundColor: Colors.white,
                      child: Icon(saved ? Icons.favorite : Icons.favorite_border,
                          size: 17, color: saved ? Colors.red : _ink),
                    ),
                  );
                }),
              ),
            ]),
          ),
          InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: _bold.copyWith(fontSize: 15)),
                  Text('${v.unit} · ${p.available ? 'স্টকে আছে' : 'স্টক শেষ'}',
                      style: const TextStyle(color: _muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(money(v.price), style: _bold.copyWith(fontSize: 17)),
                        if (sale)
                          Text(money(v.originalPrice), style: const TextStyle(
                            color: _muted, decoration: TextDecoration.lineThrough,
                            fontSize: 12, decorationThickness: 2,
                          )),
                      ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: FilledButton(
              onPressed: ready ? buy : open,
              style: FilledButton.styleFrom(
                backgroundColor: ready ? _blue : _pale,
                foregroundColor: ready ? Colors.white : _ink,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(!ready ? 'বিস্তারিত দেখুন'
                  : p.choices.length > 1 ? 'প্যাক বাছুন' : 'কার্টে যোগ করুন',
                  textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}