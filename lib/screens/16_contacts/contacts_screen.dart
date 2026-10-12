import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../business/business_ui.dart';
import '../../business/business_store.dart';
import '../17_person_ledger/person_ledger_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String role = 'customer';
  String search = '';

  bool dueOnly = false;
  bool archived = false;

  @override
  Widget build(BuildContext context) => BusinessPage(
    title: 'Customer / Supplier',
    body: (book) {
      final items = book.contacts.where((contact) {
        return contact['role'] == role &&
            contact['archived'] == archived &&
            '${contact['name']} ${contact['phone']}'
                .toLowerCase()
                .contains(search.toLowerCase()) &&
            (!dueOnly || book.balance(contact['id']) != 0);
      }).toList();

      final total = book.contacts
          .where((contact) => contact['role'] == role)
          .fold<int>(0, (sum, contact) {
        final balance = book.balance(contact['id']);
        return sum + (balance > 0 ? balance : 0);
      });

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'customer',
                label: Text('Customer'),
              ),
              ButtonSegment(
                value: 'supplier',
                label: Text('Supplier'),
              ),
            ],
            selected: {role},
            onSelectionChanged: (value) {
              setState(() => role = value.first);
            },
          ),
          const SizedBox(height: 14),
          panel([
            info(
              role == 'customer' ? 'মোট পাওনা' : 'মোট দেনা',
              money(total),
            ),
            FilledButton.icon(
              onPressed: () => safely(
                    () => BusinessForms.contact(role: role),
              ),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('নতুন ব্যক্তি যোগ করুন'),
            ),
          ]),
          TextField(
            onChanged: (value) => setState(() => search = value),
            decoration: const InputDecoration(
              hintText: 'নাম বা ফোন খুঁজুন',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('বাকি আছে'),
                selected: dueOnly,
                onSelected: (value) {
                  setState(() => dueOnly = value);
                },
              ),
              FilterChip(
                label: const Text('Archived'),
                selected: archived,
                onSelected: (value) {
                  setState(() => archived = value);
                },
              ),
            ],
          ),
          if (items.isEmpty)
            empty('এই তালিকায় কাউকে পাওয়া যায়নি'),
          for (final contact in items)
            panel([
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(
                    (contact['name'] as String).substring(0, 1),
                  ),
                ),
                title: Text(
                  contact['name'],
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  contact['phone'].isEmpty
                      ? 'ফোন দেওয়া হয়নি'
                      : contact['phone'],
                ),
                trailing: Text(
                  money(book.balance(contact['id'])),
                  style: const TextStyle(
                    color: khataBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => Get.to(
                      () => ContactLedgerScreen(
                    contactId: contact['id'],
                  ),
                ),
              ),
              if (book.balance(contact['id']) < 0)
                Text(
                  role == 'customer'
                      ? 'Customer-এর credit / ফেরতযোগ্য টাকা'
                      : 'Supplier-কে অগ্রিম দেওয়া টাকা',
                ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => safely(
                          () => BusinessForms.contact(contact: contact),
                    ),
                    child: const Text('পরিবর্তন'),
                  ),
                  TextButton(
                    onPressed: () => safely(() async {
                      final approved = await confirm(
                        archived
                            ? 'আবার সক্রিয় করবেন?'
                            : 'সরাবেন?',
                        'History/opening balance থাকলে archive হবে। '
                            'আগের হিসাব থাকবে।',
                      );

                      if (approved) {
                        await BusinessStore.instance.change((book) {
                          book.archiveContact(contact['id']);
                        });
                      }
                    }),
                    child: Text(
                      archived ? 'সক্রিয় করুন' : 'সরিয়ে রাখুন',
                    ),
                  ),
                ],
              ),
            ]),
        ],
      );
    },
  );
}