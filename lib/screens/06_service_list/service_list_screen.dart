import 'package:flutter/material.dart';

import '../../core/widgets/directory_page.dart';
import 'service_list_controller.dart';

class ServiceListScreen extends StatelessWidget {
  const ServiceListScreen({
    super.key,
    this.categoryId,
  });

  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return DirectoryPage(
      createController: () =>
          ServiceListController(categoryId: categoryId),
    );
  }
}