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

const _blue = Color(0xFF1959E8);
const _ink = Color(0xFF10264A);
const _muted = Color(0xFF69798E);
const _line = Color(0xFFE5EBF4);

class ShoppingHomeScreen extends StatefulWidget {
  const ShoppingHomeScreen({super.key});

  @override
  State<ShoppingHomeScreen> createState() =>
      _ShoppingHomeScreenState();
}

class _ShoppingHomeScreenState
    extends State<ShoppingHomeScreen> {
  final shop = ShopService.instance;
  final search = TextEditingController();

  Timer? _debounce;

  String _query = '';
  String _category = '';
  String _sort = 'featured';

  double _minPrice = 0;
  double _maxPrice = double.infinity;

  bool _availableOnly = false;
  bool _refreshing = false;
  bool _adding = false;

  int _visible = 20;
  String _startupError = '';

  bool get _filtered =>
      _availableOnly ||
          _minPrice > 0 ||
          _maxPrice.isFinite ||
          _sort != 'featured';

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
      _startupError = '';
    });

    try {
      await Future.wait<void>([
        shop.loadLocal(),
        shop.saved.load(),
        shop.loadCatalog(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _startupError = ShopService.message(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  void _update(VoidCallback action) {
    if (!mounted) return;

    setState(() {
      action();
      _visible = 20;
    });
  }

  void _searchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 250),
          () => _update(() => _query = normalized(value)),
    );
  }

  void _resetFilters() {
    _availableOnly = false;
    _minPrice = 0;
    _maxPrice = double.infinity;
    _sort = 'featured';
  }

  void _openProduct(ShopProduct product) {
    FocusManager.instance.primaryFocus?.unfocus();

    Get.to(
          () => ProductDetailsScreen(productId: product.id),
    );
  }

  Future<void> _filters() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final maximum = shop.products
        .fold<double>(
      1,
          (value, product) =>
          math.max(value, product.preview.price / 100),
    )
        .ceilToDouble();

    var range = RangeValues(
      _minPrice.clamp(0, maximum).toDouble(),
      _maxPrice.isFinite
          ? _maxPrice.clamp(0, maximum).toDouble()
          : maximum,
    );

    var only = _availableOnly;
    var sort = _sort;

    final result = await shopSheet<String>(
      StatefulBuilder(
        builder: (sheetContext, change) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'আপনার মতো করে খুঁজুন',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'দামের সীমা: ${money((range.start * 100).round())}'
                  ' — ${money((range.end * 100).round())}',
            ),
            RangeSlider(
              values: range,
              max: maximum,
              activeColor: _blue,
              labels: RangeLabels(
                money((range.start * 100).round()),
                money((range.end * 100).round()),
              ),
              onChanged: (value) {
                change(() => range = value);
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('শুধু স্টকে থাকা পণ্য'),
              value: only,
              onChanged: (value) {
                change(() => only = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: sort,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'সাজানোর নিয়ম',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'featured',
                  child: Text('নির্বাচিত পণ্য'),
                ),
                DropdownMenuItem(
                  value: 'new',
                  child: Text('নতুন পণ্য'),
                ),
                DropdownMenuItem(
                  value: 'low',
                  child: Text('দাম কম থেকে বেশি'),
                ),
                DropdownMenuItem(
                  value: 'high',
                  child: Text('দাম বেশি থেকে কম'),
                ),
              ],
              onChanged: (value) {
                change(() => sort = value ?? 'featured');
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(sheetContext).pop('apply');
              },
              child: const Text('ফলাফল দেখুন'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(sheetContext).pop('reset');
              },
              child: const Text('ফিল্টার রিসেট করুন'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || result == null) return;

    _update(() {
      if (result == 'reset') {
        _resetFilters();
      } else {
        _minPrice = range.start;
        _maxPrice = range.end >= maximum
            ? double.infinity
            : range.end;
        _availableOnly = only;
        _sort = sort;
      }
    });
  }

  Future<void> _quickAdd(ShopProduct product) async {
    if (_adding ||
        shop.busy.value ||
        shop.locked ||
        !shop.localReady.value ||
        shop.config.value?.enabled != true) {
      return;
    }

    if (product.variants.isNotEmpty) {
      _openProduct(product);
      return;
    }

    _adding = true;

    try {
      var already = 0;

      for (final line in shop.cart) {
        if (line.productId == product.id &&
            line.variantId.isEmpty) {
          already += line.qty;
        }
      }

      final maximum =
          math.min(product.base.stock, 99) - already;

      if (maximum < 1 || !product.base.available) {
        throw StateError(
          'আরও যোগ করার মতো স্টক নেই।',
        );
      }

      var quantity = 1;

      final selected = await shopSheet<int>(
        StatefulBuilder(
          builder: (sheetContext, change) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${product.base.unit} · '
                    '${money(product.base.price)}',
              ),
              const SizedBox(height: 16),
              Center(
                child: QuantityControl(
                  value: quantity,
                  max: maximum,
                  onChanged: (value) {
                    change(() => quantity = value);
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop(quantity);
                },
                child: Text(
                  'যোগ করুন · '
                      '${money(quantity * product.base.price)}',
                ),
              ),
            ],
          ),
        ),
      );

      if (!mounted || selected == null) return;

      if (shop.config.value?.enabled != true) {
        throw StateError(
          'বর্তমানে অর্ডার নেওয়া বন্ধ আছে।',
        );
      }

      await shop.add(product, product.base, selected);

      if (!mounted) return;

      Get.snackbar(
        'কার্টে যোগ হয়েছে',
        product.name,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.white,
        colorText: _ink,
        mainButton: TextButton(
          onPressed: () {
            Get.to(() => const CartScreen());
          },
          child: const Text('কার্ট দেখুন'),
        ),
      );
    } catch (e) {
      if (mounted) shopError(e);
    } finally {
      _adding = false;
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
          onPressed: () {
            Get.to(() => const MyOrdersScreen());
          },
        ),
        Obx(
              () => Badge(
            isLabelVisible: shop.units > 0,
            label: Text(
              shop.units > 99 ? '99+' : '${shop.units}',
            ),
            child: IconButton(
              tooltip: 'কার্ট',
              icon: const Icon(Icons.shopping_bag_outlined),
              onPressed: () {
                Get.to(() => const CartScreen());
              },
            ),
          ),
        ),
        const SizedBox(width: 14),
      ],
      body: Obx(() {
        final products = shop.products.toList();
        final loading = shop.loading.value || _refreshing;

        final error = shop.error.value.isNotEmpty
            ? shop.error.value
            : _startupError;

        final categories = <String, String>{
          for (final p in products)
            p.categoryId: p.categoryName,
        };

        // Calculate the preview variant once per filtering pass.
        final rows = products
            .map((p) => (product: p, variant: p.preview))
            .where((row) {
          final p = row.product;
          final price = row.variant.price / 100;

          return (_category.isEmpty ||
              p.categoryId == _category) &&
              (_query.isEmpty ||
                  normalized(
                    '${p.name} ${p.categoryName} '
                        '${p.description}',
                  ).contains(_query)) &&
              (!_availableOnly || p.available) &&
              price >= _minPrice &&
              price <= _maxPrice;
        }).toList();

        rows.sort((a, b) {
          final result = switch (_sort) {
            'low' =>
                a.variant.price.compareTo(b.variant.price),
            'high' =>
                b.variant.price.compareTo(a.variant.price),
            'new' =>
                (b.product.createdAt ?? DateTime(1970)).compareTo(
                  a.product.createdAt ?? DateTime(1970),
                ),
            _ => (b.product.featured ? 1 : 0).compareTo(
              a.product.featured ? 1 : 0,
            ),
          };

          return result == 0
              ? a.product.id.compareTo(b.product.id)
              : result;
        });

        return RefreshIndicator(
          onRefresh: _refresh,
          color: _blue,
          child: CustomScrollView(
            key: const PageStorageKey('hello-store-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: search,
                        onChanged: _searchChanged,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) {
                          _debounce?.cancel();
                          _update(
                                () => _query = normalized(value),
                          );
                          FocusManager.instance.primaryFocus
                              ?.unfocus();
                        },
                        decoration: InputDecoration(
                          hintText: 'কোন পণ্যটি খুঁজছেন?',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _blue,
                          ),
                          suffixIcon: IconButton(
                            tooltip: 'খোঁজা মুছুন',
                            icon: const Icon(
                              Icons.close_rounded,
                            ),
                            onPressed: () {
                              _debounce?.cancel();
                              search.clear();
                              _update(() => _query = '');
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      _StoreHero(shop: shop),

                      const SizedBox(height: 12),
                      const Text(
                        'কোম্পানির নিজস্ব স্টোর • '
                            'স্থানীয় দোকানের তালিকা মেনুতে',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _StoreStatus(shop: shop),

                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final entry in {
                              '': 'সব পণ্য',
                              ...categories,
                            }.entries)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 8,
                                ),
                                child: ChoiceChip(
                                  label: Text(
                                    entry.value.isEmpty
                                        ? 'অন্যান্য'
                                        : entry.value,
                                  ),
                                  selected:
                                  _category == entry.key,
                                  showCheckmark: false,
                                  selectedColor: _blue,
                                  labelStyle: TextStyle(
                                    color: _category == entry.key
                                        ? Colors.white
                                        : _ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSelected: (_) {
                                    _update(
                                          () => _category = entry.key,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              loading && products.isEmpty
                                  ? 'পণ্য আনা হচ্ছে…'
                                  : '${rows.length}টি পণ্য',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'দাম ও স্টক ফিল্টার',
                            onPressed: _filters,
                            icon: Icon(
                              _filtered
                                  ? Icons.filter_alt
                                  : Icons.tune_rounded,
                            ),
                          ),
                        ],
                      ),

                      if (_filtered)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              _update(_resetFilters);
                            },
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                            ),
                            label: const Text('ফিল্টার সরান'),
                          ),
                        ),

                      if (loading)
                        const LinearProgressIndicator(
                          minHeight: 2,
                        ),

                      if (error.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Notice(
                          text: error,
                          warning: true,
                        ),
                        TextButton(
                          onPressed: loading ? null : _refresh,
                          child: const Text('আবার চেষ্টা করুন'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (rows.isEmpty && !loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: _muted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          error.isEmpty
                              ? 'পণ্য পাওয়া যায়নি। '
                              'খোঁজা বা ফিল্টার বদলান।'
                              : 'তালিকা আনা যায়নি। '
                              'সংযোগ হলে আবার চেষ্টা করুন।',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () {
                            _debounce?.cancel();
                            search.clear();

                            _update(() {
                              _query = '';
                              _category = '';
                              _resetFilters();
                            });
                          },
                          child: const Text('সব পণ্য দেখুন'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Rows build lazily. Cards have natural height,
              // so larger text does not rely on a fixed grid height.
              SliverPadding(
                padding:
                const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final largeText =
                        MediaQuery.textScalerOf(context)
                            .scale(14) >
                            19;

                    final columns = largeText
                        ? 1
                        : (constraints.crossAxisExtent / 170)
                        .floor()
                        .clamp(1, 4)
                        .toInt();

                    final count =
                    math.min(_visible, rows.length);

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (_, rowIndex) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              for (var column = 0;
                              column < columns;
                              column++) ...[
                                if (column > 0)
                                  const SizedBox(width: 12),
                                Expanded(
                                  child: rowIndex * columns +
                                      column >=
                                      count
                                      ? const SizedBox.shrink()
                                      : _ProductCard(
                                    product: rows[
                                    rowIndex *
                                        columns +
                                        column]
                                        .product,
                                    variant: rows[
                                    rowIndex *
                                        columns +
                                        column]
                                        .variant,
                                    shop: shop,
                                    open: _openProduct,
                                    add: _quickAdd,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        childCount: (count / columns).ceil(),
                      ),
                    );
                  },
                ),
              ),

              if (_visible < rows.length)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _visible += 20);
                      },
                      child: Text(
                        'আরও পণ্য দেখুন '
                            '(${rows.length - _visible})',
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({required this.shop});

  final ShopService shop;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final raw = shop.config.value?.raw;

      final title =
      '${raw?['bannerTitle'] ?? ''}'.trim();

      final subtitle =
      '${raw?['bannerSubtitle'] ?? ''}'.trim();

      final demo = raw?['demoMode'] == true;

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF11388F),
              _blue,
              Color(0xFF227EDB),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.shopping_basket_outlined,
                  color: Color(0xFFFFD882),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SMART DIMLA • HELLO STORE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              title.isEmpty ||
                  title == 'পরীক্ষামূলক কেনাকাটা'
                  ? 'নিত্যদিনের কেনাকাটা,\nআরও সহজ।'
                  : title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              demo || subtitle.isEmpty
                  ? 'পছন্দের পণ্য খুঁজুন, বেছে নিন, '
                  'কার্টে রাখুন।'
                  : subtitle,
              style: const TextStyle(
                color: Color(0xFFDCE9FF),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0x22FFFFFF),
              ),
              onPressed: () => policies(shop.config.value),
              icon: const Icon(
                Icons.local_shipping_outlined,
                size: 19,
              ),
              label: const Text('ডেলিভারি ও ফেরতের নিয়ম'),
            ),
          ],
        ),
      );
    });
  }
}

class _StoreStatus extends StatelessWidget {
  const _StoreStatus({required this.shop});

  final ShopService shop;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final config = shop.config.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (config?.raw['demoMode'] == true)

          if (config != null && !config.enabled)
            const _Notice(
              text: 'বর্তমানে নতুন অর্ডার নেওয়া বন্ধ আছে।',
              warning: true,
            ),

          if (shop.localError.value.isNotEmpty)
            _Notice(
              text: shop.localError.value,
              warning: true,
            ),

          if (shop.locked)
            TextButton.icon(
              onPressed: () {
                Get.to(() => const CartScreen());
              },
              icon: const Icon(Icons.info_outline),
              label: const Text(
                'আগের অর্ডারের ফল কার্ট থেকে যাচাই করুন',
              ),
            ),
        ],
      );
    });
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.variant,
    required this.shop,
    required this.open,
    required this.add,
  });

  final ShopProduct product;
  final ShopVariant variant;
  final ShopService shop;

  final void Function(ShopProduct) open;
  final Future<void> Function(ShopProduct) add;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              InkWell(
                onTap: () => open(product),
                child: Semantics(
                  label: '${product.name}, বিস্তারিত দেখুন',
                  button: true,
                  child: AspectRatio(
                    aspectRatio: 1.2,
                    child: _ProductImage(
                      url: product.image,
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 4,
                right: 4,
                child: Obx(() {
                  final saved =
                  shop.saved.productIds.contains(
                    product.id,
                  );

                  return IconButton.filledTonal(
                    tooltip: saved ? 'সেভ সরান' : 'সেভ করুন',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _blue,
                    ),
                    onPressed: shop.saved.ready.value
                        ? () => guarded(
                          () => shop.toggleSaved(product),
                    )
                        : null,
                    icon: Icon(
                      saved
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                  );
                }),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  product.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => open(product),
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  variant.unit,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${product.variants.isNotEmpty ? 'থেকে ' : ''}'
                      '${money(variant.price)}',
                  style: const TextStyle(
                    color: _blue,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                if (variant.originalPrice > variant.price)
                  Text(
                    money(variant.originalPrice),
                    style: const TextStyle(
                      color: _muted,
                      decoration: TextDecoration.lineThrough,
                      fontSize: 12,
                    ),
                  ),

                const SizedBox(height: 6),
                Text(
                  product.available
                      ? 'স্টকে আছে'
                      : 'স্টক শেষ',
                  style: TextStyle(
                    fontSize: 12,
                    color: product.available
                        ? const Color(0xFF167351)
                        : Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 10),

                Obx(() {
                  final ready = shop.localReady.value;
                  final busy = shop.busy.value;
                  final locked = shop.locked;
                  final enabled =
                      shop.config.value?.enabled == true;

                  return FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                    ),
                    onPressed: product.available &&
                        ready &&
                        !busy &&
                        !locked &&
                        enabled
                        ? () => add(product)
                        : null,
                    child: Text(
                      product.variants.isEmpty
                          ? 'কার্টে যোগ করুন'
                          : 'ধরন বাছুন',
                      textAlign: TextAlign.center,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: Color(0xFFF1F5FC),
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 40,
          color: _blue,
        ),
      ),
    );

    if (Uri.tryParse(url)?.scheme != 'https') {
      return fallback;
    }

    return Image.network(
      url,
      fit: BoxFit.contain,
      cacheWidth: 480,
      filterQuality: FilterQuality.low,
      frameBuilder: (_, child, frame, synchronous) {
        return synchronous || frame != null
            ? child
            : fallback;
      },
      errorBuilder: (_, error, stack) => fallback,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    this.warning = false,
  });

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning
            ? const Color(0xFFFFF4DE)
            : const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: warning
                ? const Color(0xFF9A6500)
                : _blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}