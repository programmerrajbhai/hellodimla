import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../business/business_ui.dart';
import '../../business/business_store.dart';

class ProductsStockScreen extends StatefulWidget {
  const ProductsStockScreen({super.key});

  @override
  State<ProductsStockScreen> createState() =>
      _ProductsStockScreenState();
}

class _ProductsStockScreenState extends State<ProductsStockScreen> {
  String search = '';
  String filter = 'all';

  Future<void> history(BookRow product) async {
    final book = BusinessStore.instance.book;

    await Get.bottomSheet<void>(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('${product['name']} — Stock history'),
                info(
                  'Opening quantity',
                  '${qtyText(product['openingQty'])} ${product['unit']}',
                ),
                info(
                  'Opening value',
                  product['openingValue'] == null
                      ? 'Cost অজানা'
                      : money(product['openingValue']),
                ),
                for (final entry in book
                    .list(productId: product['id'])
                    .reversed)
                  ListTile(
                    title: Text(
                      '${entryNames[entry['type']]} • '
                          '${bn(entry['date'])}',
                    ),
                    subtitle: Text(entry['note']),
                    trailing: Text(
                      '${qtyText(entry['qty'])} ${product['unit']}',
                    ),
                    onTap: () {
                      Get.back();
                      entryDetails(entry);
                    },
                  ),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('বন্ধ করুন'),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) => BusinessPage(
    title: 'পণ্য ও stock',
    body: (book) {
      final items = book.products.where((product) {
        final quantity = book.stock(product['id'])['qty'] as int;

        final matchesName = (product['name'] as String)
            .toLowerCase()
            .contains(search.toLowerCase());

        final matchesFilter =
            filter == 'all' ||
                filter == 'low' &&
                    quantity > 0 &&
                    quantity <= product['low'] ||
                filter == 'empty' && quantity == 0;

        return matchesName && matchesFilter;
      }).toList();

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          panel([
            const Text(
              'এটি আপনার ব্যবসার stock। '
                  'Hello Store-এর পণ্য আলাদা।',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => safely(
                    () => BusinessForms.product(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('নতুন পণ্য যোগ করুন'),
            ),
          ]),
          TextField(
            onChanged: (value) => setState(() => search = value),
            decoration: const InputDecoration(
              hintText: 'পণ্য খুঁজুন',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final option in const {
                'all': 'সব',
                'low': 'কম stock',
                'empty': 'Stock শেষ',
              }.entries)
                ChoiceChip(
                  label: Text(option.value),
                  selected: filter == option.key,
                  onSelected: (_) {
                    setState(() => filter = option.key);
                  },
                ),
            ],
          ),
          if (items.isEmpty) empty('কোনো পণ্য পাওয়া যায়নি'),
          for (final product in items)
            panel([
              heading(product['name']),
              info(
                'বর্তমান quantity',
                '${qtyText(book.stock(product['id'])['qty'])} '
                    '${product['unit']}',
              ),
              info(
                'ক্রয় / বিক্রয় unit দাম',
                '${money(product['buy'])} / ${money(product['sell'])}',
              ),
              info(
                'Stock-এর cost value',
                book.stock(product['id'])['value'] == null
                    ? 'হিসাব অসম্পূর্ণ'
                    : money(book.stock(product['id'])['value']),
              ),
              if (book.stock(product['id'])['qty'] <= product['low'])
                Text(
                  book.stock(product['id'])['qty'] == 0
                      ? 'Stock শেষ'
                      : 'কম stock',
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => safely(
                          () => BusinessForms.product(product: product),
                    ),
                    child: const Text('Edit'),
                  ),
                  TextButton(
                    onPressed: () => history(product),
                    child: const Text('History'),
                  ),
                  TextButton(
                    onPressed: () => safely(
                          () => BusinessForms.entry(
                        'adjust',
                        productId: product['id'],
                      ),
                    ),
                    child: const Text('Stock adjustment / নষ্ট'),
                  ),
                ],
              ),
            ]),
        ],
      );
    },
  );
}