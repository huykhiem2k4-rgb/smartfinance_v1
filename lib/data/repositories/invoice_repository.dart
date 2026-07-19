import '../datasources/supabase_datasource.dart';
import '../datasources/local_datasource.dart';
import '../../core/utils/connectivity_helper.dart';
import '../models/invoice_model.dart';

class InvoiceRepository {
  final SupabaseDatasource _cloud;
  final LocalDatasource _local;

  InvoiceRepository({SupabaseDatasource? cloud, LocalDatasource? local})
      : _cloud = cloud ?? SupabaseDatasource(),
        _local = local ?? LocalDatasource();

  Future<List<InvoiceModel>> getAll({InvoiceStatus? status, String? userId}) async {
    final localData = await _local.queryInvoices(status: status, userId: userId);
    if (await ConnectivityHelper.isOnline) {
      try {
        final cloudData = await _cloud.queryInvoices(status: status, userId: userId);
        final cloudIds = cloudData.map((e) => e.id).toSet();
        return [...cloudData, ...localData.where((l) => !cloudIds.contains(l.id))];
      } catch (_) {}
    }
    return localData;
  }

  Future<InvoiceModel?> getById(String id) async {
    final local = await _local.getInvoice(id);
    if (local != null) return local;
    if (await ConnectivityHelper.isOnline) {
      try {
        return await _cloud.getInvoice(id);
      } catch (_) {}
    }
    return null;
  }

  Future<void> add(InvoiceModel inv, String userId) async {
    await _local.insertInvoice(inv, userId);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.insertInvoice(inv, userId);
      } catch (_) {}
    }
  }

  Future<void> update(InvoiceModel inv) async {
    await _local.updateInvoice(inv);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.updateInvoice(inv);
      } catch (_) {}
    }
  }

  Future<void> remove(String id) async {
    await _local.deleteInvoice(id);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.deleteInvoice(id);
      } catch (_) {}
    }
  }

  Future<Map<String, int>> stats({String? userId}) async {
    final localData = await _local.invoiceStats(userId: userId);
    if (await ConnectivityHelper.isOnline) {
      try {
        final cloudData = await _cloud.invoiceStats(userId: userId);
        if (cloudData.isNotEmpty) return cloudData;
      } catch (_) {}
    }
    return localData;
  }

  Future<void> syncToCloud(InvoiceModel inv) async {
    if (!await ConnectivityHelper.isOnline) return;
    try {
      final rows = await _local.getInvoicesRaw();
      final match = rows.where((r) => r['id'] == inv.id);
      if (match.isEmpty) return;
      final userId = match.first['user_id'] as String? ?? 'u_admin';
      await _cloud.insertInvoice(inv, userId);
    } catch (_) {}
  }

  Future<void> syncAllToCloud() async {
    if (!await ConnectivityHelper.isOnline) return;
    try {
      final rows = await _local.getInvoicesRaw();
      for (final row in rows) {
        final items = await _local.getInvoiceItems(row['id'] as String);
        final inv = InvoiceModel.fromMap(row, items: items);
        final userId = row['user_id'] as String? ?? 'u_admin';
        await _cloud.insertInvoice(inv, userId);
      }
    } catch (_) {}
  }
}
