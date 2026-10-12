import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'shop_models.dart';
import 'shop_service.dart';

const shopBlue = Color(0xFF175CFF);
const shopInk = Color(0xFF152543);
const shopBackground = Color(0xFFF4F7FF);

class ShopPage extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottom;

  const ShopPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFDCE5F5)),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: shopBlue),
        scaffoldBackgroundColor: shopBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: shopBackground,
          foregroundColor: shopInk,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: border,
          enabledBorder: border,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: shopBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: actions,
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: 980, child: body),
          ),
        ),
        bottomNavigationBar: bottom == null
            ? null
            : SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE3EAF8)),
              ),
            ),
            child: bottom,
          ),
        ),
      ),
    );
  }
}

class ShopBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const ShopBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4EBF7)),
      ),
      child: child,
    );
  }
}

class ShopImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;

  const ShopImage(
      this.url, {
        super.key,
        this.width,
        this.height,
      });

  @override
  Widget build(BuildContext context) {
    Widget placeholder() {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFEDF3FF),
        alignment: Alignment.center,
        child: const Icon(
          Icons.shopping_bag_outlined,
          color: shopBlue,
          size: 38,
        ),
      );
    }

    if (Uri.tryParse(url)?.scheme != 'https') {
      return placeholder();
    }

    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stack) => placeholder(),
      loadingBuilder: (_, child, progress) {
        return progress == null ? child : placeholder();
      },
    );
  }
}

class ShopEmpty extends StatelessWidget {
  final String text;
  final VoidCallback? retry;

  const ShopEmpty(this.text, {super.key, this.retry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_basket_outlined,
              size: 54,
              color: shopBlue,
            ),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            if (retry != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton(
                  onPressed: retry,
                  child: const Text('আবার চেষ্টা করুন'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class QuantityControl extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int>? onChanged;

  const QuantityControl({
    super.key,
    required this.value,
    required this.max,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: 'পরিমাণ কমান',
          onPressed: value > 1 && onChanged != null
              ? () => onChanged!(value - 1)
              : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        IconButton(
          tooltip: 'পরিমাণ বাড়ান',
          onPressed: value < max && onChanged != null
              ? () => onChanged!(value + 1)
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class PriceText extends StatelessWidget {
  final int price;
  final int original;

  const PriceText(this.price, {super.key, this.original = 0});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          money(price),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: shopBlue,
          ),
        ),
        if (original > price)
          Text(
            money(original),
            style: const TextStyle(
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}

Widget totalRow(String label, int amount, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          money(amount),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            fontSize: bold ? 20 : 15,
            color: bold ? shopBlue : shopInk,
          ),
        ),
      ],
    ),
  );
}

Future<bool> confirm(
    String title,
    String message, {
      String action = 'নিশ্চিত করুন',
    }) async {
  return await Get.dialog<bool>(
    AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('ফিরে যান'),
        ),
        FilledButton(
          onPressed: () => Get.back(result: true),
          child: Text(action),
        ),
      ],
    ),
  ) ??
      false;
}

Future<T?> shopSheet<T>(Widget child) {
  return Get.bottomSheet<T>(
    Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            22,
            12,
            22,
            22 + MediaQuery.viewInsetsOf(Get.context!).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

Future<void> policies(StoreConfig? config) async {
  await shopSheet<void>(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery ও return',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Delivery',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(config?.deliveryPolicy ?? 'তথ্য পাওয়া যায়নি।'),
        const SizedBox(height: 18),
        const Text(
          'Return',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(config?.returnPolicy ?? 'তথ্য পাওয়া যায়নি।'),
        const SizedBox(height: 14),
        const Text('অনুরোধ জমা হওয়া মানেই refund অনুমোদিত নয়।'),
      ],
    ),
  );
}

void shopError(Object error) {
  Get.snackbar(
    'কাজটি সম্পন্ন হয়নি',
    ShopService.message(error),
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.white,
    colorText: shopInk,
    duration: const Duration(seconds: 5),
  );
}

Future<void> guarded(Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    shopError(e);
  }
}

Future<void> dialStore(String value) {
  return guarded(() async {
    final phone = value.replaceAll(RegExp(r'[^0-9+]'), '');

    if (!RegExp(r'^\+?\d{6,15}$').hasMatch(phone)) {
      throw StateError('Store-এর ফোন নম্বর দেওয়া হয়নি।');
    }

    final opened = await launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw StateError('Dialer খোলা যায়নি।');
    }
  });
}