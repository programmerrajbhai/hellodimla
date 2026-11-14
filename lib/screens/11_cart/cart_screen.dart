import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../commerce/shop_models.dart';
import '../../commerce/shop_service.dart';
import '../../commerce/shop_widgets.dart';
import '../../core/network/service_api.dart';
import '../10_product_details/product_details_screen.dart';
import '../12_checkout/checkout_screen.dart';

typedef _Json = Map<String, dynamic>;

const _blue = Color(0xFF1959E8);
const _ink = Color(0xFF162644);
const _muted = Color(0xFF596A80);
const _bg = Color(0xFFF5F8FD);

int _id(dynamic v) => int.tryParse('$v') ?? 0;

int _minor(dynamic v) {
  final price = double.tryParse('$v');
  if (price == null || !price.isFinite || price < 0) {
    throw const FormatException('দামের তথ্য সঠিক নয়।');
  }
  return (price * 100).round();
}

String _randomHex(int bytes) {
  final random = Random.secure();
  return List.generate(
    bytes,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String _phone(String value) {
  var phone = value.trim().replaceAllMapped(
    RegExp('[০-৯]'),
        (m) => '০১২৩৪৫৬৭৮৯'.indexOf(m[0]!).toString(),
  );
  phone = phone.replaceAll(RegExp(r'[\s()-]'), '');
  if (phone.startsWith('+880')) phone = '0${phone.substring(4)}';
  return phone;
}

class _StoreError implements Exception {
  const _StoreError(this.message, {this.status = 0});
  final String message;
  final int status;

  @override
  String toString() => message;
}

class _StoreApi {
  final prefs = SharedPreferencesAsync();

  // mysql_main.dart-এ ব্যবহৃত ডিভাইস পরিচয়টিই ব্যবহার করা হচ্ছে।
  static const tokenKey = 'sd.token';
  static const pendingKey = 'hello.store.checkout.pending.v1';

  Future<_Json> request(
      String action, {
        Map<String, String> query = const {},
        _Json? body,
      }) async {
    final url = ServiceApi.menuIcon(1).resolve('mobile.php').replace(
      queryParameters: {'a': action, ...query},
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);

    Future<_Json> send() async {
      final request = await client.openUrl(body == null ? 'GET' : 'POST', url);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      if (body != null) {
        var token = await prefs.getString(tokenKey);
        if (token == null) {
          token = _randomHex(32);
          await prefs.setString(tokenKey, token);
        }
        if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
          throw const _StoreError('ডিভাইস পরিচয় সঠিক নয়।');
        }
        request.headers.set('X-Device-Token', token);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(text);
      if (decoded is! _Json) {
        throw const _StoreError('সার্ভার থেকে সঠিক উত্তর পাওয়া যায়নি।');
      }
      if (response.statusCode != 200) {
        throw _StoreError(
          '${decoded['error'] ?? 'সার্ভারে অনুরোধ সম্পন্ন হয়নি।'}',
          status: response.statusCode,
        );
      }
      return decoded;
    }

    try {
      return await send().timeout(const Duration(seconds: 20));
    } finally {
      client.close(force: true);
    }
  }

  Future<_Json?> pending() async {
    final raw = await prefs.getString(pendingKey);
    if (raw == null) return null;
    return jsonDecode(raw) as _Json;
  }

  Future<void> savePending(_Json state) =>
      prefs.setString(pendingKey, jsonEncode(state));

  Future<void> removePending() => prefs.remove(pendingKey);
}

String _cartSignature(Iterable<CartLine> cart) {
  final rows = cart.map((l) => '${l.key}/${l.qty}/${l.price}').toList()..sort();
  return jsonEncode(rows);
}

String _message(Object error) {
  if (error is _StoreError) return error.message;
  if (error is SocketException || error is TimeoutException) {
    return 'সার্ভারের সঙ্গে যোগাযোগ হয়নি। সংযোগ দেখে আবার চেষ্টা করুন।';
  }
  return ShopService.message(error);
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final shop = ShopService.instance;
  final api = _StoreApi();

  bool loading = true;
  bool working = false;
  String error = '';
  _Json? pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      await shop.loadLocal();
      final saved = await api.pending();
      if (mounted) setState(() => pending = saved);
    } catch (e) {
      if (mounted) setState(() => error = _message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() task) async {
    if (working) return;
    setState(() => working = true);
    try {
      await task();
    } catch (e) {
      _notice(_message(e));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _checkout() => _run(() async {
    if (shop.locked || shop.cart.isEmpty || pending != null) return;

    // ঠিকানা লেখার আগে অন্তত একটি চালু ডেলিভারি ইউনিয়ন থাকতে হবে।
    final store = await api.request('store', query: {'area': '0'});
    final zones = (store['zones'] as List).whereType<_Json>().toList();
    if (zones.isEmpty) {
      throw const _StoreError(
        'এখন কোনো ইউনিয়নে ডেলিভারি চালু নেই। কার্টের পণ্যগুলো রাখা হয়েছে।',
      );
    }

    if (!mounted) return;
    final snapshot = shop.cart.toList();
    final order = await Navigator.of(context).push<_Json>(
      MaterialPageRoute<_Json>(
        builder: (_) => CheckoutScreen(
          zones: zones,
          lines: snapshot,
          loadStore: (areaId) => api.request(
            'store',
            query: {'area': '$areaId'},
          ),
        ),
      ),
    );

    if (!mounted || order == null) return;
    final signature = _cartSignature(snapshot);
    if (_cartSignature(shop.cart) != signature) {
      throw const _StoreError('কার্ট বদলেছে। আবার মোট দাম দেখে নিন।');
    }

    final state = <String, dynamic>{
      'request': order,
      'signature': signature,
    };

    // POST-এর আগেই key সেভ হয়। নেট কেটে গেলে একই অর্ডার পুনরায় যাচাই হবে।
    await api.savePending(state);
    if (mounted) setState(() => pending = state);
    await _finish(state);
  });

  Future<void> _finish(_Json state) async {
    var orderId = _id(state['confirmedId']);

    if (orderId <= 0) {
      try {
        final result = await api.request(
          'place',
          body: Map<String, dynamic>.from(state['request'] as Map),
        );
        orderId = _id(result['id']);
        if (orderId <= 0) {
          throw const _StoreError('অর্ডারের ফল নিশ্চিত হয়নি। একই অর্ডার যাচাই করুন।');
        }
      } on _StoreError catch (e) {
        // এই API-তে 400/409 মানে অনুরোধ প্রত্যাখ্যাত; লেনদেন সম্পন্ন হয়নি।
        if (e.status == 400 || e.status == 409) {
          await api.removePending();
          if (mounted) setState(() => pending = null);
        }
        rethrow;
      }

      state = {...state, 'confirmedId': orderId};
      await api.savePending(state);
      if (mounted) setState(() => pending = state);
    }

    // এর মধ্যে অন্য স্ক্রিন থেকে কার্ট বদলালে নতুন পণ্য মুছে ফেলবে না।
    if (_cartSignature(shop.cart) == state['signature']) {
      await shop.clear();
    }
    await api.removePending();
    if (!mounted) return;
    setState(() => pending = null);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded,
            color: Color(0xFF087F5B), size: 42),
        title: const Text('অর্ডার জমা হয়েছে'),
        content: Text('আপনার অর্ডার নম্বর: #$orderId'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
  }

  Widget _card(CartLine line, bool editable) {
    final details = [line.unit, line.variantName]
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .join(' · ');

    return ShopBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: !editable
                    ? null
                    : () => Get.to(
                      () => ProductDetailsScreen(productId: line.productId),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ShopImage(line.image, width: 72, height: 72),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    if (details.isNotEmpty)
                      Text(details, style: const TextStyle(color: _muted)),
                    const SizedBox(height: 5),
                    PriceText(line.price),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'পণ্য সরান',
                onPressed: editable
                    ? () => _run(() => shop.remove(line))
                    : null,
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              QuantityControl(
                value: line.qty,
                max: 99,
                onChanged: editable
                    ? (qty) => _run(() => shop.quantity(line, qty))
                    : null,
              ),
              Text('মোট ${money(line.subtotal)}',
                  style: const TextStyle(
                      color: _ink, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShopPage(
      title: 'আমার কার্ট',
      actions: [
        Obx(() {
          final enabled = shop.cart.isNotEmpty &&
              !shop.busy.value &&
              !shop.locked &&
              !working &&
              !loading &&
              pending == null;
          return IconButton(
            tooltip: 'কার্ট খালি করুন',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: !enabled
                ? null
                : () => _run(() async {
              if (await confirm(
                'কার্ট খালি করবেন?',
                'কার্ট থেকে সব পণ্য সরানো হবে।',
              )) {
                await shop.clear();
              }
            }),
          );
        }),
      ],
      body: Obx(() {
        final ready = shop.localReady.value;
        final localError = shop.localError.value;
        final busy = shop.busy.value;
        final locked = shop.locked;
        final lines = shop.cart.toList();

        if (loading) return const Center(child: CircularProgressIndicator());
        if (error.isNotEmpty || localError.isNotEmpty) {
          return ShopEmpty(error.isNotEmpty ? error : localError, retry: _load);
        }
        if (!ready) return const Center(child: CircularProgressIndicator());

        if (pending != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ShopBox(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_long_rounded, color: _blue, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'আগের অর্ডারের ফল যাচাই করুন। একই অর্ডার আবার তৈরি হবে না।',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: working ? null : () => _run(() => _finish(pending!)),
                    child: Text(working ? 'যাচাই হচ্ছে…' : 'অর্ডার যাচাই করুন'),
                  ),
                ]),
              ),
            ),
          );
        }

        if (locked) {
          return const ShopEmpty(
            'পুরোনো চেকআউটের একটি অর্ডার অসম্পূর্ণ আছে। সেটির ফল যাচাই না হওয়া পর্যন্ত নতুন অর্ডার বন্ধ।',
          );
        }
        if (lines.isEmpty) {
          return const ShopEmpty('কার্ট খালি। Hello Store থেকে পণ্য যোগ করুন।');
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _card(line, !busy && !working),
              ),
            ShopBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  totalRow('পণ্যের মোট', shop.subtotal, bold: true),
                  const SizedBox(height: 8),
                  const Text(
                    'পরের ধাপে ইউনিয়ন বেছে নিলে ডেলিভারি চার্জসহ মোট দেখাবে।',
                    style: TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
      bottom: Obx(() {
        final lines = shop.cart.toList();
        final enabled = lines.isNotEmpty &&
            shop.localReady.value &&
            !shop.busy.value &&
            !shop.locked &&
            !working &&
            !loading &&
            error.isEmpty &&
            pending == null;
        if (lines.isEmpty || pending != null) return const SizedBox.shrink();
        return FilledButton.icon(
          onPressed: enabled ? _checkout : null,
          icon: const Icon(Icons.local_shipping_outlined),
          label: Text(working ? 'অপেক্ষা করুন…' : 'ঠিকানা দিন · ${money(shop.subtotal)}'),
        );
      }),
    );
  }
}

class _AddressScreen extends StatefulWidget {
  const _AddressScreen({
    required this.api,
    required this.zones,
    required this.lines,
  });

  final _StoreApi api;
  final List<_Json> zones;
  final List<CartLine> lines;

  @override
  State<_AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<_AddressScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();

  int? area;
  bool checking = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    if (widget.zones.length == 1) area = _id(widget.zones.first['id']);
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  _Json? get zone {
    for (final z in widget.zones) {
      if (_id(z['id']) == area) return z;
    }
    return null;
  }

  int get subtotal => widget.lines.fold<int>(0, (n, line) => n + line.subtotal);

  Future<void> _review() async {
    if (checking || !form.currentState!.validate() || zone == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      checking = true;
      error = '';
    });

    try {
      final selectedArea = area!;
      final data = await widget.api.request(
        'store',
        query: {'area': '$selectedArea'},
      );

      final liveZones = (data['zones'] as List).whereType<_Json>();
      final matches = liveZones.where((z) => _id(z['id']) == selectedArea);
      if (matches.isEmpty) {
        throw const _StoreError('এই ইউনিয়নে এখন ডেলিভারি বন্ধ। অন্য ইউনিয়ন বেছে নিন।');
      }
      final delivery = matches.first;
      final fee = _minor(delivery['fee']);
      final packs = {
        for (final p in (data['items'] as List).whereType<_Json>())
          '${p['pack']}': p,
      };

      final cart = <String, dynamic>{};
      final summary = <String>[];
      var total = fee;

      for (final line in widget.lines) {
        final key = '${line.variantId}';
        final pack = packs[key];
        if (pack == null || 'mysql:${pack['product']}' != line.productId) {
          throw _StoreError('${line.name} এই ইউনিয়নে পাওয়া যাচ্ছে না।');
        }
        if (_id(pack['stock']) < line.qty) {
          throw _StoreError(
            '${line.name}: স্টকে আছে ${pack['stock']}টি। কার্টে ফিরে পরিমাণ কমান।',
          );
        }

        final price = _minor(pack['price']);
        total += price * line.qty;
        cart[key] = {'qty': line.qty, 'priceMinor': price};

        final changed = price == line.price
            ? ''
            : ' (দাম বদলেছে: ${money(line.price)} → ${money(price)})';
        summary.add(
          '${line.name} · ${pack['label']} × ${line.qty}'
              ' = ${money(price * line.qty)}$changed',
        );
      }

      if (!mounted) return;
      final accepted = await confirm(
        'অর্ডারটি নিশ্চিত করবেন?',
        '${summary.join('\n')}\n\n'
            'প্রাপক: ${name.text.trim()}\n'
            'মোবাইল: ${_phone(phone.text)}\n'
            'ঠিকানা: ${address.text.trim()}, ${delivery['name']}\n\n'
            'ডেলিভারি: ${money(fee)}\n'
            'সর্বমোট: ${money(total)}',
        action: 'অর্ডার নিশ্চিত করুন',
      );
      if (!mounted || !accepted) return;

      Navigator.of(context).pop(<String, dynamic>{
        'key': _randomHex(16),
        'name': name.text.trim(),
        'phone': _phone(phone.text),
        'address': address.text.trim(),
        'area': selectedArea,
        'feeMinor': fee,
        'cart': cart,
      });
    } catch (e) {
      if (mounted) setState(() => error = _message(e));
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  InputDecoration _input(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

  @override
  Widget build(BuildContext context) {
    final fee = zone == null ? null : _minor(zone!['fee']);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: const Text('ডেলিভারির ঠিকানা')),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ShopBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('কে পণ্য গ্রহণ করবেন?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: name,
                      enabled: !checking,
                      maxLength: 100,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      decoration: _input('প্রাপকের নাম', Icons.person_outline),
                      validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'প্রাপকের নাম লিখুন।' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: phone,
                      enabled: !checking,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: _input('মোবাইল নম্বর', Icons.phone_outlined),
                      validator: (v) => RegExp(r'^01[3-9][0-9]{8}$')
                          .hasMatch(_phone(v ?? ''))
                          ? null
                          : 'সঠিক বাংলাদেশি মোবাইল নম্বর লিখুন।',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: area,
                      isExpanded: true,
                      decoration: _input('ডেলিভারি ইউনিয়ন', Icons.map_outlined),
                      items: [
                        for (final z in widget.zones)
                          DropdownMenuItem(
                            value: _id(z['id']),
                            child: Text('${z['name']}', overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: checking ? null : (v) => setState(() => area = v),
                      validator: (v) => v == null ? 'ইউনিয়ন নির্বাচন করুন।' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: address,
                      enabled: !checking,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 400,
                      autofillHints: const [AutofillHints.fullStreetAddress],
                      decoration: _input('গ্রাম, রাস্তা, বাড়ি বা পরিচিত স্থান',
                          Icons.location_on_outlined),
                      validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'ডেলিভারির ঠিকানা লিখুন।' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ShopBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    totalRow('কার্টের পণ্যমূল্য', subtotal),
                    const SizedBox(height: 8),
                    if (fee == null)
                      const Text('ডেলিভারি চার্জ দেখতে ইউনিয়ন বেছে নিন।')
                    else ...[
                      totalRow('ডেলিভারি চার্জ', fee),
                      const Divider(height: 22),
                      totalRow('আনুমানিক মোট', subtotal + fee, bold: true),
                    ],
                    const SizedBox(height: 8),
                    const Text('নিশ্চিত করার আগে সর্বশেষ দাম ও স্টক যাচাই হবে।',
                        style: TextStyle(color: _muted)),
                  ],
                ),
              ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error, style: const TextStyle(color: Colors.deepOrange)),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: checking ? null : _review,
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(checking ? 'দাম ও স্টক যাচাই হচ্ছে…' : 'অর্ডার যাচাই করুন'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}