import 'package:cloud_firestore/cloud_firestore.dart';

String readText(Map<String, dynamic> data, String key) {
  final value = data[key];
  return value is String ? value : '';
}

DateTime? readDate(Map<String, dynamic> data, String key) {
  final value = data[key];
  return value is Timestamp ? value.toDate() : null;
}

String moneyText(int minorUnits) {
  final amount = minorUnits / 100;
  return '৳${amount.toStringAsFixed(minorUnits % 100 == 0 ? 0 : 2)}';
}

String dateText(DateTime? value) {
  if (value == null) return '';

  final date = value.toLocal();

  String two(int number) => number.toString().padLeft(2, '0');

  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

class ServiceSummary {
  const ServiceSummary({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.subtitle,
    required this.imageUrl,
    required this.areas,
  });

  final String id;
  final String name;
  final String categoryId;
  final String subtitle;
  final String imageUrl;
  final List<String> areas;

  factory ServiceSummary.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();
    final rawAreas = data['areas'];

    return ServiceSummary(
      id: doc.id,
      name: readText(data, 'name'),
      categoryId: readText(data, 'categoryId'),
      subtitle: readText(data, 'subtitle'),
      imageUrl: readText(data, 'imageUrl'),
      areas: rawAreas is List
          ? rawAreas.whereType<String>().toList()
          : const [],
    );
  }
}

class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.name,
    required this.unit,
    required this.imageUrl,
    required this.priceMinor,
    required this.inStock,
  });

  final String id;
  final String name;
  final String unit;
  final String imageUrl;
  final int priceMinor;
  final bool inStock;

  factory ProductSummary.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    return ProductSummary(
      id: doc.id,
      name: readText(data, 'name'),
      unit: readText(data, 'unit'),
      imageUrl: readText(data, 'imageUrl'),
      priceMinor: (data['priceMinor'] as num?)?.toInt() ?? 0,
      inStock: data['inStock'] == true,
    );
  }
}

class LocalUpdate {
  const LocalUpdate({
    required this.id,
    required this.title,
    required this.body,
    required this.label,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final String body;
  final String label;
  final DateTime? publishedAt;

  factory LocalUpdate.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    return LocalUpdate.fromMap(doc.id, doc.data());
  }

  factory LocalUpdate.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return LocalUpdate(
      id: id,
      title: readText(data, 'title'),
      body: readText(data, 'body'),
      label: readText(data, 'label'),
      publishedAt: readDate(data, 'publishedAt'),
    );
  }
}

enum NoticeKind { order, update }

class InboxNotice {
  const InboxNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.targetId,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final NoticeKind kind;
  final String targetId;
  final DateTime? createdAt;

  factory InboxNotice.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    return InboxNotice(
      id: doc.id,
      title: readText(data, 'title'),
      body: readText(data, 'body'),
      kind: data['kind'] == 'order'
          ? NoticeKind.order
          : NoticeKind.update,
      targetId: readText(data, 'targetId'),
      createdAt: readDate(data, 'createdAt'),
    );
  }
}