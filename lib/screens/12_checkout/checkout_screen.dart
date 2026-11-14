import 'dart:math';

import 'package:flutter/material.dart';

import '../../commerce/shop_models.dart';
import '../../commerce/shop_widgets.dart';

typedef CheckoutJson = Map<String, dynamic>;

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.zones,
    required this.lines,
    required this.loadStore,
  });

  final List<CheckoutJson> zones;
  final List<CartLine> lines;

  // নির্বাচিত ইউনিয়নের সর্বশেষ পণ্য, স্টক, দাম ও ডেলিভারি চার্জ।
  final Future<CheckoutJson> Function(int areaId) loadStore;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  int? _area;
  bool _checking = false;
  String _error = '';

  static const _blue = Color(0xFF1959E8);
  static const _ink = Color(0xFF162644);
  static const _muted = Color(0xFF596A80);

  int _id(dynamic value) => int.tryParse('$value') ?? 0;

  int _minor(dynamic value) {
    final price = double.tryParse('$value');
    if (price == null || !price.isFinite || price < 0) {
      throw const FormatException('দামের তথ্য সঠিক নয়।');
    }
    return (price * 100).round();
  }

  String _normalPhone(String input) {
    var value = input.trim().replaceAllMapped(
      RegExp('[০-৯]'),
          (m) => '০১২৩৪৫৬৭৮৯'.indexOf(m[0]!).toString(),
    );
    value = value.replaceAll(RegExp(r'[\s()-]'), '');
    if (value.startsWith('+880')) value = '0${value.substring(4)}';
    return value;
  }

  String _attemptKey() {
    final random = Random.secure();
    return List.generate(
      16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  @override
  void initState() {
    super.initState();
    if (widget.zones.length == 1) {
      _area = _id(widget.zones.first['id']);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  CheckoutJson? get _selectedZone {
    for (final zone in widget.zones) {
      if (_id(zone['id']) == _area) return zone;
    }
    return null;
  }

  int get _subtotal =>
      widget.lines.fold<int>(0, (sum, line) => sum + line.subtotal);

  InputDecoration _input(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      alignLabelWithHint: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE5F1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _blue, width: 1.5),
      ),
    );
  }

  Future<void> _review() async {
    if (_checking || !_form.currentState!.validate()) return;
    final area = _area;
    if (area == null || widget.lines.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _error = '';
    });

    try {
      final data = await widget.loadStore(area);
      if (!mounted) return;

      final rawZones = data['zones'];
      final rawItems = data['items'];
      if (rawZones is! List || rawItems is! List) {
        throw const FormatException('স্টোরের তথ্য পাওয়া যায়নি। আবার চেষ্টা করুন।');
      }

      CheckoutJson? zone;
      for (final z in rawZones.whereType<CheckoutJson>()) {
        if (_id(z['id']) == area) {
          zone = z;
          break;
        }
      }

      if (zone == null) {
        throw const FormatException(
          'এই ইউনিয়নে এখন ডেলিভারি বন্ধ। কার্টে ফিরে আবার ঠিকানা দিন।',
        );
      }

      final packs = <String, CheckoutJson>{
        for (final row in rawItems.whereType<CheckoutJson>())
          '${row['pack']}': row,
      };

      final cart = <String, dynamic>{};
      final summary = <String>[];
      final fee = _minor(zone['fee']);
      var productsTotal = 0;

      for (final line in widget.lines) {
        final packId = '${line.variantId}';
        final pack = packs[packId];

        if (pack == null || 'mysql:${pack['product']}' != line.productId) {
          throw FormatException('${line.name} এই ইউনিয়নে পাওয়া যাচ্ছে না।');
        }

        final stock = _id(pack['stock']);
        if (line.qty < 1 || line.qty > 99 || stock < line.qty) {
          throw FormatException(
            '${line.name}: স্টকে আছে $stock প্যাক। কার্টে ফিরে পরিমাণ ঠিক করুন।',
          );
        }

        final price = _minor(pack['price']);
        final amount = price * line.qty;
        productsTotal += amount;

        cart[packId] = {'qty': line.qty, 'priceMinor': price};

        final packName = '${pack['label'] ?? ''}'.trim();
        final title = packName.isEmpty ? line.name : '${line.name} · $packName';
        summary.add('$title × ${line.qty} = ${money(amount)}');

        if (price != line.price) {
          summary.add('প্রতি প্যাকের দাম বদলেছে: ${money(line.price)} → ${money(price)}');
        }
      }

      final name = _name.text.trim();
      final phone = _normalPhone(_phone.text);
      final address = _address.text.trim();

      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('অর্ডারটি দেখে নিন'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(phone),
                Text('$address, ${zone!['name']}'),
                const Divider(height: 24),
                for (final text in summary)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(text),
                  ),
                const Divider(height: 24),
                totalRow('পণ্যের দাম', productsTotal),
                totalRow('ডেলিভারি', fee),
                const SizedBox(height: 6),
                totalRow('সর্বমোট', productsTotal + fee, bold: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ফিরে যান'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('অর্ডার নিশ্চিত করুন'),
            ),
          ],
        ),
      );

      if (!mounted || accepted != true) return;

      // কার্ট এই request সেভ করে mobile.php?a=place-এ একবার পাঠাবে।
      Navigator.pop<CheckoutJson>(context, {
        'key': _attemptKey(),
        'name': name,
        'phone': phone,
        'address': address,
        'area': area,
        'feeMinor': fee,
        'cart': cart,
      });
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'সর্বশেষ দাম ও স্টক যাচাই করা যায়নি। আবার চেষ্টা করুন।');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zone = _selectedZone;
    final fee = zone == null ? null : _minor(zone['fee']);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FD),
      appBar: AppBar(
        title: const Text('চেকআউট'),
        backgroundColor: const Color(0xFFF5F8FD),
        foregroundColor: _ink,
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              ShopBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ডেলিভারির ঠিকানা',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'যিনি পণ্য গ্রহণ করবেন, তাঁর তথ্য দিন।',
                      style: TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _name,
                      enabled: !_checking,
                      maxLength: 100,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      decoration: _input('প্রাপকের নাম', Icons.person_outline),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'প্রাপকের নাম লিখুন।'
                          : null,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phone,
                      enabled: !_checking,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      textInputAction: TextInputAction.next,
                      decoration: _input('মোবাইল নম্বর', Icons.phone_outlined),
                      validator: (v) => RegExp(r'^01[3-9][0-9]{8}$')
                          .hasMatch(_normalPhone(v ?? ''))
                          ? null
                          : 'সঠিক বাংলাদেশি মোবাইল নম্বর দিন।',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _area,
                      isExpanded: true,
                      decoration: _input('ডেলিভারি ইউনিয়ন', Icons.map_outlined),
                      items: [
                        for (final z in widget.zones)
                          DropdownMenuItem<int>(
                            value: _id(z['id']),
                            child: Text(
                              '${z['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _checking
                          ? null
                          : (value) => setState(() {
                        _area = value;
                        _error = '';
                      }),
                      validator: (v) => v == null ? 'ইউনিয়ন বেছে নিন।' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _address,
                      enabled: !_checking,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 400,
                      autofillHints: const [AutofillHints.fullStreetAddress],
                      decoration: _input(
                        'পূর্ণ ঠিকানা',
                        Icons.location_on_outlined,
                        hint: 'গ্রাম, পাড়া, বাড়ি বা কাছের পরিচিত স্থান',
                      ),
                      validator: (v) => (v ?? '').trim().length < 8
                          ? 'পণ্য পৌঁছানোর জন্য আরেকটু বিস্তারিত ঠিকানা দিন।'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ShopBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'আপনার কেনাকাটা',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    for (final line in widget.lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${line.name}'
                                    '${line.variantName.isEmpty ? '' : ' · ${line.variantName}'}'
                                    ' × ${line.qty}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(money(line.subtotal)),
                          ],
                        ),
                      ),
                    const Divider(height: 18),
                    totalRow('পণ্যের দাম', _subtotal),
                    const SizedBox(height: 6),
                    if (fee == null)
                      const Text('ইউনিয়ন বেছে নিলে ডেলিভারি চার্জ দেখাবে।')
                    else ...[
                      totalRow('ডেলিভারি চার্জ', fee),
                      const Divider(height: 18),
                      totalRow('আনুমানিক মোট', _subtotal + fee, bold: true),
                    ],
                  ],
                ),
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _checking || widget.lines.isEmpty ? null : _review,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(_checking ? 'যাচাই হচ্ছে…' : 'অর্ডার দেখে নিন'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}