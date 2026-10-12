import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/controllers/directory_controller.dart';
import 'saved_items_controller.dart';

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  static const blue = Color(0xFF1959FF);
  static const navy = Color(0xFF142B55);
  static const muted = Color(0xFF7183A4);

  late final SavedItemsController c;
  late final String tag;

  TextStyle font(
      double size, {
        Color color = navy,
        FontWeight weight = FontWeight.w500,
      }) {
    return GoogleFonts.hindSiliguri(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: 1.4,
    );
  }

  @override
  void initState() {
    super.initState();

    tag = UniqueKey().toString();
    c = Get.put(SavedItemsController(), tag: tag);
  }

  @override
  void dispose() {
    if (Get.isRegistered<SavedItemsController>(tag: tag)) {
      Get.delete<SavedItemsController>(tag: tag);
    }

    super.dispose();
  }

  Future<void> clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('সব saved items পরিষ্কার করবেন?'),
        content: const Text(
          'এই ডিভাইসের সেভ করা সেবা ও পণ্য সরবে। '
              'অর্ডার বা ব্যবসার খাতা মুছবে না।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ফিরে যান'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('পরিষ্কার করুন'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await c.saved.clear();
    }
  }

  Widget header() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1645BA), Color(0xFF397CFF)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'আপনার পছন্দ, কাছেই থাকুক',
            style: font(
              23,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'সেভ করা তালিকা এই ডিভাইসে থাকে।',
            style: font(13, color: const Color(0xFFDDE8FF)),
          ),
          const SizedBox(height: 17),
          TextField(
            controller: c.searchInput,
            onChanged: (value) => c.query.value = value,
            style: font(15),
            decoration: InputDecoration(
              hintText: 'সেভ করা তালিকায় খুঁজুন',
              hintStyle: font(14, color: muted),
              prefixIcon: const Icon(Icons.search_rounded, color: blue),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget tabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [false, true].map((product) {
          final selected = c.productTab.value == product;
          final count = product
              ? c.saved.productIds.length
              : c.saved.serviceIds.length;

          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => c.productTab.value = product,
            selectedColor: blue,
            backgroundColor: const Color(0xFFDDE9FF),
            side: BorderSide.none,
            label: Text(
              '${product ? 'পণ্য' : 'সেবা'} · $count',
              style: font(
                14,
                color: selected ? Colors.white : blue,
                weight: FontWeight.w600,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget savedCard(String id, bool product) {
    final key = c.key(id, product);
    final item = c.current[key];
    final reference = c.saved.reference(id, product);

    final fresh = c.freshKeys.contains(key);
    final missing = c.missingKeys.contains(key);

    final cachedName = reference['name'];
    final name = item?.name ??
        (cachedName is String && cachedName.isNotEmpty
            ? cachedName
            : product
            ? 'সেভ করা পণ্য'
            : 'সেভ করা সেবা');

    final cachedImage = reference['imageUrl'];
    final imageUrl = item?.imageUrl ??
        (cachedImage is String ? cachedImage : '');

    final uri = Uri.tryParse(imageUrl);
    final hasImage =
        uri != null && ['https', 'http'].contains(uri.scheme);

    final cachedPrice = reference['priceMinor'];
    final price = fresh
        ? item?.priceMinor
        : cachedPrice is int
        ? cachedPrice
        : item?.priceMinor;

    Widget imagePlaceholder() {
      return Container(
        color: const Color(0xFFE3EDFF),
        child: Icon(
          product
              ? Icons.shopping_bag_outlined
              : Icons.storefront_outlined,
          color: blue,
          size: 29,
        ),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: missing ? null : () => c.open(id, product),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: hasImage
                          ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            imagePlaceholder(),
                      )
                          : imagePlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: font(17, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          product
                              ? 'Hello Store'
                              : item?.typeTitle ??
                              reference['type']?.toString() ??
                              'স্থানীয় সেবা',
                          style: font(12, color: blue),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'সেভ থেকে সরান',
                    onPressed: c.saved.saving.value
                        ? null
                        : () => c.remove(id, product),
                    icon: const Icon(
                      Icons.bookmark_remove_outlined,
                      color: blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (missing)
                Text(
                  'এখন পাওয়া যাচ্ছে না',
                  style: font(
                    13,
                    color: const Color(0xFFB74458),
                    weight: FontWeight.w600,
                  ),
                )
              else if (!fresh)
                Text(
                  c.loading.value
                      ? 'বর্তমান তথ্য যাচাই হচ্ছে…'
                      : 'বর্তমান তথ্য যাচাই করা যায়নি।',
                  style: font(12, color: muted),
                ),
              if (product && !missing) ...[
                const SizedBox(height: 7),
                Text(
                  price == null
                      ? 'দাম দেওয়া হয়নি'
                      : '${fresh ? 'দাম' : 'সর্বশেষ জানা দাম'}: '
                      '${directoryMoney(price)}',
                  style: font(
                    15,
                    color: blue,
                    weight: FontWeight.w700,
                  ),
                ),
                if (fresh) ...[
                  const SizedBox(height: 5),
                  Text(
                    switch (item?.inStock) {
                      true => 'স্টকে আছে',
                      false => 'স্টকে নেই',
                      null => 'স্টক তথ্য দেওয়া হয়নি',
                    },
                    style: font(12, color: muted),
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  'অর্ডারের সময় বর্তমান দাম ও stock আবার যাচাই হবে।',
                  style: font(11, color: muted),
                ),
              ],
              if (!product && !missing) ...[
                if (fresh && item != null && item.areas.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.areas.join(' · '),
                    style: font(12, color: muted),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: fresh && item?.dialNumber != null
                      ? () => c.call(id)
                      : null,
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('কল করুন'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: blue,
                    minimumSize: const Size(120, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F6FF),
        surfaceTintColor: Colors.transparent,
        foregroundColor: navy,
        title: Text(
          'সেভ করা',
          style: font(21, weight: FontWeight.w700),
        ),
        actions: [
          Obx(
                () => IconButton(
              tooltip: 'সব saved items পরিষ্কার করুন',
              onPressed: !c.saved.ready.value ||
                  c.saved.saving.value ||
                  (c.saved.serviceIds.isEmpty &&
                      c.saved.productIds.isEmpty)
                  ? null
                  : clearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Obx(() {
              final ids = c.visibleIds;
              final product = c.productTab.value;

              return RefreshIndicator(
                color: blue,
                onRefresh: c.refreshItems,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(child: header()),
                    SliverToBoxAdapter(child: tabs()),
                    if (c.loading.value)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
                          child: LinearProgressIndicator(),
                        ),
                      ),
                    if (c.saved.error.value.isNotEmpty ||
                        c.errors.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEAF0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  if (c.saved.error.value.isNotEmpty)
                                    c.saved.error.value,
                                  ...c.errors,
                                ].join('\n'),
                                style: font(
                                  13,
                                  color: const Color(0xFFAD3D55),
                                ),
                              ),
                              TextButton(
                                onPressed: c.loading.value
                                    ? null
                                    : c.refreshItems,
                                child: const Text('আবার চেষ্টা করুন'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (ids.isEmpty && !c.loading.value)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(34),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.bookmarks_outlined,
                                size: 55,
                                color: blue,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                c.query.value.trim().isNotEmpty
                                    ? 'খোঁজার সঙ্গে কোনো item মেলেনি'
                                    : 'এখনো ${product ? 'পণ্য' : 'সেবা'} সেভ করা নেই',
                                textAlign: TextAlign.center,
                                style: font(
                                  19,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'পছন্দের item-এর Save button চাপলে\n'
                                    'এখানে পাওয়া যাবে।',
                                textAlign: TextAlign.center,
                                style: font(14, color: muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                            key: ValueKey(c.key(ids[index], product)),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: savedCard(ids[index], product),
                          ),
                          childCount: ids.length,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}