import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../commerce/shop_models.dart';
import '../../commerce/shop_service.dart';
import '../../commerce/shop_widgets.dart';
import '../11_cart/cart_screen.dart';
import '../13_my_orders/my_orders_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String? orderId;
  final bool showConfirmation;

  const OrderDetailsScreen({
    super.key,
    this.orderId,
    this.showConfirmation = false,
  });

  @override
  State<OrderDetailsScreen> createState() =>
      _OrderDetailsScreenState();
}

class _OrderDetailsScreenState
    extends State<OrderDetailsScreen> {
  final shop = ShopService.instance;
  late Future<String> identity;

  @override
  void initState() {
    super.initState();
    identity = shop.identity();
    shop.loadLocal();
  }

  Future<void> cancel() => guarded(() async {
    final controller = TextEditingController();

    final reason = await shopSheet<String>(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'বাতিলের কারণ',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'কারণ লিখুন',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length < 2) {
                shopError(StateError('কারণ লিখুন।'));
                return;
              }
              Get.back(result: controller.text.trim());
            },
            child: const Text('পরবর্তী ধাপ'),
          ),
        ],
      ),
    );

    Future<void>.delayed(
      const Duration(milliseconds: 350),
      controller.dispose,
    );

    if (reason == null) return;

    if (await confirm(
      'অর্ডার বাতিল করবেন?',
      'Firestore cancellation গ্রহণ করলে order বাতিল হবে।',
      action: 'বাতিল করুন',
    )) {
      await shop.cancel(widget.orderId!, reason);
    }
  });

  Future<void> reorder(Map<String, dynamic> order) =>
      guarded(() async {
        if (!await confirm(
          'আবার কিনবেন?',
          'আগের cart বদলে বর্তমান দাম ও stock অনুযায়ী cart তৈরি হবে।',
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

  Future<void> issue() => shopSheet<void>(
    _IssueSheet(orderId: widget.orderId!),
  ).then((_) {});

  Future<void> requests() => shopSheet<void>(
    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: shop.db
          .collection('orders/${widget.orderId}/issues')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'সমস্যা / Return-এর অবস্থা',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (s.hasError)
            Text(ShopService.message(s.error!)),
          if (!s.hasData && !s.hasError)
            const CircularProgressIndicator(),
          if (s.hasData && s.data!.docs.isEmpty)
            const Text('এখনো কোনো অনুরোধ করা হয়নি।'),
          if (s.hasData)
            for (final d in s.data!.docs)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ShopBox(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.data()['type'] == 'return' ? 'Return' : 'সমস্যা'}'
                            ' · ${d.data()['reason']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${d.data()['description'] ?? ''}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'অনুরোধ: '
                            '${statusLabel('${d.data()['requestStatus']}')}',
                      ),
                      Text(
                        'Refund: '
                            '${statusLabel('${d.data()['refundStatus']}')}'
                            ' · ${money(number(d.data()['refundMinor']))}',
                      ),
                      if ('${d.data()['response'] ?? ''}'
                          .isNotEmpty)
                        Text(
                          'Store: ${d.data()['response']}',
                        ),
                      Text(
                        displayDate(
                          d.data()['createdAt'],
                        ),
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const Text(
            'Return অনুমোদন, refund সিদ্ধান্ত ও refund দেওয়া—আলাদা ধাপ।',
          ),
        ],
      ),
    ),
  ).then((_) {});

  Widget details(
      Map<String, dynamic> o,
      bool cached,
      ) {
    final status = '${o['status']}';
    final delivery = object(o['address']);

    const stages = [
      'placed',
      'confirmed',
      'packing',
      'out_for_delivery',
      'delivered',
    ];

    final step = stages.indexOf(status);
    final history =
    ((o['statusHistory'] as List?) ?? []).map(object).toList();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (o['demoMode'] == true)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'DEMO ORDER • এটি বাস্তব delivery order নয়।',
              style: TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        if (cached)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'Offline তথ্য; internet এলে সর্বশেষ status দেখাবে।',
              style: TextStyle(color: Colors.deepOrange),
            ),
          ),
        if (widget.showConfirmation && status == 'placed')
          Container(
            padding: const EdgeInsets.all(22),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE4F7F1),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 56,
                  color: Colors.teal,
                ),
                SizedBox(height: 10),
                Text(
                  'অর্ডারের অনুরোধ জমা হয়েছে',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.teal,
                  ),
                ),
                Text(
                  'Stock ও delivery যাচাইয়ের পর দোকান confirm করবে।',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ShopBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                '${o['orderNumber']}',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                displayDate(o['createdAt']),
                style: const TextStyle(color: Colors.blueGrey),
              ),
              const SizedBox(height: 18),
              if (status == 'cancelled') ...[
                Text(
                  statusLabel(status),
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('${o['cancellationReason'] ?? ''}'),
              ] else
                for (var i = 0; i < stages.length; i++)
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          i <= step
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: i <= step
                              ? shopBlue
                              : Colors.blueGrey.shade200,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            statusLabel(stages[i]),
                            style: TextStyle(
                              fontWeight: i == step
                                  ? FontWeight.w900
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (history.any(
                              (x) => x['status'] == stages[i],
                        ))
                          Text(
                            displayDate(
                              history.firstWhere(
                                    (x) => x['status'] == stages[i],
                              )['at'],
                            ).split(' · ').first,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey,
                            ),
                          ),
                      ],
                    ),
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
                'পণ্য ও হিসাব',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              for (final x in
              ((o['lines'] as List?) ?? []).map(object))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ShopImage(
                      '${x['imageUrl']}',
                      width: 48,
                      height: 48,
                    ),
                  ),
                  title: Text('${x['name']}'),
                  subtitle: Text(
                    '${x['variantName'] ?? ''} · '
                        '${x['qty']} ${x['unit']} × '
                        '${money(number(x['priceMinor']))}',
                  ),
                  trailing: Text(
                    money(number(x['subtotalMinor'])),
                  ),
                ),
              const Divider(),
              totalRow(
                'Subtotal',
                number(o['subtotalMinor']),
              ),
              totalRow(
                'Delivery',
                number(o['deliveryMinor']),
              ),
              if (number(o['discountMinor']) > 0)
                totalRow(
                  'Discount',
                  -number(o['discountMinor']),
                ),
              totalRow(
                'মোট',
                number(o['totalMinor']),
                bold: true,
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
                'Delivery ও payment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${delivery['name']} · ${delivery['phone']}',
              ),
              Text('${delivery['zoneLabel']}'),
              Text('${delivery['address']}'),
              if ('${delivery['landmark'] ?? ''}'.isNotEmpty)
                Text('Landmark: ${delivery['landmark']}'),
              if ('${delivery['note'] ?? ''}'.isNotEmpty)
                Text('Note: ${delivery['note']}'),
              const Divider(height: 28),
              const Text('Cash on Delivery'),
              Text(
                'Payment: ${statusLabel('${o['paymentStatus']}')}',
              ),
              TextButton(
                onPressed: () => policies(
                  StoreConfig({
                    'deliveryPolicy': o['deliveryPolicy'],
                    'returnPolicy': o['returnPolicy'],
                  }),
                ),
                child: const Text(
                  'এই order-এর delivery ও return policy',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShopBox(
          child: Obx(
                () => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => dialStore(
                    '${o['supportPhone'] ?? ''}',
                  ),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Store support'),
                ),
                const SizedBox(height: 8),
                if (status == 'placed')
                  OutlinedButton(
                    onPressed: shop.busy.value ? null : cancel,
                    child: const Text('Order বাতিল করুন'),
                  ),
                OutlinedButton(
                  onPressed: shop.busy.value ? null : issue,
                  child: const Text(
                    'সমস্যা / ফেরতের অনুরোধ',
                  ),
                ),
                TextButton(
                  onPressed: requests,
                  child: const Text(
                    'অনুরোধ ও refund-এর অবস্থা',
                  ),
                ),
                TextButton(
                  onPressed: shop.busy.value || shop.locked
                      ? null
                      : () => reorder(o),
                  child: const Text('আবার কিনুন'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ShopPage(
    title: 'অর্ডারের বিস্তারিত',
    actions: [
      IconButton(
        tooltip: 'আমার অর্ডার',
        onPressed: () => Get.to(
              () => const MyOrdersScreen(),
        ),
        icon: const Icon(Icons.receipt_long_outlined),
      ),
    ],
    body: widget.orderId == null || widget.orderId!.isEmpty
        ? const ShopEmpty('Order ID দেওয়া হয়নি।')
        : FutureBuilder<String>(
      future: identity,
      builder: (_, auth) {
        if (auth.hasError) {
          return ShopEmpty(
            ShopService.message(auth.error!),
          );
        }

        if (!auth.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return StreamBuilder<
            DocumentSnapshot<Map<String, dynamic>>>(
          stream: shop.order(widget.orderId!),
          builder: (_, snapshot) {
            if (snapshot.hasError) {
              return ShopEmpty(
                ShopService.message(snapshot.error!),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final o = snapshot.data!.data();

            if (o == null ||
                o['ownerUid'] != auth.data) {
              return const ShopEmpty(
                'এই পরিচয়ের order পাওয়া যায়নি।',
              );
            }

            return details(
              o,
              snapshot.data!.metadata.isFromCache,
            );
          },
        );
      },
    ),
  );
}

class _IssueSheet extends StatefulWidget {
  final String orderId;

  const _IssueSheet({required this.orderId});

  @override
  State<_IssueSheet> createState() => _IssueSheetState();
}

class _IssueSheetState extends State<_IssueSheet> {
  final shop = ShopService.instance;
  final reason = TextEditingController();
  final description = TextEditingController();

  late final String requestId = shop.newId();
  String type = 'issue';
  String failure = '';
  bool submitting = false;
  bool frozen = false;

  @override
  void dispose() {
    reason.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (reason.text.trim().length < 2) {
      shopError(StateError('কারণ লিখুন।'));
      return;
    }

    setState(() {
      submitting = true;
      frozen = true;
      failure = '';
    });

    try {
      await shop.issue(
        orderId: widget.orderId,
        requestId: requestId,
        type: type,
        reason: reason.text.trim(),
        description: description.text.trim(),
      );

      if (!mounted) return;

      Get.back();
      Get.snackbar(
        'অনুরোধ জমা হয়েছে',
        'Review ও refund-এর অবস্থা আলাদাভাবে দেখুন।',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      if (mounted) {
        setState(() => failure = ShopService.message(e));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'সমস্যা / ফেরতের অনুরোধ',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Return শুধু delivered order ও নির্ধারিত সময়সীমায়। '
            'আবেদন মানেই refund approval নয়। '
            'এই version-এ লিখিত আবেদন নেওয়া হয়।',
      ),
      const SizedBox(height: 16),
      AbsorbPointer(
        absorbing: frozen,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(
                labelText: 'অনুরোধের ধরন',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'issue',
                  child: Text('সমস্যা জানান'),
                ),
                DropdownMenuItem(
                  value: 'return',
                  child: Text('পণ্য ফেরত'),
                ),
              ],
              onChanged: (v) => setState(
                    () => type = v!,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reason,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'কারণ',
              ),
            ),
            TextField(
              controller: description,
              maxLength: 2000,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'বিবরণ (optional)',
              ),
            ),
          ],
        ),
      ),
      if (failure.isNotEmpty)
        Padding(
          padding:
          const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '$failure\nএকই অনুরোধ আবার চেষ্টা করতে পারবেন।',
            style: const TextStyle(
              color: Colors.deepOrange,
            ),
          ),
        ),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: submitting ? null : submit,
          child: Text(
            submitting
                ? 'জমা হচ্ছে…'
                : 'অনুরোধ জমা দিন',
          ),
        ),
      ),
    ],
  );
}