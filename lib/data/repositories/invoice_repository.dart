import '../datasources/local_datasource.dart';
import '../models/invoice_model.dart';

class InvoiceRepository {
  final LocalDatasource _ds;
  InvoiceRepository({LocalDatasource? datasource})
      : _ds = datasource ?? LocalDatasource();

  Future<List<InvoiceModel>> getAll({InvoiceStatus? status, String? userId}) =>
      _ds.queryInvoices(status: status, userId: userId);

  Future<InvoiceModel?> getById(String id) => _ds.getInvoice(id);

  Future<void> add(InvoiceModel inv, String userId) => _ds.insertInvoice(inv, userId);

  Future<void> update(InvoiceModel inv) => _ds.updateInvoice(inv);

  Future<void> remove(String id) => _ds.deleteInvoice(id);

  Future<Map<String, int>> stats({String? userId}) => _ds.invoiceStats(userId: userId);
}
