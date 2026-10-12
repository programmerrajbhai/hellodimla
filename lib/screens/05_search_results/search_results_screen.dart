import 'package:flutter/material.dart';

import '../../core/widgets/directory_page.dart';
import 'search_results_controller.dart';

class SearchResultsScreen extends StatelessWidget {
  const SearchResultsScreen({
    super.key,
    this.query,
  });

  final String? query;

  @override
  Widget build(BuildContext context) {
    return DirectoryPage(
      createController: () => SearchResultsController(query: query),
    );
  }
}