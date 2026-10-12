import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/directory_controller.dart';

class DirectoryPage extends StatefulWidget {
  const DirectoryPage({
    super.key,
    required this.createController,
  });

  final DirectoryController Function() createController;

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  static const blue = Color(0xFF1959FF);
  static const navy = Color(0xFF142B55);
  static const muted = Color(0xFF6E82A5);
  static const background = Color(0xFFF1F6FF);

  late final DirectoryController c;
  late final String tag;

  TextStyle font(
      double size, {
        Color color = navy,
        FontWeight weight = FontWeight.w500,
      }) {
    return GoogleFonts.hindSiliguri(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.4,
    );
  }

  @override
  void initState() {
    super.initState();

    tag = UniqueKey().toString();

    c = Get.put<DirectoryController>(
      widget.createController(),
      tag: tag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<DirectoryController>(tag: tag)) {
      Get.delete<DirectoryController>(tag: tag);
    }

    super.dispose();
  }

  Future<String?> choose(
      String title,
      Map<String, String> options,
      String selected,
      ) {
    FocusManager.instance.primaryFocus?.unfocus();

    final entries = options.entries.toList();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: background,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Text(
                  title,
                  style: font(21, weight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final active = entry.key == selected;

                    return ListTile(
                      title: Text(
                        entry.value,
                        style: font(
                          16,
                          color: active ? blue : navy,
                        ),
                      ),
                      trailing: Icon(
                        active
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: active ? blue : muted,
                      ),
                      onTap: () =>
                          Navigator.of(sheetContext).pop(entry.key),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> chooseArea() async {
    final result = await choose(
      'ইউনিয়ন, বাজার বা স্ট্যান্ড',
      {for (final area in c.areas) area: area},
      c.area.value,
    );

    if (result != null && mounted) {
      c.changeArea(result);
    }
  }

  Future<void> chooseCategory() async {
    final result = await choose(
      'সেবার বিভাগ',
      {'': 'সব বিভাগ', ...directoryCategories},
      c.category.value,
    );

    if (result != null && mounted) {
      c.changeCategory(result);
    }
  }

  Future<void> chooseSubtype() async {
    final result = await choose(
      'সেবার ধরন',
      {'': 'সব ধরন', ...c.subtypes},
      c.subtype.value,
    );

    if (result != null && mounted) {
      c.changeSubtype(result);
    }
  }

  Future<void> choosePrice() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final result = await showModalBottomSheet<PriceSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: background,
      builder: (_) => DirectoryPriceSheet(
        minimum: c.minimumPrice.value,
        maximum: c.maximumPrice.value,
        sort: c.sort.value,
      ),
    );

    if (result != null && mounted) {
      c.applyPrice(
        result.minimum,
        result.maximum,
        result.sort,
      );
    }
  }

  Widget chip(
      String label,
      IconData icon,
      VoidCallback onTap, {
        bool active = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        avatar: Icon(icon, size: 17, color: blue),
        label: Text(
          label,
          style: font(
            12,
            color: blue,
            weight: FontWeight.w600,
          ),
        ),
        backgroundColor:
        active ? const Color(0xFFD9E7FF) : Colors.white,
        side: BorderSide(
          color: active
              ? const Color(0xFF9DBDFF)
              : Colors.transparent,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 8,
        ),
      ),
    );
  }

  Widget header() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1746BD),
            Color(0xFF397CFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.servicesOnly
                ? 'প্রয়োজনের সময়, সঠিক যোগাযোগ'
                : 'ডিমলার সেবা ও Hello Store',
            style: font(
              18,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: c.searchInput,
            builder: (context, value, _) {
              return TextField(
                controller: c.searchInput,
                onChanged: c.search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                style: font(15),
                cursorColor: blue,
                decoration: InputDecoration(
                  hintText: c.servicesOnly
                      ? 'এই বিভাগের মধ্যে খুঁজুন'
                      : 'সেবা বা পণ্যের নাম লিখুন',
                  hintStyle: font(14, color: muted),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: blue,
                  ),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                    tooltip: 'Search পরিষ্কার করুন',
                    onPressed: () {
                      c.searchInput.clear();
                      c.search('');
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: muted,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: Color(0xFFBCD3FF),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'নাম, বিবরণ ও keywords দিয়ে খোঁজা যায়। '
                'ভুল বানান স্বয়ংক্রিয়ভাবে সংশোধন হয় না।',
            style: font(
              11,
              color: const Color(0xFFE3ECFF),
            ),
          ),
        ],
      ),
    );
  }

  Widget filters() {
    return Column(
      children: [
        if (!c.servicesOnly)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: DirectoryKind.values.map((kind) {
                final selected = c.kind.value == kind;

                final label = switch (kind) {
                  DirectoryKind.all => 'সব',
                  DirectoryKind.services => 'সেবা',
                  DirectoryKind.products => 'পণ্য',
                };

                return Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: ChoiceChip(
                    selected: selected,
                    onSelected: (_) => c.changeKind(kind),
                    showCheckmark: false,
                    selectedColor: blue,
                    backgroundColor: const Color(0xFFE1EBFF),
                    side: BorderSide.none,
                    label: Text(
                      label,
                      style: font(
                        14,
                        color: selected ? Colors.white : blue,
                        weight: FontWeight.w600,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (c.kind.value != DirectoryKind.products) ...[
                if (!c.servicesOnly)
                  chip(
                    directoryCategories[c.category.value] ??
                        'সেবার বিভাগ',
                    Icons.grid_view_rounded,
                    chooseCategory,
                    active: c.category.value.isNotEmpty,
                  ),
                if (c.subtypes.isNotEmpty)
                  chip(
                    c.subtypes[c.subtype.value] ?? 'সব ধরন',
                    Icons.tune_rounded,
                    chooseSubtype,
                    active: c.subtype.value.isNotEmpty,
                  ),
                chip(
                  c.area.value,
                  Icons.location_on_outlined,
                  chooseArea,
                  active: c.area.value != 'সব এলাকা',
                ),
              ],
              if (!c.servicesOnly &&
                  c.kind.value != DirectoryKind.services)
                chip(
                  'দাম ও সাজানো',
                  Icons.sort_rounded,
                  choosePrice,
                  active: c.minimumPrice.value != null ||
                      c.maximumPrice.value != null ||
                      c.sort.value != ProductSort.name,
                ),
              chip(
                'রিসেট',
                Icons.restart_alt_rounded,
                c.reset,
              ),
            ],
          ),
        ),
        if (!c.servicesOnly && c.kind.value == DirectoryKind.all)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 3, 18, 8),
            child: Text(
              'বিভাগ ও এলাকা filter সেবার জন্য; '
                  'দাম filter পণ্যের জন্য।',
              style: font(11, color: muted),
            ),
          ),
      ],
    );
  }

  Widget picture(DirectoryItem item) {
    final placeholder = ColoredBox(
      color: const Color(0xFFE5EFFF),
      child: Center(
        child: Icon(
          item.product
              ? Icons.shopping_bag_outlined
              : Icons.storefront_outlined,
          color: blue,
          size: 30,
        ),
      ),
    );

    final uri = Uri.tryParse(item.imageUrl);

    final usable = uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' || uri.scheme == 'http');

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        width: 78,
        height: 78,
        child: usable
            ? Image.network(
          item.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
          loadingBuilder: (_, child, progress) =>
          progress == null ? child : placeholder,
        )
            : placeholder,
      ),
    );
  }

  Widget saveButton(
      DirectoryItem item, {
        required bool saved,
        required bool enabled,
      }) {
    return OutlinedButton.icon(
      onPressed: !enabled
          ? null
          : () {
        if (item.product) {
          c.catalog.toggleProductSaved(item);
        } else {
          c.catalog.toggleSaved(item.id);
        }
      },
      icon: Icon(
        saved
            ? Icons.bookmark_rounded
            : Icons.bookmark_outline_rounded,
        size: 19,
      ),
      label: Text(
        saved ? 'সেভ করা' : 'সেভ',
        style: font(
          13,
          color: enabled ? blue : muted,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: blue,
        minimumSize: const Size(95, 48),
        side: const BorderSide(
          color: Color(0xFFD2E0FF),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    );
  }

  Widget card(DirectoryItem item) {
    // Each lazy-built card observes its own saved state.
    return Obx(() {
      final saved = item.product
          ? c.catalog.savedProductIds.contains(item.id)
          : c.catalog.savedIds.contains(item.id);

      final saveEnabled =
          c.catalog.savedReady.value && !c.catalog.saving.value;

      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => c.open(item),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    picture(item),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: font(
                              17,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.product ? 'Hello Store' : item.typeTitle,
                            style: font(12, color: blue),
                          ),
                          if (!item.product &&
                              item.typeTitle != item.categoryTitle)
                            Text(
                              item.categoryTitle,
                              style: font(11, color: muted),
                            ),
                          if (item.product) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.priceMinor == null
                                  ? 'দাম দেওয়া হয়নি'
                                  : '${directoryMoney(item.priceMinor!)}'
                                  '${item.unit.isEmpty ? '' : ' / ${item.unit}'}',
                              style: font(
                                16,
                                color: blue,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (item.product) ...[
                  const SizedBox(height: 12),
                  Text(
                    switch (item.inStock) {
                      true => 'স্টকে আছে',
                      false => 'স্টকে নেই',
                      null => 'স্টক তথ্য দেওয়া হয়নি',
                    },
                    style: font(
                      12,
                      color: item.inStock == true
                          ? const Color(0xFF18764A)
                          : item.inStock == false
                          ? const Color(0xFFBC4050)
                          : muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  saveButton(
                    item,
                    saved: saved,
                    enabled: saveEnabled,
                  ),
                ] else ...[
                  if (item.areas.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.areas.join(' · '),
                            style: font(12, color: muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: font(13, color: muted),
                    ),
                  ],
                  if (item.verified) ...[
                    const SizedBox(height: 10),
                    Tooltip(
                      message:
                      'যোগাযোগ যাচাই: ${item.verificationSource}\n'
                          '${item.verifiedAt!.day}/'
                          '${item.verifiedAt!.month}/'
                          '${item.verifiedAt!.year}',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_outlined,
                            color: blue,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'যোগাযোগ যাচাই করা',
                              style: font(11, color: blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: item.dialNumber == null
                            ? null
                            : () => c.call(item),
                        icon: const Icon(
                          Icons.call_outlined,
                          size: 18,
                        ),
                        label: Text(
                          item.dialNumber == null
                              ? 'নম্বর নেই'
                              : 'কল করুন',
                          style: font(
                            13,
                            color: item.dialNumber == null
                                ? muted
                                : Colors.white,
                            weight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: blue,
                          minimumSize: const Size(115, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                      saveButton(
                        item,
                        saved: saved,
                        enabled: saveEnabled,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget empty({required bool failed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 30,
      ),
      child: Column(
        children: [
          Icon(
            failed
                ? Icons.cloud_off_outlined
                : Icons.search_off_rounded,
            size: 54,
            color: blue,
          ),
          const SizedBox(height: 15),
          Text(
            failed
                ? 'ফলাফল নিশ্চিত করা যায়নি'
                : 'কোনো ফল পাওয়া যায়নি',
            textAlign: TextAlign.center,
            style: font(20, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            failed
                ? 'তালিকা refresh করে আবার চেষ্টা করুন।'
                : 'ছোট নাম দিয়ে খুঁজুন, অন্য বিভাগ বেছে নিন\n'
                'অথবা এলাকা ও দাম filter সরিয়ে দেখুন।',
            textAlign: TextAlign.center,
            style: font(14, color: muted),
          ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: failed
                ? () => c.reload(force: true)
                : c.reset,
            child: Text(
              failed
                  ? 'আবার চেষ্টা করুন'
                  : 'Search ও filter রিসেট',
              style: font(14, color: blue),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: navy,
        title: Text(
          c.title,
          style: font(20, weight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Obx(() {
              final results = c.filtered;
              final count = math.min(
                c.visibleLimit.value,
                results.length,
              );
              final errors = c.errors;
              final loading = c.loading;

              final catalogFailed = switch (c.kind.value) {
                DirectoryKind.services =>
                c.catalog.servicesError.value.isNotEmpty,
                DirectoryKind.products =>
                c.catalog.productsError.value.isNotEmpty,
                DirectoryKind.all =>
                c.catalog.servicesError.value.isNotEmpty ||
                    c.catalog.productsError.value.isNotEmpty,
              };

              return RefreshIndicator(
                color: blue,
                onRefresh: () => c.reload(force: true),
                child: CustomScrollView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: header()),
                    SliverToBoxAdapter(child: filters()),
                    if (errors.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEAF0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                errors.join('\n'),
                                style: font(
                                  13,
                                  color: const Color(0xFFA33851),
                                ),
                              ),
                              TextButton(
                                onPressed: loading
                                    ? null
                                    : () => c.reload(force: true),
                                child: const Text('আবার চেষ্টা করুন'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (loading)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(
                                color: blue,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'তালিকা প্রস্তুত হচ্ছে…',
                                style: font(14, color: muted),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            18,
                            12,
                            18,
                            14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  catalogFailed
                                      ? '${results.length}টি ফল দেখানো যাচ্ছে'
                                      : '${results.length}টি ফল পাওয়া গেছে',
                                  style: font(
                                    15,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedSwitcher(
                                duration: Duration(
                                  milliseconds:
                                  reduceMotion ? 0 : 180,
                                ),
                                child: Text(
                                  '$count / ${results.length}',
                                  key: ValueKey(
                                    '$count-${results.length}',
                                  ),
                                  style: font(12, color: muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (results.isEmpty)
                        SliverToBoxAdapter(
                          child: empty(failed: catalogFailed),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                final item = results[index];

                                return Padding(
                                  key: ValueKey(
                                    '${item.product}-${item.id}',
                                  ),
                                  padding:
                                  const EdgeInsets.only(bottom: 12),
                                  child: card(item),
                                );
                              },
                              childCount: count,
                            ),
                          ),
                        ),
                      if (count < results.length)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              24,
                            ),
                            child: OutlinedButton(
                              onPressed: () =>
                              c.visibleLimit.value += 20,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: blue,
                                minimumSize:
                                const Size.fromHeight(50),
                                side: const BorderSide(
                                  color: Color(0xFFB4CCFF),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(
                                'আরও দেখুন',
                                style: font(
                                  15,
                                  color: blue,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 20),
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

class PriceSelection {
  const PriceSelection(
      this.minimum,
      this.maximum,
      this.sort,
      );

  final int? minimum;
  final int? maximum;
  final ProductSort sort;
}

class DirectoryPriceSheet extends StatefulWidget {
  const DirectoryPriceSheet({
    super.key,
    required this.minimum,
    required this.maximum,
    required this.sort,
  });

  final int? minimum;
  final int? maximum;
  final ProductSort sort;

  @override
  State<DirectoryPriceSheet> createState() =>
      _DirectoryPriceSheetState();
}

class _DirectoryPriceSheetState extends State<DirectoryPriceSheet> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController minimum;
  late final TextEditingController maximum;
  late ProductSort sort;

  String priceText(int? value) {
    return value == null
        ? ''
        : directoryMoney(value).substring(1);
  }

  @override
  void initState() {
    super.initState();

    minimum = TextEditingController(
      text: priceText(widget.minimum),
    );

    maximum = TextEditingController(
      text: priceText(widget.maximum),
    );

    sort = widget.sort;
  }

  @override
  void dispose() {
    minimum.dispose();
    maximum.dispose();
    super.dispose();
  }

  String? validate(String? value, {bool upper = false}) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return null;

    final price = directoryParsePrice(text);

    if (price == null) {
      return 'সঠিক দাম লিখুন; সর্বোচ্চ ২ ঘর দশমিক।';
    }

    final lower = directoryParsePrice(minimum.text);

    if (upper && lower != null && price < lower) {
      return 'সর্বোচ্চ দাম কম হতে পারবে না।';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'পণ্যের দাম ও সাজানো',
                style: GoogleFonts.hindSiliguri(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF142B55),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: minimum,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: (value) => validate(value),
                decoration: const InputDecoration(
                  labelText: 'সর্বনিম্ন দাম — টাকা',
                  hintText: 'খালি রাখলে সীমা নেই',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: maximum,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                validator: (value) =>
                    validate(value, upper: true),
                decoration: const InputDecoration(
                  labelText: 'সর্বোচ্চ দাম — টাকা',
                  hintText: 'খালি রাখলে সীমা নেই',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ProductSort>(
                initialValue: sort,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'পণ্য সাজান',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ProductSort.name,
                    child: Text('নাম অনুযায়ী'),
                  ),
                  DropdownMenuItem(
                    value: ProductSort.priceLow,
                    child: Text('দাম: কম থেকে বেশি'),
                  ),
                  DropdownMenuItem(
                    value: ProductSort.priceHigh,
                    child: Text('দাম: বেশি থেকে কম'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => sort = value);
                  }
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;

                  FocusManager.instance.primaryFocus?.unfocus();

                  Navigator.of(context).pop(
                    PriceSelection(
                      directoryParsePrice(minimum.text),
                      directoryParsePrice(maximum.text),
                      sort,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1959FF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('প্রয়োগ করুন'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}