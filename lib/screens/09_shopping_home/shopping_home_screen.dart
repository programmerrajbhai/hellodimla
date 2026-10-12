import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../commerce/shop_models.dart';
import '../../commerce/shop_service.dart';
import '../../commerce/shop_widgets.dart';
import '../10_product_details/product_details_screen.dart';
import '../11_cart/cart_screen.dart';
import '../13_my_orders/my_orders_screen.dart';

class ShoppingHomeScreen extends StatefulWidget {
  const ShoppingHomeScreen({super.key});

  @override
  State<ShoppingHomeScreen> createState() =>
      _ShoppingHomeScreenState();
}

class _ShoppingHomeScreenState extends State<ShoppingHomeScreen> {
  final shop = ShopService.instance;
  final search = TextEditingController();

  String category = '';
  String sort = 'featured';

  bool availableOnly = false;
  double minPrice = 0;
  double maxPrice = double.infinity;
  int visible = 20;

  @override
  void initState() {
    super.initState();
    shop.initialize();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void update(VoidCallback action) {
    setState(() {
      action();
      visible = 20;
    });
  }

  Future<void> filterSheet() async {
    final maximum = max(
      1.0,
      shop.products.fold<double>(
        0,
            (amount, product) => max(amount, product.preview.price / 100),
      ),
    ).ceilToDouble();

    var range = RangeValues(
      minPrice.clamp(0, maximum).toDouble(),
      maxPrice.isFinite
          ? maxPrice.clamp(0, maximum).toDouble()
          : maximum,
    );

    var only = availableOnly;
    var order = sort;

    await shopSheet<void>(
      StatefulBuilder(
        builder: (_, change) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'পণ্য filter',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${money((range.start * 100).round())}'
                    ' — ${money((range.end * 100).round())}',
              ),
              RangeSlider(
                values: range,
                max: maximum,
                divisions: 100,
                onChanged: (value) => change(() => range = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('শুধু stock-এ থাকা পণ্য'),
                value: only,
                onChanged: (value) => change(() => only = value),
              ),
              DropdownButtonFormField<String>(
                initialValue: order,
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
                onChanged: (value) => change(() => order = value!),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      update(() {
                        minPrice = 0;
                        maxPrice = double.infinity;
                        availableOnly = false;
                        sort = 'featured';
                      });
                      Get.back();
                    },
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      update(() {
                        minPrice = range.start;
                        maxPrice = range.end == maximum
                            ? double.infinity
                            : range.end;
                        availableOnly = only;
                        sort = order;
                      });
                      Get.back();
                    },
                    child: const Text('ফলাফল দেখুন'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> quickAdd(ShopProduct product) async {
    if (product.variants.isNotEmpty) {
      Get.to(() => ProductDetailsScreen(productId: product.id));
      return;
    }

    final previous = shop.cart
        .where(
          (line) =>
      line.productId == product.id && line.variantId.isEmpty,
    )
        .toList();

    final already = previous.isEmpty ? 0 : previous.first.qty;
    final maximum = min(product.base.stock, 99) - already;

    if (maximum < 1 || !product.base.available) {
      shopError(StateError('আরও নেওয়ার মতো stock নেই।'));
      return;
    }

    var quantity = 1;

    final selected = await shopSheet<int>(
      StatefulBuilder(
        builder: (_, change) => Column(
          children: [
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'প্রতি ${product.base.unit} ${money(product.base.price)}',
            ),
            const SizedBox(height: 14),
            QuantityControl(
              value: quantity,
              max: maximum,
              onChanged: (value) => change(() => quantity = value),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Get.back(result: quantity),
                child: Text(
                  'যোগ করুন · ${money(quantity * product.base.price)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;

    await guarded(() async {
      await shop.add(product, product.base, selected);

      Get.snackbar(
        'Cart-এ যোগ হয়েছে',
        product.name,
        snackPosition: SnackPosition.BOTTOM,
        mainButton: TextButton(
          onPressed: () => Get.to(() => const CartScreen()),
          child: const Text('Cart দেখুন'),
        ),
      );
    });
  }

  Widget productCard(ShopProduct product) {
    return ShopBox(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => Get.to(
                    () => ProductDetailsScreen(productId: product.id),
              ),
              borderRadius: BorderRadius.circular(24),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ShopImage(product.image),
                    if (product.featured)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDF83),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'নির্বাচিত',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Obx(
                            () => IconButton.filledTonal(
                          tooltip: 'Save',
                          onPressed: shop.saved.ready.value
                              ? () => guarded(
                                () => shop.toggleSaved(product),
                          )
                              : null,
                          icon: Icon(
                            shop.saved.productIds.contains(product.id)
                                ? Icons.bookmark
                                : Icons.bookmark_outline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  product.preview.unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${product.variants.isNotEmpty ? 'থেকে ' : ''}'
                      '${money(product.preview.price)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: shopBlue,
                    fontSize: 18,
                  ),
                ),
                Text(
                  product.available ? 'Stock-এ আছে' : 'Stock নেই',
                  style: TextStyle(
                    fontSize: 11,
                    color: product.available
                        ? Colors.teal
                        : Colors.deepOrange,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: FilledButton.tonal(
              onPressed: product.available &&
                  !shop.busy.value &&
                  !shop.locked
                  ? () => quickAdd(product)
                  : null,
              child: Text(
                product.variants.isEmpty ? 'যোগ করুন' : 'Variant বাছুন',
              ),
            ),
          ),
        ],
      ),
    );
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
        Obx(
              () => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Badge(
              isLabelVisible: shop.units > 0,
              label: Text('${shop.units}'),
              child: IconButton(
                tooltip: 'Cart',
                onPressed: () => Get.to(() => const CartScreen()),
                icon: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
          ),
        ),
      ],
      body: Obx(() {
        final query = normalized(search.text);

        final filtered = shop.products.where((product) {
          final matchesCategory =
              category.isEmpty || product.categoryId == category;

          final matchesQuery = query.isEmpty ||
              normalized(
                '${product.name} '
                    '${product.categoryName} '
                    '${product.description}',
              ).contains(query);

          return matchesCategory &&
              matchesQuery &&
              (!availableOnly || product.available) &&
              product.preview.price / 100 >= minPrice &&
              product.preview.price / 100 <= maxPrice;
        }).toList();

        filtered.sort((a, b) {
          switch (sort) {
            case 'low':
              return a.preview.price.compareTo(b.preview.price);
            case 'high':
              return b.preview.price.compareTo(a.preview.price);
            case 'new':
              return (b.createdAt ?? DateTime(1970))
                  .compareTo(a.createdAt ?? DateTime(1970));
            default:
              return (b.featured ? 1 : 0)
                  .compareTo(a.featured ? 1 : 0);
          }
        });

        final categories = {
          for (final product in shop.products)
            product.categoryId: product.categoryName,
        };

        final config = shop.config.value;

        return RefreshIndicator(
          onRefresh: shop.loadCatalog,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1045CA),
                              Color(0xFF3884FF),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'HELLO DIMLA • OWN STORE',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${config?.raw['bannerTitle'] ?? 'কেনাকাটা,\nএক জায়গাতেই।'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      height: 1.25,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${config?.raw['bannerSubtitle'] ?? 'Hello Dimla-র নিজস্ব Store'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Icon(
                              Icons.shopping_bag_rounded,
                              color: Color(0xFFFFD777),
                              size: 54,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'এখানে কোম্পানির পণ্য। স্থানীয় দোকানের directory মেনুতে।',
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                      if (config != null && !config.enabled)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'বর্তমানে অর্ডার নেওয়া বন্ধ।',
                            style: TextStyle(color: Colors.deepOrange),
                          ),
                        ),
                      if (shop.locked)
                        TextButton.icon(
                          onPressed: () =>
                              Get.to(() => const CartScreen()),
                          icon: const Icon(Icons.sync),
                          label: const Text('আগের attempt যাচাই করুন'),
                        ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: search,
                        onChanged: (_) => update(() {}),
                        decoration: InputDecoration(
                          hintText: 'কোন পণ্য খুঁজছেন?',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Search মুছুন',
                            onPressed: () {
                              search.clear();
                              update(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('সব পণ্য'),
                              selected: category.isEmpty,
                              onSelected: (_) =>
                                  update(() => category = ''),
                            ),
                            for (final entry in categories.entries)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: ChoiceChip(
                                  label: Text(entry.value),
                                  selected: category == entry.key,
                                  onSelected: (_) =>
                                      update(() => category = entry.key),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: MediaQuery.disableAnimationsOf(
                                context,
                              )
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              child: Text(
                                '${filtered.length}টি পণ্য',
                                key: ValueKey(filtered.length),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => update(() => sort = 'new'),
                            child: const Text('নতুন'),
                          ),
                          IconButton(
                            tooltip: 'Filter',
                            onPressed: filterSheet,
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                      if (shop.loading.value)
                        const LinearProgressIndicator(),
                      if (shop.error.value.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          child: Text(
                            shop.error.value,
                            style: const TextStyle(
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty && !shop.loading.value)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: ShopEmpty(
                    'পণ্য পাওয়া যায়নি। Search বা filter বদলান।',
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.all(18),
                sliver: SliverLayoutBuilder(
                  builder: (_, constraints) {
                    final columns = constraints.crossAxisExtent > 720
                        ? 4
                        : constraints.crossAxisExtent > 500
                        ? 3
                        : 2;

                    final height = 308.0 +
                        (MediaQuery.textScalerOf(context).scale(14) - 14)
                            .clamp(0, 100);

                    return SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                            (_, index) => productCard(filtered[index]),
                        childCount: min(visible, filtered.length),
                      ),
                      gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: height,
                      ),
                    );
                  },
                ),
              ),
              if (visible < filtered.length)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: OutlinedButton(
                      onPressed: () => setState(() => visible += 20),
                      child: const Text('আরও পণ্য দেখুন'),
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