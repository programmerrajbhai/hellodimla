import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'business_store.dart';

const khataBlue = Color(0xFF174BB8);

Future<void> safely(Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    Get.snackbar(
      'হিসাব সংরক্ষণ হয়নি',
      e is FormatException
          ? e.message
          : 'কাজটি সম্পন্ন হয়নি। আবার চেষ্টা করুন।',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.white,
      colorText: Colors.red.shade800,
      margin: const EdgeInsets.all(12),
    );
  }
}

Future<bool> confirm(
    String title,
    String message,
    ) async {
  return await Get.dialog<bool>(
    AlertDialog(
      title: Text(title),
      content: Text(message),
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

class BusinessPage extends StatefulWidget {
  const BusinessPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final String title;
  final Widget Function(Book) body;
  final List<Widget> actions;

  @override
  State<BusinessPage> createState() => _BusinessPageState();
}

class _BusinessPageState extends State<BusinessPage>
    with WidgetsBindingObserver {
  final store = BusinessStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) &&
        !store.external) {
      store.lock();

      if (store.locked.value) {
        if (Get.isBottomSheetOpen == true) Get.back();
        if (Get.isDialogOpen == true) Get.back();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: khataBlue),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F6FC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      child: Obx(() {
        Widget body;

        if (!store.ready.value) {
          body = Center(
            child: store.error.value.isEmpty
                ? const CircularProgressIndicator()
                : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(store.error.value),
                ),
                FilledButton(
                  onPressed: store.init,
                  child: const Text('আবার চেষ্টা করুন'),
                ),
              ],
            ),
          );
        } else if (store.locked.value) {
          body = const _Unlock();
        } else {
          body = Stack(
            children: [
              widget.body(store.book),
              if (store.busy.value)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0xAAFFFFFF),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF3F6FC),
          appBar: AppBar(
            title: Text(widget.title),
            backgroundColor: Colors.white,
            actions: store.ready.value && !store.locked.value
                ? widget.actions
                : [],
          ),
          body: body,
        );
      }),
    );
  }
}

class _Unlock extends StatefulWidget {
  const _Unlock();

  @override
  State<_Unlock> createState() => _UnlockState();
}

class _UnlockState extends State<_Unlock> {
  final pin = TextEditingController();

  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 64,
              color: khataBlue,
            ),
            const SizedBox(height: 16),
            const Text(
              'ব্যক্তিগত খাতা খুলুন',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '৬ সংখ্যার PIN',
              ),
            ),
            Obx(() => FilledButton(
              onPressed: BusinessStore.instance.busy.value
                  ? null
                  : () => safely(() async {
                await BusinessStore.instance.unlock(
                  englishDigits(pin.text),
                );
                pin.clear();
              }),
              child: const Text('খাতা খুলুন'),
            )),
            const SizedBox(height: 12),
            const Text(
              'PIN ভুলে গেলে বর্তমান PIN ছাড়া খুলবে না।\n'
                  'নিরাপদ জায়গায় PIN ও backup password রাখুন.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Widget panel(List<Widget> children) => Container(
  margin: const EdgeInsets.only(bottom: 14),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children,
  ),
);

Widget heading(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.bold,
    ),
  ),
);

Widget info(String title, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(fontSize: 16)),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: khataBlue,
          ),
        ),
      ),
    ],
  ),
);

Widget empty(String text) => Padding(
  padding: const EdgeInsets.all(28),
  child: Center(
    child: Text(text, textAlign: TextAlign.center),
  ),
);

class Field {
  const Field(
      this.key,
      this.label, {
        this.value = '',
        this.options,
        this.number = false,
        this.password = false,
        this.date = false,
        this.enabled = true,
      });

  final String key;
  final String label;
  final String value;

  final Map<String, String>? options;

  final bool number;
  final bool password;
  final bool date;
  final bool enabled;
}

Future<void> formSheet(
    String title,
    List<Field> fields,
    Future<void> Function(Map<String, String>) save, {
      String hint = '',
    }) async {
  BusinessStore.instance.guard();

  await Get.bottomSheet<void>(
    _EntrySheet(
      title: title,
      fields: fields,
      save: save,
      hint: hint,
    ),
    isScrollControlled: true,
    backgroundColor: Colors.white,
    enableDrag: false,
    isDismissible: false,
  );
}

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({
    required this.title,
    required this.fields,
    required this.save,
    required this.hint,
  });

  final String title;
  final String hint;
  final List<Field> fields;
  final Future<void> Function(Map<String, String>) save;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  final controllers = <String, TextEditingController>{};

  bool saving = false;
  String error = '';

  @override
  void initState() {
    super.initState();

    for (final field in widget.fields) {
      controllers[field.key] = TextEditingController(
        text: field.value,
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

  Future<void> submit() async {
    if (saving) return;

    setState(() {
      saving = true;
      error = '';
    });

    try {
      await widget.save({
        for (final entry in controllers.entries)
          entry.key: entry.value.text.trim(),
      });

      if (mounted) Get.back();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is FormatException
              ? e.message
              : 'সংরক্ষণ হয়নি। আবার চেষ্টা করুন।';
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
                      Expanded(child: heading(widget.title)),
                      IconButton(
                        onPressed: saving ? null : () => Get.back(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (widget.hint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(widget.hint),
                    ),
                  for (final field in widget.fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: field.options != null
                          ? DropdownButtonFormField<String>(
                        initialValue:
                        controllers[field.key]!.text.isEmpty
                            ? null
                            : controllers[field.key]!.text,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: field.label,
                        ),
                        items: field.options!.entries.map((e) {
                          return DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: saving || !field.enabled
                            ? null
                            : (value) {
                          controllers[field.key]!.text =
                              value ?? '';
                        },
                      )
                          : TextField(
                        controller: controllers[field.key],
                        enabled: !saving && field.enabled,
                        obscureText: field.password,
                        readOnly: field.date,
                        keyboardType: field.number
                            ? const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        )
                            : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: field.label,
                        ),
                        onTap: field.date
                            ? () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate:
                            DateTime.tryParse(
                              controllers[field.key]!.text,
                            ) ??
                                DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );

                          if (selected != null) {
                            controllers[field.key]!.text =
                                day(selected);
                          }
                        }
                            : null,
                      ),
                    ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  FilledButton(
                    onPressed: saving ? null : submit,
                    child: Text(
                      saving ? 'সংরক্ষণ হচ্ছে…' : 'সংরক্ষণ করুন',
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

class BusinessForms {
  static BusinessStore get s => BusinessStore.instance;

  static String decimal(int value, int scale) =>
      (value / scale).toStringAsFixed(scale == 100 ? 2 : 3);

  static Future<void> setup() => formSheet(
    'আপনার ব্যবসা শুরু করুন',
    [
      const Field('name', 'ব্যবসার নাম'),
      const Field('type', 'ব্যবসার ধরন', value: 'মুদি দোকান'),
      Field('date', 'হিসাব শুরুর তারিখ', value: today(), date: true),
      const Field('cash', 'শুরুর নগদ টাকা', value: '0', number: true),
    ],
        (v) => s.change((b) {
      b.setup(
        v['name']!,
        v['type']!,
        v['date']!,
        scaled(v['cash']!, 2),
      );
    }),
    hint: 'শুরুর নগদ বিক্রি বা লাভ হিসেবে যোগ হবে না।',
  );

  static Future<void> contact({
    BookRow? contact,
    String role = 'customer',
  }) {
    final c = contact;
    final id = c?['id'] ?? newId();
    final history = c != null && s.book.list(contactId: id).isNotEmpty;

    return formSheet(
      c == null ? 'নতুন ব্যক্তি' : 'তথ্য পরিবর্তন',
      [
        Field('name', 'নাম', value: c?['name'] ?? ''),
        Field('phone', 'ফোন (না দিলেও হবে)', value: c?['phone'] ?? ''),
        Field(
          'role',
          'পরিচয়',
          value: c?['role'] ?? role,
          enabled: !history,
          options: const {
            'customer': 'Customer — ক্রেতা',
            'supplier': 'Supplier — সরবরাহকারী',
          },
        ),
        Field(
          'opening',
          'শুরুর পাওনা / দেনা',
          value: decimal(c?['opening'] ?? 0, 100),
          number: true,
          enabled: !history,
        ),
        Field('note', 'নোট (ঐচ্ছিক)', value: c?['note'] ?? ''),
      ],
          (v) => s.change((b) {
        b.saveContact({
          'id': id,
          'name': v['name'],
          'phone': v['phone'],
          'role': v['role'],
          'opening': scaled(v['opening']!, 2),
          'note': v['note'],
          'archived': c?['archived'] ?? false,
        });
      }),
      hint: history
          ? 'History আছে। Opening বদলাতে বাকি adjustment ব্যবহার করুন।'
          : 'ক্রেতার কাছে পাওনা অথবা supplier-কে দেওয়ার দেনা লিখুন।',
    );
  }

  static Future<void> product({BookRow? product}) {
    final p = product;
    final id = p?['id'] ?? newId();

    return formSheet(
      p == null ? 'নতুন পণ্য' : 'পণ্যের তথ্য',
      [
        Field('name', 'পণ্যের নাম', value: p?['name'] ?? ''),
        Field(
          'unit',
          'Unit: কেজি / পিস / প্যাকেট',
          value: p?['unit'] ?? 'পিস',
          enabled: p == null,
        ),
        Field(
          'buy',
          'বর্তমান unit ক্রয়মূল্য',
          value: decimal(p?['buy'] ?? 0, 100),
          number: true,
        ),
        Field(
          'sell',
          'বর্তমান unit বিক্রয়মূল্য',
          value: decimal(p?['sell'] ?? 0, 100),
          number: true,
        ),
        Field(
          'openingQty',
          'শুরুর stock quantity',
          value: decimal(p?['openingQty'] ?? 0, 1000),
          number: true,
          enabled: p == null,
        ),
        Field(
          'openingValue',
          'শুরুর stock-এর মোট cost (অজানা হলে ফাঁকা)',
          value: p?['openingValue'] == null
              ? ''
              : decimal(p!['openingValue'], 100),
          number: true,
          enabled: p == null,
        ),
        Field(
          'low',
          'কম stock-এর সীমা',
          value: decimal(p?['low'] ?? 1000, 1000),
          number: true,
        ),
      ],
          (v) => s.change((b) {
        b.saveProduct({
          'id': id,
          'name': v['name'],
          'unit': v['unit'],
          'buy': scaled(v['buy']!, 2),
          'sell': scaled(v['sell']!, 2),
          'low': scaled(v['low']!, 3),
          'openingQty': scaled(v['openingQty']!, 3),
          'openingValue': v['openingValue']!.isEmpty
              ? null
              : scaled(v['openingValue']!, 2),
        });
      }),
      hint:
      'দাম পরিবর্তনে পুরোনো লেনদেনের cost বদলাবে না। '
          'Stock cost-এর weighted average ব্যবহার হয়।',
    );
  }

  static Future<void> entry(
      String type, {
        String? contactId,
        String? productId,
      }) {
    final b = s.book;
    final id = newId();

    final trade = ['sale', 'purchase'].contains(type);

    final contactNeeded = [
      'receive',
      'payment',
      'balance',
      'credit_settle',
    ].contains(type);

    final role = ['sale', 'receive'].contains(type)
        ? 'customer'
        : 'supplier';

    final contactOptions = <String, String>{
      if (!contactNeeded) '': 'নগদ — ব্যক্তি ছাড়া',
      for (final c in b.contacts.where((c) {
        return !c['archived'] &&
            (['balance', 'credit_settle'].contains(type) ||
                c['role'] == role);
      }))
        c['id']: '${c['name']} • ${money(b.balance(c['id']))}',
    };

    final stockOptions = <String, String>{
      if (type != 'adjust') '': 'Stock ছাড়া / সাধারণ বিবরণ',
      for (final p in b.products)
        p['id']:
        '${p['name']} • ${qtyText(b.stock(p['id'])['qty'])} ${p['unit']}',
    };

    return formSheet(
      entryNames[type]!,
      [
        Field('date', 'তারিখ', value: today(), date: true),
        if (trade || contactNeeded)
          Field(
            'contact',
            'ব্যক্তি',
            value: contactId ?? '',
            options: contactOptions,
          ),
        if (trade || type == 'adjust')
          Field(
            'product',
            'পণ্য',
            value: productId ?? '',
            options: stockOptions,
          ),
        if (trade || type == 'adjust')
          Field(
            'qty',
            type == 'adjust'
                ? 'Quantity: বাড়লে +, কমলে −'
                : 'Quantity (stock পণ্যের জন্য)',
            value: '1',
            number: true,
          ),
        Field(
          'amount',
          type == 'balance'
              ? 'বাকি: বাড়লে + টাকা, কমলে − টাকা'
              : type == 'adjust'
              ? 'টাকা নয়; নিচে stock cost দিন'
              : trade
              ? 'মোট ${type == 'sale' ? 'বিক্রির' : 'ক্রয়ের'} টাকা'
              : 'টাকা',
          value: type == 'adjust' ? '0' : '',
          number: true,
          enabled: type != 'adjust',
        ),
        if (trade)
          const Field(
            'paid',
            'এখন নগদ পাওয়া / দেওয়া টাকা',
            value: '0',
            number: true,
          ),
        if (type == 'sale' || type == 'adjust')
          const Field(
            'cost',
            'মোট cost (stock বাড়লে আবশ্যক; সাধারণ বিক্রিতে ঐচ্ছিক)',
            number: true,
          ),
        const Field('note', 'বিবরণ / কারণ'),
      ],
          (v) => s.change((book) {
        book.post(
          id: id,
          type: type,
          date: v['date']!,
          amount: scaled(
            v['amount']!,
            2,
            negative: type == 'balance',
          ),
          paid: trade ? scaled(v['paid']!, 2) : 0,
          contactId: v['contact'] == null || v['contact']!.isEmpty
              ? null
              : v['contact'],
          productId: v['product'] == null || v['product']!.isEmpty
              ? null
              : v['product'],
          units: v['qty'] == null
              ? 0
              : scaled(v['qty']!, 3, negative: type == 'adjust'),
          manualCost: v['cost'] == null || v['cost']!.isEmpty
              ? null
              : scaled(v['cost']!, 2),
          note: v['note']!,
        );
      }),
      hint: trade
          ? 'প্রতি entry-তে একটি পণ্য। মোট ও নগদ সমান হলে বাকি নেই। '
          'Stock ছাড়া বিক্রির cost অজানা হলে লাভ অসম্পূর্ণ দেখাবে।'
          : type == 'adjust'
          ? 'কম stock নষ্ট/হারানো হিসেবে cost অনুযায়ী খরচ হবে। '
          'বাড়তি stock cash বা বিক্রি নয়।'
          : 'আদায়/পরিশোধ নতুন বিক্রি/ক্রয় নয়। '
          'বাকি adjustment cash বা লাভ বদলায় না।',
    );
  }

  static Future<void> returnForm(BookRow original) {
    final id = newId();
    final simple = original['productId'] == null;

    return formSheet(
      'ফেরত লিখুন',
      [
        Field('date', 'তারিখ', value: today(), date: true),
        Field(
          'qty',
          simple
              ? 'সম্পূর্ণ entry ফেরত = ১; অর্ধেক = ০.৫'
              : 'ফেরত quantity',
          value: '1',
          number: true,
        ),
        const Field(
          'refund',
          'এখন নগদ ফেরত দেওয়া / পাওয়া টাকা',
          value: '0',
          number: true,
        ),
        const Field('note', 'ফেরতের কারণ'),
      ],
          (v) => s.change((b) {
        b.returnEntry(
          id,
          original['id'],
          scaled(v['qty']!, 3),
          scaled(v['refund']!, 2),
          v['date']!,
          v['note']!,
        );
      }),
      hint:
      'মূল্য original entry অনুযায়ী হবে। নগদ না ফেরালে balance '
          'সমন্বয় হবে; অতিরিক্ত হলে credit/advance দেখাবে। '
          'ফেরত পণ্য পুনরায় বিক্রয়যোগ্য হতে হবে। '
          'নষ্ট পণ্য হলে পরে stock loss লিখুন।',
    );
  }

  static Future<void> reversal(BookRow original) {
    final id = newId();

    return formSheet(
      'ভুল entry reverse করুন',
      [const Field('reason', 'কেন সংশোধন করছেন?')],
          (v) async {
        need(v['reason']!.isNotEmpty, 'কারণ লিখুন');

        if (!await confirm(
          'Reversal করবেন?',
          'Original entry থাকবে। বিপরীত হিসাব যোগ হবে। '
              'এরপর দরকার হলে সঠিক নতুন entry লিখুন।',
        )) {
          return;
        }

        await s.change((b) {
          b.reverse(id, original['id'], v['reason']!);
        });
      },
    );
  }

  static Future<void> pin() => formSheet(
    'খাতার PIN',
    [
      const Field(
        'pin',
        '৬ সংখ্যার নতুন PIN',
        password: true,
        number: true,
      ),
      const Field(
        'again',
        'আবার একই PIN',
        password: true,
        number: true,
      ),
    ],
        (v) async {
      need(v['pin'] == v['again'], 'দুই PIN মিলছে না');
      await s.setPin(englishDigits(v['pin']!));
    },
    hint:
    'এটি app unlock PIN। Database file নিজে encrypted নয়; '
        'ফোনের screen lock-ও ব্যবহার করুন।',
  );

  static Future<void> chooseEntry({String? contactId}) async {
    await Get.bottomSheet<void>(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                heading('কী লিখবেন?'),
                for (final type in [
                  'sale',
                  'receive',
                  'purchase',
                  'payment',
                  'expense',
                  'deposit',
                  'withdraw',
                  'balance',
                  'credit_settle',
                ])
                  ListTile(
                    title: Text(entryNames[type]!),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Get.back();
                      safely(() => entry(type, contactId: contactId));
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

Widget entryTile(
    Book book,
    BookRow entry, {
      VoidCallback? onTap,
    }) => ListTile(
  contentPadding: const EdgeInsets.symmetric(
    horizontal: 4,
    vertical: 4,
  ),
  leading: CircleAvatar(
    backgroundColor: const Color(0xFFE8F0FF),
    child: Icon(
      entry['cash'] >= 0 ? Icons.south_west : Icons.north_east,
      color: khataBlue,
    ),
  ),
  title: Text(
    '${entryNames[entry['type']]}'
        '${book.reversed(entry['id']) ? ' • সংশোধিত' : ''}',
    style: const TextStyle(fontWeight: FontWeight.bold),
  ),
  subtitle: Text(
    [
      bn(entry['date']),
      entry['contactName'],
      entry['productName'],
      entry['note'],
    ].where((v) => v is String && v.isNotEmpty).join(' • '),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  ),
  trailing: Text(
    money(entry['amount']),
    style: const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
    ),
  ),
  onTap: onTap ?? () => entryDetails(entry),
);

Future<void> entryDetails(BookRow entry) async {
  final b = BusinessStore.instance.book;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              heading(
                '${entryNames[entry['type']]} • ${bn(entry['date'])}',
              ),
              info('মোট টাকা', money(entry['amount'])),
              info('নগদ পরিবর্তন', money(entry['cash'])),
              info('বাকি পরিবর্তন', money(entry['balance'])),
              if (entry['productId'] != null)
                info(
                  'Stock পরিবর্তন',
                  '${qtyText(entry['qty'])} ${entry['unit']}',
                ),
              if (entry['unknown'] != 0)
                const Text('Cost অজানা — লাভের হিসাব অসম্পূর্ণ'),
              Text(
                '${entry['contactName']} ${entry['productName']}\n'
                    '${entry['note']}',
              ),
              const SizedBox(height: 12),
              if (!b.reversed(entry['id']) &&
                  ['sale', 'purchase'].contains(entry['type']))
                OutlinedButton(
                  onPressed: () {
                    Get.back();
                    safely(() => BusinessForms.returnForm(entry));
                  },
                  child: const Text('ফেরত লিখুন'),
                ),
              if (!b.reversed(entry['id']) &&
                  entry['type'] != 'reversal')
                OutlinedButton(
                  onPressed: () {
                    Get.back();
                    safely(() => BusinessForms.reversal(entry));
                  },
                  child: const Text('ভুল entry / রিভার্সাল'),
                ),
              heading('সংশোধন / ফেরতের history'),
              for (final item in b.entries.where((item) {
                return item['reverseOf'] == entry['id'] ||
                    item['returnOf'] == entry['id'];
              }))
                Text(
                  '${bn(item['date'])} • '
                      '${entryNames[item['type']]} • '
                      '${money(item['amount'])} • ${item['note']}',
                ),
              if (entry['reverseOf'] != null)
                Text('Original entry: ${entry['reverseOf']}'),
              if (entry['returnOf'] != null)
                Text('Original entry: ${entry['returnOf']}'),
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