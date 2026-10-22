import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../commerce/shop_models.dart';
import '../../commerce/shop_service.dart';
import '../../commerce/shop_widgets.dart';
import '../10_product_details/product_details_screen.dart';
import '../11_cart/cart_screen.dart';
import '../13_my_orders/my_orders_screen.dart';

// --- Modern Store Palette ---
const _storeBlue = Color(0xFF1959E8);
const _storeDark = Color(0xFF0F2D6B);
const _ink = Color(0xFF0F1E36);
const _muted = Color(0xFF64748B);
const _surfaceBg = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);

class ShoppingHomeScreen extends StatefulWidget {
  const ShoppingHomeScreen({super.key});

  @override
  State<ShoppingHomeScreen> createState() => _ShoppingHomeScreenState();
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

  bool get _hasActiveFilters =>
      availableOnly ||
          minPrice > 0 ||
          maxPrice.isFinite ||
          sort != 'featured';

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

  String _sortLabel(String value) {
    return switch (value) {
      'new' => 'নতুন পণ্য',
      'low' => 'দাম: কম থেকে বেশি',
      'high' => 'দাম: বেশি থেকে কম',
      _ => 'নির্বাচিত পণ্য',
    };
  }

  // --- Modern Filter Bottom Sheet ---
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
      maxPrice.isFinite ? maxPrice.clamp(0, maximum).toDouble() : maximum,
    );

    var only = availableOnly;
    var order = sort;

    await shopSheet<void>(
      StatefulBuilder(
        builder: (_, change) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _storeBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: _storeBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'পণ্য ফিল্টার ও সাজানো',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: Get.back,
                    icon: const Icon(Icons.close_rounded, color: _muted),
                  ),
                ],
              ),
              const Divider(height: 24, color: _border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'দামের সীমা',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _storeBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${money((range.start * 100).round())} — ${money((range.end * 100).round())}',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _storeBlue,
                      ),
                    ),
                  ),
                ],
              ),
              RangeSlider(
                values: range,
                max: maximum,
                divisions: 100,
                activeColor: _storeBlue,
                inactiveColor: _border,
                onChanged: (value) => change(() => range = value),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: _surfaceBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  title: Text(
                    'শুধু স্টকে থাকা পণ্য দেখুন',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  activeColor: _storeBlue,
                  value: only,
                  onChanged: (value) => change(() => only = value),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: order,
                decoration: InputDecoration(
                  labelText: 'সাজানোর নিয়ম',
                  labelStyle: GoogleFonts.hindSiliguri(color: _muted),
                  filled: true,
                  fillColor: _surfaceBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _border),
                  ),
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
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        update(() {
                          minPrice = 0;
                          maxPrice = double.infinity;
                          availableOnly = false;
                          sort = 'featured';
                        });
                        Get.back();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'রিসেট করুন',
                        style: GoogleFonts.hindSiliguri(
                          fontWeight: FontWeight.w700,
                          color: _muted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
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
                      style: FilledButton.styleFrom(
                        backgroundColor: _storeBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'ফলাফল দেখুন',
                        style: GoogleFonts.hindSiliguri(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Quick Add Bottom Sheet ---
  Future<void> quickAdd(ShopProduct product) async {
    if (product.variants.isNotEmpty) {
      Get.to(() => ProductDetailsScreen(productId: product.id));
      return;
    }

    final previous = shop.cart
        .where(
          (line) => line.productId == product.id && line.variantId.isEmpty,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: ShopImage(product.image),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.hindSiliguri(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'প্রতি ${product.base.unit} · ${money(product.base.price)}',
                        style: GoogleFonts.hindSiliguri(
                          fontSize: 13.5,
                          color: _storeBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28, color: _border),
            QuantityControl(
              value: quantity,
              max: maximum,
              onChanged: (value) => change(() => quantity = value),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Get.back(result: quantity),
                style: FilledButton.styleFrom(
                  backgroundColor: _storeBlue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                label: Text(
                  'যোগ করুন · ${money(quantity * product.base.price)}',
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
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
        backgroundColor: _ink,
        colorText: Colors.white,
        margin: const EdgeInsets.all(14),
        borderRadius: 14,
        mainButton: TextButton(
          onPressed: () => Get.to(() => const CartScreen()),
          child: const Text(
            'Cart দেখুন',
            style: TextStyle(
              color: Color(0xFFFFD166),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    });
  }

  // --- Modern E-Commerce Product Card ---
  Widget productCard(ShopProduct product) {
    final canAdd = product.available && !shop.busy.value && !shop.locked;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F1E36),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Image & Badges
          Expanded(
            child: InkWell(
              onTap: () => Get.to(
                    () => ProductDetailsScreen(productId: product.id),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ShopImage(product.image),
                  // Subtle Bottom Scrim for contrast
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Featured Badge
                  if (product.featured)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD166),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: _ink,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'নির্বাচিত',
                              style: GoogleFonts.hindSiliguri(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Stock Status Badge (Bottom Left of Image)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: product.available
                            ? const Color(0xFF059669).withValues(alpha: 0.92)
                            : const Color(0xFFE11D48).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.available ? 'স্টকে আছে' : 'স্টক শেষ',
                        style: GoogleFonts.hindSiliguri(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Save / Bookmark Button
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Obx(() {
                      final isSaved =
                      shop.saved.productIds.contains(product.id);
                      return Material(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        elevation: 1,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: shop.saved.ready.value
                              ? () => guarded(() => shop.toggleSaved(product))
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Icon(
                              isSaved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              size: 19,
                              color: isSaved ? _storeBlue : _ink,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),

          // Product Details Info
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.categoryName.isNotEmpty)
                  Text(
                    product.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _storeBlue,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hindSiliguri(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: _ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.preview.unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hindSiliguri(
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (product.variants.isNotEmpty)
                      Text(
                        'থেকে ',
                        style: GoogleFonts.hindSiliguri(
                          fontSize: 11.5,
                          color: _muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        money(product.preview.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.hindSiliguri(
                          fontWeight: FontWeight.w700,
                          color: _storeBlue,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Add / Variant Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              height: 38,
              child: FilledButton.tonalIcon(
                onPressed: canAdd ? () => quickAdd(product) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _storeBlue.withValues(alpha: 0.1),
                  foregroundColor: _storeBlue,
                  disabledBackgroundColor: const Color(0xFFF1F5F9),
                  disabledForegroundColor: _muted,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  product.variants.isEmpty
                      ? Icons.add_shopping_cart_rounded
                      : Icons.tune_rounded,
                  size: 16,
                ),
                label: Text(
                  product.variants.isEmpty ? 'যোগ করুন' : 'Variant বাছুন',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hindSiliguri(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
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
              backgroundColor: const Color(0xFFE11D48),
              label: Text(
                '${shop.units}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
              return (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0);
          }
        });

        final categories = {
          for (final product in shop.products)
            product.categoryId: product.categoryName,
        };

        final config = shop.config.value;

        return RefreshIndicator(
          color: _storeBlue,
          onRefresh: shop.loadCatalog,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- 1. Hero Store Banner ---
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: const LinearGradient(
                            colors: [
                              _storeDark,
                              _storeBlue,
                              Color(0xFF088395),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _storeDark.withValues(alpha: 0.22),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -30,
                              top: -30,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 40,
                              bottom: -45,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(22),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.16),
                                            borderRadius:
                                            BorderRadius.circular(30),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.verified_rounded,
                                                color: Color(0xFFFFD166),
                                                size: 14,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                'HELLO DIMLA • OWN STORE',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '${config?.raw['bannerTitle'] ?? 'কেনাকাটা,\nএক জায়গাতেই।'}',
                                          style: GoogleFonts.hindSiliguri(
                                            color: Colors.white,
                                            fontSize: 26,
                                            height: 1.2,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${config?.raw['bannerSubtitle'] ?? 'Hello Dimla-র নিজস্ব অনলাইন স্টোর'}',
                                          style: GoogleFonts.hindSiliguri(
                                            color: const Color(0xFFDCEBFF),
                                            fontSize: 13.5,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color:
                                      Colors.white.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.shopping_bag_rounded,
                                      color: Color(0xFFFFD777),
                                      size: 42,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // --- Info Strip ---
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 17,
                              color: _storeBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'এখানে কোম্পানির নিজস্ব পণ্য। স্থানীয় দোকানের তালিকা মূল মেনুতে।',
                                style: GoogleFonts.hindSiliguri(
                                  color: _muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- Store Closed / Locked Alerts ---
                      if (config != null && !config.enabled)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFFCCD5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.pause_circle_filled_rounded,
                                color: Color(0xFFE11D48),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'বর্তমানে অর্ডার নেওয়া সাময়িকভাবে বন্ধ আছে।',
                                  style: GoogleFonts.hindSiliguri(
                                    color: const Color(0xFF9F1239),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (shop.locked)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton.icon(
                            onPressed: () => Get.to(() => const CartScreen()),
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text('আগের অর্ডার প্রসেস যাচাই করুন'),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // --- 2. Search Bar & Filter Trigger ---
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: _storeBlue.withValues(alpha: 0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: search,
                                onChanged: (_) => update(() {}),
                                style: GoogleFonts.hindSiliguri(
                                  color: _ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'কোন পণ্য খুঁজছেন?',
                                  hintStyle: GoogleFonts.hindSiliguri(
                                    color: _muted,
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: _storeBlue,
                                  ),
                                  suffixIcon: search.text.isNotEmpty
                                      ? IconButton(
                                    tooltip: 'Search মুছুন',
                                    onPressed: () {
                                      search.clear();
                                      update(() {});
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                    ),
                                  )
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide:
                                    const BorderSide(color: _border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide:
                                    const BorderSide(color: _border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                      color: _storeBlue,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Badge(
                            isLabelVisible: _hasActiveFilters,
                            backgroundColor: const Color(0xFFE11D48),
                            child: Material(
                              color: _hasActiveFilters
                                  ? _storeBlue
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                  color: _hasActiveFilters
                                      ? _storeBlue
                                      : _border,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: filterSheet,
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: Icon(
                                    Icons.tune_rounded,
                                    color: _hasActiveFilters
                                        ? Colors.white
                                        : _ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // --- 3. Horizontal Category Pills ---
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _CategoryPill(
                              label: 'সব পণ্য',
                              selected: category.isEmpty,
                              onTap: () => update(() => category = ''),
                            ),
                            for (final entry in categories.entries)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _CategoryPill(
                                  label: entry.value,
                                  selected: category == entry.key,
                                  onTap: () =>
                                      update(() => category = entry.key),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // --- 4. Product Count & Quick Sort Header ---
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _storeBlue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),

                              child: Text(
                                '${filtered.length}টি পণ্য পাওয়া গেছে',
                                key: ValueKey(filtered.length),
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => update(
                                    () => sort = sort == 'new' ? 'featured' : 'new',
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: sort == 'new'
                                        ? _storeBlue
                                        : _border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_outlined,
                                      size: 14,
                                      color: sort == 'new'
                                          ? _storeBlue
                                          : _muted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'নতুন',
                                      style: GoogleFonts.hindSiliguri(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: sort == 'new'
                                            ? _storeBlue
                                            : _ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: filterSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.sort_rounded,
                                      size: 15,
                                      color: _storeBlue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _sortLabel(sort),
                                      style: GoogleFonts.hindSiliguri(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Active Filter Summary Pill
                      if (_hasActiveFilters)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'ফিল্টার চালু আছে (${availableOnly ? "শুধু স্টকে থাকা · " : ""}${_sortLabel(sort)})',
                                  style: GoogleFonts.hindSiliguri(
                                    fontSize: 12,
                                    color: _storeBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => update(() {
                                  minPrice = 0;
                                  maxPrice = double.infinity;
                                  availableOnly = false;
                                  sort = 'featured';
                                }),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('সব মুছুন'),
                              ),
                            ],
                          ),
                        ),

                      if (shop.loading.value)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),

                      if (shop.error.value.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            shop.error.value,
                            style: const TextStyle(color: Colors.deepOrange),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // --- Empty State ---
              if (filtered.isEmpty && !shop.loading.value)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: ShopEmpty(
                    'পণ্য পাওয়া যায়নি। Search বা filter বদলান।',
                  ),
                ),

              // --- 5. Products Grid ---
              SliverPadding(
                padding: const EdgeInsets.all(18),
                sliver: SliverLayoutBuilder(
                  builder: (_, constraints) {
                    final columns = constraints.crossAxisExtent > 720
                        ? 4
                        : constraints.crossAxisExtent > 500
                        ? 3
                        : 2;

                    final height = 324.0 +
                        (MediaQuery.textScalerOf(context).scale(14) - 14)
                            .clamp(0, 100);

                    return SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                            (_, index) => productCard(filtered[index]),
                        childCount: min(visible, filtered.length),
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 14,
                        mainAxisExtent: height,
                      ),
                    );
                  },
                ),
              ),

              // --- Load More Button ---
              if (visible < filtered.length)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => visible += 20),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: _storeBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: Text(
                        'আরও পণ্য দেখুন (${filtered.length - visible}+)',
                        style: GoogleFonts.hindSiliguri(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 28),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// --- Custom Category Pill Widget ---
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _storeBlue : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(
          color: selected ? _storeBlue : _border,
        ),
      ),
      elevation: selected ? 2 : 0,
      shadowColor: _storeBlue.withValues(alpha: 0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 9,
          ),
          child: Text(
            label,
            style: GoogleFonts.hindSiliguri(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? Colors.white : _ink,
            ),
          ),
        ),
      ),
    );
  }
}