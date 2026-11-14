import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../commerce/shop_models.dart' show money;
import '../../commerce/shop_widgets.dart' show ShopBox, ShopPage;
import '../../core/network/service_api.dart';

typedef _Json = Map<String, dynamic>;

const _blue = Color(0xFF1959E8);
const _ink = Color(0xFF162644);
const _muted = Color(0xFF596A80);

const _filters = {
  'all': 'সব',
  'active': 'চলমান',
  'delivered': 'সম্পন্ন',
  'cancelled': 'বাতিল',
};

const _active = {
  'placed',
  'confirmed',
  'packing',
  'packed',
  'out_for_delivery',
};

String _status(dynamic raw) => '${raw ?? ''}'.trim().toLowerCase();

String _statusLabel(String status) {
  const labels = {
    'placed': 'অর্ডার জমা হয়েছে',
    'confirmed': 'অর্ডার নিশ্চিত',
    'packing': 'প্যাকিং চলছে',
    'packed': 'প্যাকিং সম্পন্ন',
    'out_for_delivery': 'ডেলিভারির পথে',
    'delivered': 'ডেলিভারি সম্পন্ন',
    'cancelled': 'বাতিল',
    'canceled': 'বাতিল',
  };
  return labels[status] ?? (status.isEmpty ? 'অবস্থা জানা যায়নি' : status);
}

Color _statusColor(String status) {
  if (status == 'delivered') return const Color(0xFF087F5B);
  if (status == 'cancelled' || status == 'canceled') {
    return const Color(0xFFB42335);
  }
  return _blue;
}

// MySQL API দাম টাকায় দেয়; অ্যাপের money() পয়সা নেয়।
int? _minor(dynamic value) {
  final n = double.tryParse('$value');
  return n == null || !n.isFinite ? null : (n * 100).round();
}

String _amount(dynamic value) {
  final n = _minor(value);
  return n == null ? '—' : money(n);
}

String _date(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}'
      ' · ${two(date.hour)}:${two(date.minute)}';
}

class _OrderError implements Exception {
  const _OrderError(this.message);
  final String message;
}

String _errorText(Object e) {
  if (e is _OrderError) return e.message;
  if (e is TimeoutException || e is SocketException) {
    return 'সার্ভারে সংযোগ পাওয়া যায়নি। আবার চেষ্টা করুন।';
  }
  return 'অর্ডারের তথ্য পড়া যায়নি। আবার চেষ্টা করুন।';
}

class _OrdersApi {
  final _prefs = SharedPreferencesAsync();

  Future<_Json> _get(String action, String token, {int? id}) async {
    final uri = ServiceApi.menuIcon(1).resolve('mobile.php').replace(
      queryParameters: {
        'a': action,
        if (id != null) 'id': '$id',
      },
    );

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 7);

    Future<_Json> read() async {
      final req = await client.getUrl(uri);
      req.followRedirects = false;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set('X-Device-Token', token);

      final res = await req.close();
      final text = await utf8.decoder.bind(res).join();
      final body = jsonDecode(text);

      if (body is! _Json) {
        throw const _OrderError('API থেকে সঠিক উত্তর পাওয়া যায়নি।');
      }
      if (res.statusCode != HttpStatus.ok) {
        throw _OrderError('${body['error'] ?? 'অর্ডার লোড হয়নি।'}');
      }
      return body;
    }

    try {
      return await read().timeout(const Duration(seconds: 15));
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> _token() async {
    final token = await _prefs.getString('sd.token');
    if (token == null) return null;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
      throw const _OrderError('এই ডিভাইসের অর্ডার পরিচয় সঠিক নয়।');
    }
    return token;
  }

  Future<List<_Json>> orders() async {
    final token = await _token();
    // প্রথম অর্ডারের আগে checkout কোনো token সেভ না করাই স্বাভাবিক।
    if (token == null) return [];

    final body = await _get('orders', token);
    final items = body['items'];
    if (items is! List) throw const _OrderError('অর্ডারের তালিকা পাওয়া যায়নি।');
    return items.cast<_Json>();
  }

  Future<_Json> detail(int id) async {
    final token = await _token();
    if (token == null) {
      throw const _OrderError('এই ডিভাইসে অর্ডারের পরিচয় পাওয়া যায়নি।');
    }
    final data = await _get('detail', token, id: id);
    if (data['order'] is! _Json || data['lines'] is! List) {
      throw const _OrderError('অর্ডারের বিস্তারিত পাওয়া যায়নি।');
    }
    return data;
  }
}

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _api = _OrdersApi();

  List<_Json> _orders = [];
  String _filter = 'all';
  String _error = '';
  bool _initial = true;
  int _limit = 30;

  Future<void>? _pending;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted ||
          !TickerMode.of(context) ||
          ModalRoute.of(context)?.isCurrent != true ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() {
    return _pending ??= _load().whenComplete(() {
      _pending = null;
    });
  }

  Future<void> _load() async {
    try {
      final rows = await _api.orders();
      if (!mounted) return;
      setState(() {
        _orders = rows;
        _error = '';
        _initial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errorText(e);
        _initial = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _matches(_Json order) {
    final status = _status(order['status']);
    if (_filter == 'all') return true;
    if (_filter == 'active') return _active.contains(status);
    if (_filter == 'cancelled') {
      return status == 'cancelled' || status == 'canceled';
    }
    return status == _filter;
  }

  Future<void> _open(_Json order) async {
    final id = int.tryParse('${order['id']}');
    if (id == null || id <= 0) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _OrderDetailsPage(id: id, api: _api),
      ),
    );
    if (mounted) await _refresh();
  }

  void _help() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('অর্ডার খুঁজে পাচ্ছেন না?'),
        content: const Text(
          'যে ডিভাইস থেকে অর্ডার করেছেন, সেই ডিভাইসের অর্ডার এখানে দেখা যায়। '
              'অ্যাপের ডেটা মুছে ফেললে আগের অর্ডার আর দেখা নাও যেতে পারে। '
              'দোকানের সঙ্গে কথা বলার জন্য অর্ডার নম্বরটি রেখে দিন।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matching = _orders.where(_matches).toList();
    final visible = matching.take(_limit).toList();

    return ShopPage(
      title: 'আমার অর্ডার',
      actions: [
        IconButton(
          tooltip: 'অর্ডার সহায়তা',
          onPressed: _help,
          icon: const Icon(Icons.help_outline_rounded),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                for (final entry in _filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _filter == entry.key,
                      onSelected: (_) => setState(() {
                        _filter = entry.key;
                        _limit = 30;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _initial
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (_error.isNotEmpty)
                    _Retry(message: _error, retry: _refresh),
                  if (_error.isEmpty && matching.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long_outlined,
                              color: _muted, size: 42),
                          const SizedBox(height: 12),
                          Text(
                            _filter == 'all'
                                ? 'এই ডিভাইসে এখনো কোনো অর্ডার নেই।'
                                : 'এই বিভাগে কোনো অর্ডার নেই।',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  for (final order in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ShopBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "অর্ডার #${order['id']}",
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  _amount(order['total']),
                                  style: const TextStyle(
                                    color: _blue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _date(order['created_at']),
                              style: const TextStyle(color: _muted),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              crossAxisAlignment:
                              WrapCrossAlignment.center,
                              children: [
                                _StatusBadge(_status(order['status'])),
                                TextButton(
                                  onPressed: () => _open(order),
                                  child: const Text('বিস্তারিত দেখুন ›'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (visible.length < matching.length)
                    OutlinedButton(
                      onPressed: () => setState(() => _limit += 30),
                      child: const Text('আরও অর্ডার দেখুন'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailsPage extends StatefulWidget {
  const _OrderDetailsPage({required this.id, required this.api});

  final int id;
  final _OrdersApi api;

  @override
  State<_OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<_OrderDetailsPage> {
  late Future<_Json> _result;

  @override
  void initState() {
    super.initState();
    _result = widget.api.detail(widget.id);
  }

  void _reload() {
    setState(() => _result = widget.api.detail(widget.id));
  }

  Widget _total(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 17 : 14,
      color: bold ? _ink : _muted,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShopPage(
      title: 'অর্ডার #${widget.id}',
      actions: [
        IconButton(
          tooltip: 'সর্বশেষ অবস্থা দেখুন',
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: FutureBuilder<_Json>(
        future: _result,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: _Retry(
                message: _errorText(snapshot.error ?? 'error'),
                retry: _reload,
              ),
            );
          }

          final order = snapshot.data!['order'] as _Json;
          final lines = (snapshot.data!['lines'] as List).cast<_Json>();
          final total = _minor(order['total']);
          final delivery = _minor(order['delivery']);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              ShopBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusBadge(_status(order['status'])),
                    const SizedBox(height: 8),
                    Text(
                      _date(order['created_at']),
                      style: const TextStyle(color: _muted),
                    ),
                    const Divider(height: 24),
                    const Text(
                      'ডেলিভারির ঠিকানা',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text([
                      '${order['address'] ?? ''}'.trim(),
                      '${order['area_name'] ?? ''}'.trim(),
                    ].where((s) => s.isNotEmpty).join(', ')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ShopBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'অর্ডারের পণ্য',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${line['title'] ?? ''}'),
                                  Text(
                                    "${line['qty']} × ${_amount(line['price'])}",
                                    style: const TextStyle(color: _muted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_lineAmount(line)),
                          ],
                        ),
                      ),
                    const Divider(height: 22),
                    _total(
                      'পণ্যের মোট',
                      total != null && delivery != null
                          ? money(total - delivery)
                          : '—',
                    ),
                    _total('ডেলিভারি চার্জ', _amount(order['delivery'])),
                    _total('সর্বমোট', _amount(order['total']), bold: true),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _lineAmount(_Json line) {
    final qty = int.tryParse('${line['qty']}');
    final price = _minor(line['price']);
    return qty == null || price == null ? '—' : money(qty * price);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('আবার চেষ্টা করুন'),
          ),
        ],
      ),
    );
  }
}