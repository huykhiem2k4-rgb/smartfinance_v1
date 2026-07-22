import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/invoice_model.dart';
import '../models/user_model.dart';

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
        'role': 'user',
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

    final metadata = authUser.userMetadata ?? {};
    final username = metadata['username'] as String? ?? authUser.email?.split('@').first ?? '';
    final roleStr = metadata['role'] as String? ?? 'user';
    final fullName = metadata['full_name'] as String?;

    return UserModel(
      id: authUser.id,
      username: username,
      passwordHash: '',
      role: roleStr == 'admin' ? UserRole.admin : UserRole.user,
      fullName: fullName,
      createdAt: DateTime.parse(authUser.createdAt),
    );
  }

  // ── USERS ──────────────────────────────────────────────────────

  Future<UserModel?> getUserByUsername(String username) async {
    final response = await _client
        .from('users')
        .select()
        .eq('username', username)
        .maybeSingle();
    if (response == null) return null;
    return UserModel(
      id: response['id'],
      username: response['username'],
      passwordHash: '',
      role: response['role'] == 'admin' ? UserRole.admin : UserRole.user,
      fullName: response['full_name'],
      createdAt: DateTime.parse(response['created_at']),
    );
  }

  Future<UserModel?> getUserById(String id) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return UserModel(
      id: response['id'],
      username: response['username'],
      passwordHash: '',
      role: response['role'] == 'admin' ? UserRole.admin : UserRole.user,
      fullName: response['full_name'],
      createdAt: DateTime.parse(response['created_at']),
    );
  }

  Future<List<UserModel>> getAllUsers() async {
    final response = await _client
        .from('users')
        .select()
        .order('created_at', ascending: true);
    return (response as List).map((m) => UserModel(
      id: m['id'],
      username: m['username'],
      passwordHash: '',
      role: m['role'] == 'admin' ? UserRole.admin : UserRole.user,
      fullName: m['full_name'],
      createdAt: DateTime.parse(m['created_at']),
    )).toList();
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
      imagePath: m['image_path'],
    )).toList();
  }

  Future<void> insertTransaction(TransactionModel t, String userId) async {
    await _client.from('transactions').upsert({
      'id': t.id,
      'user_id': userId,
      'title': t.title,
      'amount': t.amount,
      'type': t.type.name,
      'category': t.category.name,
      'description': t.description,
      'date': t.date.toIso8601String(),
      'image_path': t.imagePath,
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
      'image_path': t.imagePath,
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
    if (status != null) query = query.eq('status', status.name);
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
      'invoice_number': inv.invoiceNumber,
      'vendor': inv.vendor,
      'vendor_tax_code': inv.vendorTaxCode,
      'subtotal': inv.subtotal,
      'vat_rate': inv.vatRate.name,
      'invoice_date': inv.invoiceDate.toIso8601String(),
      'due_date': inv.dueDate?.toIso8601String(),
      'status': inv.status.name,
      'ai_confidence': inv.aiConfidence,
      'ai_notes': inv.aiNotes,
      'image_path': inv.imagePath,
    });
    await insertInvoiceItems(inv.id, inv.items);
  }

  Future<void> updateInvoice(InvoiceModel inv) async {
    await _client.from('invoices').update({
      'invoice_number': inv.invoiceNumber,
      'vendor': inv.vendor,
      'vendor_tax_code': inv.vendorTaxCode,
      'subtotal': inv.subtotal,
      'vat_rate': inv.vatRate.name,
      'invoice_date': inv.invoiceDate.toIso8601String(),
      'due_date': inv.dueDate?.toIso8601String(),
      'status': inv.status.name,
      'ai_confidence': inv.aiConfidence,
      'ai_notes': inv.aiNotes,
      'image_path': inv.imagePath,
    }).eq('id', inv.id);
    await deleteInvoiceItems(inv.id);
    await insertInvoiceItems(inv.id, inv.items);
  }

  Future<void> deleteInvoice(String id) async {
    await deleteInvoiceItems(id);
    await _client.from('invoices').delete().eq('id', id);
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
      name: m['name'] as String,
      quantity: (m['quantity'] as num).toInt(),
      unitPrice: (m['unit_price'] as num).toInt(),
    )).toList();
  }

  Future<void> insertInvoiceItems(String invoiceId, List<InvoiceItem> items) async {
    if (items.isEmpty) return;
    final rows = items.map((item) => {
      'id': const Uuid().v4(),
      'invoice_id': invoiceId,
      'name': item.name,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'amount': item.total,
    }).toList();
    await _client.from('invoice_items').upsert(rows);
  }

  Future<void> deleteInvoiceItems(String invoiceId) async {
    await _client.from('invoice_items').delete().eq('invoice_id', invoiceId);
  }

  // ── AUDIT LOGS ─────────────────────────────────────────────────

  Future<void> insertAuditLog({
    required String userId,
    required String action,
    required String entityType,
    required String entityId,
    String? oldValue,
    String? newValue,
  }) async {
    await _client.from('audit_logs').insert({
      'id': const Uuid().v4(),
      'user_id': userId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'old_value': oldValue,
      'new_value': newValue,
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({String? userId, String? entityType}) async {
    var query = _client.from('audit_logs').select();
    if (userId != null) query = query.eq('user_id', userId);
    if (entityType != null) query = query.eq('entity_type', entityType);
    final response = await query.order('created_at', ascending: false);
    return (response as List).map((m) => m as Map<String, dynamic>).toList();
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
      vendor: m['vendor'],
      vendorTaxCode: m['vendor_tax_code'],
      subtotal: (m['subtotal'] as num).toInt(),
      vatRate: VatRate.values.firstWhere(
        (e) => e.name == (m['vat_rate'] ?? 'vat10'),
        orElse: () => VatRate.vat10,
      ),
      invoiceDate: DateTime.parse(m['invoice_date']),
      dueDate: m['due_date'] != null ? DateTime.parse(m['due_date']) : null,
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name == m['status'],
        orElse: () => InvoiceStatus.pending,
      ),
      aiConfidence: m['ai_confidence'] != null ? (m['ai_confidence'] as num).toDouble() : null,
      aiNotes: m['ai_notes'],
      items: items ?? [],
      imagePath: m['image_path'],
      createdAt: DateTime.parse(m['created_at']),
    );
  }
}
