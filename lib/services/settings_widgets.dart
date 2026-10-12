import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app_settings_service.dart';

const settingsBlue = Color(0xFF174BB8);

String _settingsError(Object error) {
  if (error is FormatException) return error.message;
  if (error is StateError) return '${error.message}';

  return 'কাজটি সম্পন্ন হয়নি। সংযোগ ও অনুমতি পরীক্ষা করে '
      'আবার চেষ্টা করুন।';
}

Future<void> settingsAction(
    Future<void> Function() action,
    ) async {
  try {
    await action();
  } catch (error) {
    Get.snackbar(
      'কাজটি সম্পন্ন হয়নি',
      _settingsError(error),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.white,
      colorText: Colors.red.shade800,
      margin: const EdgeInsets.all(12),
    );
  }
}

Future<bool> settingsConfirm(
    String title,
    String message,
    ) async {
  return await Get.dialog<bool>(
    AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Text(message),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('না'),
        ),
        FilledButton(
          onPressed: () => Get.back(result: true),
          child: const Text('হ্যাঁ'),
        ),
      ],
    ),
    barrierDismissible: false,
  ) ??
      false;
}

Widget settingsCard(List<Widget> children) {
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

Widget settingsHeading(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Future<void> copySettingsText(String text) async {
  await Clipboard.setData(ClipboardData(text: text));

  Get.snackbar(
    'কপি হয়েছে',
    'তথ্য clipboard-এ রাখা হয়েছে।',
    snackPosition: SnackPosition.BOTTOM,
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final Widget Function(AppSettingsService) body;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final settings = AppSettingsService.instance;

  @override
  void initState() {
    super.initState();
    settings.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: settingsBlue,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF2F5FC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      child: Obx(() {
        return PopScope(
          canPop: !settings.erasing.value,
          child: Scaffold(
            backgroundColor: const Color(0xFFF2F5FC),
            appBar: AppBar(
              automaticallyImplyLeading: !settings.erasing.value,
              title: Text(widget.title),
              backgroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed:
                  settings.busy.value || settings.erasing.value
                      ? null
                      : () => settingsAction(settings.refresh),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: _body(),
          ),
        );
      }),
    );
  }

  Widget _body() {
    if (settings.erasing.value) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!settings.ready.value) {
      if (settings.localError.value.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                settings.localError.value,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: settings.initialize,
                child: const Text('আবার চেষ্টা করুন'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        widget.body(settings),
        if (settings.busy.value)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x88FFFFFF),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> settingsForm(
    String title,
    Map<String, String> labels,
    Map<String, String> initial,
    Future<void> Function(Map<String, String>) submit, {
      String hint = '',
      bool consent = false,
    }) async {
  await Get.bottomSheet<void>(
    _SettingsForm(
      title: title,
      labels: labels,
      initial: initial,
      submit: submit,
      hint: hint,
      consent: consent,
    ),
    isScrollControlled: true,
    backgroundColor: Colors.white,
    isDismissible: false,
    enableDrag: false,
  );
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({
    required this.title,
    required this.labels,
    required this.initial,
    required this.submit,
    required this.hint,
    required this.consent,
  });

  final String title;
  final String hint;

  final Map<String, String> labels;
  final Map<String, String> initial;

  final Future<void> Function(Map<String, String>) submit;
  final bool consent;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final controllers = <String, TextEditingController>{};

  bool saving = false;
  bool accepted = false;
  String error = '';

  @override
  void initState() {
    super.initState();

    for (final key in widget.labels.keys) {
      controllers[key] = TextEditingController(
        text: widget.initial[key] ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  int _limit(String key) {
    if (key.toLowerCase().contains('pin')) return 6;

    return const {
      'message': 1000,
      'phone': 16,
      'address': 400,
      'note': 300,
      'landmark': 160,
      'name': 80,
      'type': 60,
    }[key] ?? 100;
  }

  Future<void> _save() async {
    if (saving) return;

    setState(() {
      saving = true;
      error = '';
    });

    try {
      settingsRequire(
        !widget.consent || accepted,
        'আগে সম্মতি দিন।',
      );

      await widget.submit({
        for (final entry in controllers.entries)
          entry.key: entry.value.text.trim(),
      });

      if (mounted) Get.back();
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = _settingsError(exception);
        });
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !saving,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .9,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: settingsHeading(widget.title),
                      ),
                      IconButton(
                        onPressed: saving
                            ? null
                            : () => Get.back(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (widget.hint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(widget.hint),
                    ),
                  for (final entry in widget.labels.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextField(
                        controller: controllers[entry.key],
                        enabled: !saving,
                        obscureText: entry.key
                            .toLowerCase()
                            .contains('pin'),
                        autocorrect: !entry.key
                            .toLowerCase()
                            .contains('pin'),
                        enableSuggestions: !entry.key
                            .toLowerCase()
                            .contains('pin'),
                        keyboardType:
                        entry.key.toLowerCase().contains('pin')
                            ? TextInputType.number
                            : entry.key == 'phone'
                            ? TextInputType.phone
                            : TextInputType.text,
                        maxLines: [
                          'message',
                          'address',
                          'note',
                        ].contains(entry.key) ? 4 : 1,
                        maxLength: _limit(entry.key),
                        decoration: InputDecoration(
                          labelText: entry.value,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  if (widget.consent)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: accepted,
                      onChanged: saving
                          ? null
                          : (value) => setState(
                            () => accepted = value ?? false,
                      ),
                      title: const Text(
                        'Policy পড়েছি। এই অনুরোধ ও পরিচয় '
                            'যাচাইয়ের জন্য আমার বর্তমান cloud identity '
                            'ব্যবহার করতে সম্মতি দিচ্ছি।',
                      ),
                    ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        error,
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: saving ? null : _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      child: Text(
                        saving
                            ? 'অপেক্ষা করুন…'
                            : 'নিশ্চিত করুন',
                      ),
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

Future<void> showPolicy(
    String key,
    String title,
    ) async {
  final settings = AppSettingsService.instance;

  await Get.bottomSheet<void>(
    SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: Get.height * .85,
          ),
          child: SingleChildScrollView(
            child: Obx(() {
              final isStorePolicy =
                  key == 'delivery' || key == 'return';

              final cached = isStorePolicy
                  ? settings.storeCached.value
                  : settings.configCached.value;

              final body = settings.policyBody(key);
              final updated = settingsText(
                settings.config,
                'policyUpdated',
              );

              String externalUrl = '';

              if (key == 'privacy') {
                externalUrl = settingsText(
                  settings.config,
                  'privacyUrl',
                );
              } else if (key == 'terms') {
                externalUrl = settingsText(
                  settings.config,
                  'termsUrl',
                );
              } else if (key == 'deletion') {
                externalUrl = settingsText(
                  settings.config,
                  'deletionUrl',
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  settingsHeading(title),
                  if (cached)
                    const Text(
                      'সংরক্ষিত তথ্য • Internet এ সর্বশেষ '
                          'তথ্য refresh হবে',
                    ),
                  if (!isStorePolicy && updated.isNotEmpty)
                    Text('সর্বশেষ পরিবর্তন: $updated'),
                  const SizedBox(height: 16),
                  SelectableText(
                    body.isEmpty
                        ? 'এখনও প্রকাশিত হয়নি'
                        : body,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                  if (key == 'about')
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(independentAppNotice),
                    ),
                  if (settings.policiesReady &&
                      settingsHttps(externalUrl) != null)
                    TextButton.icon(
                      onPressed: () => settingsAction(
                            () => settings.openUrl(externalUrl),
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Browser-এ খুলুন'),
                    ),
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('বন্ধ করুন'),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    ),
    isScrollControlled: true,
  );
}