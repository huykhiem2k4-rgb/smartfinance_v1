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
    if (await ConnectivityHelper.isOnline) {
      try {
        final data = await _cloud.queryTransactions(
          from: from, to: to, type: type, userId: userId,
        );
        return data;
      } catch (_) {}
    }
    return _local.queryTransactions(from: from, to: to, type: type, userId: userId);
  }

  Future<TransactionModel?> getById(String id) async {
    return _local.getTransactionById(id);
  }

  Future<void> add(TransactionModel t, String userId) async {
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.insertTransaction(t, userId);
      } catch (_) {}
    }
    await _local.insertTransaction(t, userId);
  }

  Future<void> update(TransactionModel t) async {
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.updateTransaction(t);
      } catch (_) {}
    }
    await _local.updateTransaction(t);
  }

  Future<void> remove(String id) async {
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.deleteTransaction(id);
      } catch (_) {}
    }
    await _local.deleteTransaction(id);
  }

  Future<List<Map<String, dynamic>>> monthlyTrend(int months, {String? userId}) async {
    if (await ConnectivityHelper.isOnline) {
      try {
        return await _cloud.monthlyTrend(months, userId: userId);
      } catch (_) {}
    }
    return _local.monthlyTrend(months, userId: userId);
  }

  Future<List<Map<String, dynamic>>> categoryBreakdown(
    TransactionType type, {
    DateTime? from,
    DateTime? to,
    String? userId,
  }) async {
    if (await ConnectivityHelper.isOnline) {
      try {
        return await _cloud.categoryBreakdown(type, from: from, to: to, userId: userId);
      } catch (_) {}
    }
    return _local.categoryBreakdown(type, from: from, to: to, userId: userId);
  }

  Future<Map<String, int>> summaryForPeriod(DateTime from, DateTime to, {String? userId}) async {
    if (await ConnectivityHelper.isOnline) {
      try {
        return await _cloud.summaryForPeriod(from, to, userId: userId);
      } catch (_) {}
    }
    return _local.summaryForPeriod(from, to, userId: userId);
  }
}
