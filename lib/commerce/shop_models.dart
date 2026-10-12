import 'package:cloud_firestore/cloud_firestore.dart';

int number(dynamic v, [int fallback = 0]) =>
    v is num && v.isFinite ? v.toInt() : fallback;

String money(int minor) =>
    '৳${(minor / 100).toStringAsFixed(minor % 100 == 0 ? 0 : 2)}';

String normalized(String value) =>
    value.trim().toLowerCase().replaceAllMapped(
      RegExp('[০-৯]'),
          (m) => '০১২৩৪৫৬৭৮৯'.indexOf(m[0]!).toString(),
    );

Map<String, dynamic> object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

DateTime? date(dynamic value) =>
    value is Timestamp ? value.toDate() : DateTime.tryParse('$value');

String displayDate(dynamic value) {
  final d = date(value)?.toLocal();
  return d == null
      ? '—'
      : '${d.day}/${d.month}/${d.year} · '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

String statusLabel(String s) =>
    const {
      'placed': 'অনুরোধ জমা হয়েছে',
      'confirmed': 'নিশ্চিত',
      'packing': 'প্যাকিং চলছে',
      'out_for_delivery': 'ডেলিভারির পথে',
      'delivered': 'ডেলিভারি হয়েছে',
      'cancelled': 'বাতিল',
      'pending': 'অপেক্ষমাণ',
      'reviewing': 'পর্যালোচনা চলছে',
      'approved': 'অনুমোদিত',
      'rejected': 'অনুমোদন হয়নি',
      'resolved': 'সমাধান হয়েছে',
      'not_requested': 'Refund শুরু হয়নি',
      'paid': 'Refund দেওয়া হয়েছে',
      'declined': 'Refund অনুমোদন হয়নি',
      'unpaid': 'টাকা আদায় হয়নি',
      'collected': 'টাকা আদায় হয়েছে',
    }[s] ??
        s;

class ShopVariant {
  final String id, name, unit, image;
  final int price, originalPrice, stock;
  final bool enabled;

  const ShopVariant({
    required this.id,
    required this.name,
    required this.unit,
    required this.image,
    required this.price,
    required this.originalPrice,
    required this.stock,
    required this.enabled,
  });

  factory ShopVariant.fromMap(
      Map<String, dynamic> m, {
        String id = '',
        String unit = 'পিস',
        String image = '',
      }) =>
      ShopVariant(
        id: '${m['id'] ?? id}',
        name: '${m['name'] ?? ''}',
        unit: '${m['unit'] ?? unit}',
        image: '${m['imageUrl'] ?? image}',
        price: number(m['priceMinor']),
        originalPrice: number(m['originalPriceMinor']),
        stock: number(m['stockQty'], -1),
        enabled: m['inStock'] != false && m['published'] != false,
      );

  bool get available => enabled && price > 0 && stock > 0;
}

class ShopProduct {
  final String id, name, categoryId, categoryName, description;
  final List<String> images;
  final List<ShopVariant> variants;
  final ShopVariant base;
  final bool featured;
  final DateTime? createdAt;

  const ShopProduct({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.images,
    required this.variants,
    required this.base,
    required this.featured,
    this.createdAt,
  });

  factory ShopProduct.fromMap(String id, Map<String, dynamic> m) {
    final image = '${m['imageUrl'] ?? ''}';
    final unit = '${m['unit'] ?? 'পিস'}';

    final urls = <String>{
      image,
      ...((m['images'] as List?) ?? []).whereType<String>(),
    }.where((x) => Uri.tryParse(x)?.scheme == 'https').toList();

    return ShopProduct(
      id: id,
      name: '${m['name'] ?? 'পণ্য'}',
      categoryId: '${m['categoryId'] ?? 'other'}',
      categoryName: '${m['categoryName'] ?? 'অন্যান্য'}',
      description: '${m['description'] ?? ''}',
      images: urls,
      variants: ((m['variants'] as List?) ?? [])
          .map(
            (x) => ShopVariant.fromMap(
          object(x),
          unit: unit,
          image: image,
        ),
      )
          .toList(),
      base: ShopVariant.fromMap(m, unit: unit, image: image),
      featured: m['featured'] == true,
      createdAt: date(m['createdAt']),
    );
  }

  List<ShopVariant> get choices => variants.isEmpty ? [base] : variants;

  ShopVariant? choice(String id) {
    if (variants.isEmpty) return id.isEmpty ? base : null;
    for (final v in variants) {
      if (v.id == id) return v;
    }
    return null;
  }

  ShopVariant get preview {
    final all = choices.where((x) => x.available).toList();
    if (all.isEmpty) return choices.first;
    all.sort((a, b) => a.price.compareTo(b.price));
    return all.first;
  }

  bool get available => choices.any((x) => x.available);
  String get image => images.isEmpty ? '' : images.first;
}

class CartLine {
  final String productId, variantId, name, variantName, unit, image;
  final int qty, price;

  const CartLine({
    required this.productId,
    required this.variantId,
    required this.name,
    required this.variantName,
    required this.unit,
    required this.image,
    required this.qty,
    required this.price,
  });

  String get key => '$productId:$variantId';
  int get subtotal => qty * price;

  factory CartLine.fromMap(Map<String, dynamic> m) => CartLine(
    productId: '${m['productId'] ?? ''}',
    variantId: '${m['variantId'] ?? ''}',
    name: '${m['name'] ?? ''}',
    variantName: '${m['variantName'] ?? ''}',
    unit: '${m['unit'] ?? 'পিস'}',
    image: '${m['imageUrl'] ?? ''}',
    qty: number(m['qty'], 1),
    price: number(m['priceMinor']),
  );

  factory CartLine.fromProduct(
      ShopProduct p,
      ShopVariant v,
      int qty,
      ) =>
      CartLine(
        productId: p.id,
        variantId: p.variants.isEmpty ? '' : v.id,
        name: p.name,
        variantName: p.variants.isEmpty ? '' : v.name,
        unit: v.unit,
        image: v.image.isEmpty ? p.image : v.image,
        qty: qty,
        price: v.price,
      );

  Map<String, dynamic> get request => {
    'productId': productId,
    'variantId': variantId,
    'qty': qty,
  };

  Map<String, dynamic> toMap() => {
    ...request,
    'name': name,
    'variantName': variantName,
    'unit': unit,
    'imageUrl': image,
    'priceMinor': price,
  };

  CartLine withQuantity(int quantity) =>
      CartLine.fromMap({...toMap(), 'qty': quantity});
}

class StoreConfig {
  final Map<String, dynamic> raw;

  const StoreConfig(this.raw);

  bool get enabled => raw['enabled'] == true;

  List<Map<String, dynamic>> get zones =>
      ((raw['deliveryZones'] as List?) ?? [])
          .map(object)
          .where((x) => x['enabled'] == true)
          .toList();

  String get deliveryPolicy =>
      '${raw['deliveryPolicy'] ?? 'Delivery তথ্য এখন প্রকাশিত হয়নি।'}';

  String get returnPolicy =>
      '${raw['returnPolicy'] ?? 'Return policy এখন প্রকাশিত হয়নি।'}';

  String get supportPhone => '${raw['supportPhone'] ?? ''}';
}