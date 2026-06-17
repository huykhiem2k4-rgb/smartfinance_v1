import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import '../../data/models/transaction_model.dart';
import '../../data/models/invoice_model.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../core/utils/currency_calculator.dart';

enum FilterPeriod { thisMonth, lastMonth, allTime }

class AppProvider extends ChangeNotifier {
  final TransactionRepository _txRepo;
  final InvoiceRepository _invRepo;

  AppProvider({
    TransactionRepository? txRepo,
    InvoiceRepository? invRepo,
  })  : _txRepo = txRepo ?? TransactionRepository(),
        _invRepo = invRepo ?? InvoiceRepository();

  // ── Auth context ──────────────────────────────────────────────
  String? _userId;
  bool _isAdmin = false;

  void setUser(String? userId, {bool isAdmin = false}) {
    _userId = userId;
    _isAdmin = isAdmin;
  }

  String? get _filterUserId => _isAdmin ? null : _userId;

  // ── State ────────────────────────────────────────────────────
  List<TransactionModel> _transactions = [];
  List<InvoiceModel> _invoices = [];
  List<Map<String, dynamic>> _trend = [];
  FilterPeriod _filterPeriod = FilterPeriod.thisMonth;
  bool _isLoading = false;
  String? _error;

  List<TransactionModel> get transactions => _transactions;
  List<InvoiceModel> get invoices => _invoices;
  List<Map<String, dynamic>> get trend => _trend;
  FilterPeriod get filterPeriod => _filterPeriod;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Computed ──────────────────────────────────────────────────
  int get totalIncome => CurrencyCalculator.totalIncome(
      _transactions.where((t) => t.type == TransactionType.income).map((t) => t.amount).toList());

  int get totalExpense => CurrencyCalculator.totalExpense(
      _transactions.where((t) => t.type == TransactionType.expense).map((t) => t.amount).toList());

  int get netCashFlow => CurrencyCalculator.netCashFlow(totalIncome, totalExpense);

  DateTimeRange get _periodRange {
    final now = DateTime.now();
    switch (_filterPeriod) {
      case FilterPeriod.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case FilterPeriod.lastMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 1),
        );
      case FilterPeriod.allTime:
        return DateTimeRange(
          start: DateTime(2000),
          end: DateTime(2099),
        );
    }
  }

  // ── Load ──────────────────────────────────────────────────────
  Future<void> loadAll() async {
    _setLoading(true);
    try {
      await Future.wait([
        _loadTransactions(),
        _loadInvoices(),
        _loadTrend(),
      ]);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> _loadTransactions() async {
    final range = _periodRange;
    _transactions = await _txRepo.getAll(
      from: range.start,
      to: range.end,
      userId: _filterUserId,
    );
    notifyListeners();
  }

  Future<void> _loadInvoices() async {
    _invoices = await _invRepo.getAll(userId: _filterUserId);
    notifyListeners();
  }

  Future<void> _loadTrend() async {
    _trend = await _txRepo.monthlyTrend(6, userId: _filterUserId);
    notifyListeners();
  }

  Future<void> setFilterPeriod(FilterPeriod period) async {
    _filterPeriod = period;
    notifyListeners();
    await _loadTransactions();
  }

  // ── Transactions ──────────────────────────────────────────────
  Future<void> addTransaction(TransactionModel t) async {
    await _txRepo.add(t, _userId ?? 'u_admin');
    await Future.wait([_loadTransactions(), _loadTrend()]);
  }

  Future<void> deleteTransaction(String id) async {
    await _txRepo.remove(id);
    await Future.wait([_loadTransactions(), _loadTrend()]);
  }

  Future<List<Map<String, dynamic>>> getCategoryBreakdown(TransactionType type) {
    final range = _periodRange;
    return _txRepo.categoryBreakdown(type,
        from: range.start, to: range.end, userId: _filterUserId);
  }

  // ── Invoices ──────────────────────────────────────────────────
  Future<void> addInvoice(InvoiceModel inv) async {
    await _invRepo.add(inv, _userId ?? 'u_admin');
    await _loadInvoices();
  }

  Future<void> deleteInvoice(String id) async {
    await _invRepo.remove(id);
    await _loadInvoices();
  }

  Future<void> updateInvoice(InvoiceModel inv) async {
    await _invRepo.update(inv);
    await _loadInvoices();
  }

  Future<InvoiceModel?> getInvoice(String id) => _invRepo.getById(id);

  Future<Map<String, int>> getInvoiceStats() => _invRepo.stats(userId: _filterUserId);

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
