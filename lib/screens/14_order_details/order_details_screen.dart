import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/service_api.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String? orderId;
  final bool showConfirmation;

  const OrderDetailsScreen({
    super.key,
    this.orderId,
    this.showConfirmation = false,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  static const _blue = Color(0xFF205AF2);
  static const _ink = Color(0xFF172746);
  static const _muted = Color(0xFF586780);

  late Future<_Receipt> _receipt;

  @override
  void initState() {
    super.initState();
    _receipt = _load();
  }

  @override
  void didUpdateWidget(covariant OrderDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) _receipt = _load();
  }

  Future<_Receipt> _load() async {
    final id = int.tryParse(widget.orderId?.trim() ?? '');
    if (id == null || id < 1) {
      throw const _Problem('সঠিক অর্ডার নম্বর পাওয়া যায়নি।');
    }

    final token = await SharedPreferencesAsync().getString('sd.token');
    if (token == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
      throw const _Problem('এই ডিভাইসে অর্ডারের পরিচয় পাওয়া যায়নি।');
    }

    final uri = ServiceApi.menuIcon(1).resolve('mobile.php').replace(
      queryParameters: {'a': 'detail', 'id': '$id'},
    );

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);

    try {
      final request = await client.getUrl(uri).timeout(
        const Duration(seconds: 12),
      );
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('X-Device-Token', token);

      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 404) {
        throw const _Problem('এই ডিভাইসের জন্য অর্ডারটি পাওয়া যায়নি।');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const _Problem('এই ডিভাইস থেকে অর্ডারটি দেখা যাচ্ছে না।');
      }
      if (response.statusCode != 200) {
        throw _Problem('অর্ডার লোড হয়নি (HTTP ${response.statusCode})।');
      }

      final body = await utf8.decoder.bind(response).join().timeout(
        const Duration(seconds: 15),
      );
      return _Receipt.parse(jsonDecode(body), id);
    } on TimeoutException {
      throw const _Problem('সার্ভার উত্তর দিতে সময় নিচ্ছে। আবার চেষ্টা করুন।');
    } on IOException {
      throw const _Problem('সার্ভারের সঙ্গে সংযোগ হয়নি। আবার চেষ্টা করুন।');
    } on FormatException {
      throw const _Problem('সার্ভার থেকে অর্ডারের তথ্য সঠিকভাবে আসেনি।');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _receipt = next);
    try {
      await next;
    } catch (_) {
      // FutureBuilder একই error দেখাবে।
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        title: const Text('অর্ডারের বিস্তারিত'),
        actions: [
          IconButton(
            tooltip: 'সর্বশেষ অবস্থা দেখুন',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_Receipt>(
          future: _receipt,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              final error = snapshot.error;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 42, color: _muted),
                      const SizedBox(height: 12),
                      Text(
                        error is _Problem ? error.message : 'অর্ডার লোড হয়নি।',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('আবার চেষ্টা করুন'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final r = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (widget.showConfirmation)
                    const Card(
                      color: Color(0xFFE6F6EB),
                      child: ListTile(
                        leading: Icon(Icons.check_circle, color: Color(0xFF187544)),
                        title: Text('আপনার অর্ডার গ্রহণ করা হয়েছে'),
                        subtitle: Text('নিচে অর্ডারের নম্বর ও রসিদ দেখুন।'),
                      ),
                    ),
                  _section(
                    icon: Icons.receipt_long_outlined,
                    title: 'অর্ডার #${_bn('${r.id}')}',
                    children: [
                      _pair('বর্তমান অবস্থা', _statusLabel(r.status)),
                      if (r.created.isNotEmpty)
                        _pair('অর্ডারের সময়', _bn(r.created)),
                    ],
                  ),
                  _section(
                    icon: Icons.location_on_outlined,
                    title: 'ডেলিভারির ঠিকানা',
                    children: [
                      if (r.area.isNotEmpty) _pair('ইউনিয়ন', r.area),
                      SelectableText(
                        r.address.isEmpty ? 'ঠিকানা দেওয়া হয়নি' : r.address,
                        style: const TextStyle(color: _ink, height: 1.5),
                      ),
                    ],
                  ),
                  _section(
                    icon: Icons.shopping_bag_outlined,
                    title: 'অর্ডারের পণ্য',
                    children: [
                      if (r.lines.isEmpty) const Text('পণ্যের তালিকা পাওয়া যায়নি।'),
                      for (final line in r.lines) ...[
                        _pair(line.title, _money(line.price * line.qty), bold: true),
                        Text(
                          '${_bn('${line.qty}')} × ${_money(line.price)}',
                          style: const TextStyle(color: _muted),
                        ),
                        const Divider(height: 22),
                      ],
                      _pair('ডেলিভারি চার্জ', _money(r.delivery)),
                      _pair('সর্বমোট', _money(r.total), bold: true),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E7F2)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: _blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _ink,
                )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _pair(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: _ink))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: bold ? _blue : _ink,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Problem implements Exception {
  final String message;
  const _Problem(this.message);
}

class _Line {
  final String title;
  final int qty;
  final int price; // পয়সায় একক দাম
  const _Line(this.title, this.qty, this.price);
}

class _Receipt {
  final int id, total, delivery;
  final String status, area, address, created;
  final List<_Line> lines;

  const _Receipt(this.id, this.total, this.delivery, this.status,
      this.area, this.address, this.created, this.lines);

  static _Receipt parse(dynamic json, int expectedId) {
    if (json is! Map || json['order'] is! Map || json['lines'] is! List) {
      throw const FormatException();
    }
    final order = json['order'] as Map;
    if (int.tryParse('${order['id']}') != expectedId) {
      throw const FormatException();
    }

    final lines = <_Line>[];
    for (final row in json['lines'] as List) {
      if (row is! Map) throw const FormatException();
      final qty = int.tryParse('${row['qty']}');
      if (qty == null || qty < 1) throw const FormatException();
      lines.add(_Line('${row['title'] ?? ''}', qty, _minor(row['price'])));
    }

    return _Receipt(
      expectedId, _minor(order['total']), _minor(order['delivery']),
      '${order['status'] ?? ''}', '${order['area_name'] ?? ''}',
      '${order['address'] ?? ''}', '${order['created_at'] ?? ''}', lines,
    );
  }
}

int _minor(dynamic value) {
  final n = num.tryParse('$value');
  if (n == null || !n.isFinite || n < 0) throw const FormatException();
  return (n * 100).round();
}

String _money(int minor) {
  final taka = minor ~/ 100;
  final paisa = minor % 100;
  final amount = paisa == 0 ? '$taka' : '$taka.${'$paisa'.padLeft(2, '0')}';
  return '৳${_bn(amount)}';
}

String _bn(String text) => text.replaceAllMapped(
  RegExp('[0-9]'), (m) => '০১২৩৪৫৬৭৮৯'[int.parse(m[0]!)],
);

String _statusLabel(String status) {
  const labels = {
    'placed': 'অর্ডার গ্রহণ করা হয়েছে',
    'confirmed': 'নিশ্চিত হয়েছে',
    'packing': 'প্যাকিং চলছে',
    'packed': 'প্যাকিং সম্পন্ন',
    'out_for_delivery': 'ডেলিভারির পথে',
    'delivered': 'ডেলিভারি সম্পন্ন',
    'cancelled': 'বাতিল হয়েছে',
    'canceled': 'বাতিল হয়েছে',
  };
  return labels[status.trim().toLowerCase()] ??
      (status.isEmpty ? 'অবস্থা পাওয়া যায়নি' : status);
}