import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../business/business_store.dart';
import '../../business/business_ui.dart';
import '../16_contacts/contacts_screen.dart';
import '../18_products_stock/products_stock_screen.dart';
import '../19_transactions/transactions_screen.dart';
import '../20_reports/reports_screen.dart';

class ShopDashboardScreen extends StatelessWidget {
  const ShopDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BusinessPage(
      title: 'দোকানের হিসাব',
      actions: [
        IconButton(
          tooltip: 'পিন সেট করুন',
          icon: const Icon(Icons.shield_outlined),
          onPressed: () => safely(BusinessForms.pin),
        ),
        IconButton(
          tooltip: 'খাতা লক করুন',
          icon: const Icon(Icons.lock_outline),
          onPressed: BusinessStore.instance.lock,
        ),
      ],
      body: (book) {
        if (book.settings == null) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined,
                      size: 64, color: khataBlue),
                  const SizedBox(height: 12),
                  heading('আপনার দোকানের খাতা'),
                  const Text(
                    'বিক্রি, বাকি ও খরচের হিসাব লিখতে দোকান সেটআপ করুন।',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => safely(BusinessForms.setup),
                    child: const Text('দোকানের খাতা খুলুন'),
                  ),
                ],
              ),
            ),
          );
        }

        final date = today();
        final report = book.report(date, date);
        final recent = book.entries.reversed.take(8);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF174BB8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${book.settings!['name']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('আজ · ${bn(date)}',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 14),
                  const Text('হাতে নগদ',
                      style: TextStyle(color: Colors.white)),
                  Text(
                    money(report['cash']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, box) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(16) > 24;
                final width = box.maxWidth < 260 || largeText
                    ? box.maxWidth
                    : (box.maxWidth - 10) / 2;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final action in const [
                      ('sale', 'বিক্রি', Icons.shopping_bag_outlined),
                      ('receive', 'বাকি আদায়', Icons.payments_outlined),
                      ('purchase', 'ক্রয়', Icons.inventory_2_outlined),
                      ('expense', 'খরচ', Icons.receipt_long_outlined),
                    ])
                      SizedBox(
                        width: width,
                        child: FilledButton.icon(
                          onPressed: () => safely(
                                () => BusinessForms.entry(action.$1),
                          ),
                          icon: Icon(action.$3),
                          label: Text(action.$2),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 52),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            panel([
              heading('আজকের হিসাব'),
              info('বিক্রি (ফেরত বাদে)', money(report['sales'])),
              info('পুরোনো বাকি আদায়', money(report['collect'])),
              info('খরচ ও স্টকের ক্ষতি', money(report['expense'])),
              info(
                'লাভ–লোকসান',
                report['incomplete']
                    ? 'হিসাব অসম্পূর্ণ'
                    : money(report['profit']),
              ),
            ]),
            panel([
              heading('দেনা–পাওনা'),
              info('ক্রেতার কাছে পাওনা', money(report['receivable'])),
              info('সরবরাহকারীকে দেনা', money(report['payable'])),
              if (report['customerCredit'] > 0)
                info('ক্রেতাকে ফেরতযোগ্য', money(report['customerCredit'])),
              if (report['supplierAdvance'] > 0)
                info('সরবরাহকারীকে অগ্রিম', money(report['supplierAdvance'])),
            ]),
            panel([
              heading('খাতার অন্য কাজ'),
              _link('ক্রেতা ও সরবরাহকারী', Icons.people_outline,
                      () => Get.to(() => const ContactsScreen())),
              _link('পণ্য ও স্টক', Icons.inventory_2_outlined,
                      () => Get.to(() => const ProductsStockScreen())),
              _link('সব লেনদেন', Icons.receipt_long_outlined,
                      () => Get.to(() => const TransactionsScreen())),
              _link('রিপোর্ট ও ব্যাকআপ', Icons.bar_chart_rounded,
                      () => Get.to(() => const ReportsScreen())),
              _link('মালিকের টাকা জমা / উত্তোলন',
                  Icons.account_balance_wallet_outlined,
                      () => BusinessForms.chooseEntry()),
            ]),
            panel([
              heading('সাম্প্রতিক লেনদেন'),
              if (recent.isEmpty) empty('এখনও কোনো লেনদেন নেই।'),
              for (final entry in recent) entryTile(book, entry),
            ]),
          ],
        );
      },
    );
  }

  Widget _link(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: khataBlue),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}