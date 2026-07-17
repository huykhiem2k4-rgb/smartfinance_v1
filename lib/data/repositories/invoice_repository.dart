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
    if (await ConnectivityHelper.isOnline) {
      try {
        return await _cloud.queryInvoices(status: status, userId: userId);
      } catch (_) {}
    }
    return _local.queryInvoices(status: status, userId: userId);
  }

  Future<InvoiceModel?> getById(String id) async {
    if (await ConnectivityHelper.isOnline) {
      try {
        return await _cloud.getInvoice(id);
      } catch (_) {}
    }
    return _local.getInvoice(id);
  }

  Future<void> add(InvoiceModel inv, String userId) async {
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.insertInvoice(inv, userId);
      } catch (_) {}
    }
    await _local.insertInvoice(inv, userId);
  }

  Future<void> update(InvoiceModel inv) async {
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.updateInvoice(inv);
      } catch (_) {}
    }
    await _local.updateInvoice(inv);
  }

  Future<void> remove(String id) async {
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.deleteInvoice(id);
      } catch (_) {}
    }
    await _local.deleteInvoice(id);
  }

  Future<Map<String, int>> stats({String? userId}) async {
    if (await ConnectivityHelper.isOnline) {
      try {
        return await _cloud.invoiceStats(userId: userId);
      } catch (_) {}
    }
    return _local.invoiceStats(userId: userId);
  }
}
