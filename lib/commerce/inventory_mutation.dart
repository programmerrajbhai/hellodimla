/// Orders reserve available stock at placement.
/// Cancellation restores that reservation.
///
/// Keep variant IDs and array positions stable while orders are active.
Map<String, dynamic> inventoryMutation({
  required Map<String, dynamic> product,
  required String productId,
  required List<Map<String, dynamic>> lines,
  required String requestId,
  required int direction,
}) {
  if (direction != -1 && direction != 1) {
    throw StateError('Invalid stock direction');
  }

  final selected = lines.where(
        (line) => line['productId'] == productId,
  );

  final variants = ((product['variants'] as List?) ?? [])
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();

  int readStock(dynamic value) {
    if (value is! int || value < 0) {
      throw StateError('পণ্যের stock তথ্য ঠিক করুন।');
    }
    return value;
  }

  int move(int current, int quantity) {
    final next = current + direction * quantity;

    if (quantity < 1 || quantity > 99 || next < 0) {
      throw StateError(
        'পর্যাপ্ত stock নেই। Cart আবার যাচাই করুন।',
      );
    }

    return next;
  }

  final patch = <String, dynamic>{
    'stockMutation': requestId,
  };

  final seen = <String>{};

  for (final line in selected) {
    final id = line['variantId'] as String;
    final index = line['variantIndex'] as int;
    final quantity = line['qty'] as int;

    if (!seen.add(id)) {
      throw StateError('Duplicate stock line');
    }

    if (variants.isEmpty) {
      if (id.isNotEmpty || index != -1) {
        throw StateError(
          'পণ্যের ধরন বদলেছে। Support-এ যোগাযোগ করুন।',
        );
      }

      patch['stockQty'] = move(
        readStock(product['stockQty']),
        quantity,
      );
    } else {
      if (index < 0 ||
          index >= variants.length ||
          variants[index]['id'] != id) {
        throw StateError(
          'Variant বদলেছে। Support-এ যোগাযোগ করুন।',
        );
      }

      variants[index]['stockQty'] = move(
        readStock(variants[index]['stockQty']),
        quantity,
      );
    }
  }

  if (seen.isEmpty) {
    throw StateError('Stock line missing');
  }

  if (variants.isNotEmpty) {
    patch['variants'] = variants;
  }

  return patch;
}