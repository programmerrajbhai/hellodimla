import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/service_api.dart';

typedef _Json = Map<String, dynamic>;

const _navy = Color(0xFF122E58);
const _blue = Color(0xFF1956BD);
const _paleBlue = Color(0xFFEBF3FF);
const _background = Color(0xFFF4F7FC);
const _border = Color(0xFFD9E4F2);
const _muted = Color(0xFF50647B);

int _id(dynamic value) => int.tryParse('$value') ?? 0;
bool _yes(dynamic value) => value == true || _id(value) == 1;
String _text(dynamic value) => value?.toString().trim() ?? '';

List<_Json> _rows(dynamic value) {
  if (value is! List) return [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

List<String> _options(_Json field) {
  final values = field['options'];
  if (values is! List) return [];
  return values.map(_text).where((s) => s.isNotEmpty).toSet().toList();
}

String _normalizePhone(String value) {
  return value
      .replaceAllMapped(
    RegExp('[০-৯]'),
        (m) => '০১২৩৪৫৬৭৮৯'.indexOf(m[0]!).toString(),
  )
      .replaceAll(RegExp(r'[\s()-]'), '');
}

String _formTitle(_Json menu) {
  final title = _text(menu['title']).toLowerCase();

  if (title.contains('blood') || title.contains('রক্ত')) {
    return 'রক্তদাতার তথ্য দিন';
  }

  if (title.contains('ambulance') ||
      title.contains('অ্যাম্বুলেন্স') ||
      title.contains('এম্বুলেন্স')) {
    return 'অ্যাম্বুলেন্সের তথ্য দিন';
  }

  return 'সেবার তথ্য দিন';
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: _border),
);

InputDecoration _input(String label, IconData icon, {String? hint}) {
  OutlineInputBorder edge(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, size: 21, color: _blue),
    filled: true,
    fillColor: Colors.white,
    border: edge(_border),
    enabledBorder: edge(_border),
    focusedBorder: edge(_blue, 1.6),
    errorMaxLines: 2,
  );
}

ButtonStyle _primaryButton() => FilledButton.styleFrom(
  backgroundColor: _blue,
  foregroundColor: Colors.white,
  minimumSize: const Size(0, 48),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  textStyle: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  ),
);

// ───────────────────── সেবার তালিকা ─────────────────────

class ServiceListPanel extends StatefulWidget {
  const ServiceListPanel({
    super.key,
    required this.menu,
    required this.zone,
    required this.areas,
  });

  final Map<String, dynamic> menu;
  final int zone;
  final Map<int, String> areas;

  @override
  State<ServiceListPanel> createState() => _ServiceListState();
}

class _ServiceListState extends State<ServiceListPanel> {
  List<_Json> _entries = [];
  final Map<String, String> _filters = {};
  Timer? _timer;
  bool _loading = false;
  String _error = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();

    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (TickerMode.of(context) &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _load();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ServiceListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_id(oldWidget.menu['id']) != _id(widget.menu['id']) ||
        oldWidget.zone != widget.zone) {
      _generation++;
      _loading = false;
      _entries = [];
      _filters.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;

    final token = ++_generation;
    final menuId = _id(widget.menu['id']);
    final areaId = widget.zone;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = <int, _Json>{};
      int after = 0;

      while (true) {
        final page = await ServiceApi.entries(
          menuId: menuId,
          areaId: areaId,
          after: after,
        );

        if (!mounted || token != _generation) return;

        for (final entry in page.items) {
          result[_id(entry['id'])] = entry;
        }

        final next = page.nextAfter;
        if (next == null) break;
        if (next <= after) {
          throw const FormatException('তালিকার পরের অংশ লোড করা যায়নি।');
        }
        after = next;
      }

      final sorted = result.values.toList()
        ..sort((a, b) => _text(a['name']).compareTo(_text(b['name'])));

      setState(() => _entries = sorted);
    } catch (e) {
      if (mounted && token == _generation) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted && token == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  String _areaOf(_Json entry) {
    if (_yes(entry['wide'])) return 'পুরো ডিমলা';
    final ids = entry['areas'];
    if (ids is! List) return '';

    return ids
        .map((id) => widget.areas[_id(id)])
        .whereType<String>()
        .join(' · ');
  }

  Widget _avatar(_Json entry) {
    const fallback = Icon(Icons.person_outline_rounded, color: _blue);

    return CircleAvatar(
      radius: 24,
      backgroundColor: _paleBlue,
      child: !_yes(entry['hasPhoto'])
          ? fallback
          : ClipOval(
        child: Image.network(
          ServiceApi.profilePhoto(
            _id(entry['id']),
            revision: _id(entry['rev']),
          ).toString(),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }

  Future<void> _openLink(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // নিচে ব্যবহারকারীকে জানানো হবে।
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('এই ফোনে লিংকটি খোলা যায়নি।')),
    );
  }

  void _details(_Json entry) {
    final phone = _text(entry['phone']);
    final area = _areaOf(entry);
    final extra = entry['extra'];
    final profile = _rows(entry['profileFields']);

    final address = profile
        .where((f) => _text(f['label']) == 'ঠিকানা')
        .map((f) => _text(f['value']))
        .where((s) => s.isNotEmpty)
        .join(', ');

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _avatar(entry)),
              const SizedBox(height: 8),
              Text(
                _text(entry['name']),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (area.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.place_outlined, color: _blue),
                  title: Text(area),
                ),
              for (final field in profile)
                ListTile(
                  dense: true,
                  title: Text(_text(field['label'])),
                  subtitle: Text(_text(field['value'])),
                ),
              if (extra is Map)
                for (final field in _rows(widget.menu['fields']))
                  if (_text(extra[field['key']]).isNotEmpty)
                    ListTile(
                      dense: true,
                      title: Text(_text(field['label'])),
                      subtitle: Text(_text(extra[field['key']])),
                    ),
              if (address.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openLink(
                    Uri.https('www.google.com', '/maps/search/', {
                      'api': '1',
                      'query': [
                        address,
                        if (area.isNotEmpty) area,
                        'ডিমলা',
                        'বাংলাদেশ',
                      ].join(', '),
                    }),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('ম্যাপে ঠিকানা দেখুন'),
                ),
              if (phone.isNotEmpty)
                FilledButton.icon(
                  style: _primaryButton(),
                  onPressed: () => _openLink(Uri(scheme: 'tel', path: phone)),
                  icon: const Icon(Icons.call_outlined),
                  label: Text('কল করুন · $phone'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm() async {
    if (!widget.areas.keys.any((id) => id > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ইউনিয়নের তালিকা পাওয়া যায়নি। মেনুটি আবার খুলুন।'),
        ),
      );
      return;
    }

    final receipt = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => _SubmissionPage(
          menu: widget.menu,
          zone: widget.zone,
          areas: widget.areas,
        ),
      ),
    );

    if (!mounted || receipt == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text('আবেদন #$receipt জমা হয়েছে। যাচাইয়ের পর প্রকাশ হবে।'),
      ),
    );
  }

  Widget _header() {
    const fallback = Icon(Icons.contacts_outlined, color: _blue, size: 26);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _blue],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _yes(widget.menu['hasIcon'])
                ? Image.network(
              ServiceApi.menuIcon(
                _id(widget.menu['id']),
                revision: _id(widget.menu['rev']),
              ).toString(),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => fallback,
            )
                : fallback,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(widget.menu['title']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.areas[widget.zone] ?? 'সকল ইউনিয়ন',
                  style: const TextStyle(color: Color(0xFFDEEAFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterField(_Json field) {
    final key = _text(field['key']);
    final options = _options(field);
    final selected = _filters[key] ?? '';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InputDecorator(
        decoration: _input(_text(field['label']), Icons.tune_rounded),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            isDense: true,
            value: options.contains(selected) ? selected : '',
            items: [
              const DropdownMenuItem(value: '', child: Text('সব দেখুন')),
              for (final option in options)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: (v) => setState(() => _filters[key] = v ?? ''),
          ),
        ),
      ),
    );
  }

  Widget _contactCard(_Json entry) {
    final phone = _text(entry['phone']);
    final area = _areaOf(entry);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: _cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: _avatar(entry),
        onTap: () => _details(entry),
        title: Text(
          _text(entry['name']),
          style: const TextStyle(color: _navy, fontWeight: FontWeight.w700),
        ),
        subtitle: Text([
          if (area.isNotEmpty) area,
          if (phone.isNotEmpty) phone,
        ].join('\n')),
        trailing: IconButton(
          tooltip: 'কল করুন',
          style: IconButton.styleFrom(
            backgroundColor: _paleBlue,
            foregroundColor: _blue,
          ),
          onPressed: phone.isEmpty
              ? null
              : () => _openLink(Uri(scheme: 'tel', path: phone)),
          icon: const Icon(Icons.call_outlined),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = _rows(widget.menu['fields']);
    final filtered = _entries.where((entry) {
      final extra = entry['extra'];
      return fields.every((field) {
        final selected = _filters[_text(field['key'])] ?? '';
        return selected.isEmpty ||
            !_options(field).contains(selected) ||
            (extra is Map && _text(extra[field['key']]) == selected);
      });
    }).toList();

    return Scaffold(
      backgroundColor: _background,

      // সব সেবার তালিকায় দৃশ্যমান; তালিকা খালি হলেও থাকবে।
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        tooltip: _formTitle(widget.menu),
        onPressed: _openForm,
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 26),
        label: const Text(
          'তথ্য দিন',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      body: RefreshIndicator(
        color: _blue,
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
          itemCount: filtered.length + 1,
          itemBuilder: (_, index) {
            if (index > 0) return _contactCard(filtered[index - 1]);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                for (final field in fields)
                  if (_options(field).isNotEmpty) _filterField(field),
                const SizedBox(height: 16),
                const Text(
                  'যোগাযোগের তালিকা',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                if (_loading)
                  const LinearProgressIndicator(color: _blue, minHeight: 2),
                if (_error.isNotEmpty)
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text('$_error\nআবার চেষ্টা করুন'),
                  ),
                if (!_loading && _error.isEmpty && filtered.isEmpty)
                  Container(
                    decoration: _cardDecoration(),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.contact_phone_outlined,
                          size: 30,
                          color: _blue,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'এই নির্বাচনে কোনো প্রকাশিত তথ্য নেই।',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _filters.values.any((v) => v.isNotEmpty)
                              ? 'অন্য ফলাফল দেখতে ফিল্টারে “সব দেখুন” বেছে নিন।'
                              : 'নতুন তথ্য পাঠাতে নিচের “＋ তথ্য দিন” চাপুন।',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────── আবেদন ফর্ম ─────────────────────

class _SubmissionPage extends StatefulWidget {
  const _SubmissionPage({
    required this.menu,
    required this.zone,
    required this.areas,
  });

  final _Json menu;
  final int zone;
  final Map<int, String> areas;

  @override
  State<_SubmissionPage> createState() => _SubmissionState();
}

class _SubmissionState extends State<_SubmissionPage> {
  final _formKey = GlobalKey<FormState>();
  final _extra = <String, String>{};

  String _name = '';
  String _phone = '';
  String _address = '';
  String _error = '';

  int? _zone;
  Uint8List? _photo;
  bool _consent = false;
  bool _sending = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    if (widget.zone > 0 && widget.areas.containsKey(widget.zone)) {
      _zone = widget.zone;
    }
  }

  Future<void> _pickPhoto() async {
    if (_sending || _picking) return;
    setState(() {
      _picking = true;
      _error = '';
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
        throw const FormatException('৪ MB-এর মধ্যে একটি ছবি বেছে নিন।');
      }

      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) {
        throw const FormatException('ছবিটি পড়া যায়নি। JPG বা PNG ছবি দিন।');
      }

      final thumb = img.copyResizeCropSquare(
        img.bakeOrientation(decoded),
        size: 160,
      );

      Uint8List? jpeg;
      for (final quality in [80, 65, 45, 30]) {
        final bytes = img.encodeJpg(thumb, quality: quality);
        if (bytes.length <= 24000) {
          jpeg = Uint8List.fromList(bytes);
          break;
        }
      }
      if (jpeg == null) {
        throw const FormatException('ছবিটি বেশি বড়। অন্য ছবি বেছে নিন।');
      }
      if (mounted) setState(() => _photo = jpeg);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _picking) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_consent) {
      setState(() => _error = 'তথ্য প্রকাশের সম্মতি নিশ্চিত করুন।');
      return;
    }

    final zone = _zone;
    if (zone == null || zone < 1) {
      setState(() => _error = 'সেবার ইউনিয়ন বেছে নিন।');
      return;
    }

    setState(() {
      _sending = true;
      _error = '';
    });

    try {
      final receipt = await ServiceApi.submit(
        menuId: _id(widget.menu['id']),
        name: _name.trim(),
        phone: _normalizePhone(_phone),
        areaIds: [zone],
        consent: _consent,
        extra: Map<String, String>.from(_extra),
        address: _address.trim(),
        photoBase64: _photo == null ? null : base64Encode(_photo!),
      );

      if (mounted) Navigator.of(context).pop(receipt);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '$e';
      });
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _extraField(_Json field) {
    final key = _text(field['key']);
    final label = _text(field['label']);
    final options = _options(field);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: options.isEmpty
          ? TextFormField(
        enabled: !_sending,
        maxLength: 120,
        decoration: _input(label, Icons.notes_outlined),
        onChanged: (v) => _extra[key] = v.trim(),
      )
          : DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: _input(label, Icons.list_alt),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: _sending ? null : (v) => _extra[key] = v ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zones = widget.areas.entries.where((e) => e.key > 0);
    final fields = _rows(widget.menu['fields']);

    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: Text(_formTitle(widget.menu)),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(14),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _paleBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${_text(widget.menu['title'])} · '
                        'অ্যাডমিন যাচাই করার পর তথ্যটি প্রকাশ হবে।',
                    style: const TextStyle(color: _navy),
                  ),
                ),

                _section('যোগাযোগের তথ্য', [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: _paleBlue,
                        backgroundImage:
                        _photo == null ? null : MemoryImage(_photo!),
                        child: _photo == null
                            ? const Icon(Icons.person_outline, color: _blue)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _sending || _picking ? null : _pickPhoto,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: Text(
                            _picking
                                ? 'ছবি প্রস্তুত হচ্ছে…'
                                : _photo == null
                                ? 'ছবি দিন (ঐচ্ছিক)'
                                : 'ছবি বদলান',
                          ),
                        ),
                      ),
                      if (_photo != null)
                        IconButton(
                          tooltip: 'ছবি বাদ দিন',
                          onPressed: _sending || _picking
                              ? null
                              : () => setState(() => _photo = null),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    enabled: !_sending,
                    maxLength: 100,
                    textInputAction: TextInputAction.next,
                    decoration: _input(
                      'ব্যক্তি / প্রতিষ্ঠানের নাম',
                      Icons.badge_outlined,
                    ),
                    onChanged: (v) => _name = v,
                    validator: (v) =>
                    _text(v).length < 2 ? 'পুরো নাম লিখুন।' : null,
                  ),
                  TextFormField(
                    enabled: !_sending,
                    maxLength: 20,
                    keyboardType: TextInputType.phone,
                    decoration: _input(
                      'মোবাইল নম্বর',
                      Icons.phone_outlined,
                      hint: '01XXXXXXXXX',
                    ),
                    onChanged: (v) => _phone = v,
                    validator: (v) {
                      final phone = _normalizePhone(v ?? '');
                      return RegExp(r'^(?:\+88)?01[3-9][0-9]{8}$')
                          .hasMatch(phone)
                          ? null
                          : 'সঠিক বাংলাদেশি মোবাইল নম্বর দিন।';
                    },
                  ),
                ]),

                _section('সেবার এলাকা', [
                  DropdownButtonFormField<int>(
                    initialValue: _zone,
                    isExpanded: true,
                    decoration: _input('ইউনিয়ন', Icons.place_outlined),
                    items: [
                      for (final zone in zones)
                        DropdownMenuItem(
                          value: zone.key,
                          child: Text(zone.value),
                        ),
                    ],
                    onChanged: _sending
                        ? null
                        : (v) => setState(() => _zone = v),
                    validator: (v) =>
                    v == null || v < 1 ? 'ইউনিয়ন বেছে নিন।' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    enabled: !_sending,
                    maxLength: 180,
                    decoration: _input(
                      'সেবার স্থান / বাজার / স্ট্যান্ড',
                      Icons.map_outlined,
                    ),
                    onChanged: (v) => _address = v,
                    validator: (v) =>
                    _text(v).isEmpty ? 'সেবার স্থানের নাম লিখুন।' : null,
                  ),
                ]),

                if (fields.isNotEmpty)
                  _section('সেবার বিস্তারিত', [
                    for (final field in fields) _extraField(field),
                  ]),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: _blue,
                  value: _consent,
                  onChanged: _sending
                      ? null
                      : (v) => setState(() {
                    _consent = v ?? false;
                    _error = '';
                  }),
                  title: const Text(
                    'যাঁর তথ্য দিচ্ছি, তাঁর নাম, নম্বর, ছবি ও দেওয়া তথ্য '
                        'প্রকাশে তাঁর সম্মতি আছে।',
                    style: TextStyle(color: _navy, fontSize: 14),
                  ),
                ),

                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error,
                        style: const TextStyle(color: Color(0xFFA12632)),
                      ),
                    ),
                  ),

                FilledButton.icon(
                  style: _primaryButton(),
                  onPressed: _sending || _picking ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    _sending ? 'জমা হচ্ছে…' : 'যাচাইয়ের জন্য জমা দিন',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}