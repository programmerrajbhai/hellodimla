import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../business/business_ui.dart';
import '../../business/business_store.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String period = 'today';
  DateTimeRange? custom;

  (String, String) dates(Book book) {
    final now = DateTime.now();

    final start = period == 'week'
        ? DateTime(now.year, now.month, now.day).subtract(
      Duration(days: now.weekday - 1),
    )
        : period == 'month'
        ? DateTime(now.year, now.month, 1)
        : period == 'custom' && custom != null
        ? custom!.start
        : now;

    final from = day(start).compareTo(book.settings!['date']) < 0
        ? book.settings!['date'] as String
        : day(start);

    final to = period == 'custom' && custom != null
        ? day(custom!.end)
        : today();

    return (from, to);
  }

  Future<void> backup() => formSheet(
    'Password দিয়ে backup',
    [
      const Field(
        'password',
        'Backup password — কমপক্ষে ৮ অক্ষর',
        password: true,
      ),
      const Field(
        'again',
        'আবার একই password',
        password: true,
      ),
    ],
        (values) async {
      need(
        values['password'] == values['again'],
        'দুই password মিলছে না',
      );

      final store = BusinessStore.instance;
      final bytes = await store.backup(values['password']!);

      need(
        await store.saveBytes(
          'dimla_backup_${DateTime.now().millisecondsSinceEpoch}.hdb',
          bytes,
        ),
        'ফাইল সংরক্ষণ বাতিল হয়েছে',
      );
    },
    hint:
    'PIN ও backup password আলাদা। Password হারালে recovery '
        'নিশ্চিত নয়। Settings ও সব history এই backup-এ থাকবে।',
  );

  Future<void> restore() => formSheet(
    'Backup restore',
    [
      const Field(
        'password',
        'এই backup-এর password',
        password: true,
      ),
    ],
        (values) async {
      final store = BusinessStore.instance;
      final data = await store.readBackup(values['password']!);

      if (data == null) {
        throw const FormatException('File নির্বাচন বাতিল হয়েছে');
      }

      final preview = Book(data);

      final approved = await confirm(
        'বর্তমান খাতা replace করবেন?',
        '${preview.settings?['name'] ?? 'খালি খাতা'}\n'
            '${bn('${preview.contacts.length}')} ব্যক্তি • '
            '${bn('${preview.products.length}')} পণ্য • '
            '${bn('${preview.entries.length}')} entry\n\n'
            'বর্তমান খাতা replace হবে। '
            'আগে বর্তমান খাতার backup রাখুন।',
      );

      if (!approved) {
        throw const FormatException(
          'Restore বাতিল হয়েছে; বর্তমান data ঠিক আছে',
        );
      }

      await store.restore(data);
    },
    hint:
    'প্রথমে file যাচাই ও preview হবে। ভুল password/invalid '
        'file বর্তমান খাতা বদলাবে না।',
  );

  Future<void> export(
      Book book,
      BookRow report,
      String from,
      String to,
      ) async {
    final table = <List<String>>[
      ['সময়', '$from → $to'],
      ['বিক্রি (ফেরত বাদে)', money(report['sales'])],
      ['বিক্রি ফেরত', money(report['salesReturn'])],
      ['ক্রয় (ফেরত বাদে)', money(report['purchase'])],
      ['ক্রয় ফেরত', money(report['purchaseReturn'])],
      ['বিক্রীত পণ্যের cost', money(report['cost'])],
      ['খরচ / stock loss', money(report['expense'])],
      [
        'লাভ–লোকসান',
        report['incomplete']
            ? 'হিসাব অসম্পূর্ণ'
            : money(report['profit']),
      ],
      ['আদায়', money(report['collect'])],
      ['Supplier payment', money(report['pay'])],
      ['মালিকের জমা', money(report['ownerIn'])],
      ['মালিকের উত্তোলন', money(report['ownerOut'])],
      ['Cash movement', money(report['movement'])],
      ['শেষ তারিখে নগদ', money(report['cash'])],
      ['পাওনা', money(report['receivable'])],
      ['দেনা', money(report['payable'])],
      ['Customer credit', money(report['customerCredit'])],
      ['Supplier advance', money(report['supplierAdvance'])],
      ['পণ্যের stock — শেষ তারিখ'],
      for (final product in book.products.where(
            (p) => (p['date'] as String).compareTo(to) <= 0,
      ))
        [
          product['name'],
          '${qtyText(book.stock(product['id'], to: to)['qty'])} '
              '${product['unit']}',
          book.stock(product['id'], to: to)['value'] == null
              ? 'Cost অজানা'
              : money(book.stock(product['id'], to: to)['value']),
        ],
      [
        'তারিখ',
        'ধরন',
        'ব্যক্তি',
        'পণ্য',
        'মোট টাকা',
        'নগদ পরিবর্তন',
        'বিবরণ',
      ],
      for (final entry in book.list(from: from, to: to))
        [
          bn(entry['date']),
          entryNames[entry['type']]!,
          entry['contactName'],
          entry['productName'],
          money(entry['amount']),
          money(entry['cash']),
          entry['note'],
        ],
    ];

    await formSheet(
      'Report export',
      [
        const Field(
          'format',
          'Format',
          value: 'pdf',
          options: {'pdf': 'PDF', 'csv': 'CSV'},
        ),
        const Field(
          'action',
          'কী করবেন?',
          value: 'save',
          options: {
            'save': 'ফাইল সংরক্ষণ',
            'share': 'Share',
          },
        ),
      ],
          (values) async {
        final store = BusinessStore.instance;

        final bytes = values['format'] == 'pdf'
            ? await store.pdfBytes('ব্যবসার Report', table)
            : Uint8List.fromList(utf8.encode(store.csv(table)));

        final name =
            'dimla_report_${DateTime.now().millisecondsSinceEpoch}.'
            '${values['format']}';

        if (values['action'] == 'share') {
          await store.shareBytes(context, name, bytes);
        } else {
          need(
            await store.saveBytes(name, bytes),
            'ফাইল সংরক্ষণ বাতিল হয়েছে',
          );
        }
      },
      hint: 'PDF/CSV রিপোর্ট। এটি পূর্ণ backup নয়।',
    );
  }

  Future<void> selectPeriod(String value, Book book) async {
    if (value == 'custom') {
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime.parse(book.settings!['date']),
        lastDate: DateTime.now(),
        initialDateRange: custom,
      );

      if (selected == null || !mounted) return;

      setState(() {
        custom = selected;
        period = 'custom';
      });
    } else {
      setState(() => period = value);
    }
  }

  @override
  Widget build(BuildContext context) => BusinessPage(
    title: 'Reports ও backup',
    body: (book) {
      if (book.settings == null) {
        return empty('আগে ব্যবসার setup করুন');
      }

      final (from, to) = dates(book);
      final report = book.report(from, to);

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const {
                'today': 'আজ',
                'week': 'এই সপ্তাহ',
                'month': 'এই মাস',
                'custom': 'নিজের সময়',
              }.entries)
                ChoiceChip(
                  label: Text(option.value),
                  selected: period == option.key,
                  onSelected: (_) => selectPeriod(option.key, book),
                ),
            ],
          ),
          Text('${bn(from)} → ${bn(to)}'),
          const SizedBox(height: 12),
          panel([
            heading('বিক্রি ও লাভ'),
            info('বিক্রি (ফেরত বাদে)', money(report['sales'])),
            info('বিক্রি ফেরত', money(report['salesReturn'])),
            info('বিক্রীত পণ্যের cost', money(report['cost'])),
            info('Operating expense / stock loss', money(report['expense'])),
            info(
              'লাভ–লোকসান',
              report['incomplete']
                  ? 'হিসাব অসম্পূর্ণ'
                  : money(report['profit']),
            ),
            const Text(
              'লাভ = net বিক্রি − বিক্রীত পণ্যের cost − ব্যবসার খরচ। '
                  'নগদ আলাদা।',
            ),
          ]),
          panel([
            heading('Cash movement'),
            info('পুরোনো বাকি আদায়', money(report['collect'])),
            info('Supplier payment', money(report['pay'])),
            info('মালিকের জমা', money(report['ownerIn'])),
            info('মালিকের উত্তোলন', money(report['ownerOut'])),
            info('এই সময়ে নগদ পরিবর্তন', money(report['movement'])),
            info('শেষ তারিখে নগদ', money(report['cash'])),
          ]),
          panel([
            heading('শেষ তারিখের বাকি'),
            info('পাওনা', money(report['receivable'])),
            info('দেনা', money(report['payable'])),
            info('Customer credit', money(report['customerCredit'])),
            info('Supplier advance', money(report['supplierAdvance'])),
          ]),
          panel([
            heading('Stock summary — শেষ তারিখ'),
            for (final product in book.products.where(
                  (p) => (p['date'] as String).compareTo(to) <= 0,
            ))
              info(
                product['name'],
                '${qtyText(book.stock(product['id'], to: to)['qty'])} '
                    '${product['unit']}',
              ),
            if (book.products.isEmpty)
              const Text('পণ্য যোগ করা হয়নি'),
          ]),
          FilledButton.icon(
            onPressed: () => safely(
                  () => export(book, report, from, to),
            ),
            icon: const Icon(Icons.ios_share),
            label: const Text('PDF / CSV export'),
          ),
          const SizedBox(height: 14),
          panel([
            heading('খাতা নিরাপদ রাখুন'),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('পূর্ণ encrypted backup'),
              onTap: () => safely(backup),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Backup restore'),
              onTap: () => safely(restore),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(
                book.settings!['pin'] == null
                    ? 'PIN চালু করুন'
                    : 'PIN পরিবর্তন',
              ),
              onTap: () => safely(BusinessForms.pin),
            ),
            if (book.settings!['pin'] != null)
              ListTile(
                title: const Text('PIN বন্ধ করুন'),
                onTap: () => safely(() async {
                  if (await confirm(
                    'PIN বন্ধ করবেন?',
                    'খাতা খুলতে আর PIN লাগবে না।',
                  )) {
                    await BusinessStore.instance.removePin();
                  }
                }),
              ),
            const Text(
              'এই খাতা ফোনে থাকে। App data মুছলে/reinstall করলে '
                  'data হারাতে পারে। নিয়মিত backup অন্য নিরাপদ '
                  'জায়গায় রাখুন।',
            ),
          ]),
        ],
      );
    },
  );
}