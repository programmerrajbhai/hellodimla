import '../../core/controllers/directory_controller.dart';

class SearchResultsController extends DirectoryController {
  SearchResultsController({String? query})
      : super(initialQuery: query);
}