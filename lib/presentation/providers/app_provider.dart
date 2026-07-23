import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import '../../data/models/transaction_model.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/partner_model.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/activity_log_repository.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/user_model.dart';
import '../../core/utils/currency_calculator.dart';

enum FilterPeriod { thisMonth, lastMonth, allTime }

class AppProvider extends ChangeNotifier {
  final TransactionRepository _txRepo;
  final InvoiceRepository _invRepo;
  final CategoryRepository _catRepo;
  final PartnerRepository _partnerRepo;
  final NotificationRepository _notifRepo;
  final ActivityLogRepository _logRepo;
  final LocalDatasource _local;

  AppProvider({
    TransactionRepository? txRepo,
    InvoiceRepository? invRepo,
    CategoryRepository? catRepo,
    PartnerRepository? partnerRepo,
    NotificationRepository? notifRepo,
    ActivityLogRepository? logRepo,
    LocalDatasource? local,
  })  : _txRepo = txRepo ?? TransactionRepository(),
        _invRepo = invRepo ?? InvoiceRepository(),
        _catRepo = catRepo ?? CategoryRepository(),
        _partnerRepo = partnerRepo ?? PartnerRepository(),
        _notifRepo = notifRepo ?? NotificationRepository(),
        _logRepo = logRepo ?? ActivityLogRepository(),
        _local = local ?? LocalDatasource();

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
  List<CategoryModel> _categories = [];
  List<PartnerModel> _partners = [];
  List<Map<String, dynamic>> _trend = [];
  FilterPeriod _filterPeriod = FilterPeriod.thisMonth;
  bool _isLoading = false;
  String? _error;

  List<TransactionModel> get transactions => _transactions;
  List<InvoiceModel> get invoices => _invoices;
  List<CategoryModel> get categories => _categories;
  List<PartnerModel> get partners => _partners;
  List<Map<String, dynamic>> get trend => _trend;
  FilterPeriod get filterPeriod => _filterPeriod;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Computed ──────────────────────────────────────────────────
  int get totalIncome => CurrencyCalculator.totalIncome(
      _transactions.where((t) => t.type == TransactionType.income && t.isPosted).map((t) => t.amount).toList());

  int get totalExpense => CurrencyCalculator.totalExpense(
      _transactions.where((t) => t.type == TransactionType.expense && t.isPosted).map((t) => t.amount).toList());

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
        _loadCategories(),
        _loadPartners(),
        loadNotifications(),
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

  Future<void> _loadCategories() async {
    _categories = await _catRepo.getAll();
    notifyListeners();
  }

  Future<void> _loadPartners() async {
    _partners = await _partnerRepo.getAll();
    notifyListeners();
  }

  Future<void> setFilterPeriod(FilterPeriod period) async {
    _filterPeriod = period;
    notifyListeners();
    await _loadTransactions();
  }

  // ── Transactions ──────────────────────────────────────────────
  Future<void> _ensureUserExists() async {
    if (_userId == null) return;
    final existing = await _local.getUserById(_userId!);
    if (existing == null) {
      // Try to get role from Supabase
      UserRole role = UserRole.accountant;
      try {
        final cloudUser = await SupabaseDatasource().getUserById(_userId!);
        if (cloudUser != null) role = cloudUser.role;
      } catch (_) {}
      await _local.insertUser(UserModel(
        id: _userId!,
        username: _userId!,
        passwordHash: '',
        role: role,
        fullName: null,
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<TransactionModel?> getTransaction(String id) => _txRepo.getById(id);

  Future<void> addTransaction(TransactionModel t) async {
    await _ensureUserExists();
    await _txRepo.add(t, _userId ?? 'u_admin');
    await _logRepo.log(userId: _userId ?? 'u_admin', module: 'TRANSACTION', actionType: 'CREATE', referenceId: t.id, description: t.title);
    await Future.wait([_loadTransactions(), _loadTrend()]);
  }

  Future<void> updateTransaction(TransactionModel t) async {
    await _txRepo.update(t);
    await _logRepo.log(userId: _userId ?? 'u_admin', module: 'TRANSACTION', actionType: 'UPDATE', referenceId: t.id, description: t.title);
    await Future.wait([_loadTransactions(), _loadTrend()]);
  }

  Future<void> deleteTransaction(String id) async {
    await _txRepo.remove(id);
    await _logRepo.log(userId: _userId ?? 'u_admin', module: 'TRANSACTION', actionType: 'CANCEL', referenceId: id);
    await Future.wait([_loadTransactions(), _loadTrend()]);
  }

  Future<void> cancelTransaction(String id, {required String reason}) async {
    await _txRepo.cancel(id, cancelledBy: _userId ?? 'u_admin', reason: reason);
    await _logRepo.log(userId: _userId ?? 'u_admin', module: 'TRANSACTION', actionType: 'CANCEL', referenceId: id, description: reason);
    await Future.wait([_loadTransactions(), _loadTrend()]);
  }

  Future<List<Map<String, dynamic>>> getCategoryBreakdown(TransactionType type) {
    final range = _periodRange;
    return _txRepo.categoryBreakdown(type,
        from: range.start, to: range.end, userId: _filterUserId);
  }

  // ── Invoices ──────────────────────────────────────────────────
  Future<void> addInvoice(InvoiceModel inv) async {
    await _ensureUserExists();
    await _invRepo.add(inv, _userId ?? 'u_admin');
    await _logRepo.log(userId: _userId ?? 'u_admin', module: 'INVOICE', actionType: 'CREATE', referenceId: inv.id, description: inv.invoiceNumber);
    await _loadInvoices();
  }

  Future<void> deleteInvoice(String id) async {
    await _invRepo.remove(id);
    await _logRepo.log(userId: _userId ?? 'u_admin', module: 'INVOICE', actionType: 'CANCEL', referenceId: id);
    await _loadInvoices();
  }

  Future<void> updateInvoice(InvoiceModel inv) async {
    await _invRepo.update(inv);
    await _logRepo.log(userId: _userId ?? 'u_admin', module: 'INVOICE', actionType: 'UPDATE', referenceId: inv.id, description: inv.invoiceNumber);
    await _loadInvoices();
  }

  Future<void> approveInvoice(String invoiceId, {String? comment}) async {
    await _invRepo.approve(invoiceId, _userId ?? 'u_admin', comment: comment);
    await _logRepo.log(userId: _userId ?? 'u_admin', module: 'INVOICE', actionType: 'APPROVE', referenceId: invoiceId, description: comment);
    await _notifRepo.create(
      userId: _userId ?? 'u_admin',
      title: 'Hóa đơn đã duyệt',
      message: 'Hóa đơn #$invoiceId đã được phê duyệt',
      type: 'INVOICE',
      referenceId: invoiceId,
    );
    await _loadInvoices();
  }

  Future<void> rejectInvoice(String invoiceId, {String? comment}) async {
    await _invRepo.reject(invoiceId, _userId ?? 'u_admin', comment: comment);
    await _logRepo.log(userId: _userId ?? 'u_admin', module: 'INVOICE', actionType: 'REJECT', referenceId: invoiceId, description: comment);
    await _notifRepo.create(
      userId: _userId ?? 'u_admin',
      title: 'Hóa đơn bị từ chối',
      message: 'Hóa đơn #$invoiceId đã bị từ chối. Lý do: $comment',
      type: 'INVOICE',
      referenceId: invoiceId,
    );
    await _loadInvoices();
  }

  Future<InvoiceModel?> getInvoice(String id) => _invRepo.getById(id);

  Future<Map<String, int>> getInvoiceStats() => _invRepo.stats();

  // ── Categories ────────────────────────────────────────────────
  Future<void> addCategory(CategoryModel cat) async {
    await _catRepo.add(cat);
    await _loadCategories();
  }

  Future<void> updateCategory(CategoryModel cat) async {
    await _catRepo.update(cat);
    await _loadCategories();
  }

  Future<void> deleteCategory(String id) async {
    await _catRepo.remove(id);
    await _loadCategories();
  }

  // ── Partners ──────────────────────────────────────────────────
  Future<void> addPartner(PartnerModel partner) async {
    await _partnerRepo.add(partner);
    await _loadPartners();
  }

  Future<void> updatePartner(PartnerModel partner) async {
    await _partnerRepo.update(partner);
    await _loadPartners();
  }

  Future<void> deletePartner(String id) async {
    await _partnerRepo.remove(id);
    await _loadPartners();
  }

  // ── Notifications ─────────────────────────────────────────────
  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> loadNotifications() async {
    if (_userId == null) return;
    _notifications = await _notifRepo.getNotifications(_userId!);
    notifyListeners();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _notifRepo.markRead(notificationId);
    await loadNotifications();
  }

  Future<void> markAllNotificationsRead() async {
    if (_userId == null) return;
    await _notifRepo.markAllRead(_userId!);
    await loadNotifications();
  }

  // ── Activity Logs ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getActivityLogs({String? module, String? actionType}) {
    return _logRepo.getAll(userId: _userId, module: module, actionType: actionType);
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
