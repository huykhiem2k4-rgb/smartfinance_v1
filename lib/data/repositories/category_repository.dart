import '../datasources/supabase_datasource.dart';
import '../datasources/local_datasource.dart';
import '../../core/utils/connectivity_helper.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final SupabaseDatasource _cloud;
  final LocalDatasource _local;

  CategoryRepository({SupabaseDatasource? cloud, LocalDatasource? local})
      : _cloud = cloud ?? SupabaseDatasource(),
        _local = local ?? LocalDatasource();

  Future<List<CategoryModel>> getAll() async {
    final localData = await _local.getAllCategories();
    if (await ConnectivityHelper.isOnline) {
      try {
        final cloudData = await _cloud.getAllCategories();
        if (cloudData.isNotEmpty) return cloudData;
      } catch (_) {}
    }
    return localData;
  }

  Future<CategoryModel?> getById(String id) async {
    return _local.getCategoryById(id);
  }

  Future<void> add(CategoryModel cat) async {
    await _local.insertCategory(cat);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.insertCategory(cat);
      } catch (_) {}
    }
  }

  Future<void> update(CategoryModel cat) async {
    await _local.updateCategory(cat);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.updateCategory(cat);
      } catch (_) {}
    }
  }

  Future<void> remove(String id) async {
    await _local.deleteCategory(id);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.deleteCategory(id);
      } catch (_) {}
    }
  }
}
