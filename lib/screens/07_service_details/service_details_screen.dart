import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/public_service_phone.dart';
import 'service_details_controller.dart';

class ServiceDetailsScreen extends StatefulWidget {
  const ServiceDetailsScreen({
    super.key,
    this.serviceId,
  });

  final String? serviceId;

  @override
  State<ServiceDetailsScreen> createState() =>
      _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  static const blue = Color(0xFF1959FF);
  static const navy = Color(0xFF142B55);
  static const muted = Color(0xFF7183A4);

  late final ServiceDetailsController c;
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
      height: 1.45,
    );
  }

  @override
  void initState() {
    super.initState();

    tag = UniqueKey().toString();

    c = Get.put(
      ServiceDetailsController(serviceId: widget.serviceId),
      tag: tag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<ServiceDetailsController>(tag: tag)) {
      Get.delete<ServiceDetailsController>(tag: tag);
    }

    super.dispose();
  }

  Widget section(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: font(17, weight: FontWeight.w700),
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }

  Future<void> callService(ServiceDetail value) async {
    final phones = value.phones;

    if (phones.isEmpty) return;

    if (phones.length == 1) {
      await c.call(phones.first);
      return;
    }

    final selected = await showModalBottomSheet<PublicServicePhone>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF1F6FF),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Column(
            children: [
              Text(
                'কোন নম্বরে কল করবেন?',
                style: font(21, weight: FontWeight.w700),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: phones.length,
                  itemBuilder: (context, index) {
                    final phone = phones[index];

                    return ListTile(
                      leading: const Icon(
                        Icons.call_outlined,
                        color: blue,
                      ),
                      title: Text(phone.label, style: font(16)),
                      subtitle: Text(phone.number),
                      trailing:
                      const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).pop(phone),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && mounted) {
      await c.call(selected);
    }
  }

  Future<void> report() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF1F6FF),
      builder: (_) => ServiceReportSheet(controller: c),
    );
  }

  Widget stateMessage(String title, {bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 48,
              color: blue,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: font(18, weight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (retry)
              FilledButton(
                onPressed: c.load,
                child: const Text('আবার চেষ্টা করুন'),
              ),
          ],
        ),
      ),
    );
  }

  Widget content(ServiceDetail value) {
    final item = value.item;
    final uri = Uri.tryParse(item.imageUrl);

    final hasImage =
        uri != null && ['https', 'http'].contains(uri.scheme);

    return RefreshIndicator(
      onRefresh: c.load,
      color: blue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (hasImage)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: Image.network(
                  item.imageUrl,
                  height: 205,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 150,
                    color: const Color(0xFFDDE9FF),
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: blue,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(21),
            margin: const EdgeInsets.only(bottom: 16),
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
                  item.categoryTitle,
                  style: font(
                    13,
                    color: const Color(0xFFDDE8FF),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  item.name,
                  style: font(
                    26,
                    color: Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
                if (item.typeTitle != item.categoryTitle) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.typeTitle,
                    style: font(
                      14,
                      color: const Color(0xFFE7EEFF),
                    ),
                  ),
                ],
                if (item.verified) ...[
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'যোগাযোগ যাচাই করা',
                          style: font(12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (value.address.isNotEmpty || item.areas.isNotEmpty)
            section(
              'ঠিকানা ও সেবার এলাকা',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (value.address.isNotEmpty)
                    SelectableText(
                      value.address,
                      style: font(15),
                    ),
                  if (item.areas.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      'এলাকা: ${item.areas.join(' · ')}',
                      style: font(13, color: muted),
                    ),
                  ],
                ],
              ),
            ),
          if (value.openingHours.isNotEmpty)
            section(
              'খোলার সময়',
              Text(value.openingHours, style: font(15)),
            ),
          section(
            'যোগাযোগ',
            value.phones.isEmpty
                ? Text(
              'প্রকাশের উপযোগী ফোন নম্বর যুক্ত করা হয়নি।',
              style: font(14, color: muted),
            )
                : Column(
              children: value.phones.map((phone) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              phone.label,
                              style: font(13, color: muted),
                            ),
                            SelectableText(
                              phone.number,
                              style: font(
                                17,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '${phone.label}-এ কল করুন',
                        onPressed: () => c.call(phone),
                        icon: const Icon(
                          Icons.call_outlined,
                          color: blue,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (value.description.isNotEmpty)
            section(
              'বিস্তারিত',
              SelectableText(
                value.description,
                style: font(15),
              ),
            ),
          section(
            'তথ্যের উৎস ও যাচাই',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.sourceName.isEmpty
                      ? 'তথ্যের উৎস দেওয়া হয়নি।'
                      : 'উৎস: ${value.sourceName}',
                  style: font(14),
                ),
                const SizedBox(height: 9),
                Text(
                  item.verified
                      ? 'সর্বশেষ যোগাযোগ যাচাই: '
                      '${item.verifiedAt!.day}/'
                      '${item.verifiedAt!.month}/'
                      '${item.verifiedAt!.year}\n'
                      'যাচাই করেছেন: ${item.verificationSource}'
                      : 'যোগাযোগ যাচাইয়ের তথ্য পাওয়া যায়নি।',
                  style: font(13, color: muted),
                ),
                if (value.sourceUri != null)
                  TextButton.icon(
                    onPressed: c.openSource,
                    icon: const Icon(
                      Icons.open_in_new_rounded,
                      size: 17,
                    ),
                    label: const Text('উৎসের link খুলুন'),
                  ),
                if (value.governmentInformation) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Hello Dimla একটি স্বাধীন স্থানীয় সেবা app। '
                        'এটি সরকারি app নয় এবং কোনো সরকারি '
                        'প্রতিষ্ঠানের প্রতিনিধিত্ব করে না।',
                    style: font(13, color: blue),
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            onPressed: report,
            icon: const Icon(Icons.flag_outlined),
            label: Text(
              'ভুল তথ্য জানান',
              style: font(14, color: blue),
            ),
          ),
        ],
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
          'সেবার বিস্তারিত',
          style: font(20, weight: FontWeight.w700),
        ),
        actions: [
          Builder(
            builder: (buttonContext) => Obx(
                  () => IconButton(
                tooltip: 'Share',
                onPressed: c.detail.value == null
                    ? null
                    : () {
                  final box =
                  buttonContext.findRenderObject() as RenderBox?;

                  if (box == null || !box.hasSize) return;

                  c.share(
                    box.localToGlobal(Offset.zero) & box.size,
                  );
                },
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Obx(() {
            if (c.loading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            if (c.error.value.isNotEmpty) {
              return stateMessage(c.error.value, retry: true);
            }

            final value = c.detail.value;

            if (c.missing.value || value == null) {
              return stateMessage('এই সেবা এখন পাওয়া যাচ্ছে না।');
            }

            return content(value);
          }),
        ),
      ),
      bottomNavigationBar: Obx(() {
        final value = c.detail.value;
        if (value == null) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                  value.phones.isEmpty ? null : () => callService(value),
                  icon: const Icon(Icons.call_outlined, size: 20),
                  label: const Text('কল করুন'),
                  style: FilledButton.styleFrom(
                    backgroundColor: blue,
                    minimumSize: const Size(170, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: !c.saved.ready.value || c.saved.saving.value
                      ? null
                      : c.toggleSaved,
                  icon: Icon(
                    c.isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                  ),
                  label: Text(c.isSaved ? 'সেভ করা' : 'সেভ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: blue,
                    minimumSize: const Size(115, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class ServiceReportSheet extends StatefulWidget {
  const ServiceReportSheet({
    super.key,
    required this.controller,
  });

  final ServiceDetailsController controller;

  @override
  State<ServiceReportSheet> createState() => _ServiceReportSheetState();
}

class _ServiceReportSheetState extends State<ServiceReportSheet> {
  final form = GlobalKey<FormState>();
  final description = TextEditingController();
  String? reason;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return Obx(
          () => PopScope(
        canPop: !c.reporting.value,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ভুল তথ্য জানান',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'রিপোর্ট Admin যাচাই করবেন। '
                        'এতে প্রকাশিত তথ্য সঙ্গে সঙ্গে বদলাবে না।',
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: reason,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'কারণ নির্বাচন করুন',
                      border: OutlineInputBorder(),
                    ),
                    items: serviceReportReasons.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: c.reporting.value
                        ? null
                        : (value) => setState(() => reason = value),
                    validator: (value) =>
                    value == null ? 'একটি কারণ নির্বাচন করুন।' : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: description,
                    enabled: !c.reporting.value,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'বিবরণ — optional',
                      hintText: 'কোন তথ্যটি ভুল, সংক্ষেপে লিখুন।',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    (value?.trim().length ?? 0) > 500
                        ? 'সর্বোচ্চ ৫০০ অক্ষর লিখুন।'
                        : null,
                  ),
                  const SizedBox(height: 15),
                  FilledButton(
                    onPressed: c.reporting.value
                        ? null
                        : () async {
                      if (!form.currentState!.validate()) return;

                      final result = await c.submitReport(
                        reason!,
                        description.text,
                      );

                      if (!mounted || result == null) return;

                      Navigator.of(context).pop();

                      Get.snackbar(
                        'রিপোর্ট',
                        result,
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1959FF),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(
                      c.reporting.value ? 'জমা হচ্ছে…' : 'রিপোর্ট জমা দিন',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}