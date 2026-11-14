import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/service_api.dart';

typedef _J = Map<String, dynamic>;

const _blue = Color(0xFF2258CB);
const _navy = Color(0xFF16366C);
const _bg = Color(0xFFF4F7FC);

int _id(dynamic value) => int.tryParse('$value') ?? 0;

bool _yes(dynamic value) => value == true || _id(value) == 1;

List<Map> _rows(dynamic value) =>
    value is List ? value.whereType<Map>().toList() : [];

List<String> _options(Map field) =>
    (field['options'] as List? ?? []).whereType<String>().toList();

class ServiceListPanel extends StatefulWidget {
  const ServiceListPanel({
    super.key,
    required this.menu,
    required this.zone,
    required this.areas,
  });

  final _J menu;
  final int zone;
  final Map<int, String> areas;

  @override
  State<ServiceListPanel> createState() => _ServiceListState();
}

class _ServiceListState extends State<ServiceListPanel> {
  List<_J> entries = [];
  final filters = <String, String>{};

  Timer? timer;
  bool loading = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    load();

    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          TickerMode.of(context) &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        load();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (loading) return;

    setState(() {
      loading = true;
      error = '';
    });

    try {
      final rows = <int, _J>{};
      int? cursor = 0;

      while (mounted && cursor != null) {
        final page = await ServiceApi.entries(
          menuId: _id(widget.menu['id']),
          areaId: widget.zone,
          after: cursor,
        );

        for (final row in page.items) {
          rows[_id(row['id'])] = row;
        }
        cursor = page.nextAfter;
      }

      if (!mounted) return;

      final result = rows.values.toList()
        ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));

      setState(() => entries = result);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String areaOf(_J row) {
    if (_yes(row['wide'])) return 'পুরো ডিমলা';

    return (row['areas'] as List? ?? [])
        .map((id) => widget.areas[_id(id)])
        .whereType<String>()
        .join(' · ');
  }

  Widget avatar(_J row) {
    const fallback = Icon(Icons.person_outline, color: _blue);

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFEDF3FF),
      child: !_yes(row['hasPhoto'])
          ? fallback
          : ClipOval(
        child: Image.network(
          ServiceApi.profilePhoto(
            _id(row['id']),
            revision: _id(row['rev']),
          ).toString(),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }

  Future<void> openExternal(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // দেখানোর মতো অ্যাপ না থাকলে নিচে বার্তা দেখানো হবে।
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ফোনে এই লিংকটি খোলা যায়নি।')),
      );
    }
  }

  void details(_J row) {
    final phone = '${row['phone'] ?? ''}';
    final profile = _rows(row['profileFields']);
    final address = profile
        .where((f) => f['label'] == 'ঠিকানা')
        .map((f) => '${f['value']}')
        .join(' ');

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: avatar(row)),
              const SizedBox(height: 8),
              Text(
                '${row['name']}',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(areaOf(row)),
              ),
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: Text(phone),
                onTap: phone.isEmpty
                    ? null
                    : () => openExternal(Uri(scheme: 'tel', path: phone)),
              ),
              for (final f in profile)
                ListTile(
                  title: Text('${f['label']}'),
                  subtitle: Text('${f['value']}'),
                ),
              for (final f in _rows(widget.menu['fields']))
                if (row['extra']?[f['key']] != null)
                  ListTile(
                    title: Text('${f['label']}'),
                    subtitle: Text("${row['extra'][f['key']]}"),
                  ),
              if (address.isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('ম্যাপে ঠিকানা দেখুন'),
                  onPressed: () => openExternal(Uri.https(
                    'www.google.com',
                    '/maps/search/',
                    {
                      'api': '1',
                      'query': '$address, ${areaOf(row)}, ডিমলা, বাংলাদেশ',
                    },
                  )),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> add() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _SubmissionPage(
          menu: widget.menu,
          areas: widget.areas,
          zone: widget.zone,
        ),
      ),
    );

    if (mounted && ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('তথ্য জমা হয়েছে। অনুমোদনের পর তালিকায় দেখা যাবে।'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _rows(widget.menu['fields']);

    final list = entries.where((row) {
      return fields.every((f) {
        final selected = filters[f['key']];
        return selected == null ||
            !_options(f).contains(selected) ||
            row['extra']?[f['key']] == selected;
      });
    }).toList();

    return ColoredBox(
      color: _bg,
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          itemCount: list.length + 1,
          itemBuilder: (_, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _navy,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        if (_yes(widget.menu['hasIcon']))
                          Image.network(
                            ServiceApi.menuIcon(
                              _id(widget.menu['id']),
                              revision: _id(widget.menu['rev']),
                            ).toString(),
                            width: 36,
                            height: 36,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.contacts_outlined,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(
                            Icons.contacts_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.menu['title']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.areas[widget.zone] ?? 'সকল ইউনিয়ন',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_yes(widget.menu['accept']))
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: FilledButton.icon(
                        onPressed: add,
                        icon: const Icon(Icons.add),
                        label: const Text('সেবার তথ্য যোগ করুন'),
                      ),
                    ),
                  for (final f in fields.where((f) => _options(f).isNotEmpty))
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _options(f).contains(filters[f['key']])
                          ? filters[f['key']]
                          : '',
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text("${f['label']}: সব"),
                        ),
                        for (final option in _options(f))
                          DropdownMenuItem(value: option, child: Text(option)),
                      ],
                      onChanged: (v) => setState(
                            () => filters['${f['key']}'] = v ?? '',
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (loading) const LinearProgressIndicator(minHeight: 2),
                  if (error.isNotEmpty)
                    TextButton.icon(
                      onPressed: load,
                      icon: const Icon(Icons.refresh),
                      label: Text('$error · আবার চেষ্টা করুন'),
                    ),
                  if (!loading && error.isEmpty && list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'এই নির্বাচনে এখনো কোনো প্রকাশিত তথ্য নেই।',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              );
            }

            final row = list[index - 1];
            final phone = '${row['phone'] ?? ''}';

            return Card(
              color: Colors.white,
              elevation: 0,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                leading: avatar(row),
                title: Text(
                  '${row['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [areaOf(row), phone].where((s) => s.isNotEmpty).join('\n'),
                ),
                trailing: IconButton.filledTonal(
                  tooltip: 'কল করুন',
                  icon: const Icon(Icons.call_outlined),
                  onPressed: phone.isEmpty
                      ? null
                      : () => openExternal(Uri(scheme: 'tel', path: phone)),
                ),
                onTap: () => details(row),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SubmissionPage extends StatefulWidget {
  const _SubmissionPage({
    required this.menu,
    required this.areas,
    required this.zone,
  });

  final _J menu;
  final Map<int, String> areas;
  final int zone;

  @override
  State<_SubmissionPage> createState() => _SubmissionState();
}

class _SubmissionState extends State<_SubmissionPage> {
  final key = GlobalKey<FormState>();
  final extra = <String, String>{};

  String name = '', phone = '', address = '', error = '';
  int? zone;
  Uint8List? photo;
  bool consent = false, busy = false, picking = false;

  @override
  void initState() {
    super.initState();
    zone = widget.areas.containsKey(widget.zone) ? widget.zone : null;
  }

  InputDecoration decoration(String title, IconData icon) => InputDecoration(
    labelText: title,
    prefixIcon: Icon(icon),
    border: const OutlineInputBorder(),
  );

  String normalizePhone(String value) => value
      .trim()
      .replaceAllMapped(
    RegExp('[০-৯]'),
        (m) => '০১২৩৪৫৬৭৮৯'.indexOf(m[0]!).toString(),
  )
      .replaceAll(RegExp(r'[\s()-]'), '');

  Future<void> pickPhoto() async {
    if (picking || busy) return;

    setState(() {
      picking = true;
      error = '';
    });

    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 192,
        maxHeight: 192,
        imageQuality: 80,
      );

      if (file == null) return;

      if (await file.length() > 4000000) {
        throw const FormatException('আরেকটি ছোট ছবি বাছুন।');
      }

      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) {
        throw const FormatException('JPG অথবা PNG ছবি দিন।');
      }

      final thumb = img.copyResizeCropSquare(
        img.bakeOrientation(decoded),
        size: 160,
      );

      var bytes = img.encodeJpg(thumb, quality: 75);
      if (bytes.length > 24000) {
        bytes = img.encodeJpg(thumb, quality: 45);
      }
      if (bytes.length > 24000) {
        throw const FormatException('ছবিটি বেশি বড়। আরেকটি ছবি বাছুন।');
      }

      if (mounted) setState(() => photo = Uint8List.fromList(bytes));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> send() async {
    if (busy || picking || !key.currentState!.validate()) return;

    if (!consent) {
      setState(() => error = 'প্রকাশের সম্মতি দিন।');
      return;
    }

    setState(() {
      busy = true;
      error = '';
    });

    try {
      await ServiceApi.submit(
        menuId: _id(widget.menu['id']),
        name: name.trim(),
        phone: normalizePhone(phone),
        areaIds: [zone!],
        consent: true,
        extra: extra,
        address: address.trim(),
        photoBase64: photo == null ? null : base64Encode(photo!),
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('সেবার তথ্য যোগ করুন')),
        body: SafeArea(
          child: Form(
            key: key,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  '${widget.menu['title']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text('তথ্য যাচাইয়ের পর প্রকাশ করা হবে।'),
                const SizedBox(height: 16),
                Center(
                  child: CircleAvatar(
                    radius: 38,
                    backgroundImage: photo == null ? null : MemoryImage(photo!),
                    child: photo == null
                        ? const Icon(Icons.person_outline, size: 36)
                        : null,
                  ),
                ),
                TextButton.icon(
                  onPressed: busy || picking ? null : pickPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    picking
                        ? 'ছবি প্রস্তুত হচ্ছে…'
                        : photo == null
                        ? 'প্রোফাইল ছবি বাছুন (ঐচ্ছিক)'
                        : 'ছবি বদলান',
                  ),
                ),
                TextFormField(
                  maxLength: 100,
                  decoration: decoration('ব্যক্তি / প্রতিষ্ঠানের নাম', Icons.badge_outlined),
                  onChanged: (v) => name = v,
                  validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'পুরো নাম লিখুন' : null,
                ),
                TextFormField(
                  maxLength: 20,
                  keyboardType: TextInputType.phone,
                  decoration: decoration('মোবাইল নম্বর', Icons.phone_outlined),
                  onChanged: (v) => phone = v,
                  validator: (v) =>
                  RegExp(r'^(?:\+88)?01[3-9][0-9]{8}$')
                      .hasMatch(normalizePhone(v ?? ''))
                      ? null
                      : 'সঠিক বাংলাদেশি মোবাইল নম্বর দিন',
                ),
                DropdownButtonFormField<int>(
                  initialValue: zone,
                  isExpanded: true,
                  decoration: decoration('সেবার ইউনিয়ন', Icons.place_outlined),
                  items: [
                    for (final e in widget.areas.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => zone = v),
                  validator: (v) => v == null ? 'ইউনিয়ন নির্বাচন করুন' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  maxLength: 180,
                  decoration: decoration('সেবার স্থান / বাজার / স্ট্যান্ড', Icons.map_outlined),
                  onChanged: (v) => address = v,
                  validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'সেবার ঠিকানা লিখুন' : null,
                ),
                for (final f in _rows(widget.menu['fields']))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _options(f).isEmpty
                        ? TextFormField(
                      maxLength: 120,
                      decoration: decoration('${f['label']}', Icons.notes),
                      onChanged: (v) => extra['${f['key']}'] = v.trim(),
                    )
                        : DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: decoration('${f['label']}', Icons.list),
                      items: [
                        for (final option in _options(f))
                          DropdownMenuItem(value: option, child: Text(option)),
                      ],
                      onChanged: (v) => extra['${f['key']}'] = v ?? '',
                    ),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: consent,
                  onChanged: busy ? null : (v) => setState(() => consent = v ?? false),
                  title: const Text(
                    'নাম, মোবাইল, ছবি ও সেবার ঠিকানা প্রকাশে সংশ্লিষ্ট ব্যক্তির সম্মতি আছে।',
                  ),
                ),
                if (error.isNotEmpty)
                  Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: busy || picking ? null : send,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(busy ? 'জমা হচ্ছে…' : 'যাচাইয়ের জন্য জমা দিন'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}