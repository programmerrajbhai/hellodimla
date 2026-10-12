import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../business/business_ui.dart';
import '../../business/business_store.dart';
import '../16_contacts/contacts_screen.dart';
import '../18_products_stock/products_stock_screen.dart';
import '../19_transactions/transactions_screen.dart';
import '../20_reports/reports_screen.dart';

class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => BusinessPage(
    title: 'ব্যবসার খাতা',
    actions: [
      IconButton(
        onPressed: () => safely(BusinessForms.pin),
        icon: const Icon(Icons.shield_outlined),
      ),
      IconButton(
        onPressed: BusinessStore.instance.lock,
        icon: const Icon(Icons.lock_outline),
      ),
    ],
    body: (book) {
      if (book.settings == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  size: 80,
                  color: khataBlue,
                ),
                heading('খাতা–কলমের হিসাব এখন ফোনে'),
                const Text(
                  'ইন্টারনেট ছাড়াই বিক্রি, বাকি ও নগদ লিখুন।',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => safely(BusinessForms.setup),
                  child: const Text('আমার ব্যবসা শুরু করি'),
                ),
              ],
            ),
          ),
        );
      }

      final report = book.report(today(), today());
      final recent = book.entries.reversed.take(8).toList();

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF174BB8),
                  Color(0xFF367DE6),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.settings!['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'আজ ${bn(today())} • Offline খাতা',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                const Text(
                  'হাতে নগদ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 17,
                  ),
                ),
                Text(
                  money(report['cash']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              for (final action in const [
                ['sale', 'বিক্রি', Icons.shopping_bag_outlined],
                ['receive', 'আদায়', Icons.payments_outlined],
                ['purchase', 'ক্রয়', Icons.inventory_2_outlined],
                ['expense', 'খরচ', Icons.outbox_outlined],
              ])
                FilledButton(
                  onPressed: () => safely(
                        () => BusinessForms.entry(action[0] as String),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: action[0] == 'receive'
                        ? const Color(0xFF087F68)
                        : khataBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(action[2] as IconData, size: 30),
                      const SizedBox(height: 6),
                      Text(
                        action[1] as String,
                        style: const TextStyle(fontSize: 21),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          panel([
            heading('আজকের হিসাব'),
            info('বিক্রি (ফেরত বাদে)', money(report['sales'])),
            info('পুরোনো বাকি আদায়', money(report['collect'])),
            info('খরচ / stock loss', money(report['expense'])),
            info(
              'লাভ–লোকসান',
              report['incomplete']
                  ? 'হিসাব অসম্পূর্ণ'
                  : money(report['profit']),
            ),
            const Text(
              'নগদ বিক্রির টাকা বিক্রিতে আছে। '
                  'আদায়ে আবার গণনা হয় না।',
            ),
          ]),
          panel([
            heading('মোট বাকি'),
            info(
              'Customer-এর কাছে পাওনা',
              money(report['receivable']),
            ),
            info('Supplier-কে দেনা', money(report['payable'])),
            if (report['customerCredit'] > 0)
              info(
                'Customer-এর ফেরতযোগ্য credit',
                money(report['customerCredit']),
              ),
            if (report['supplierAdvance'] > 0)
              info(
                'Supplier-কে অগ্রিম',
                money(report['supplierAdvance']),
              ),
          ]),
          panel([
            heading('খাতার অন্য কাজ'),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Customer / Supplier'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.to(() => const ContactsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('পণ্য ও stock'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.to(() => const ProductsStockScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('সব লেনদেন'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.to(() => const TransactionsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Reports ও backup'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.to(() => const ReportsScreen()),
            ),
            ListTile(
              leading: const Icon(
                Icons.account_balance_wallet_outlined,
              ),
              title: const Text('মালিকের টাকা জমা / উত্তোলন'),
              onTap: () => BusinessForms.chooseEntry(),
            ),
          ]),
          panel([
            heading('সাম্প্রতিক লেনদেন'),
            if (recent.isEmpty) empty('এখনও লেনদেন নেই'),
            for (final entry in recent)
              entryTile(book, entry),
          ]),
        ],
      );
    },
  );
}