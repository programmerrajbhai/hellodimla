import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../business/business_ui.dart';
import '../../business/business_store.dart';

class ContactLedgerScreen extends StatefulWidget {
  const ContactLedgerScreen({
    super.key,
    required this.contactId,
  });

  final String contactId;

  @override
  State<ContactLedgerScreen> createState() =>
      _ContactLedgerScreenState();
}

class _ContactLedgerScreenState extends State<ContactLedgerScreen> {
  DateTimeRange? range;

  Future<void> chooseDates(Book book) async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime.parse(book.settings!['date']),
      lastDate: DateTime.now(),
      initialDateRange: range,
    );

    if (selected != null && mounted) {
      setState(() => range = selected);
    }
  }

  Future<void> exportStatement(
      Book book,
      BookRow contact,
      List<BookRow> rows,
      ) async {
    final opening = range == null
        ? contact['opening'] as int
        : book.balance(
      widget.contactId,
      to: day(
        range!.start.subtract(const Duration(days: 1)),
      ),
    );

    var running = opening;

    final table = <List<String>>[
      ['নাম', contact['name']],
      ['ফোন', contact['phone']],
      ['Period opening', money(opening)],
      [
        'তারিখ',
        'ধরন',
        'টাকা',
        'নগদ পরিবর্তন',
        'বাকি পরিবর্তন',
        'চলতি balance',
        'বিবরণ',
      ],
      for (final entry in rows)
        [
          bn(entry['date']),
          entryNames[entry['type']]!,
          money(entry['amount']),
          money(entry['cash']),
          money(entry['balance']),
          money(running += entry['balance'] as int),
          entry['note'],
        ],
    ];

    await formSheet(
      'Statement',
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
          value: 'share',
          options: {
            'share': 'Share',
            'save': 'ফাইল সংরক্ষণ',
          },
        ),
      ],
          (values) async {
        final store = BusinessStore.instance;

        final bytes = values['format'] == 'pdf'
            ? await store.pdfBytes('ব্যক্তির Statement', table)
            : Uint8List.fromList(utf8.encode(store.csv(table)));

        final shortId = widget.contactId.split('').take(8).join();
        final name = 'dimla_statement_$shortId.${values['format']}';

        if (values['action'] == 'share') {
          await store.shareBytes(context, name, bytes);
        } else {
          need(
            await store.saveBytes(name, bytes),
            'ফাইল সংরক্ষণ বাতিল হয়েছে',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => BusinessPage(
    title: 'ব্যক্তির খাতা',
    body: (book) {
      final matches = book.contacts.where(
            (contact) => contact['id'] == widget.contactId,
      );

      if (matches.isEmpty) return empty('ব্যক্তি পাওয়া যায়নি');

      final contact = matches.first;
      final customer = contact['role'] == 'customer';
      final balance = book.balance(widget.contactId);

      final rows = book.list(
        contactId: widget.contactId,
        from: range == null ? null : day(range!.start),
        to: range == null ? null : day(range!.end),
      );

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          panel([
            heading(contact['name']),
            Text(
              contact['phone'].isEmpty
                  ? 'ফোন নেই'
                  : contact['phone'],
            ),
            info(
              balance < 0
                  ? 'Credit / অগ্রিম'
                  : customer
                  ? 'বর্তমান পাওনা'
                  : 'বর্তমান দেনা',
              money(balance.abs()),
            ),
            info('শুরুর balance', money(contact['opening'])),
            Text(contact['note']),
            TextButton(
              onPressed: () => safely(
                    () => BusinessForms.contact(contact: contact),
              ),
              child: const Text('ব্যক্তির তথ্য পরিবর্তন'),
            ),
          ]),
          if (!contact['archived'])
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => safely(
                        () => BusinessForms.entry(
                      customer ? 'sale' : 'purchase',
                      contactId: widget.contactId,
                    ),
                  ),
                  child: Text(
                    customer ? 'বিক্রি লিখুন' : 'ক্রয় লিখুন',
                  ),
                ),
                FilledButton(
                  onPressed: () => safely(
                        () => BusinessForms.entry(
                      customer ? 'receive' : 'payment',
                      contactId: widget.contactId,
                    ),
                  ),
                  child: Text(
                    customer ? 'আদায় করুন' : 'পরিশোধ করুন',
                  ),
                ),
                if (balance < 0)
                  FilledButton(
                    onPressed: () => safely(
                          () => BusinessForms.entry(
                        'credit_settle',
                        contactId: widget.contactId,
                      ),
                    ),
                    child: Text(
                      customer
                          ? 'Customer-কে credit ফেরত'
                          : 'Supplier-এর অগ্রিম ফেরত পাই',
                    ),
                  ),
                OutlinedButton(
                  onPressed: () => safely(
                        () => BusinessForms.entry(
                      'balance',
                      contactId: widget.contactId,
                    ),
                  ),
                  child: const Text('বাকি adjustment'),
                ),
              ],
            ),
          const SizedBox(height: 14),
          panel([
            Row(
              children: [
                Expanded(child: heading('লেনদেনের তালিকা')),
                IconButton(
                  onPressed: () => chooseDates(book),
                  icon: const Icon(Icons.date_range),
                ),
                if (range != null)
                  IconButton(
                    onPressed: () => setState(() => range = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
            if (range != null)
              Text(
                '${bn(day(range!.start))} → ${bn(day(range!.end))}',
              ),
            if (rows.isEmpty) empty('কোনো লেনদেন নেই'),
            for (final entry in rows.reversed)
              entryTile(book, entry),
          ]),
          FilledButton.icon(
            icon: const Icon(Icons.ios_share),
            label: const Text('Statement export / share'),
            onPressed: () => safely(
                  () => exportStatement(book, contact, rows),
            ),
          ),
        ],
      );
    },
  );
}