import 'dart:convert';
import 'dart:math';

typedef BookRow = Map<String, dynamic>;

const entryNames = {
  'sale': 'বিক্রি',
  'purchase': 'ক্রয়',
  'receive': 'আদায়',
  'payment': 'পরিশোধ',
  'expense': 'খরচ',
  'deposit': 'জমা',
  'withdraw': 'উত্তোলন',
  'sale_return': 'বিক্রি ফেরত',
  'purchase_return': 'ক্রয় ফেরত',
  'adjust': 'Stock adjustment',
  'balance': 'বাকি adjustment',
  'credit_settle': 'Credit / অগ্রিম ফেরত',
  'reversal': 'রিভার্সাল',
};

const deltaKeys = [
  'cash',
  'balance',
  'qty',
  'value',
  'sales',
  'purchase',
  'cost',
  'expense',
  'collect',
  'pay',
  'ownerIn',
  'ownerOut',
  'salesReturn',
  'purchaseReturn',
  'unknown',
];

String day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

String today() => day(DateTime.now());

String bn(String s) {
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll('$i', '০১২৩৪৫৬৭৮৯'[i]);
  }
  return s;
}

String englishDigits(String s) {
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll('০১২৩৪৫৬৭৮৯'[i], '$i');
  }
  return s.trim();
}

void need(bool value, String message) {
  if (!value) throw FormatException(message);
}

int scaled(String text, int digits, {bool negative = false}) {
  final s = englishDigits(text);

  if (!RegExp(
    '^${negative ? '[-+]?' : ''}\\d+(\\.\\d{1,$digits})?\$',
  ).hasMatch(s)) {
    throw const FormatException('সঠিক সংখ্যা লিখুন');
  }

  final neg = s.startsWith('-');
  final parts = s.replaceFirst(RegExp(r'^[+-]'), '').split('.');

  final result =
      BigInt.parse(parts[0]) *
          BigInt.from(pow(10, digits).toInt()) +
          BigInt.parse(
            (parts.length == 2 ? parts[1] : '')
                .padRight(digits, '0'),
          );

  need(result <= BigInt.from(100000000000), 'সংখ্যা অনেক বড়');

  return neg ? -result.toInt() : result.toInt();
}

String money(int n) =>
    '৳${bn((n / 100).toStringAsFixed(2))}';

String qtyText(int n) => bn(
  (n / 1000)
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'\.?0+$'), ''),
);

int ratio(int total, int part, int whole) =>
    ((BigInt.from(total) * BigInt.from(part) +
        BigInt.from(whole ~/ 2)) ~/
        BigInt.from(whole))
        .toInt();

BookRow copyRow(BookRow r) =>
    Map<String, dynamic>.from(
      jsonDecode(jsonEncode(r)) as Map,
    );

String newId() => List.generate(
  16,
      (_) => Random.secure()
      .nextInt(256)
      .toRadixString(16)
      .padLeft(2, '0'),
).join();

class Book {
  Book(this.data);

  factory Book.empty() => Book({
    'version': 1,
    'settings': null,
    'contacts': <dynamic>[],
    'products': <dynamic>[],
    'entries': <dynamic>[],
  });

  final BookRow data;

  BookRow? get settings => data['settings'] as BookRow?;

  List<BookRow> get contacts =>
      (data['contacts'] as List).cast<BookRow>();

  List<BookRow> get products =>
      (data['products'] as List).cast<BookRow>();

  List<BookRow> get entries =>
      (data['entries'] as List).cast<BookRow>();

  Book clone() => Book(copyRow(data));

  BookRow contact(String id) =>
      contacts.firstWhere((c) => c['id'] == id);

  BookRow product(String id) =>
      products.firstWhere((p) => p['id'] == id);

  bool reversed(String id) =>
      entries.any((e) => e['reverseOf'] == id);

  List<BookRow> list({
    String? contactId,
    String? productId,
    String? from,
    String? to,
  }) {
    return entries.where((e) {
      return (contactId == null || e['contactId'] == contactId) &&
          (productId == null || e['productId'] == productId) &&
          (from == null ||
              (e['date'] as String).compareTo(from) >= 0) &&
          (to == null ||
              (e['date'] as String).compareTo(to) <= 0);
    }).toList();
  }

  int balance(String id, {String? to}) {
    final c = contact(id);

    var result =
    to != null && (c['date'] as String).compareTo(to) > 0
        ? 0
        : c['opening'] as int;

    for (final e in list(contactId: id, to: to)) {
      result += e['balance'] as int;
    }

    return result;
  }

  BookRow stock(String id, {String? to}) {
    final p = product(id);

    var q =
    to != null && (p['date'] as String).compareTo(to) > 0
        ? 0
        : p['openingQty'] as int;

    int? value = q == 0 ? 0 : p['openingValue'] as int?;

    for (final e in list(productId: id, to: to)) {
      q += e['qty'] as int;

      if (e['value'] == null || value == null) {
        value = null;
      } else {
        value += e['value'] as int;
      }

      if (q == 0) value = 0;

      need(
        q >= 0 && (value == null || value >= 0),
        'Stock হিসাব অসঙ্গত',
      );
    }

    return {'qty': q, 'value': value};
  }

  BookRow report(String from, String to) {
    final rows = list(from: from, to: to);

    int sum(String key) =>
        rows.fold(0, (a, e) => a + (e[key] as int? ?? 0));

    final all = list(to: to);

    final cash =
    settings == null ||
        (settings!['date'] as String).compareTo(to) > 0
        ? 0
        : (settings!['openingCash'] as int) +
        all.fold<int>(
          0,
              (a, e) => a + (e['cash'] as int),
        );

    var receivable = 0;
    var payable = 0;
    var customerCredit = 0;
    var supplierAdvance = 0;

    for (final c in contacts) {
      final amount = balance(c['id'], to: to);

      if (c['role'] == 'customer') {
        if (amount >= 0) {
          receivable += amount;
        } else {
          customerCredit -= amount;
        }
      } else {
        if (amount >= 0) {
          payable += amount;
        } else {
          supplierAdvance -= amount;
        }
      }
    }

    return {
      'sales': sum('sales'),
      'purchase': sum('purchase'),
      'salesReturn': sum('salesReturn'),
      'purchaseReturn': sum('purchaseReturn'),
      'cost': sum('cost'),
      'expense': sum('expense'),
      'collect': sum('collect'),
      'pay': sum('pay'),
      'ownerIn': sum('ownerIn'),
      'ownerOut': sum('ownerOut'),
      'movement': sum('cash'),
      'cash': cash,
      'receivable': receivable,
      'payable': payable,
      'customerCredit': customerCredit,
      'supplierAdvance': supplierAdvance,
      'incomplete': sum('unknown') != 0,
      'profit': sum('sales') - sum('cost') - sum('expense'),
    };
  }

  void setup(
      String name,
      String type,
      String date,
      int cash,
      ) {
    need(settings == null, 'ব্যবসা ইতোমধ্যে তৈরি হয়েছে');

    text(name, 80);
    text(type, 60);
    validDate(date);

    need(cash >= 0, 'Opening cash ঋণাত্মক হতে পারে না');

    data['settings'] = {
      'name': name.trim(),
      'type': type.trim(),
      'date': date,
      'openingCash': cash,
      'pin': null,
      'attempts': 0,
      'lockUntil': 0,
    };
  }

  void saveContact(BookRow c) {
    need(settings != null, 'আগে ব্যবসা তৈরি করুন');

    text(c['name'], 80);
    text(c['note'], 300, optional: true);

    need(
      ['customer', 'supplier'].contains(c['role']),
      'পরিচয় নির্বাচন করুন',
    );

    final phone = englishDigits(c['phone'] ?? '');

    need(
      phone.isEmpty ||
          RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone),
      'ফোন নম্বর ঠিক করুন',
    );

    need(
      c['opening'] is int && c['opening'] >= 0,
      'Opening balance ঠিক করুন',
    );

    final index =
    contacts.indexWhere((r) => r['id'] == c['id']);

    if (index >= 0) {
      final old = contacts[index];

      if (list(contactId: c['id']).isNotEmpty) {
        need(
          c['role'] == old['role'] &&
              c['opening'] == old['opening'],
          'History থাকায় পরিচয় ও opening বদলানো যাবে না; '
              'adjustment লিখুন',
        );
      }

      c['date'] = old['date'];
      data['contacts'][index] = {...c, 'phone': phone};
    } else {
      c['date'] = today();
      c['archived'] = false;

      data['contacts'].add({...c, 'phone': phone});
    }
  }

  void saveProduct(BookRow p) {
    need(settings != null, 'আগে ব্যবসা তৈরি করুন');

    text(p['name'], 80);
    text(p['unit'], 20);

    for (final key in ['openingQty', 'buy', 'sell', 'low']) {
      need(
        p[key] is int && p[key] >= 0,
        'পণ্যের সংখ্যা/দাম ঠিক করুন',
      );
    }

    need(
      p['openingValue'] == null ||
          p['openingValue'] is int &&
              p['openingValue'] >= 0,
      'Opening stock value ঠিক করুন',
    );

    final index =
    products.indexWhere((r) => r['id'] == p['id']);

    if (index >= 0) {
      final old = products[index];

      need(
        old['unit'] == p['unit'] &&
            old['openingQty'] == p['openingQty'] &&
            old['openingValue'] == p['openingValue'],
        'Unit/opening stock অপরিবর্তিত রাখুন; '
            'stock adjustment ব্যবহার করুন',
      );

      p['date'] = old['date'];
      data['products'][index] = p;
    } else {
      p['date'] = today();
      data['products'].add(p);
    }
  }

  BookRow blank(
      String id,
      String type,
      String date,
      String note,
      ) {
    need(settings != null, 'আগে ব্যবসা তৈরি করুন');

    validDate(date);

    need(
      date.compareTo(settings!['date']) >= 0,
      'হিসাব শুরুর আগের তারিখ নয়',
    );

    need(
      entries.isEmpty ||
          date.compareTo(entries.last['date']) >= 0,
      'শেষ entry-এর আগের তারিখ নয়; '
          'আগের হিসাব ঠিক করতে reversal দিন',
    );

    text(note, 300, optional: true);

    return {
      'id': id,
      'type': type,
      'date': date,
      'createdAt': DateTime.now().toIso8601String(),
      'note': note.trim(),
      'contactId': null,
      'contactName': '',
      'productId': null,
      'productName': '',
      'unit': '',
      'amount': 0,
      'units': 0,
      'paid': 0,
      'reverseOf': null,
      'returnOf': null,
      for (final key in deltaKeys) key: 0,
    };
  }

  void post({
    required String id,
    required String type,
    required String date,
    required int amount,
    int paid = 0,
    String? contactId,
    String? productId,
    int units = 0,
    int? manualCost,
    String note = '',
  }) {
    if (entries.any((e) => e['id'] == id)) return;

    need(
      [
        'sale',
        'purchase',
        'receive',
        'payment',
        'expense',
        'deposit',
        'withdraw',
        'balance',
        'credit_settle',
        'adjust',
      ].contains(type),
      'Entry type ভুল',
    );

    final e = blank(id, type, date, note);

    need(
      amount.abs() <= 100000000000 && paid >= 0,
      'টাকা ঠিক করুন',
    );

    BookRow? c;

    if (contactId != null) {
      c = contact(contactId);

      need(!c['archived'], 'Contact archived');

      e['contactId'] = contactId;
      e['contactName'] = c['name'];

      need(
        date.compareTo(c['date']) >= 0,
        'Contact তৈরির আগের তারিখ নয়',
      );
    }

    BookRow? p;
    BookRow? stockNow;

    if (productId != null) {
      p = product(productId);
      stockNow = stock(productId);

      e['productId'] = productId;
      e['productName'] = p['name'];
      e['unit'] = p['unit'];

      need(
        date.compareTo(p['date']) >= 0,
        'পণ্য তৈরির আগের তারিখ নয়',
      );
    }

    e['amount'] = amount;
    e['paid'] = paid;
    e['units'] = units;

    if (type == 'sale' || type == 'purchase') {
      final sale = type == 'sale';

      need(
        amount > 0 && paid <= amount,
        'মোট টাকা > ০ এবং নগদ ≤ মোট টাকা দিন',
      );

      need(
        c == null ||
            c['role'] == (sale ? 'customer' : 'supplier'),
        'Contact-এর পরিচয় মেলেনি',
      );

      need(
        paid == amount || c != null,
        'বাকি থাকলে contact লাগবে',
      );

      int? cost = sale ? manualCost : amount;

      if (p != null) {
        need(units > 0, 'Quantity দিন');

        if (sale) {
          need(
            units <= stockNow!['qty'],
            'পর্যাপ্ত stock নেই',
          );

          cost = stockNow['value'] == null
              ? null
              : ratio(
            stockNow['value'],
            units,
            stockNow['qty'],
          );
        }

        e['qty'] = sale ? -units : units;
        e['value'] =
        cost == null ? null : (sale ? -cost : cost);
      }

      need(cost == null || cost >= 0, 'Cost ঋণাত্মক নয়');

      e['cash'] = sale ? paid : -paid;
      e['balance'] = amount - paid;

      if (sale) {
        e['sales'] = amount;
        e['cost'] = cost ?? 0;
        e['unknown'] = cost == null ? 1 : 0;
      } else {
        e['purchase'] = amount;
      }
    } else if (type == 'receive' || type == 'payment') {
      final receive = type == 'receive';

      need(
        c != null &&
            c['role'] == (receive ? 'customer' : 'supplier'),
        'সঠিক contact দিন',
      );

      need(
        amount > 0 && amount <= balance(contactId!),
        'টাকা বাকি balance-এর বেশি হতে পারে না',
      );

      e['cash'] = receive ? amount : -amount;
      e['balance'] = -amount;
      e[receive ? 'collect' : 'pay'] = amount;
    } else if (type == 'credit_settle') {
      need(
        c != null &&
            amount > 0 &&
            amount <= -balance(contactId!),
        'Credit / অগ্রিম balance অনুযায়ী টাকা দিন',
      );

      e['cash'] = c!['role'] == 'customer'
          ? -amount
          : amount;

      e['balance'] = amount;
    } else if (type == 'balance') {
      need(
        c != null &&
            amount != 0 &&
            note.trim().isNotEmpty,
        'Contact, signed টাকা এবং কারণ দিন',
      );

      e['balance'] = amount;
    } else if (type == 'adjust') {
      need(
        p != null &&
            units != 0 &&
            note.trim().isNotEmpty,
        'পণ্য, signed quantity এবং কারণ দিন',
      );

      need(
        stockNow!['qty'] + units >= 0,
        'Stock ঋণাত্মক হবে',
      );

      final int? value = units > 0
          ? manualCost
          : stockNow['value'] == null
          ? null
          : ratio(
        stockNow['value'],
        -units,
        stockNow['qty'],
      );

      need(
        units < 0 || value != null && value >= 0,
        'বাড়তি stock-এর মোট cost দিন',
      );

      e['qty'] = units;

      e['value'] = value == null
          ? null
          : units > 0
          ? value
          : -value;

      if (units < 0) {
        e['expense'] = value ?? 0;
        e['unknown'] = value == null ? 1 : 0;
      }
    } else {
      need(amount > 0, 'টাকা > ০ দিন');

      final inflow = type == 'deposit';
      e['cash'] = inflow ? amount : -amount;

      final key = type == 'expense'
          ? 'expense'
          : inflow
          ? 'ownerIn'
          : 'ownerOut';

      e[key] = amount;
    }

    data['entries'].add(e);

    if (p != null) stock(productId!);

    need(
      report(settings!['date'], today())['cash'] >= 0,
      'নগদ পর্যাপ্ত নেই; opening বা মালিকের জমা যাচাই করুন',
    );
  }

  void returnEntry(
      String id,
      String originalId,
      int units,
      int refund,
      String date,
      String note,
      ) {
    if (entries.any((r) => r['id'] == id)) return;

    final original =
    entries.firstWhere((r) => r['id'] == originalId);

    need(
      ['sale', 'purchase'].contains(original['type']) &&
          !reversed(originalId),
      'এই entry ফেরতযোগ্য নয়',
    );

    final prior = entries.where((r) {
      return r['returnOf'] == originalId &&
          !reversed(r['id']);
    }).toList();

    final totalUnits = original['productId'] == null
        ? 1000
        : original['units'] as int;

    final done = prior.fold<int>(
      0,
          (a, r) => a + (r['units'] as int),
    );

    need(
      units > 0 && done + units <= totalUnits,
      'অবশিষ্ট ফেরত quantity ঠিক করুন',
    );

    final returnedAmount = prior.fold<int>(
      0,
          (a, r) => a + (r['amount'] as int),
    );

    final amount =
        ratio(
          original['amount'],
          done + units,
          totalUnits,
        ) -
            returnedAmount;

    need(
      refund >= 0 && refund <= amount,
      'ফেরতের নগদ মোট টাকার বেশি নয়',
    );

    need(
      original['contactId'] != null || refund == amount,
      'নগদ entry-তে সম্পূর্ণ টাকা ফেরত দিন',
    );

    final sale = original['type'] == 'sale';

    final e = blank(
      id,
      sale ? 'sale_return' : 'purchase_return',
      date,
      note,
    );

    e.addAll({
      'returnOf': originalId,
      'contactId': original['contactId'],
      'contactName': original['contactName'],
      'productId': original['productId'],
      'productName': original['productName'],
      'unit': original['unit'],
      'units': units,
      'amount': amount,
      'paid': refund,
      'balance': -(amount - refund),
      'cash': sale ? -refund : refund,
    });

    if (sale) {
      e['sales'] = -amount;
      e['salesReturn'] = amount;

      final oldCost = prior.fold<int>(
        0,
            (a, r) => a - (r['cost'] as int),
      );

      final cost = original['unknown'] == 1
          ? null
          : ratio(
        original['cost'],
        done + units,
        totalUnits,
      ) -
          oldCost;

      e['cost'] = -(cost ?? 0);
      e['unknown'] = cost == null ? 1 : 0;

      if (original['productId'] != null) {
        e['qty'] = units;
        e['value'] = cost;
      }
    } else {
      e['purchase'] = -amount;
      e['purchaseReturn'] = amount;

      if (original['productId'] != null) {
        final current = stock(original['productId']);

        need(
          units <= current['qty'],
          'ফেরত দেওয়ার পর্যাপ্ত stock নেই',
        );

        final int? carryingValue =
        current['value'] == null
            ? null
            : ratio(
          current['value'],
          units,
          current['qty'],
        );

        e['qty'] = -units;

        e['value'] =
        carryingValue == null ? null : -carryingValue;

        // Invoice/carrying-value difference adjusts cost of sales.
        e['cost'] = carryingValue == null
            ? 0
            : carryingValue - amount;

        e['unknown'] = carryingValue == null ? 1 : 0;
      }
    }

    data['entries'].add(e);

    if (original['productId'] != null) {
      stock(original['productId']);
    }

    need(
      report(settings!['date'], today())['cash'] >= 0,
      'ফেরত দেওয়ার নগদ পর্যাপ্ত নেই',
    );
  }

  void reverse(
      String id,
      String originalId,
      String reason,
      ) {
    if (entries.any((r) => r['id'] == id)) return;

    final original =
    entries.firstWhere((r) => r['id'] == originalId);

    need(
      original['type'] != 'reversal' &&
          !reversed(originalId),
      'ইতোমধ্যে reversed বা reversal entry',
    );

    need(
      !entries.any((r) {
        return r['returnOf'] == originalId &&
            !reversed(r['id']);
      }),
      'আগে সংশ্লিষ্ট ফেরত reverse করুন',
    );

    text(reason, 300);

    if (original['productId'] != null) {
      final active = entries.where((r) {
        return r['productId'] == original['productId'] &&
            r['type'] != 'reversal' &&
            !reversed(r['id']);
      }).toList();

      need(
        active.isNotEmpty &&
            active.last['id'] == originalId,
        'পুরোনো stock entry বদলাতে ওই পণ্যের '
            'পরবর্তী movement আগে reverse করুন',
      );
    }

    final e = blank(id, 'reversal', today(), reason);

    for (final key in [
      'contactId',
      'contactName',
      'productId',
      'productName',
      'unit',
      'amount',
      'units',
      'paid',
    ]) {
      e[key] = original[key];
    }

    e['reverseOf'] = originalId;

    for (final key in deltaKeys) {
      e[key] = original[key] == null
          ? null
          : -(original[key] as int);
    }

    data['entries'].add(e);

    if (original['productId'] != null) {
      stock(original['productId']);
    }

    need(
      report(settings!['date'], today())['cash'] >= 0,
      'Reversal করলে নগদ ঋণাত্মক হবে',
    );
  }

  void archiveContact(String id) {
    final c = contact(id);

    if (list(contactId: id).isEmpty &&
        c['opening'] == 0) {
      data['contacts'].removeWhere((r) => r['id'] == id);
    } else {
      c['archived'] = !c['archived'];
    }
  }

  static void text(
      dynamic s,
      int max, {
        bool optional = false,
      }) {
    need(
      s is String &&
          s.length <= max &&
          (optional || s.trim().isNotEmpty),
      'নাম/বিবরণ ঠিক করুন',
    );
  }

  static void validDate(String s) {
    final d = DateTime.tryParse(s);

    need(
      d != null &&
          day(d) == s &&
          s.compareTo(today()) <= 0,
      'তারিখ ঠিক করুন; ভবিষ্যৎ তারিখ নয়',
    );
  }

  void validate() {
    need(
      data.length == 5 &&
          data['version'] == 1 &&
          data.keys.toSet().difference({
            'version',
            'settings',
            'contacts',
            'products',
            'entries',
          }).isEmpty,
      'অচেনা backup format',
    );

    need(
      data['contacts'] is List &&
          data['products'] is List &&
          data['entries'] is List,
      'Backup তালিকা ভুল',
    );

    need(
      contacts.length <= 10000 &&
          products.length <= 10000 &&
          entries.length <= 50000,
      'Backup অত্যন্ত বড়',
    );

    if (settings == null) {
      need(
        contacts.isEmpty &&
            products.isEmpty &&
            entries.isEmpty,
        'Setup ছাড়া হিসাব নয়',
      );
      return;
    }

    text(settings!['name'], 80);
    text(settings!['type'], 60);
    validDate(settings!['date']);

    need(
      settings!['openingCash'] is int &&
          settings!['openingCash'] >= 0,
      'Opening cash ভুল',
    );

    need(
      settings!['attempts'] is int &&
          settings!['lockUntil'] is int,
      'PIN settings ভুল',
    );

    final pin = settings!['pin'];

    if (pin != null) {
      need(
        pin is Map &&
            base64Decode(pin['salt']).length == 16 &&
            base64Decode(pin['hash']).length == 32,
        'PIN format ভুল',
      );
    }

    final ids = <String>{};

    for (final c in contacts) {
      need(
        c['id'] is String && ids.add(c['id']),
        'Duplicate contact',
      );

      text(c['name'], 80);
      text(c['phone'], 16, optional: true);
      text(c['note'], 300, optional: true);

      need(
        ['customer', 'supplier'].contains(c['role']) &&
            c['archived'] is bool &&
            c['opening'] is int &&
            c['opening'] >= 0,
        'Contact হিসাব ভুল',
      );

      validDate(c['date']);
    }

    ids.clear();

    for (final p in products) {
      need(
        p['id'] is String && ids.add(p['id']),
        'Duplicate product',
      );

      text(p['name'], 80);
      text(p['unit'], 20);

      for (final key in ['openingQty', 'buy', 'sell', 'low']) {
        need(
          p[key] is int && p[key] >= 0,
          'Product হিসাব ভুল',
        );
      }

      need(
        p['openingValue'] == null ||
            p['openingValue'] is int &&
                p['openingValue'] >= 0,
        'Stock value ভুল',
      );

      validDate(p['date']);
    }

    ids.clear();

    String previous = settings!['date'];

    for (final e in entries) {
      need(
        e['id'] is String &&
            ids.add(e['id']) &&
            entryNames.containsKey(e['type']),
        'Entry format ভুল',
      );

      validDate(e['date']);

      need(
        (e['date'] as String).compareTo(previous) >= 0,
        'Entry date order ভুল',
      );

      previous = e['date'];

      need(
        e['createdAt'] is String &&
            DateTime.tryParse(e['createdAt']) != null,
        'Entry timestamp ভুল',
      );

      for (final key in ['contactName', 'productName', 'unit']) {
        text(e[key], 100, optional: true);
      }

      need(
        e['unknown'] is int &&
            (e['unknown'] as int).abs() <= 1,
        'Cost flag ভুল',
      );

      text(e['note'], 300, optional: true);

      for (final key in [
        ...deltaKeys,
        'amount',
        'units',
        'paid',
      ]) {
        need(
          key == 'value' && e[key] == null ||
              e[key] is int &&
                  (e[key] as int).abs() <= 100000000000,
          'Entry-এর সংখ্যা ভুল',
        );
      }

      need(
        e['contactId'] == null ||
            contacts.any((c) => c['id'] == e['contactId']),
        'Contact অনুপস্থিত',
      );

      need(
        e['productId'] == null ||
            products.any((p) => p['id'] == e['productId']),
        'পণ্য অনুপস্থিত',
      );

      for (final key in ['reverseOf', 'returnOf']) {
        need(
          e[key] == null ||
              e[key] != e['id'] && ids.contains(e[key]),
          'History reference ভুল',
        );
      }
    }

    for (final p in products) {
      stock(p['id']);
    }

    need(
      report(settings!['date'], today())['cash'] >= 0,
      'নগদ হিসাব অসঙ্গত',
    );
  }
}