import '../datasources/supabase_datasource.dart';
import '../datasources/local_datasource.dart';
import '../../core/utils/connectivity_helper.dart';

class ActivityLogRepository {
  final SupabaseDatasource _cloud;
  final LocalDatasource _local;

  ActivityLogRepository({SupabaseDatasource? cloud, LocalDatasource? local})
      : _cloud = cloud ?? SupabaseDatasource(),
        _local = local ?? LocalDatasource();

  Future<void> log({
    required String userId,
    required String module,
    required String actionType,
    String? referenceId,
    String? description,
    String? entityType,
    String? entityId,
  }) async {
    await _local.insertActivityLog(
      userId: userId,
      module: module,
      actionType: actionType,
      referenceId: referenceId,
      description: description,
      entityType: entityType,
      entityId: entityId,
    );
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.insertActivityLog(
          userId: userId,
          module: module,
          actionType: actionType,
          referenceId: referenceId,
          description: description,
          entityType: entityType,
          entityId: entityId,
        );
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> getAll({
    String? userId,
    String? module,
    String? actionType,
  }) async {
    final localData = await _local.getActivityLogs(userId: userId, module: module, actionType: actionType);
    if (await ConnectivityHelper.isOnline) {
      try {
        final cloudData = await _cloud.getActivityLogs(userId: userId, module: module, actionType: actionType);
        if (cloudData.isNotEmpty) return cloudData;
      } catch (_) {}
    }
    return localData;
  }
}
