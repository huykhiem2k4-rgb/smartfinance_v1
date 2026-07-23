import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/invoice_model.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../models/partner_model.dart';
import '../models/notification_model.dart';

class SupabaseDatasource {
  static final SupabaseDatasource _instance = SupabaseDatasource._internal();
  factory SupabaseDatasource() => _instance;
  SupabaseDatasource._internal();

  SupabaseClient get _client => Supabase.instance.client;
  GoTrueClient get _auth => _client.auth;

  // ── AUTH ──────────────────────────────────────────────────────

  Session? get currentSession => _auth.currentSession;
  User? get currentAuthUser => _auth.currentUser;

  Future<void> signIn(String username, String password) async {
    final email = '$username@smartfinance.app';
    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String username, String password, String fullName) async {
    final email = '$username@smartfinance.app';
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
        'role': 'ACCOUNTANT',
        'full_name': fullName,
      },
    );
    return response;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<UserModel?> getCurrentUser() async {
    final authUser = _auth.currentUser;
    if (authUser == null) return null;

    // Query bảng users trong Supabase để lấy role thực tế
    try {
      final dbUser = await _client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();
      if (dbUser != null) {
        return UserModel.fromSupabase(dbUser);
      }
    } catch (_) {}

    // Fallback: dùng auth metadata nếu user chưa có trong bảng users
    final metadata = authUser.userMetadata ?? {};
    return UserModel.fromSupabase({
      'id': authUser.id,
      'username': metadata['username'] as String? ?? authUser.email?.split('@').first ?? '',
      'role': (metadata['role'] as String? ?? 'ACCOUNTANT').toUpperCase(),
      'full_name': metadata['full_name'] as String?,
      'email': metadata['email'] as String?,
      'phone': metadata['phone'] as String?,
      'avatar_url': metadata['avatar_url'] as String?,
      'status': metadata['status'] as String? ?? 'ACTIVE',
      'created_at': authUser.createdAt,
      'updated_at': metadata['updated_at'] as String?,
    });
  }

  // ── USERS ──────────────────────────────────────────────────────

  Future<UserModel?> getUserByUsername(String username) async {
    final response = await _client
        .from('users')
        .select()
        .eq('username', username)
        .maybeSingle();
    if (response == null) return null;
    return UserModel.fromSupabase(response);
  }

  Future<UserModel?> getUserById(String id) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return UserModel.fromSupabase(response);
  }

  Future<List<UserModel>> getAllUsers() async {
    final response = await _client
        .from('users')
        .select()
        .order('created_at', ascending: true);
    return (response as List).map((m) => UserModel.fromSupabase(m as Map<String, dynamic>)).toList();
  }

  Future<void> updateUser(UserModel user) async {
    await _client.from('users').update({
      'full_name': user.fullName,
      'email': user.email,
      'phone': user.phone,
      'avatar_url': user.avatarUrl,
      'status': user.status,
      'role': user.role.dbValue,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  Future<void> deleteUser(String userId) async {
    await _client.from('users').delete().eq('id', userId);
  }

  Future<void> insertUser(UserModel user) async {
    await _client.from('users').upsert({
      'id': user.id,
      'username': user.username,
      'password_hash': user.passwordHash,
      'role': user.role.dbValue,
      'full_name': user.fullName,
      'email': user.email,
      'phone': user.phone,
      'avatar_url': user.avatarUrl,
      'status': user.status,
      'created_at': user.createdAt.toIso8601String(),
    });
  }

  // ── TRANSACTIONS ───────────────────────────────────────────────

  Future<List<TransactionModel>> queryTransactions({
    DateTime? from,
    DateTime? to,
    TransactionType? type,
    String? userId,
  }) async {
    var query = _client.from('transactions').select();
    if (userId != null) query = query.eq('user_id', userId);
    if (from != null) query = query.gte('date', from.toIso8601String());
    if (to != null) query = query.lt('date', to.toIso8601String());
    if (type != null) query = query.eq('type', type.name);

    final response = await query.order('date', ascending: false);
    return (response as List).map((m) => TransactionModel(
      id: m['id'],
      title: m['title'],
      amount: (m['amount'] as num).toInt(),
      type: TransactionType.values.firstWhere((e) => e.name == m['type']),
      category: TransactionCategory.values.firstWhere(
        (e) => e.name == m['category'],
        orElse: () => TransactionCategory.otherExpense,
      ),
      description: m['description'],
      date: DateTime.parse(m['date']),
      imagePath: m['image_path'] ?? m['receipt_image_url'],
      createdBy: m['created_by'],
      categoryId: m['category_id'],
      receiptImageUrl: m['receipt_image_url'],
      status: m['status'] as String? ?? 'POSTED',
      cancelReason: m['cancel_reason'],
      cancelledBy: m['cancelled_by'],
      cancelledAt: m['cancelled_at'] != null ? DateTime.tryParse(m['cancelled_at']) : null,
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at']) : null,
      updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at']) : null,
    )).toList();
  }

  Future<void> insertTransaction(TransactionModel t, String userId) async {
    await _client.from('transactions').upsert({
      'id': t.id,
      'user_id': userId,
      'created_by': t.createdBy ?? userId,
      'category_id': t.categoryId,
      'title': t.title,
      'amount': t.amount,
      'type': t.type.name,
      'category': t.category.name,
      'description': t.description,
      'date': t.date.toIso8601String(),
      'receipt_image_url': t.receiptImageUrl,
      'image_path': t.imagePath,
      'status': t.status,
    });
  }

  Future<void> updateTransaction(TransactionModel t) async {
    await _client.from('transactions').update({
      'title': t.title,
      'amount': t.amount,
      'type': t.type.name,
      'category': t.category.name,
      'description': t.description,
      'date': t.date.toIso8601String(),
      'receipt_image_url': t.receiptImageUrl,
      'image_path': t.imagePath,
      'category_id': t.categoryId,
      'status': t.status,
      'cancel_reason': t.cancelReason,
      'cancelled_by': t.cancelledBy,
      'cancelled_at': t.cancelledAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', t.id);
  }

  Future<void> deleteTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> monthlyTrend(int months, {String? userId}) async {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = months - 1; i >= 0; i--) {
      final from = DateTime(now.year, now.month - i, 1);
      final to = DateTime(now.year, now.month - i + 1, 1);
      var query = _client.from('transactions').select('type, amount');
      if (userId != null) query = query.eq('user_id', userId);
      query = query.gte('date', from.toIso8601String()).lt('date', to.toIso8601String());
      final response = await query;
      int income = 0, expense = 0;
      for (final r in response as List) {
        if (r['type'] == 'income') income += (r['amount'] as num).toInt();
        if (r['type'] == 'expense') expense += (r['amount'] as num).toInt();
      }
      result.add({'month': from, 'income': income, 'expense': expense});
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> categoryBreakdown(
    TransactionType type, {
    DateTime? from,
    DateTime? to,
    String? userId,
  }) async {
    final now = DateTime.now();
    final f = from ?? DateTime(now.year, now.month, 1);
    final t = to ?? DateTime(now.year, now.month + 1, 1);
    var query = _client.from('transactions').select('category, amount');
    if (userId != null) query = query.eq('user_id', userId);
    query = query.eq('type', type.name)
        .gte('date', f.toIso8601String())
        .lt('date', t.toIso8601String());
    final response = await query;

    final Map<String, int> grouped = {};
    for (final r in response as List) {
      final cat = r['category'] as String;
      grouped[cat] = (grouped[cat] ?? 0) + (r['amount'] as num).toInt();
    }
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => {'category': e.key, 'total': e.value}).toList();
  }

  Future<Map<String, int>> summaryForPeriod(DateTime from, DateTime to, {String? userId}) async {
    var query = _client.from('transactions').select('type, amount');
    if (userId != null) query = query.eq('user_id', userId);
    query = query.gte('date', from.toIso8601String()).lt('date', to.toIso8601String());
    final response = await query;
    int income = 0, expense = 0;
    for (final r in response as List) {
      if (r['type'] == 'income') income += (r['amount'] as num).toInt();
      if (r['type'] == 'expense') expense += (r['amount'] as num).toInt();
    }
    return {'income': income, 'expense': expense};
  }

  // ── INVOICES ────────────────────────────────────────────────────

  Future<List<InvoiceModel>> queryInvoices({InvoiceStatus? status, String? userId}) async {
    var query = _client.from('invoices').select();
    if (userId != null) query = query.eq('user_id', userId);
    if (status != null) query = query.eq('status', status.name.toUpperCase());
    final response = await query.order('created_at', ascending: false);
    final invoices = <InvoiceModel>[];
    for (final m in response as List) {
      final items = await getInvoiceItems(m['id'] as String);
      invoices.add(_invoiceFromRow(m as Map<String, dynamic>, items: items));
    }
    return invoices;
  }

  Future<InvoiceModel?> getInvoice(String id) async {
    final response = await _client
        .from('invoices')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    final items = await getInvoiceItems(id);
    return _invoiceFromRow(response, items: items);
  }

  Future<void> insertInvoice(InvoiceModel inv, String userId) async {
    await _client.from('invoices').upsert({
      'id': inv.id,
      'user_id': userId,
      'created_by': userId,
      'partner_id': inv.partnerId,
      'invoice_number': inv.invoiceNumber,
      'invoice_type': inv.invoiceType,
      'subtotal': inv.subtotal,
      'vat_rate': inv.vatRate.name,
      'vat_amount': inv.vatAmount,
      'total_amount': inv.totalAmount,
      'invoice_date': inv.invoiceDate.toIso8601String(),
      'status': inv.status.name.toUpperCase(),
      'image_path': inv.imagePath,
      'pdf_url': inv.pdfUrl,
      'ocr_text': inv.ocrText,
      'note': inv.note,
    });
    await insertInvoiceItems(inv.id, inv.items);
  }

  Future<void> updateInvoice(InvoiceModel inv) async {
    await _client.from('invoices').update({
      'invoice_number': inv.invoiceNumber,
      'partner_id': inv.partnerId,
      'invoice_type': inv.invoiceType,
      'subtotal': inv.subtotal,
      'vat_rate': inv.vatRate.name,
      'vat_amount': inv.vatAmount,
      'total_amount': inv.totalAmount,
      'invoice_date': inv.invoiceDate.toIso8601String(),
      'status': inv.status.name.toUpperCase(),
      'image_path': inv.imagePath,
      'pdf_url': inv.pdfUrl,
      'ocr_text': inv.ocrText,
      'note': inv.note,
    }).eq('id', inv.id);
    await deleteInvoiceItems(inv.id);
    await insertInvoiceItems(inv.id, inv.items);
  }

  Future<void> deleteInvoice(String id) async {
    await deleteInvoiceItems(id);
    await _client.from('invoices').delete().eq('id', id);
  }

  Future<void> updateInvoiceStatus(String invoiceId, String status) async {
    await _client.from('invoices').update({'status': status}).eq('id', invoiceId);
  }

  Future<Map<String, int>> invoiceStats({String? userId}) async {
    var query = _client.from('invoices').select('status');
    if (userId != null) query = query.eq('user_id', userId);
    final response = await query;
    final Map<String, int> stats = {};
    for (final r in response as List) {
      final s = r['status'] as String;
      stats[s] = (stats[s] ?? 0) + 1;
    }
    return stats;
  }

  Future<Map<String, int>> getUserStats(String userId) async {
    final txResponse = await _client
        .from('transactions')
        .select('type, amount')
        .eq('user_id', userId);
    final invResponse = await _client
        .from('invoices')
        .select('id')
        .eq('user_id', userId);

    int income = 0, expense = 0;
    for (final r in txResponse as List) {
      if (r['type'] == 'income') income += (r['amount'] as num).toInt();
      if (r['type'] == 'expense') expense += (r['amount'] as num).toInt();
    }
    return {
      'income': income,
      'expense': expense,
      'invoices': (invResponse as List).length,
    };
  }

  // ── INVOICE ITEMS ──────────────────────────────────────────────

  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) async {
    final response = await _client
        .from('invoice_items')
        .select()
        .eq('invoice_id', invoiceId);
    return (response as List).map((m) => InvoiceItem(
      name: m['item_name'] as String? ?? m['name'] as String? ?? '',
      quantity: (m['quantity'] as num).toInt(),
      unitPrice: (m['unit_price'] as num).toInt(),
      unit: m['unit'] as String?,
    )).toList();
  }

  Future<void> insertInvoiceItems(String invoiceId, List<InvoiceItem> items) async {
    if (items.isEmpty) return;
    final rows = items.map((item) => {
      'id': const Uuid().v4(),
      'invoice_id': invoiceId,
      'item_name': item.name,
      'quantity': item.quantity,
      'unit': item.unit ?? 'cái',
      'unit_price': item.unitPrice,
      'line_total': item.lineTotal,
    }).toList();
    await _client.from('invoice_items').upsert(rows);
  }

  Future<void> deleteInvoiceItems(String invoiceId) async {
    await _client.from('invoice_items').delete().eq('invoice_id', invoiceId);
  }

  // ── CATEGORIES ─────────────────────────────────────────────────

  Future<List<CategoryModel>> getAllCategories() async {
    final response = await _client.from('categories').select().order('type', ascending: true);
    return (response as List).map((m) => CategoryModel.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<void> insertCategory(CategoryModel cat) async {
    await _client.from('categories').upsert(cat.toMap());
  }

  Future<void> updateCategory(CategoryModel cat) async {
    await _client.from('categories').update({
      'category_name': cat.categoryName,
      'type': cat.type,
      'icon': cat.icon,
      'color': cat.color,
    }).eq('category_id', cat.categoryId);
  }

  Future<void> deleteCategory(String categoryId) async {
    await _client.from('categories').delete().eq('category_id', categoryId);
  }

  // ── PARTNERS ───────────────────────────────────────────────────

  Future<List<PartnerModel>> getAllPartners() async {
    final response = await _client.from('partners').select().order('partner_name', ascending: true);
    return (response as List).map((m) => PartnerModel.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<PartnerModel?> getPartnerByTaxCode(String taxCode) async {
    final response = await _client.from('partners').select().eq('tax_code', taxCode).maybeSingle();
    if (response == null) return null;
    return PartnerModel.fromMap(response);
  }

  Future<void> insertPartner(PartnerModel partner) async {
    await _client.from('partners').upsert(partner.toMap());
  }

  Future<void> updatePartner(PartnerModel partner) async {
    await _client.from('partners').update({
      'partner_name': partner.partnerName,
      'partner_type': partner.partnerType,
      'tax_code': partner.taxCode,
      'phone': partner.phone,
      'email': partner.email,
      'address': partner.address,
      'status': partner.status,
    }).eq('partner_id', partner.partnerId);
  }

  Future<void> deletePartner(String partnerId) async {
    await _client.from('partners').delete().eq('partner_id', partnerId);
  }

  // ── INVOICE APPROVALS ──────────────────────────────────────────

  Future<void> insertInvoiceApproval({
    required String invoiceId,
    required String approvedBy,
    required String action,
    String? comment,
  }) async {
    await _client.from('invoice_approvals').insert({
      'approval_id': const Uuid().v4(),
      'invoice_id': invoiceId,
      'approved_by': approvedBy,
      'action': action,
      'comment': comment,
    });
  }

  Future<List<Map<String, dynamic>>> getInvoiceApprovals(String invoiceId) async {
    final response = await _client
        .from('invoice_approvals')
        .select()
        .eq('invoice_id', invoiceId)
        .order('approved_at', ascending: false);
    return (response as List).map((m) => Map<String, dynamic>.from(m)).toList();
  }

  // ── NOTIFICATIONS ──────────────────────────────────────────────

  Future<void> insertNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? referenceId,
  }) async {
    await _client.from('notifications').insert({
      'notification_id': const Uuid().v4(),
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'reference_id': referenceId,
    });
  }

  Future<List<NotificationModel>> getNotifications(String userId, {bool? unreadOnly}) async {
    var query = _client.from('notifications').select().eq('user_id', userId);
    if (unreadOnly == true) query = query.eq('is_read', false);
    final response = await query.order('created_at', ascending: false);
    return (response as List).map((m) => NotificationModel.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    final response = await _client
        .from('notifications')
        .select('notification_id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (response as List).length;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _client.from('notifications').update({'is_read': true}).eq('notification_id', notificationId);
  }

  Future<void> markAllNotificationsRead(String userId) async {
    await _client.from('notifications').update({'is_read': true}).eq('user_id', userId).eq('is_read', false);
  }

  // ── ACTIVITY LOGS ──────────────────────────────────────────────

  Future<void> insertActivityLog({
    required String userId,
    required String module,
    required String actionType,
    String? referenceId,
    String? description,
    String? entityType,
    String? entityId,
  }) async {
    await _client.from('activity_logs').insert({
      'log_id': const Uuid().v4(),
      'user_id': userId,
      'module': module,
      'action_type': actionType,
      'reference_id': referenceId,
      'description': description,
      'entity_type': entityType,
      'entity_id': entityId,
    });
  }

  Future<List<Map<String, dynamic>>> getActivityLogs({
    String? userId,
    String? module,
    String? actionType,
  }) async {
    var query = _client.from('activity_logs').select();
    if (userId != null) query = query.eq('user_id', userId);
    if (module != null) query = query.eq('module', module);
    if (actionType != null) query = query.eq('action_type', actionType);
    final response = await query.order('created_at', ascending: false);
    return (response as List).map((m) => Map<String, dynamic>.from(m)).toList();
  }

  // ── AUDIT LOGS (legacy compat) ─────────────────────────────────

  Future<void> insertAuditLog({
    required String userId,
    required String action,
    required String entityType,
    required String entityId,
    String? oldValue,
    String? newValue,
  }) async {
    await insertActivityLog(
      userId: userId,
      module: entityType.toUpperCase(),
      actionType: action.toUpperCase(),
      referenceId: entityId,
      description: newValue,
      entityType: entityType,
      entityId: entityId,
    );
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({String? userId, String? entityType}) async {
    return getActivityLogs(userId: userId, module: entityType?.toUpperCase());
  }

  // ── HELPERS ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> queryAllTransactionsRaw() async {
    final response = await _client.from('transactions').select().order('date', ascending: false);
    return (response as List).map((m) => Map<String, dynamic>.from(m)).toList();
  }

  Future<List<Map<String, dynamic>>> queryAllInvoicesRaw() async {
    final response = await _client.from('invoices').select().order('created_at', ascending: false);
    final result = <Map<String, dynamic>>[];
    for (final m in response as List) {
      final row = Map<String, dynamic>.from(m);
      final items = await getInvoiceItems(row['id'] as String);
      row['items'] = items;
      result.add(row);
    }
    return result;
  }

  InvoiceModel _invoiceFromRow(Map<String, dynamic> m, {List<InvoiceItem>? items}) {
    return InvoiceModel(
      id: m['id'],
      invoiceNumber: m['invoice_number'],
      partnerId: m['partner_id'],
      createdBy: m['created_by'],
      invoiceType: (m['invoice_type'] as String?) ?? 'IN',
      subtotal: (m['subtotal'] as num).toInt(),
      vatRate: VatRate.values.firstWhere(
        (e) => e.name == (m['vat_rate'] ?? 'none'),
        orElse: () => VatRate.none,
      ),
      vatAmount: (m['vat_amount'] as num?)?.toInt() ?? 0,
      totalAmount: (m['total_amount'] as num?)?.toInt() ?? 0,
      invoiceDate: DateTime.parse(m['invoice_date']),
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name == (m['status'] as String?)?.toLowerCase(),
        orElse: () => InvoiceStatus.draft,
      ),
      items: items ?? [],
      imagePath: m['image_path'],
      pdfUrl: m['pdf_url'],
      ocrText: m['ocr_text'],
      note: m['note'],
      createdAt: DateTime.parse(m['created_at']),
    );
  }
}
