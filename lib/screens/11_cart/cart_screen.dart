import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../commerce/shop_models.dart';
import '../../commerce/shop_service.dart';
import '../../commerce/shop_widgets.dart';
import '../10_product_details/product_details_screen.dart';
import '../12_checkout/checkout_screen.dart';
import '../14_order_details/order_details_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final shop = ShopService.instance;

  @override
  void initState() {
    super.initState();
    shop.loadLocal();
  }

  void openOrder(String id) {
    Get.to(
          () => OrderDetailsScreen(
        orderId: id,
        showConfirmation: true,
      ),
    );
  }

  Future<void> proceed() {
    return guarded(() async {
      final checked = await shop.checkCart();

      final changes = checked.where((line) {
        return line['valid'] == true &&
            shop.cart.any(
                  (old) =>
              old.key ==
                  '${line['productId']}:${line['variantId']}' &&
                  old.price != number(line['priceMinor']),
            );
      }).toList();

      if (changes.isNotEmpty) {
        final message = changes.map((line) {
          final old = shop.cart.firstWhere(
                (entry) =>
            entry.key ==
                '${line['productId']}:${line['variantId']}',
          );

          return '${old.name}: ${money(old.price)}'
              ' → ${money(number(line['priceMinor']))}';
        }).join('\n');

        final accepted = await confirm(
          'পণ্যের দাম বদলেছে',
          '$message\n\nবর্তমান দাম গ্রহণ করবেন?',
          action: 'নতুন দাম গ্রহণ করুন',
        );

        if (!accepted) return;
        await shop.acceptPrices(checked);
      }

      if (checked.any((line) => line['valid'] != true)) {
        throw StateError('চিহ্নিত পণ্য সংশোধন করুন অথবা সরান।');
      }

      Get.to(() => const CheckoutScreen());
    });
  }

  Future<void> closeAttempt() {
    return guarded(() async {
      final accepted = await confirm(
        'Attempt বন্ধ করবেন?',
        'Order হয়ে থাকলে সেটি খুলবে। না হলে cart edit করা যাবে।',
      );

      if (!accepted) return;

      final orderId = await shop.abandon();
      if (orderId != null) openOrder(orderId);
    });
  }

  Widget cartCard(CartLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ShopBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => Get.to(
                        () => ProductDetailsScreen(
                      productId: line.productId,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ShopImage(
                      line.image,
                      width: 78,
                      height: 78,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${line.unit}'
                            '${line.variantName.isEmpty ? '' : ' · ${line.variantName}'}',
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 6),
                      PriceText(line.price),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'পণ্য সরান',
                  onPressed: shop.busy.value || shop.locked
                      ? null
                      : () => guarded(() => shop.remove(line)),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                QuantityControl(
                  value: line.qty,
                  max: min(
                    99,
                    number(shop.validation[line.key]?['stockQty'], 99),
                  ),
                  onChanged: shop.busy.value || shop.locked
                      ? null
                      : (value) => guarded(
                        () => shop.quantity(line, value),
                  ),
                ),
                const Spacer(),
                Text(
                  money(line.subtotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: shopInk,
                  ),
                ),
              ],
            ),
            if (shop.validation[line.key]?['valid'] == false)
              Text(
                '${shop.validation[line.key]?['message']}',
                style: const TextStyle(color: Colors.deepOrange),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShopPage(
      title: 'আমার Cart',
      actions: [
        Obx(
              () => IconButton(
            tooltip: 'Cart পরিষ্কার করুন',
            onPressed: shop.cart.isNotEmpty &&
                !shop.busy.value &&
                !shop.locked
                ? () => guarded(() async {
              if (await confirm(
                'Cart পরিষ্কার করবেন?',
                'সব পণ্য cart থেকে সরবে।',
              )) {
                await shop.clear();
              }
            })
                : null,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ),
      ],
      body: Obx(() {
        if (shop.localError.value.isNotEmpty) {
          return ShopEmpty(
            shop.localError.value,
            retry: shop.loadLocal,
          );
        }

        if (!shop.localReady.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (shop.cart.isEmpty && !shop.locked) {
          return const ShopEmpty('Cart খালি। Store থেকে পণ্য যোগ করুন।');
        }

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (shop.locked)
              ShopBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sync_rounded, color: shopBlue),
                    const SizedBox(height: 10),
                    const Text(
                      'Order-এর ফল নিশ্চিত নয়',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'একই attempt retry করুন। এখন cart বদলানো যাবে না।',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: shop.busy.value
                          ? null
                          : () => guarded(() async {
                        openOrder(await shop.place({}));
                      }),
                      child: const Text('একই attempt retry করুন'),
                    ),
                    TextButton(
                      onPressed: shop.busy.value ? null : closeAttempt,
                      child: const Text('যাচাই করে attempt বন্ধ করুন'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            for (final line in shop.cart) cartCard(line),
            ShopBox(
              child: Column(
                children: [
                  totalRow('পণ্যের subtotal', shop.subtotal, bold: true),
                  const SizedBox(height: 10),
                  const Text(
                    'Delivery charge ও discount checkout-এ নিশ্চিত হবে।',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      }),
      bottom: Obx(
            () => FilledButton(
          onPressed: shop.cart.isNotEmpty &&
              !shop.busy.value &&
              !shop.locked &&
              shop.localReady.value
              ? proceed
              : null,
          child: Text(
            shop.busy.value
                ? 'যাচাই হচ্ছে…'
                : 'Checkout করুন · ${money(shop.subtotal)}',
          ),
        ),
      ),
    );
  }
}