import '../../core/controllers/directory_controller.dart';

class ServiceListController extends DirectoryController {
  ServiceListController({String? categoryId})
      : super(
    fixedCategory: categoryId,
    servicesOnly: true,
  );
}