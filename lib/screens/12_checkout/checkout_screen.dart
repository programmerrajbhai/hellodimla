import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../commerce/shop_models.dart';
import '../../commerce/shop_service.dart';
import '../../commerce/shop_widgets.dart';
import '../../services/app_settings_service.dart';
import '../../services/settings_widgets.dart' show showPolicy;
import '../14_order_details/order_details_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final shop = ShopService.instance;
  final form = GlobalKey<FormState>();

  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final landmark = TextEditingController();
  final note = TextEditingController();

  String? zoneId;
  Map<String, dynamic>? quote;

  bool acceptedIdentity = false;
  bool acceptedPolicies = false;

  Future<void> openPolicy(
      String key,
      String title,
      ) =>
      guarded(() async {
        final settings = AppSettingsService.instance;
        await settings.initialize();
        await showPolicy(key, title);
      });

  @override
  void initState() {
    super.initState();
    setup();
  }

  Future<void> setup() async {
    await shop.loadLocal();

    if (shop.config.value == null) {
      await shop.loadCatalog();
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      name,
      phone,
      address,
      landmark,
      note,
    ]) {
      c.dispose();
    }

    super.dispose();
  }

  void invalidate() {
    if (quote != null) {
      setState(() => quote = null);
    }
  }

  Map<String, dynamic> get delivery => {
    'name': name.text.trim(),
    'phone': normalized(phone.text),
    'zoneId': zoneId,
    'address': address.text.trim(),
    'landmark': landmark.text.trim(),
    'note': note.text.trim(),
  };

  Future<void> savedAddresses() async {
    final choice = await shopSheet<Map<String, dynamic>>(
      Obx(
            () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved delivery address',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (shop.addresses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Text(
                  'প্রথম সফল order-এর address এখানে সেভ হবে।',
                ),
              ),
            for (var i = 0; i < shop.addresses.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${shop.addresses[i]['name']} · '
                      '${shop.addresses[i]['phone']}',
                ),
                subtitle: Text(
                  '${shop.addresses[i]['address']}',
                ),
                onTap: () => Get.back(
                  result: shop.addresses[i],
                ),
                trailing: IconButton(
                  tooltip: 'Address মুছুন',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: shop.busy.value
                      ? null
                      : () => guarded(() async {
                    if (await confirm(
                      'Address মুছবেন?',
                      'শুধু saved address মুছবে। '
                          'আগের order বদলাবে না।',
                    )) {
                      await shop.deleteAddress(i);
                    }
                  }),
                ),
              ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    setState(() {
      name.text = '${choice['name'] ?? ''}';
      phone.text = '${choice['phone'] ?? ''}';
      address.text = '${choice['address'] ?? ''}';
      landmark.text = '${choice['landmark'] ?? ''}';
      note.text = '${choice['note'] ?? ''}';

      zoneId = shop.config.value?.zones.any(
            (z) => z['id'] == choice['zoneId'],
      ) ==
          true
          ? choice['zoneId'] as String
          : null;

      quote = null;
    });
  }

  Future<void> verify() => guarded(() async {
    if (!form.currentState!.validate()) return;

    if (!acceptedIdentity || !acceptedPolicies) {
      throw StateError(
        'Privacy/Terms এবং anonymous identity-এর '
            'তথ্য পড়ে সম্মতি দিন।',
      );
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final q = await shop.quote(delivery);

    if (mounted) {
      setState(() => quote = q);
    }
  });

  Future<void> submit() => guarded(() async {
    if (shop.locked) {
      final id = await shop.place({});

      Get.off(
            () => OrderDetailsScreen(
          orderId: id,
          showConfirmation: true,
        ),
      );
      return;
    }

    if (quote == null ||
        !form.currentState!.validate() ||
        !acceptedIdentity ||
        !acceptedPolicies) {
      return;
    }

    final q = quote!;

    final agreed = await confirm(
      'অর্ডারের অনুরোধ নিশ্চিত করুন',
      '${q['demoMode'] == true ? 'DEMO ORDER • বাস্তব delivery নয়\n' : ''}'
          'Cash on Delivery\n'
          'মোট ${money(number(q['totalMinor']))}\n\n'
          'Delivery: ${address.text}\n\n'
          'জমা হলে stock সংরক্ষিত হবে। '
          'দোকান delivery যাচাই করে confirm করবে।',
      action: 'অনুরোধ জমা দিন',
    );

    if (!agreed) return;

    final id = await shop.place(q);

    Get.off(
          () => OrderDetailsScreen(
        orderId: id,
        showConfirmation: true,
      ),
    );
  });

  Future<void> abandon() => guarded(() async {
    final agreed = await confirm(
      'Attempt যাচাই করে বন্ধ করুন',
      'Order হয়ে থাকলে সেই order খুলবে। '
          'না হলে নতুন তথ্য দিয়ে আবার যাচাই করা যাবে।',
    );

    if (!agreed) return;

    final id = await shop.abandon();

    if (id != null) {
      Get.off(
            () => OrderDetailsScreen(
          orderId: id,
          showConfirmation: true,
        ),
      );
    } else if (mounted) {
      setState(() => quote = null);
    }
  });

  Widget field(
      TextEditingController controller,
      String label, {
        int min = 0,
        int max = 160,
        int lines = 1,
        TextInputType? keyboard,
      }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          maxLength: max,
          minLines: lines,
          maxLines: lines,
          keyboardType: keyboard,
          onChanged: (_) => invalidate(),
          decoration: InputDecoration(
            labelText: label,
            counterText: '',
          ),
          validator: (v) => (v ?? '').trim().length < min
              ? '$label সঠিকভাবে লিখুন।'
              : null,
        ),
      );

  @override
  Widget build(BuildContext context) => ShopPage(
    title: 'Checkout',
    body: Obx(() {
      final cfg = shop.config.value;
      final zones = cfg?.zones ?? [];
      final locked = shop.locked || shop.busy.value;

      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (shop.locked)
            ShopBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'আগের attempt-এর ফল নিশ্চিত করুন',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'নতুন order-এর আগে আগের attempt-এর ফল যাচাই করুন।',
                  ),
                  TextButton(
                    onPressed: shop.busy.value ? null : abandon,
                    child: const Text(
                      'যাচাই করে attempt বন্ধ করুন',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ShopBox(
            child: AbsorbPointer(
              absorbing: locked,
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Delivery information',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Saved addresses',
                          onPressed: savedAddresses,
                          icon: const Icon(
                            Icons.bookmark_outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    field(
                      name,
                      'আপনার নাম',
                      min: 2,
                      max: 80,
                    ),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      maxLength: 18,
                      onChanged: (_) => invalidate(),
                      decoration: const InputDecoration(
                        labelText: 'মোবাইল নম্বর',
                        counterText: '',
                      ),
                      validator: (v) =>
                      RegExp(r'^(?:\+88)?01[3-9]\d{8}$')
                          .hasMatch(
                        normalized(v ?? '').replaceAll(
                          RegExp(r'[\s()-]'),
                          '',
                        ),
                      )
                          ? null
                          : 'সঠিক বাংলাদেশি মোবাইল নম্বর লিখুন।',
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey(zoneId),
                      initialValue: zoneId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'ইউনিয়ন / Delivery এলাকা',
                      ),
                      items: zones
                          .map(
                            (z) => DropdownMenuItem(
                          value: '${z['id']}',
                          child: Text(
                            '${z['label']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                          .toList(),
                      validator: (v) => v == null
                          ? 'Delivery এলাকা নির্বাচন করুন।'
                          : null,
                      onChanged: (v) => setState(() {
                        zoneId = v;
                        quote = null;
                      }),
                    ),
                    if (zones.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        child: Text(
                          'Store-এর delivery এলাকা এখনো চালু হয়নি।',
                          style: TextStyle(
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    field(
                      address,
                      'পূর্ণ delivery address',
                      min: 8,
                      max: 400,
                      lines: 3,
                    ),
                    field(
                      landmark,
                      'Landmark (optional)',
                      max: 160,
                    ),
                    field(
                      note,
                      'Delivery note (optional)',
                      max: 300,
                      lines: 2,
                    ),
                    const Text(
                      'GPS লাগে না। Order সফলভাবে জমা হলে '
                          'stock সংরক্ষিত হবে। দোকান delivery '
                          'যাচাই করে confirm করবে।',
                      style: TextStyle(
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ShopBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'তোমার কেনাকাটা',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final x in shop.cart)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${x.name}'
                                '${x.variantName.isEmpty ? '' : ' (${x.variantName})'}'
                                ' × ${x.qty}',
                          ),
                        ),
                        Text(money(x.subtotal)),
                      ],
                    ),
                  ),
                const Divider(height: 24),
                if (quote == null)
                  const Text(
                    'মোট টাকা পেতে নিচে বর্তমান দাম '
                        'ও delivery charge যাচাই করুন।',
                  )
                else ...[
                  totalRow(
                    'Subtotal',
                    number(quote!['subtotalMinor']),
                  ),
                  totalRow(
                    'Delivery charge',
                    number(quote!['deliveryMinor']),
                  ),
                  if (number(quote!['discountMinor']) > 0)
                    totalRow(
                      'Discount',
                      -number(quote!['discountMinor']),
                    ),
                  const Divider(),
                  totalRow(
                    'Final total',
                    number(quote!['totalMinor']),
                    bold: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShopBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.payments_outlined,
                    color: shopBlue,
                  ),
                  title: Text('Cash on Delivery'),
                  subtitle: Text(
                    'পণ্য গ্রহণের সময় টাকা দিন।',
                  ),
                ),
                TextButton.icon(
                  onPressed: () => policies(cfg),
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text(
                    'Delivery ও return policy',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => openPolicy(
                        'privacy',
                        'Privacy Policy',
                      ),
                      child: const Text('Privacy Policy'),
                    ),
                    TextButton(
                      onPressed: () => openPolicy(
                        'terms',
                        'Terms of Use',
                      ),
                      child: const Text('Terms of Use'),
                    ),
                    TextButton(
                      onPressed: () => openPolicy(
                        'deletion',
                        'Data deletion',
                      ),
                      child: const Text('Data deletion'),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: acceptedPolicies,
                  onChanged: locked
                      ? null
                      : (value) => setState(() {
                    acceptedPolicies = value ?? false;
                  }),
                  title: const Text(
                    'অর্ডারের শর্ত ও তথ্য ব্যবহারের বিবরণ বুঝেছি।',
                  ),
                  subtitle: const Text(
                    'নাম, ফোন ও ঠিকানা order processing '
                        'এবং delivery-এর জন্য store ও সংশ্লিষ্ট '
                        'delivery কর্মীর কাছে যাবে।',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: acceptedIdentity,
                  onChanged: locked
                      ? null
                      : (v) => setState(
                        () => acceptedIdentity = v ?? false,
                  ),
                  title: const Text(
                    'এই device-এর anonymous identity দিয়ে order হবে।',
                  ),
                  subtitle: const Text(
                    'App data মুছলে বা reinstall করলে নিজের '
                        'order-এর access হারাতে পারেন। Order number '
                        'ও ফোন দিয়ে account উদ্ধার করা যাবে না।',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }),
    bottom: Obx(
          () => FilledButton(
        onPressed: shop.busy.value ||
            !shop.localReady.value ||
            shop.cart.isEmpty
            ? null
            : shop.locked
            ? submit
            : quote == null
            ? verify
            : submit,
        child: Text(
          shop.busy.value
              ? 'যাচাই হচ্ছে…'
              : shop.locked
              ? 'একই attempt আবার চেষ্টা করুন'
              : quote == null
              ? 'Delivery ও মোট টাকা যাচাই করুন'
              : 'অনুরোধ জমা দিন · '
              '${money(number(quote!['totalMinor']))}',
        ),
      ),
    ),
  );
}