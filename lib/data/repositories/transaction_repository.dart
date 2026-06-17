import '../datasources/local_datasource.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final LocalDatasource _ds;
  TransactionRepository({LocalDatasource? datasource})
      : _ds = datasource ?? LocalDatasource();

  Future<List<TransactionModel>> getAll({
    DateTime? from,
    DateTime? to,
    TransactionType? type,
    String? userId,
  }) =>
      _ds.queryTransactions(from: from, to: to, type: type, userId: userId);

  Future<void> add(TransactionModel t, String userId) => _ds.insertTransaction(t, userId);

  Future<void> remove(String id) => _ds.deleteTransaction(id);

  Future<List<Map<String, dynamic>>> monthlyTrend(int months, {String? userId}) =>
      _ds.monthlyTrend(months, userId: userId);

  Future<List<Map<String, dynamic>>> categoryBreakdown(
    TransactionType type, {
    DateTime? from,
    DateTime? to,
    String? userId,
  }) =>
      _ds.categoryBreakdown(type, from: from, to: to, userId: userId);

  Future<Map<String, int>> summaryForPeriod(DateTime from, DateTime to, {String? userId}) =>
      _ds.summaryForPeriod(from, to, userId: userId);
}
