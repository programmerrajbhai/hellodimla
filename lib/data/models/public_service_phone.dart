import 'package:cloud_firestore/cloud_firestore.dart';

class PublicServicePhone {
  const PublicServicePhone({
    required this.label,
    required this.number,
  });

  final String label;
  final String number;
}

List<PublicServicePhone> publicServicePhones(
    Map<String, dynamic> data,
    ) {
  final candidates = <Map<String, dynamic>>[];

  final list = data['phones'];

  if (list is List) {
    for (final value in list) {
      if (value is Map) {
        candidates.add(Map<String, dynamic>.from(value));
      }
    }
  }

  // Optional legacy single-number fields.
  if (data['phone'] is String) {
    candidates.add({
      'label': 'প্রধান যোগাযোগ',
      'number': data['phone'],
      'kind': data['phoneKind'],
      'publish': data['phonePublic'],
      'consentGranted': data['phoneConsent'],
      'consentAt': data['phoneConsentAt'],
    });
  }

  final result = <PublicServicePhone>[];
  final used = <String>{};

  for (final candidate in candidates) {
    if (candidate['publish'] != true) continue;

    final kind = candidate['kind'];
    if (!['business', 'public', 'personal'].contains(kind)) continue;

    if (kind == 'personal' &&
        (candidate['consentGranted'] != true ||
            candidate['consentAt'] is! Timestamp)) {
      continue;
    }

    var number = candidate['number'];
    if (number is! String) continue;

    const bangla = '০১২৩৪৫৬৭৮৯';

    for (var i = 0; i < bangla.length; i++) {
      number = number.replaceAll(bangla[i], '$i');
    }

    number = number.replaceAll(RegExp(r'[\s()\-]'), '');

    if (!RegExp(r'^\+?\d{3,15}$').hasMatch(number)) continue;
    if (!used.add(number)) continue;

    final label = candidate['label'];

    result.add(
      PublicServicePhone(
        label: label is String && label.trim().isNotEmpty
            ? label.trim()
            : 'যোগাযোগ',
        number: number,
      ),
    );
  }

  return result;
}