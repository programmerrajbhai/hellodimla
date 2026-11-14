import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../commerce/shop_models.dart';
import '../../commerce/shop_service.dart';
import '../../commerce/shop_widgets.dart';
import '../11_cart/cart_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    this.productId,
  });

  final String? productId;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final shop = ShopService.instance;

  ShopProduct? _product;
  ShopVariant? _selected;

  bool _loading = true;
  bool _adding = false;
  bool _buying = false;
  String _error = '';
  int _qty = 1;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final id = widget.productId?.trim() ?? '';
      if (id.isEmpty) throw StateError('পণ্যের আইডি পাওয়া যায়নি।');

      await shop.loadLocal();
      await shop.saved.load();

      if (shop.config.value == null) {
        await shop.loadCatalog();
      }

      final product = await shop.product(id);
      if (product == null) {
        throw StateError('এই এলাকায় পণ্যটি এখন পাওয়া যাচ্ছে না।');
      }

      final options = product.variants;
      final initial = options.isEmpty
          ? product.base
          : options.firstWhere(
            (option) => option.available,
        orElse: () => product.preview,
      );

      if (!mounted) return;
      setState(() {
        _product = product;
        _selected = initial;
        _qty = 1;
        _imageIndex = 0;
      });
    } catch (e) {
      if (mounted) setState(() => _error = ShopService.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // একই প্যাক আগে থেকেই কার্টে থাকলে অবশিষ্ট পরিমাণটুকুই নেওয়া যাবে।
  int _remaining(ShopProduct product, ShopVariant variant) {
    final variantId = product.variants.isEmpty ? '' : variant.id;
    final key = '${product.id}:$variantId';

    var inCart = 0;
    for (final line in shop.cart) {
      if (line.key == key) {
        inCart = line.qty;
        break;
      }
    }

    return max(0, min(variant.stock, 99) - inCart);
  }

  int _quantityFor(int remaining) =>
      remaining == 0 ? 0 : min(max(1, _qty), remaining);

  Future<void> _add({required bool openCart}) async {
    final p = _product;
    final v = _selected;
    if (p == null || v == null || _adding || shop.busy.value) return;

    final quantity = _quantityFor(_remaining(p, v));
    if (!v.available || quantity == 0 || shop.locked) return;

    setState(() {
      _adding = true;
      _buying = openCart;
    });

    try {
      await shop.add(p, v, quantity);
      if (!mounted) return;

      setState(() => _qty = 1);

      if (openCart) {
        await Get.to(() => const CartScreen());
      } else {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('${p.name} · $quantity প্যাক কার্টে যোগ হয়েছে'),
            action: SnackBarAction(
              label: 'কার্ট দেখুন',
              onPressed: () => Get.to(() => const CartScreen()),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ShopService.message(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _adding = false;
          _buying = false;
        });
      }
    }
  }

  void _preview(String url) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * .72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(child: ShopImage(url)),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  tooltip: 'ছবি বন্ধ করুন',
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gallery(ShopProduct p) {
    final images = p.images;
    final height =
    (MediaQuery.sizeOf(context).width * .72).clamp(210.0, 320.0).toDouble();

    return ShopBox(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (images.isEmpty)
                const ShopImage('')
              else
                PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _imageIndex = i),
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => _preview(images[i]),
                    child: ShopImage(images[i]),
                  ),
                ),
              if (images.isNotEmpty)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Material(
                    color: Colors.black.withValues(alpha: .64),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _preview(images[_imageIndex]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.zoom_in_rounded,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 5),
                            Text(
                              '${_imageIndex + 1}/${images.length}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productInfo(ShopProduct p, ShopVariant v) {
    final discounted = v.originalPrice > v.price;

    return ShopBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.categoryName.isNotEmpty) ...[
            Text(
              p.categoryName,
              style: const TextStyle(
                color: shopBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            p.name,
            style: const TextStyle(
              fontSize: 25,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PriceText(v.price, original: v.originalPrice),
              if (discounted)
                _Badge(
                  text:
                  '${((v.originalPrice - v.price) * 100 / v.originalPrice).round()}% ছাড়',
                  color: const Color(0xFF087F5B),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (v.unit.isNotEmpty) Text('প্রতি ${v.unit}'),
              _Badge(
                text: v.available ? 'স্টকে আছে · ${v.stock}' : 'স্টক শেষ',
                color: v.available
                    ? const Color(0xFF087F5B)
                    : const Color(0xFFAF354F),
              ),
            ],
          ),
          if (p.variants.isNotEmpty) ...[
            const Divider(height: 28),
            const Text(
              'প্যাক / সাইজ বেছে নিন',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final option in p.variants)
                  ChoiceChip(
                    selected: option.id == v.id,
                    label: Text(
                      '${option.name.isEmpty ? option.unit : option.name}'
                          '${option.available ? '' : ' · স্টক শেষ'}',
                    ),
                    onSelected: !option.available || _adding
                        ? null
                        : (_) => setState(() {
                      _selected = option;
                      _qty = 1;
                    }),
                  ),
              ],
            ),
          ],
          const Divider(height: 28),
          Obx(() {
            final remaining = _remaining(p, v);
            final quantity = _quantityFor(remaining);

            if (remaining == 0 || !v.available) {
              return Text(
                v.available
                    ? 'এই প্যাকের সর্বোচ্চ পরিমাণ ইতিমধ্যে কার্টে আছে।'
                    : 'এই প্যাকটি এখন কেনা যাচ্ছে না।',
                style: const TextStyle(color: Color(0xFF596A80)),
              );
            }

            return Wrap(
              spacing: 16,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'পরিমাণ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                QuantityControl(
                  value: quantity,
                  max: remaining,
                  onChanged: _adding
                      ? null
                      : (value) => setState(() => _qty = value),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _details(ShopProduct p) {
    return ShopBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'পণ্যের বিবরণ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            p.description.trim().isEmpty
                ? 'এই পণ্যের বিস্তারিত বিবরণ এখনো যোগ করা হয়নি।'
                : p.description,
            style: const TextStyle(height: 1.6),
          ),
          const Divider(height: 24),
          TextButton.icon(
            onPressed: () => policies(shop.config.value),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('ডেলিভারি ও ফেরতের নিয়ম'),
          ),
        ],
      ),
    );
  }

  Widget _purchaseBar(ShopProduct p, ShopVariant v) {
    return Obx(() {
      final remaining = _remaining(p, v);
      final quantity = _quantityFor(remaining);
      final ready = shop.localReady.value;
      final busy = shop.busy.value;
      final locked = shop.locked;
      final canAdd =
          ready && !busy && !locked && !_adding && v.available && quantity > 0;

      final cartButton = OutlinedButton.icon(
        onPressed: canAdd ? () => _add(openCart: false) : null,
        icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
        label: Text(_adding && !_buying ? 'যোগ হচ্ছে…' : 'কার্টে যোগ'),
      );

      final buyButton = FilledButton.icon(
        onPressed: canAdd ? () => _add(openCart: true) : null,
        style: FilledButton.styleFrom(
          backgroundColor: shopBlue,
          minimumSize: const Size(0, 46),
        ),
        icon: const Icon(Icons.shopping_bag_outlined, size: 18),
        label: Text(_adding && _buying ? 'খুলছে…' : 'এখনই কিনুন'),
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (quantity > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'পণ্যের মোট: ${money(quantity * v.price)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          LayoutBuilder(
            builder: (context, bounds) {
              final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
              if (bounds.maxWidth < 290 || largeText) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [buyButton, cartButton],
                );
              }
              return Row(
                children: [
                  Expanded(child: cartButton),
                  const SizedBox(width: 10),
                  Expanded(child: buyButton),
                ],
              );
            },
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final v = _selected;
    final showProduct = !_loading && _error.isEmpty && p != null && v != null;

    final Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error.isNotEmpty || p == null || v == null) {
      body = ShopEmpty(
        _error.isEmpty ? 'পণ্য পাওয়া যায়নি।' : _error,
        retry: _load,
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _gallery(p),
          const SizedBox(height: 12),
          _productInfo(p, v),
          const SizedBox(height: 12),
          _details(p),
        ],
      );
    }

    return ShopPage(
      title: 'পণ্যের বিস্তারিত',
      actions: [
        if (p != null)
          Obx(() {
            final saved = shop.saved.productIds.contains(p.id);
            return IconButton(
              tooltip: saved ? 'সেভ থেকে সরান' : 'পণ্য সেভ করুন',
              onPressed: shop.saved.ready.value
                  ? () => guarded(() => shop.toggleSaved(p))
                  : null,
              icon: Icon(
                saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                color: saved ? shopBlue : null,
              ),
            );
          }),
        IconButton(
          tooltip: 'কার্ট দেখুন',
          onPressed: _adding ? null : () => Get.to(() => const CartScreen()),
          icon: const Icon(Icons.shopping_bag_outlined),
        ),
      ],
      body: body,
      bottom: showProduct ? _purchaseBar(p, v) : null,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}