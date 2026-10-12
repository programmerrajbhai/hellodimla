import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../commerce/shop_models.dart';
import '../../commerce/shop_service.dart';
import '../../commerce/shop_widgets.dart';
import '../11_cart/cart_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String? productId;

  const ProductDetailsScreen({
    super.key,
    this.productId,
  });

  @override
  State<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final shop = ShopService.instance;

  ShopProduct? product;
  ShopVariant? selected;

  String error = '';
  bool loading = true;

  int qty = 1;
  int imageIndex = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      await shop.loadLocal();
      await shop.saved.load();

      if (shop.config.value == null) {
        await shop.loadCatalog();
      }

      if (widget.productId == null || widget.productId!.isEmpty) {
        throw StateError('Product ID দেওয়া হয়নি।');
      }

      final loaded = await shop.product(widget.productId!);

      if (loaded == null) {
        throw StateError('পণ্যটি এখন পাওয়া যাচ্ছে না।');
      }

      if (!mounted) return;

      setState(() {
        product = loaded;
        selected = loaded.variants.isEmpty
            ? loaded.base
            : loaded.preview;
        qty = 1;
        imageIndex = 0;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = ShopService.message(e));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> variants() async {
    final p = product!;

    final result = await shopSheet<ShopVariant>(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Variant নির্বাচন করুন',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          for (final variant in p.variants)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(variant.name),
              subtitle: Text(
                '${variant.unit} · ${money(variant.price)} · '
                    '${variant.available ? '${variant.stock}টি stock' : 'Stock নেই'}',
              ),
              trailing: Icon(
                variant.id == selected?.id
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: shopBlue,
              ),
              onTap: () => Get.back(result: variant),
            ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        selected = result;
        qty = 1;
      });
    }
  }

  void preview(String url) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * .75,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(child: ShopImage(url)),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: IconButton.filled(
                tooltip: 'বন্ধ করুন',
                onPressed: () => Get.back(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = product;
    final v = selected;

    Widget content;

    if (loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (error.isNotEmpty || p == null || v == null) {
      content = ShopEmpty(
        error.isEmpty ? 'পণ্য পাওয়া যায়নি।' : error,
        retry: load,
      );
    } else {
      content = ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ShopBox(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    height: 300,
                    child: p.images.isEmpty
                        ? const ShopImage('')
                        : PageView.builder(
                      itemCount: p.images.length,
                      onPageChanged: (index) =>
                          setState(() => imageIndex = index),
                      itemBuilder: (_, index) => InkWell(
                        onTap: () => preview(p.images[index]),
                        child: ShopImage(p.images[index]),
                      ),
                    ),
                  ),
                ),
                if (p.images.length > 1)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${imageIndex + 1} / ${p.images.length}'
                          ' · বড় করতে চাপুন',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ShopBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.categoryName,
                  style: const TextStyle(
                    color: shopBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 25,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                PriceText(v.price, original: v.originalPrice),
                if (v.originalPrice > v.price)
                  Text(
                    '${((v.originalPrice - v.price) * 100 / v.originalPrice).round()}% ছাড়',
                    style: const TextStyle(color: Colors.teal),
                  ),
                const SizedBox(height: 8),
                Text('প্রতি ${v.unit}'),
                Text(
                  v.available ? '${v.stock}টি stock-এ আছে' : 'Stock নেই',
                  style: TextStyle(
                    color: v.available ? Colors.teal : Colors.deepOrange,
                  ),
                ),
                if (p.variants.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: variants,
                      icon: const Icon(Icons.layers_outlined),
                      label: Text('Variant: ${v.name}'),
                    ),
                  ),
                const Divider(height: 30),
                const Text(
                  'পরিমাণ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                QuantityControl(
                  value: qty,
                  max: min(v.stock, 99),
                  onChanged: v.available
                      ? (value) => setState(() => qty = value)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShopBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'পণ্যের বিবরণ',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  p.description.isEmpty
                      ? 'বিবরণ দেওয়া হয়নি।'
                      : p.description,
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => policies(shop.config.value),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Delivery ও return policy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    return ShopPage(
      title: 'পণ্যের বিস্তারিত',
      actions: [
        IconButton(
          tooltip: 'Cart',
          onPressed: () => Get.to(() => const CartScreen()),
          icon: const Icon(Icons.shopping_bag_outlined),
        ),
      ],
      body: content,
      bottom: p == null || v == null
          ? null
          : Obx(
            () => Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Save',
              onPressed: shop.saved.ready.value
                  ? () => guarded(() => shop.toggleSaved(p))
                  : null,
              icon: Icon(
                shop.saved.productIds.contains(p.id)
                    ? Icons.bookmark
                    : Icons.bookmark_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: v.available &&
                    !shop.busy.value &&
                    !shop.locked &&
                    shop.localReady.value
                    ? () => guarded(() async {
                  await shop.add(p, v, qty);

                  Get.snackbar(
                    'Cart-এ যোগ হয়েছে',
                    '${p.name} · $qty ${v.unit}',
                    snackPosition: SnackPosition.BOTTOM,
                    mainButton: TextButton(
                      onPressed: () => Get.to(
                            () => const CartScreen(),
                      ),
                      child: const Text('Cart দেখুন'),
                    ),
                  );
                })
                    : null,
                child: Text(
                  shop.busy.value
                      ? 'যোগ হচ্ছে…'
                      : 'যোগ করুন · ${money(qty * v.price)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}