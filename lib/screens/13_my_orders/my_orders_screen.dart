import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../commerce/shop_models.dart';
import '../../commerce/shop_service.dart';
import '../../commerce/shop_widgets.dart';
import '../11_cart/cart_screen.dart';
import '../14_order_details/order_details_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final shop = ShopService.instance;
  late Future<String> identity;

  String filter = 'all';
  int limit = 30;

  @override
  void initState() {
    super.initState();
    identity = shop.identity();
    shop.loadLocal();

    if (shop.config.value == null) {
      shop.loadCatalog();
    }
  }

  bool matches(String status) =>
      filter == 'all' ||
          filter == 'active' &&
              [
                'placed',
                'confirmed',
                'packing',
                'out_for_delivery',
              ].contains(status) ||
          filter == status;

  Future<void> help() => shopSheet<void>(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order খুঁজে পাচ্ছেন না?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'এই device-এর বর্তমান anonymous identity-এর order-ই '
              'এখানে দেখা যায়। App data মুছলে বা reinstall করলে '
              'access হারাতে পারেন।',
        ),
        const SizedBox(height: 14),
        const Text(
          'Order number নিজের reference হিসেবে রাখুন। '
              'শুধু নম্বর ও ফোন জানলেই private order দেখা বা '
              'account recovery করা যাবে না।',
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => dialStore(
            shop.config.value?.supportPhone ?? '',
          ),
          icon: const Icon(Icons.call_outlined),
          label: const Text('Store support-এ কল করুন'),
        ),
      ],
    ),
  ).then((_) {});

  Future<void> reorder(Map<String, dynamic> order) =>
      guarded(() async {
        if (!await confirm(
          'আবার কিনবেন?',
          'বর্তমান দাম ও stock যাচাই করে নতুন cart তৈরি হবে। '
              'Cart-এ আগে পণ্য থাকলে তা বদলে যাবে।',
          action: 'নতুন cart তৈরি করুন',
        )) {
          return;
        }

        final skipped = await shop.reorder(order);

        if (skipped.isNotEmpty) {
          await Get.dialog(
            AlertDialog(
              title: const Text('কিছু পণ্য যোগ হয়নি'),
              content: SingleChildScrollView(
                child: Text(skipped.join('\n')),
              ),
              actions: [
                TextButton(
                  onPressed: Get.back,
                  child: const Text('ঠিক আছে'),
                ),
              ],
            ),
          );
        }

        Get.to(() => const CartScreen());
      });

  @override
  Widget build(BuildContext context) => ShopPage(
    title: 'আমার অর্ডার',
    actions: [
      IconButton(
        tooltip: 'Order সহায়তা',
        onPressed: help,
        icon: const Icon(Icons.help_outline),
      ),
    ],
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: ShopBox(
            padding: const EdgeInsets.all(14),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: shopBlue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'এই device-এর anonymous identity-এর order। '
                        'App data মুছলে বা reinstall করলে access হারাতে পারেন।',
                  ),
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding:
          const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              for (final entry in const {
                'all': 'সব',
                'active': 'চলমান',
                'delivered': 'সম্পন্ন',
                'cancelled': 'বাতিল',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: filter == entry.key,
                    onSelected: (_) => setState(
                          () => filter = entry.key,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<String>(
            future: identity,
            builder: (_, auth) {
              if (auth.hasError) {
                return ShopEmpty(
                  ShopService.message(auth.error!),
                  retry: () => setState(
                        () => identity = shop.identity(),
                  ),
                );
              }

              if (!auth.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: shop.orders(auth.data!, limit: limit),
                builder: (_, snapshot) {
                  if (snapshot.hasError) {
                    return ShopEmpty(
                      ShopService.message(snapshot.error!),
                      retry: () => setState(() {}),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final all = snapshot.data!.docs.toList()
                    ..sort(
                          (a, b) =>
                          (date(b.data()['createdAt']) ??
                              DateTime(1970))
                              .compareTo(
                            date(a.data()['createdAt']) ??
                                DateTime(1970),
                          ),
                    );

                  final matching = all
                      .where(
                        (d) => matches(
                      '${d.data()['status']}',
                    ),
                  )
                      .toList();

                  final docs = matching.take(limit).toList();

                  return ListView(
                    padding:
                    const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    children: [
                      if (snapshot.data!.metadata.isFromCache)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'সেভ থাকা তথ্য দেখাচ্ছে; internet এলে status refresh হবে।',
                            style: TextStyle(
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                      if (docs.isEmpty)
                        const Padding(
                          padding:
                          EdgeInsets.symmetric(vertical: 40),
                          child: ShopEmpty(
                            'এই filter-এ কোনো অর্ডার পাওয়া যায়নি।',
                          ),
                        ),
                      for (final d in docs)
                        Padding(
                          padding:
                          const EdgeInsets.only(bottom: 14),
                          child: ShopBox(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${d.data()['orderNumber']}',
                                        style: const TextStyle(
                                          fontWeight:
                                          FontWeight.w900,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      money(
                                        number(
                                          d.data()['totalMinor'],
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontWeight:
                                        FontWeight.w900,
                                        color: shopBlue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  displayDate(
                                    d.data()['createdAt'],
                                  ),
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  statusLabel(
                                    '${d.data()['status']}',
                                  ),
                                  style: const TextStyle(
                                    color: shopBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final line in
                                    ((d.data()['lines']
                                    as List?) ??
                                        [])
                                        .take(3))
                                      ClipRRect(
                                        borderRadius:
                                        BorderRadius.circular(
                                          12,
                                        ),
                                        child: ShopImage(
                                          '${object(line)['imageUrl'] ?? ''}',
                                          width: 48,
                                          height: 48,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  children: [
                                    FilledButton.tonal(
                                      onPressed: () => Get.to(
                                            () => OrderDetailsScreen(
                                          orderId: d.id,
                                        ),
                                      ),
                                      child:
                                      const Text('বিস্তারিত'),
                                    ),
                                    Obx(
                                          () => TextButton(
                                        onPressed:
                                        shop.busy.value ||
                                            shop.locked
                                            ? null
                                            : () => reorder(
                                          d.data(),
                                        ),
                                        child: const Text(
                                          'আবার কিনুন',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (matching.length > limit)
                        OutlinedButton(
                          onPressed: () => setState(
                                () => limit += 30,
                          ),
                          child: const Text(
                            'আরও পুরোনো অর্ডার দেখুন',
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}