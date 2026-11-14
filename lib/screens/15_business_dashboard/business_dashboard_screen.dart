import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'shop_dashboard.dart' as shop;
import '../../business/book.dart' show bn, day, money, scaled;


const _ink = Color(0xFF172A43);
const _blue = Color(0xFF2055BA);
const _green = Color(0xFF096B50);
const _red = Color(0xFFAF3743);
const _bg = Color(0xFFF4F7FB);

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() => _DashboardState();
}

class _DashboardState extends State<BusinessDashboardScreen> {
  bool personal = false;

  @override
  Widget build(BuildContext context) {
    Widget tab(String name, IconData icon, bool value) {
      final selected = personal == value;
      return Expanded(
        child: Semantics(
          selected: selected,
          child: TextButton.icon(
            onPressed: () => setState(() => personal = value),
            icon: Icon(icon, size: 19),
            label: Text(name, textAlign: TextAlign.center),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              backgroundColor: selected ? _blue : Colors.transparent,
              foregroundColor: selected ? Colors.white : _ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: _bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      tab('দোকানের হিসাব', Icons.storefront_outlined, false),
                      tab('ব্যক্তিগত আয়–ব্যয়', Icons.wallet_outlined, true),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: personal
                  ? const _PersonalLedger()
                  : const shop.ShopDashboardScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

// ব্যক্তিগত খাতা: দোকানের ডেটাবেস থেকে সম্পূর্ণ আলাদা।
class _LedgerDb {
  static Database? _db;

  static Future<Database> open() async {
    final existing = _db;
    if (existing != null) return existing;

    final dir = await getDatabasesPath();
    return _db = await openDatabase(
      '$dir/dimla_personal_ledger.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL CHECK(kind IN ('income','expense')),
            amount INTEGER NOT NULL CHECK(amount > 0),
            category TEXT NOT NULL,
            note TEXT NOT NULL,
            entry_day TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX entries_day ON entries(entry_day DESC, id DESC)',
        );
      },
    );
  }
}

typedef _Row = Map<String, Object?>;

class _PersonalLedger extends StatefulWidget {
  const _PersonalLedger();

  @override
  State<_PersonalLedger> createState() => _PersonalLedgerState();
}

class _PersonalLedgerState extends State<_PersonalLedger> {
  int period = 1; // 0 = আজ, 1 = এই মাস, 2 = সব সময়
  late Future<List<_Row>> data;

  @override
  void initState() {
    super.initState();
    data = _read(period);
  }

  Future<List<_Row>> _read(int filter) async {
    final now = DateTime.now();
    final db = await _LedgerDb.open();
    final monthStart = day(DateTime(now.year, now.month));
    final nextMonth = day(DateTime(now.year, now.month + 1));

    return db.query(
      'entries',
      where: filter == 0
          ? 'entry_day = ?'
          : filter == 1
          ? 'entry_day >= ? AND entry_day < ?'
          : null,
      whereArgs: filter == 0
          ? [day(now)]
          : filter == 1
          ? [monthStart, nextMonth]
          : null,
      orderBy: 'entry_day DESC, id DESC',
    );
  }

  void _reload([int? filter]) {
    if (!mounted) return;
    setState(() {
      period = filter ?? period;
      data = _read(period);
    });
  }

  Future<void> _edit(String kind, [_Row? row]) async {
    final savedDay = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EntryForm(initialKind: kind, row: row),
    );
    if (!mounted || savedDay == null) return;

    // পুরোনো তারিখের এন্ট্রি যেন সেভ করার পর চোখের আড়াল না হয়।
    final today = day(DateTime.now());
    final outside = (period == 0 && savedDay != today) ||
        (period == 1 && savedDay.substring(0, 7) != today.substring(0, 7));
    _reload(outside ? 2 : period);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('হিসাব সংরক্ষণ হয়েছে')),
    );
  }

  Future<void> _delete(_Row row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('এই হিসাব মুছবেন?'),
        content: Text('${row['category']} · ${money(row['amount'] as int)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('রাখুন'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('মুছুন', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      final db = await _LedgerDb.open();
      await db.delete('entries', where: 'id = ?', whereArgs: [row['id']]);
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('মোছা যায়নি। আবার চেষ্টা করুন।')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('আমার টাকার খাতা',
                        style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold, color: _ink,
                        )),
                    const Text('কত টাকা পেলেন, কত খরচ হলো—এক জায়গায় দেখুন।'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final item in const [
                          (0, 'আজ'), (1, 'এই মাস'), (2, 'সব সময়')
                        ])
                          ChoiceChip(
                            label: Text(item.$2),
                            selected: period == item.$1,
                            onSelected: (_) => _reload(item.$1),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            FutureBuilder<List<_Row>>(
              future: data,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => _reload(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('হিসাব লোড হয়নি। আবার চেষ্টা করুন'),
                      ),
                    ),
                  );
                }

                final rows = snapshot.data ?? [];
                int income = 0, expense = 0;
                for (final row in rows) {
                  final amount = row['amount'] as int;
                  if (row['kind'] == 'income') {
                    income += amount;
                  } else {
                    expense += amount;
                  }
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, i) {
                        if (i == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF173D64),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('আয় থেকে ব্যয় বাদে',
                                        style: TextStyle(color: Colors.white)),
                                    Text(money(income - expense),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                        )),
                                    const Divider(color: Colors.white30),
                                    Wrap(
                                      spacing: 20, runSpacing: 6,
                                      children: [
                                        Text('মোট আয়  ${money(income)}',
                                            style: const TextStyle(color: Colors.white)),
                                        Text('মোট ব্যয়  ${money(expense)}',
                                            style: const TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _action('আয় লিখুন', _green, 'income')),
                                  const SizedBox(width: 10),
                                  Expanded(child: _action('ব্যয় লিখুন', _red, 'expense')),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text('লেনদেন · ${bn('${rows.length}')}টি',
                                  style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700,
                                  )),
                              const SizedBox(height: 6),
                              if (rows.isEmpty)
                                const Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(18),
                                    child: Text('এই সময়ে কোনো হিসাব নেই। টাকা পেলে “আয় লিখুন”, খরচ করলে “ব্যয় লিখুন” চাপুন।'),
                                  ),
                                ),
                            ],
                          );
                        }

                        final row = rows[i - 1];
                        final isIncome = row['kind'] == 'income';
                        final color = isIncome ? _green : _red;
                        final note = row['note'] as String;
                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          child: ListTile(
                            onTap: () => _edit(row['kind'] as String, row),
                            leading: CircleAvatar(
                              backgroundColor: isIncome
                                  ? const Color(0xFFE7F5EE)
                                  : const Color(0xFFFFEDEE),
                              child: Icon(
                                isIncome ? Icons.south_west : Icons.north_east,
                                color: color,
                              ),
                            ),
                            title: Text('${row['category']}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${isIncome ? 'আয়' : 'ব্যয়'} · '
                                    '${isIncome ? '+' : '−'}${money(row['amount'] as int)}',
                                    style: TextStyle(color: color)),
                                Text(bn('${row['entry_day']}')),
                                if (note.isNotEmpty) Text(note),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'হিসাবের অপশন',
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _edit(row['kind'] as String, row);
                                } else {
                                  _delete(row);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('সম্পাদনা')),
                                PopupMenuItem(value: 'delete', child: Text('মুছুন')),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: rows.length + 1,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(String title, Color color, String kind) => FilledButton.icon(
    onPressed: () => _edit(kind),
    icon: const Icon(Icons.add),
    label: Text(title),
    style: FilledButton.styleFrom(
      backgroundColor: color,
      minimumSize: const Size(0, 48),
    ),
  );
}

class _EntryForm extends StatefulWidget {
  final String initialKind;
  final _Row? row;
  const _EntryForm({required this.initialKind, this.row});

  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController amount, category, note;
  late String kind;
  late DateTime date;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    kind = widget.initialKind;
    date = r == null ? DateTime.now() : DateTime.parse(r['entry_day'] as String);
    amount = TextEditingController(
      text: r == null ? '' : ((r['amount'] as int) / 100).toStringAsFixed(2),
    );
    category = TextEditingController(text: r?['category'] as String? ?? '');
    note = TextEditingController(text: r?['note'] as String? ?? '');
  }

  @override
  void dispose() {
    amount.dispose();
    category.dispose();
    note.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    try {
      if (scaled(value ?? '', 2) > 0) return null;
    } on FormatException {
      // বাংলা ও ইংরেজি অঙ্ক চলে; দশমিকের পরে সর্বোচ্চ দুই ঘর।
    }
    return 'শূন্যের বেশি সঠিক টাকা লিখুন, যেমন ২৫০ বা ২৫০.৫০';
  }

  Future<void> _save() async {
    if (saving || !form.currentState!.validate()) return;
    final values = <String, Object?>{
      'kind': kind,
      'amount': scaled(amount.text, 2),
      'category': category.text.trim(),
      'note': note.text.trim(),
      'entry_day': day(date),
    };
    setState(() { saving = true; error = null; });
    try {
      final db = await _LedgerDb.open();
      if (widget.row == null) {
        await db.insert('entries', values);
      } else {
        final count = await db.update(
          'entries', values, where: 'id = ?', whereArgs: [widget.row!['id']],
        );
        if (count != 1) throw StateError('missing entry');
      }
      if (mounted) Navigator.pop(context, values['entry_day'] as String);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'সংরক্ষণ হয়নি। আপনার লেখা আছে, আবার চেষ্টা করুন।';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = kind == 'income';
    final suggestions = isIncome
        ? const ['বেতন', 'দিনমজুরি', 'কৃষি আয়', 'উপহার']
        : const ['বাজার', 'যাতায়াত', 'চিকিৎসা', 'পড়াশোনা'];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.row == null ? 'নতুন হিসাব' : 'হিসাব সম্পাদনা',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'income', label: Text('আয়')),
                    ButtonSegment(value: 'expense', label: Text('ব্যয়')),
                  ],
                  selected: {kind},
                  onSelectionChanged: saving ? null : (v) => setState(() => kind = v.first),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: amount,
                  enabled: !saving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'কত টাকা?', prefixText: '৳ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateAmount,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: category,
                  enabled: !saving,
                  maxLength: 60,
                  decoration: InputDecoration(
                    labelText: isIncome ? 'আয়ের উৎস' : 'খরচের খাত',
                    hintText: 'নিজে লিখুন বা নিচ থেকে বেছে নিন',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'একটি খাত লিখুন' : null,
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final s in suggestions)
                      ActionChip(label: Text(s),
                          onPressed: saving ? null : () => category.text = s),
                  ],
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('লেনদেনের তারিখ'),
                  subtitle: Text(bn(day(date))),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: saving ? null : () async {
                    final picked = await showDatePicker(
                      context: context, initialDate: date,
                      firstDate: DateTime(1900), lastDate: DateTime.now(),
                    );
                    if (picked != null && mounted) setState(() => date = picked);
                  },
                ),
                TextFormField(
                  controller: note,
                  enabled: !saving,
                  maxLength: 250,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ছোট নোট (ঐচ্ছিক)', border: OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: _red)),
                FilledButton.icon(
                  onPressed: saving ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(saving ? 'সংরক্ষণ হচ্ছে…' : 'হিসাব সংরক্ষণ করুন'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isIncome ? _green : _red,
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}