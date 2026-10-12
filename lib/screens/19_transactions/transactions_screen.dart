import 'package:flutter/material.dart';

import '../../business/business_ui.dart';
import '../../business/business_store.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String search = '';
  String type = 'all';

  DateTimeRange? range;
  int shown = 50;

  Future<void> chooseDates(Book book) async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime.parse(book.settings!['date']),
      lastDate: DateTime.now(),
      initialDateRange: range,
    );

    if (selected != null && mounted) {
      setState(() {
        range = selected;
        shown = 50;
      });
    }
  }

  @override
  Widget build(BuildContext context) => BusinessPage(
    title: 'সব লেনদেন',
    body: (book) {
      final rows = book
          .list(
        from: range == null ? null : day(range!.start),
        to: range == null ? null : day(range!.end),
      )
          .reversed
          .where((entry) {
        final matchesType =
            type == 'all' || entry['type'] == type;

        final matchesSearch =
        '${entry['contactName']} ${entry['productName']} '
            '${entry['note']} ${entry['id']}'
            .toLowerCase()
            .contains(search.toLowerCase());

        return matchesType && matchesSearch;
      })
          .toList();

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: () => BusinessForms.chooseEntry(),
            icon: const Icon(Icons.add),
            label: const Text('নতুন লেনদেন লিখুন'),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) {
              setState(() {
                search = value;
                shown = 50;
              });
            },
            decoration: const InputDecoration(
              hintText: 'নাম, পণ্য বা বিবরণ খুঁজুন',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: type,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'লেনদেনের ধরন',
            ),
            items: {'all': 'সব', ...entryNames}.entries.map((e) {
              return DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                type = value;
                shown = 50;
              });
            },
          ),
          Row(
            children: [
              Flexible(
                child: TextButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    range == null
                        ? 'তারিখ নির্বাচন'
                        : '${bn(day(range!.start))} → '
                        '${bn(day(range!.end))}',
                  ),
                  onPressed: () => chooseDates(book),
                ),
              ),
              if (range != null)
                IconButton(
                  onPressed: () => setState(() => range = null),
                  icon: const Icon(Icons.clear),
                ),
            ],
          ),
          Text('${bn('${rows.length}')}টি entry'),
          const SizedBox(height: 12),
          panel([
            if (rows.isEmpty) empty('কোনো লেনদেন নেই'),
            for (final entry in rows.take(shown))
              entryTile(book, entry),
          ]),
          if (rows.length > shown)
            OutlinedButton(
              onPressed: () => setState(() => shown += 50),
              child: const Text('আরও দেখুন'),
            ),
          const Text(
            'পুরোনো entry মুছে যায় না। Details খুলে ফেরত, '
                'reversal ও correction history দেখুন।',
          ),
        ],
      );
    },
  );
}