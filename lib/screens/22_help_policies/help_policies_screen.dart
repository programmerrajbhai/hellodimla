import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/app_settings_service.dart';
import '../../services/settings_widgets.dart';

class HelpPoliciesScreen extends StatefulWidget {
  const HelpPoliciesScreen({
    super.key,
    this.initialSection = 0,
  });

  final int initialSection;

  @override
  State<HelpPoliciesScreen> createState() =>
      _HelpPoliciesScreenState();
}

class _HelpPoliciesScreenState extends State<HelpPoliciesScreen> {
  late int section;

  static const Map<String, String> _faqs = {
    'সেবা দেখতে account বা GPS লাগবে?':
    'Public সেবা দেখতে login করতে হবে না। '
        'এলাকা নির্বাচন ঐচ্ছিক। '
        'কল করুন চাপলে আপনার ফোনের dialer খুলবে।',

    'Hello Store ও স্থানীয় দোকানের তালিকা কি এক?':
    'Hello Store কোম্পানির বিক্রয়যোগ্য পণ্যের store। '
        'স্থানীয় দোকানের তালিকা যোগাযোগ ও তথ্যের directory।',

    'কীভাবে অর্ডার করব?':
    'পণ্য নির্বাচন করুন → Cart → Checkout। '
        'নাম, ফোন, delivery এলাকা ও পূর্ণ ঠিকানা দিন। '
        'পণ্যের দাম, delivery charge ও policy দেখে নিশ্চিত করুন। '
        'Server confirmation পাওয়ার পর অর্ডার সফল হবে। '
        'বর্তমান payment method Cash on Delivery।',

    'অর্ডার কোথায় দেখব?':
    'Shopping-এর My Orders থেকে অর্ডার দেখুন। '
        'Order Details-এ অবস্থা ও হিসাব পাওয়া যাবে। '
        'অর্ডার আপনার বর্তমান anonymous identity-এর সঙ্গে যুক্ত। '
        'App data reset বা reinstall করলে এই পরিচয় হারাতে পারে। '
        'Recovery নিশ্চিত নয়।',

    'পুরোনো বাকি আদায় কীভাবে লিখব?':
    'Customer-এর খাতা খুলে আদায় নির্বাচন করুন। '
        'আগের ৪০০ টাকা বাকি থেকে ২০০ টাকা আদায় করলে '
        'বাকি থাকবে ২০০ টাকা। আদায় নতুন বিক্রি নয়।',

    'লাভ ও নগদ টাকা আলাদা কেন?':
    'বাকিতে বিক্রি, পুরোনো বাকি আদায়, supplier payment এবং '
        'মালিকের জমা/উত্তোলনের কারণে লাভ ও হাতে থাকা টাকা '
        'আলাদা হতে পারে। Cost তথ্য অসম্পূর্ণ হলে '
        'লাভের হিসাবও অসম্পূর্ণ থাকবে।',

    'Backup কীভাবে নেব?':
    'Settings → Backup / Restore অথবা Reports খুলুন। '
        'পূর্ণ encrypted backup তৈরি করে নিজের password দিন। '
        'Backup file নিরাপদ জায়গায় রাখুন। '
        'PDF/CSV report পূর্ণ backup নয়।',

    'Restore করলে কী হবে?':
    'Backup file ও তার password দিয়ে preview যাচাই করুন। '
        'Restore নিশ্চিত করলে বর্তমান খাতা replace হবে। '
        'তাই প্রয়োজন হলে আগে বর্তমান খাতার backup নিন।',

    'PIN ভুলে গেলে কী হবে?':
    'সঠিক PIN ছাড়া পুরোনো খাতা খোলা যাবে না। '
        'খাতার PIN ও encrypted backup password আলাদা। '
        'PIN বা backup password হারালে recovery নিশ্চিত নয়।',

    'ফেরতের অনুরোধ মানেই refund হবে?':
    'না। Return request জমা, request approval এবং refund '
        'আলাদা ধাপ। আপনার order-এ সংরক্ষিত policy অনুযায়ী '
        'দোকান অনুরোধ যাচাই করবে।',

    'Local data clear করলে order মুছবে?':
    'Local data clear ও server data deletion আলাদা। '
        'Settings-এর confirmation-এ কী মুছবে তা দেখানো হবে। '
        'Server data মুছতে আলাদা request করতে হবে।',
  };

  static const Map<String, String> _policies = {
    'privacy': 'Privacy Policy',
    'terms': 'Terms of Use',
    'delivery': 'Delivery Policy',
    'cancellation': 'Cancellation Policy',
    'return': 'Return / Refund Policy',
    'deletion': 'Data deletion ও retention',
  };

  @override
  void initState() {
    super.initState();
    section = widget.initialSection.clamp(0, 2).toInt();
  }

  Future<void> _showAnswer(
      String title,
      String answer,
      ) async {
    await Get.bottomSheet<void>(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: Get.height * .8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: settingsHeading(title),
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    answer,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Get.back(),
                    child: const Text('বুঝেছি'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _complaint(AppSettingsService s) {
    return settingsForm(
      'অভিযোগ / প্রশ্ন',
      {'message': 'কী সমস্যা হয়েছে?'},
      {},
          (values) async {
        final message = values['message']!.trim();

        settingsRequire(
          message.length >= 5,
          'অন্তত ৫ অক্ষরে সমস্যাটি লিখুন।',
        );

        await s.emailSupport(
          subject: 'Hello Dimla — Support request',
          body: message,
        );
      },
      hint: 'Email app-এ draft খুলবে। দেখে নিজে Send করবেন। '
          'প্রয়োজনে order number লিখুন। PIN বা password দেবেন না।',
    );
  }

  Future<void> _requestDeletion(AppSettingsService s) {
    return settingsForm(
      'Server data deletion request',
      {'message': 'বিবরণ — ঐচ্ছিক'},
      {},
          (values) async {
        final confirmed = await settingsConfirm(
          'Deletion request পাঠাবেন?',
          'আপনার বর্তমান anonymous identity, বিবরণ ও '
              'policy version দিয়ে request পাঠানো হবে। '
              'Owner পরিচয় ও সংশ্লিষ্ট cloud records যাচাই করে '
              'request process করবেন।\n\n'
              'কিছু তথ্য রাখার প্রয়োজন হলে প্রকাশিত '
              'retention policy অনুযায়ী কারণ জানাতে হবে।\n\n'
              'Request জমা মানেই data মুছে যাওয়া নয়। '
              'ফোনের ব্যবসার খাতা মুছবে না।',
        );

        if (!confirmed) {
          throw const FormatException('অনুরোধ পাঠানো হয়নি।');
        }

        await s.requestDeletion(values['message']!);
      },
      consent: true,
      hint: 'আগে Data deletion ও retention policy পড়ুন।',
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: settingsBlue,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _header() {
    const titles = [
      'কীভাবে সাহায্য করতে পারি?',
      'জেনে ব্যবহার করুন',
      'আমাদের Hello Dimla',
    ];

    const subtitles = [
      'প্রয়োজনীয় উত্তর ও যোগাযোগ এক জায়গায়',
      'আপনার তথ্য, কেনাকাটা ও অধিকার',
      'স্থানীয় সেবা ও দৈনন্দিন প্রয়োজন',
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF123EAD),
            Color(0xFF2878E8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.support_agent_rounded,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 14),
          Text(
            titles[section],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitles[section],
            style: const TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _support(AppSettingsService s) {
    final phone = settingsText(s.config, 'supportPhone');
    final email = settingsText(s.config, 'supportEmail');
    final hours = settingsText(s.config, 'supportHours');

    return settingsCard([
      settingsHeading('যোগাযোগ ও অভিযোগ'),

      if (!s.supportReady)
        const Text(
          'Support contact এখনও প্রকাশিত হয়নি। '
              'প্রকাশিত হলে এখানে দেখা যাবে।',
        ),

      if (s.supportReady) ...[
        if (hours.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'যোগাযোগের সময়: $hours',
              style: const TextStyle(color: Colors.black54),
            ),
          ),

        if (settingsPhoneValid(phone)) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.phone_outlined,
              color: settingsBlue,
            ),
            title: const Text('Support নম্বর'),
            subtitle: SelectableText(phone),
            trailing: IconButton(
              tooltip: 'নম্বর কপি',
              onPressed: () => settingsAction(
                    () => copySettingsText(phone),
              ),
              icon: const Icon(Icons.copy_outlined),
            ),
          ),
          FilledButton.icon(
            onPressed: () => settingsAction(s.callSupport),
            icon: const Icon(Icons.call_outlined),
            label: const Text('কল করুন'),
          ),
        ],

        if (settingsEmail(email)) ...[
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.email_outlined,
              color: settingsBlue,
            ),
            title: const Text('Support email'),
            subtitle: SelectableText(email),
            trailing: IconButton(
              tooltip: 'Email কপি',
              onPressed: () => settingsAction(
                    () => copySettingsText(email),
              ),
              icon: const Icon(Icons.copy_outlined),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => settingsAction(
                  () => s.emailSupport(),
            ),
            icon: const Icon(Icons.mail_outline),
            label: const Text('Email করুন'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => settingsAction(
                  () => _complaint(s),
            ),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('অভিযোগ / প্রশ্ন লিখুন'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Email draft খুলবে। পাঠানোর আগে দেখে নিন।',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ],
    ]);
  }

  Widget _faqCard() {
    return settingsCard([
      settingsHeading('সহজ ব্যবহার নির্দেশনা'),
      for (final entry in _faqs.entries)
        _row(
          icon: Icons.help_outline_rounded,
          title: entry.key,
          onTap: () => _showAnswer(
            entry.key,
            entry.value,
          ),
        ),
    ]);
  }

  Widget _policyCard(AppSettingsService s) {
    final policyVersion = settingsText(
      s.config,
      'policyVersion',
    );

    final updated = settingsText(
      s.config,
      'policyUpdated',
    );

    return settingsCard([
      settingsHeading('প্রকাশিত নীতিমালা'),

      if (!s.policiesReady)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Privacy Policy ও প্রয়োজনীয় তথ্য এখনও '
                'সম্পূর্ণ প্রকাশিত হয়নি।',
            style: TextStyle(color: Colors.deepOrange),
          ),
        ),

      if (s.policiesReady && policyVersion.isNotEmpty)
        Text(
          'Policy version: $policyVersion',
          style: const TextStyle(color: Colors.black54),
        ),

      if (s.policiesReady && updated.isNotEmpty)
        Text(
          'পরিবর্তনের তারিখ: $updated',
          style: const TextStyle(color: Colors.black54),
        ),

      for (final entry in _policies.entries)
        _row(
          icon: Icons.description_outlined,
          title: entry.value,
          onTap: () => showPolicy(
            entry.key,
            entry.value,
          ),
        ),

      const SizedBox(height: 8),
      const Text(
        'অর্ডারের delivery ও return policy সেই '
            'অর্ডারের details-এও সংরক্ষিত থাকে।',
        style: TextStyle(color: Colors.black54),
      ),

      if (s.store['demoMode'] == true)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Hello Store এখন DEMO mode-এ আছে। '
                'Demo order বাস্তব delivery নয়।',
            style: TextStyle(color: Colors.deepOrange),
          ),
        ),
    ]);
  }

  Widget _deletionCard(AppSettingsService s) {
    final request = s.deletion.value;

    const labels = {
      'pending': 'অনুরোধ জমা হয়েছে',
      'processing': 'যাচাই / প্রক্রিয়াধীন',
      'completed': 'Owner সম্পন্ন হিসেবে চিহ্নিত করেছেন',
      'partially_retained': 'কিছু তথ্য সংরক্ষিত আছে',
      'needs_information': 'আরও তথ্য প্রয়োজন',
    };

    final rawStatus = request == null
        ? ''
        : settingsText(request, 'status');

    final response = request == null
        ? ''
        : settingsText(request, 'response');

    return settingsCard([
      settingsHeading('Shopping/server data deletion'),

      const Text(
        'এই ব্যবস্থা server-এর data ও anonymous identity '
            'সংক্রান্ত request-এর জন্য। '
            'ফোনের ব্যবসার খাতা মুছতে Settings ব্যবহার করুন।',
      ),

      TextButton(
        onPressed: () => showPolicy(
          'deletion',
          'Data deletion ও retention',
        ),
        child: const Text('আগে deletion policy পড়ুন'),
      ),

      if (s.uid.value.isEmpty)
        const Text(
          'এই device-এ এখন cloud identity নেই। '
              'Website বা support-এর মাধ্যমে যোগাযোগ করতে পারেন।',
        ),

      if (request == null && s.uid.value.isNotEmpty) ...[
        if (!s.deletionReady)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Deletion policy ও public request page '
                  'প্রকাশিত হলে এই request চালু হবে।',
              style: TextStyle(color: Colors.deepOrange),
            ),
          ),

        FilledButton.icon(
          onPressed: s.deletionReady
              ? () => settingsAction(
                () => _requestDeletion(s),
          )
              : null,
          icon: const Icon(Icons.cloud_off_outlined),
          label: const Text('Data মুছতে request করুন'),
        ),
      ],

      if (request != null) ...[
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                labels[rawStatus] ?? 'অবস্থা জানতে support-এ যোগাযোগ করুন',
                style: const TextStyle(
                  color: settingsBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (s.deletionCached.value) ...[
                const SizedBox(height: 6),
                const Text(
                  'সংরক্ষিত status; Internet এ '
                      'বর্তমান status refresh হবে।',
                ),
              ],
              if (response.isNotEmpty) ...[
                const SizedBox(height: 10),
                SelectableText(response),
              ],
            ],
          ),
        ),

        TextButton.icon(
          onPressed: () => settingsAction(
                () => copySettingsText(s.uid.value),
          ),
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Request reference কপি করুন'),
        ),
      ],

      if (s.deletionReady)
        OutlinedButton.icon(
          onPressed: () => settingsAction(
                () => s.openUrl(
              settingsText(s.config, 'deletionUrl'),
            ),
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Website থেকে request'),
        ),

      const SizedBox(height: 8),
      const Text(
        'Request জমা মানেই data deletion সম্পন্ন নয়।',
        style: TextStyle(color: Colors.black54),
      ),
    ]);
  }

  Widget _aboutCard(AppSettingsService s) {
    final operatorName = settingsText(
      s.config,
      'operatorName',
    );

    final address = settingsText(
      s.config,
      'operatorAddress',
    );

    final developer = settingsText(
      s.config,
      'developerName',
    );

    final website = settingsText(
      s.config,
      'developerWebsite',
    );

    return settingsCard([
      settingsHeading('Hello Dimla'),
      const Text(
        independentAppNotice,
        style: TextStyle(height: 1.6),
      ),

      if (operatorName.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          'পরিচালনায়: $operatorName',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],

      if (address.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SelectableText(address),
        ),

      if (developer.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Developer: $developer'),
        ),

      if (settingsHttps(website) != null)
        TextButton.icon(
          onPressed: () => settingsAction(
                () => s.openUrl(website),
          ),
          icon: const Icon(Icons.language),
          label: const Text('প্রতিষ্ঠানের website'),
        ),

      TextButton(
        onPressed: () => showPolicy(
          'about',
          'About Hello Dimla',
        ),
        child: const Text('বিস্তারিত পরিচিতি'),
      ),

      const Divider(),
      Text(
        'App version: ${s.version.value}',
        style: const TextStyle(color: Colors.black54),
      ),
    ]);
  }

  Widget _governmentSources(AppSettingsService s) {
    final raw = s.config['governmentSources'];

    final sources = raw is List
        ? raw
        .whereType<Map>()
        .where(
          (item) =>
      item['title'] is String &&
          item['url'] is String &&
          settingsHttps(item['url'] as String) != null,
    )
        .toList()
        : <Map>[];

    return settingsCard([
      settingsHeading('সরকারি তথ্যের উৎস'),
      const Text(
        'সরকারি তথ্যের জন্য সংশ্লিষ্ট মূল উৎস যাচাই করুন। '
            'Hello Dimla সরকারি প্রতিনিধিত্ব করে না।',
      ),

      if (sources.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'এখানে এখনও source link প্রকাশিত হয়নি। '
                'সংশ্লিষ্ট Service Details-এ উৎস থাকলে দেখুন।',
            style: TextStyle(color: Colors.black54),
          ),
        ),

      for (final source in sources)
        _row(
          icon: Icons.public,
          title: source['title'] as String,
          onTap: () => settingsAction(
                () => s.openUrl(source['url'] as String),
          ),
        ),
    ]);
  }

  Widget _healthNotice() {
    return settingsCard([
      settingsHeading('স্বাস্থ্যসংক্রান্ত তথ্য'),
      const Text(
        'ডাক্তার, হাসপাতাল, ফার্মেসি, অ্যাম্বুলেন্স ও '
            'রক্তদাতার তালিকা যোগাযোগের তথ্য। '
            'এটি রোগ নির্ণয়, চিকিৎসা পরামর্শ বা জরুরি '
            'সহায়তা পৌঁছানোর নিশ্চয়তা নয়।\n\n'
            'স্বাস্থ্য বিষয়ে যোগ্য চিকিৎসকের পরামর্শ নিন। '
            'জরুরি পরিস্থিতিতে সংশ্লিষ্ট জরুরি সেবায় '
            'সরাসরি যোগাযোগ করুন।',
        style: TextStyle(height: 1.6),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'সাহায্য ও নীতিমালা',
      body: (s) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(),

          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('সাহায্য'),
              ),
              ButtonSegment(
                value: 1,
                label: Text('নীতিমালা'),
              ),
              ButtonSegment(
                value: 2,
                label: Text('পরিচিতি'),
              ),
            ],
            selected: {section},
            onSelectionChanged: (selection) {
              setState(() {
                section = selection.first;
              });
            },
          ),

          const SizedBox(height: 18),

          if (s.configCached.value)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'সংরক্ষিত তথ্য • Internet এ বর্তমান তথ্য refresh হবে',
                style: TextStyle(color: Colors.black54),
              ),
            ),

          if (s.remoteError.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                s.remoteError.value,
                style: const TextStyle(
                  color: Colors.deepOrange,
                ),
              ),
            ),

          if (!s.configExists.value)
            settingsCard([
              const Text(
                'App-এর প্রাথমিক তথ্য এখনও প্রস্তুত হয়নি।',
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => settingsAction(
                  s.createPublicDefaults,
                ),
                child: const Text('প্রাথমিক তথ্য প্রস্তুত করুন'),
              ),
            ]),

          if (section == 0) ...[
            _support(s),
            _faqCard(),
          ],

          if (section == 1) ...[
            _policyCard(s),
            _deletionCard(s),
            _support(s),
          ],

          if (section == 2) ...[
            _aboutCard(s),
            _governmentSources(s),
            _healthNotice(),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}