import '../datasources/supabase_datasource.dart';
import '../datasources/local_datasource.dart';
import '../../core/utils/connectivity_helper.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final SupabaseDatasource _cloud;
  final LocalDatasource _local;

  TransactionRepository({SupabaseDatasource? cloud, LocalDatasource? local})
      : _cloud = cloud ?? SupabaseDatasource(),
        _local = local ?? LocalDatasource();

  Future<List<TransactionModel>> getAll({
    DateTime? from,
    DateTime? to,
    TransactionType? type,
    String? userId,
  }) async {
    final localData = await _local.queryTransactions(from: from, to: to, type: type, userId: userId);
    if (await ConnectivityHelper.isOnline) {
      try {
        final cloudData = await _cloud.queryTransactions(from: from, to: to, type: type, userId: userId);
        final cloudIds = cloudData.map((e) => e.id).toSet();
        final merged = [...cloudData, ...localData.where((l) => !cloudIds.contains(l.id))];
        merged.sort((a, b) => b.date.compareTo(a.date));
        return merged;
      } catch (_) {}
    }
    return localData;
  }

  Future<TransactionModel?> getById(String id) async {
    return _local.getTransactionById(id);
  }

  Future<void> add(TransactionModel t, String userId) async {
    await _local.insertTransaction(t, userId);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.insertTransaction(t, userId);
      } catch (_) {}
    }
  }

  Future<void> update(TransactionModel t) async {
    await _local.updateTransaction(t);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.updateTransaction(t);
      } catch (_) {}
    }
  }

  Future<void> remove(String id) async {
    await _local.deleteTransaction(id);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.deleteTransaction(id);
      } catch (_) {}
    }
  }

  Future<void> cancel(String id, {required String cancelledBy, required String reason}) async {
    await _local.cancelTransaction(id, cancelledBy: cancelledBy, reason: reason);
    if (await ConnectivityHelper.isOnline) {
      try {
        final tx = await _local.getTransactionById(id);
        if (tx != null) await _cloud.updateTransaction(tx);
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> monthlyTrend(int months, {String? userId}) async {
    return _local.monthlyTrend(months, userId: userId);
  }

  Future<List<Map<String, dynamic>>> categoryBreakdown(
    TransactionType type, {
    DateTime? from,
    DateTime? to,
    String? userId,
  }) async {
    return _local.categoryBreakdown(type, from: from, to: to, userId: userId);
  }

  Future<Map<String, int>> summaryForPeriod(DateTime from, DateTime to, {String? userId}) async {
    return _local.summaryForPeriod(from, to, userId: userId);
  }

  Future<void> syncToCloud(TransactionModel t) async {
    if (!await ConnectivityHelper.isOnline) return;
    try {
      final rows = await _local.getTransactionsRaw();
      final match = rows.where((r) => r['id'] == t.id);
      if (match.isEmpty) return;
      final userId = match.first['user_id'] as String? ?? 'u_admin';
      await _cloud.insertTransaction(t, userId);
    } catch (_) {}
  }

  Future<void> syncAllToCloud() async {
    if (!await ConnectivityHelper.isOnline) return;
    try {
      final rows = await _local.getTransactionsRaw();
      for (final row in rows) {
        final tx = TransactionModel.fromMap(row);
        final userId = row['user_id'] as String? ?? 'u_admin';
        await _cloud.insertTransaction(tx, userId);
      }
    } catch (_) {}
  }

  Future<void> syncFromCloud() async {
    if (!await ConnectivityHelper.isOnline) return;
    try {
      final cloudRows = await _cloud.queryAllTransactionsRaw();
      for (final row in cloudRows) {
        final tx = TransactionModel.fromMap(row);
        final userId = row['user_id'] as String? ?? 'u_admin';
        await _local.insertTransaction(tx, userId);
      }
    } catch (_) {}
  }
}
