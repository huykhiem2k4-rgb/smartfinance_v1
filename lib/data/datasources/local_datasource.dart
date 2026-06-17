import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/invoice_model.dart';
import '../models/user_model.dart';

class LocalDatasource {
  static final LocalDatasource _instance = LocalDatasource._internal();
  factory LocalDatasource() => _instance;
  LocalDatasource._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'smartfinance_v4.db'),
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        full_name TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        image_path TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        invoice_number TEXT NOT NULL,
        vendor TEXT NOT NULL,
        vendor_tax_code TEXT,
        subtotal INTEGER NOT NULL,
        vat_rate TEXT NOT NULL,
        invoice_date TEXT NOT NULL,
        due_date TEXT,
        status TEXT NOT NULL,
        ai_confidence REAL,
        ai_notes TEXT,
        items_json TEXT,
        image_path TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    await _seed(db);
  }

  Future<void> _seed(Database db) async {
    // Seed users
    final adminHash = UserModel.hashPassword('admin123');
    final userHash = UserModel.hashPassword('user123');

    await db.insert('users', {
      'id': 'u_admin',
      'username': 'admin',
      'password_hash': adminHash,
      'role': 'admin',
      'full_name': 'Quản trị viên',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('users', {
      'id': 'u_user1',
      'username': 'user1',
      'password_hash': userHash,
      'role': 'user',
      'full_name': 'Nguyễn Văn A',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('users', {
      'id': 'u_user2',
      'username': 'user2',
      'password_hash': userHash,
      'role': 'user',
      'full_name': 'Trần Thị B',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Seed transactions
    final now = DateTime.now();
    final m = now.month;
    final y = now.year;

    final transactions = [
      {'id': 't01', 'user_id': 'u_admin', 'title': 'Doanh thu bán hàng T$m', 'amount': 85000000, 'type': 'income', 'category': 'sales', 'description': 'Doanh thu tháng $m/$y', 'date': DateTime(y, m, 5).toIso8601String(), 'image_path': null},
      {'id': 't02', 'user_id': 'u_admin', 'title': 'Lương nhân viên T$m', 'amount': 32000000, 'type': 'expense', 'category': 'salary', 'description': 'Lương tháng $m/$y', 'date': DateTime(y, m, 1).toIso8601String(), 'image_path': null},
      {'id': 't03', 'user_id': 'u_admin', 'title': 'Thuê văn phòng T$m', 'amount': 12000000, 'type': 'expense', 'category': 'rent', 'description': 'Văn phòng Q1', 'date': DateTime(y, m, 2).toIso8601String(), 'image_path': null},
      {'id': 't04', 'user_id': 'u_user1', 'title': 'Doanh thu dịch vụ tư vấn', 'amount': 25000000, 'type': 'income', 'category': 'serviceRevenue', 'description': 'Hợp đồng ABC Corp', 'date': DateTime(y, m, 8).toIso8601String(), 'image_path': null},
      {'id': 't05', 'user_id': 'u_user1', 'title': 'Chi phí Marketing', 'amount': 8500000, 'type': 'expense', 'category': 'marketing', 'description': 'Facebook & Google Ads', 'date': DateTime(y, m, 10).toIso8601String(), 'image_path': null},
      {'id': 't06', 'user_id': 'u_user1', 'title': 'Điện nước văn phòng', 'amount': 2800000, 'type': 'expense', 'category': 'utilities', 'description': 'Hóa đơn điện nước', 'date': DateTime(y, m, 7).toIso8601String(), 'image_path': null},
      {'id': 't07', 'user_id': 'u_admin', 'title': 'Doanh thu bán hàng T${m - 1}', 'amount': 72000000, 'type': 'income', 'category': 'sales', 'description': 'Doanh thu tháng ${m - 1}/$y', 'date': DateTime(y, m - 1, 28).toIso8601String(), 'image_path': null},
      {'id': 't08', 'user_id': 'u_admin', 'title': 'Lương nhân viên T${m - 1}', 'amount': 31000000, 'type': 'expense', 'category': 'salary', 'description': 'Lương tháng ${m - 1}/$y', 'date': DateTime(y, m - 1, 5).toIso8601String(), 'image_path': null},
      {'id': 't09', 'user_id': 'u_user2', 'title': 'Doanh thu dịch vụ T${m - 1}', 'amount': 18000000, 'type': 'income', 'category': 'serviceRevenue', 'description': 'Dịch vụ tháng ${m - 1}', 'date': DateTime(y, m - 1, 15).toIso8601String(), 'image_path': null},
      {'id': 't10', 'user_id': 'u_user2', 'title': 'Mua văn phòng phẩm', 'amount': 1500000, 'type': 'expense', 'category': 'supplies', 'description': 'Văn phòng phẩm', 'date': DateTime(y, m, 3).toIso8601String(), 'image_path': null},
      {'id': 't11', 'user_id': 'u_admin', 'title': 'Thu từ đầu tư', 'amount': 15000000, 'type': 'income', 'category': 'investment', 'description': 'Lãi tiền gửi ngân hàng', 'date': DateTime(y, m - 2, 20).toIso8601String(), 'image_path': null},
      {'id': 't12', 'user_id': 'u_user1', 'title': 'Nộp thuế VAT', 'amount': 5500000, 'type': 'expense', 'category': 'tax', 'description': 'Thuế GTGT quý 2', 'date': DateTime(y, m - 1, 25).toIso8601String(), 'image_path': null},
    ];
    for (final t in transactions) {
      await db.insert('transactions', t);
    }

    // Seed invoices
    final invoices = [
      {
        'id': 'inv01', 'user_id': 'u_admin',
        'invoice_number': 'HD-2026-001', 'vendor': 'Công ty TNHH Thiết bị VP',
        'vendor_tax_code': '0123456789', 'subtotal': 13636364, 'vat_rate': 'vat10',
        'invoice_date': DateTime(y, m, 5).toIso8601String(),
        'due_date': DateTime(y, m, 20).toIso8601String(),
        'status': 'approved', 'ai_confidence': 0.94,
        'ai_notes': '✅ Hóa đơn hợp lệ (94%)',
        'items_json': 'Máy in HP LaserJet|||2|||5000000~~~Mực in HP|||4|||909091',
        'image_path': null, 'created_at': DateTime(y, m, 5).toIso8601String(),
      },
      {
        'id': 'inv02', 'user_id': 'u_user1',
        'invoice_number': 'HD-2026-002', 'vendor': 'Cty CP Dịch vụ Cloud XYZ',
        'vendor_tax_code': '0987654321', 'subtotal': 2963000, 'vat_rate': 'vat8',
        'invoice_date': DateTime(y, m, 8).toIso8601String(),
        'due_date': DateTime(y, m, 25).toIso8601String(),
        'status': 'pending', 'ai_confidence': null, 'ai_notes': null,
        'items_json': 'Dịch vụ Cloud Server tháng 6|||1|||2963000',
        'image_path': null, 'created_at': DateTime(y, m, 8).toIso8601String(),
      },
      {
        'id': 'inv03', 'user_id': 'u_user2',
        'invoice_number': 'HDxx-999', 'vendor': 'Nhà cung cấp Không rõ',
        'vendor_tax_code': null, 'subtotal': 41000000, 'vat_rate': 'vat10',
        'invoice_date': DateTime(y, m - 1, 30).toIso8601String(),
        'due_date': DateTime(y, m, 15).toIso8601String(),
        'status': 'rejected', 'ai_confidence': 0.23,
        'ai_notes': '❌ Hóa đơn đáng ngờ (23%)',
        'items_json': 'Hàng hóa không xác định|||1|||41000000',
        'image_path': null, 'created_at': DateTime(y, m - 1, 30).toIso8601String(),
      },
    ];
    for (final inv in invoices) {
      await db.insert('invoices', inv);
    }
  }

  // ── USERS ──────────────────────────────────────────────────────

  Future<UserModel?> getUserByUsername(String username) async {
    final d = await db;
    final rows = await d.query('users', where: 'username = ?', whereArgs: [username]);
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  Future<UserModel?> getUserById(String id) async {
    final d = await db;
    final rows = await d.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  Future<List<UserModel>> getAllUsers() async {
    final d = await db;
    final rows = await d.query('users', orderBy: 'created_at ASC');
    return rows.map(UserModel.fromMap).toList();
  }

  Future<void> insertUser(UserModel user) async {
    final d = await db;
    await d.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> updateUser(UserModel user) async {
    final d = await db;
    await d.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> deleteUser(String id) async {
    final d = await db;
    await d.delete('transactions', where: 'user_id = ?', whereArgs: [id]);
    await d.delete('invoices', where: 'user_id = ?', whereArgs: [id]);
    await d.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> getUserStats(String userId) async {
    final d = await db;
    final txRows = await d.rawQuery(
      'SELECT type, COUNT(*) as cnt, SUM(amount) as total FROM transactions WHERE user_id = ? GROUP BY type',
      [userId],
    );
    final invRow = await d.rawQuery(
      'SELECT COUNT(*) as cnt FROM invoices WHERE user_id = ?',
      [userId],
    );
    int income = 0, expense = 0;
    for (final r in txRows) {
      if (r['type'] == 'income') income = (r['total'] as num?)?.toInt() ?? 0;
      if (r['type'] == 'expense') expense = (r['total'] as num?)?.toInt() ?? 0;
    }
    return {
      'income': income,
      'expense': expense,
      'invoices': (invRow.first['cnt'] as int?) ?? 0,
    };
  }

  // ── TRANSACTIONS ───────────────────────────────────────────────

  Future<List<TransactionModel>> queryTransactions({
    DateTime? from,
    DateTime? to,
    TransactionType? type,
    String? userId,
  }) async {
    final d = await db;
    String where = '1=1';
    final args = <dynamic>[];
    if (userId != null) { where += ' AND user_id = ?'; args.add(userId); }
    if (from != null) { where += ' AND date >= ?'; args.add(from.toIso8601String()); }
    if (to != null)   { where += ' AND date <= ?'; args.add(to.toIso8601String()); }
    if (type != null) { where += ' AND type = ?'; args.add(type.name); }
    final rows = await d.query('transactions', where: where, whereArgs: args, orderBy: 'date DESC');
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<void> insertTransaction(TransactionModel t, String userId) async {
    final d = await db;
    final map = t.toMap()..['user_id'] = userId;
    await d.insert('transactions', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTransaction(String id) async {
    final d = await db;
    await d.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> monthlyTrend(int months, {String? userId}) async {
    final d = await db;
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = months - 1; i >= 0; i--) {
      final from = DateTime(now.year, now.month - i, 1);
      final to = DateTime(now.year, now.month - i + 1, 1);
      final userFilter = userId != null ? 'AND user_id = ?' : '';
      final args = userId != null
          ? [from.toIso8601String(), to.toIso8601String(), userId]
          : [from.toIso8601String(), to.toIso8601String()];
      final rows = await d.rawQuery(
        'SELECT type, SUM(amount) as total FROM transactions WHERE date >= ? AND date < ? $userFilter GROUP BY type',
        args,
      );
      int income = 0, expense = 0;
      for (final r in rows) {
        if (r['type'] == 'income') income = (r['total'] as num).toInt();
        if (r['type'] == 'expense') expense = (r['total'] as num).toInt();
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
    final d = await db;
    final now = DateTime.now();
    final f = from ?? DateTime(now.year, now.month, 1);
    final t = to ?? DateTime(now.year, now.month + 1, 1);
    final userFilter = userId != null ? 'AND user_id = ?' : '';
    final args = userId != null
        ? [type.name, f.toIso8601String(), t.toIso8601String(), userId]
        : [type.name, f.toIso8601String(), t.toIso8601String()];
    final rows = await d.rawQuery(
      'SELECT category, SUM(amount) as total FROM transactions WHERE type = ? AND date >= ? AND date < ? $userFilter GROUP BY category ORDER BY total DESC',
      args,
    );
    return rows.map((r) => {'category': r['category'], 'total': (r['total'] as num).toInt()}).toList();
  }

  Future<Map<String, int>> summaryForPeriod(DateTime from, DateTime to, {String? userId}) async {
    final d = await db;
    final userFilter = userId != null ? 'AND user_id = ?' : '';
    final args = userId != null
        ? [from.toIso8601String(), to.toIso8601String(), userId]
        : [from.toIso8601String(), to.toIso8601String()];
    final rows = await d.rawQuery(
      'SELECT type, SUM(amount) as total FROM transactions WHERE date >= ? AND date < ? $userFilter GROUP BY type',
      args,
    );
    int income = 0, expense = 0;
    for (final r in rows) {
      if (r['type'] == 'income') income = (r['total'] as num).toInt();
      if (r['type'] == 'expense') expense = (r['total'] as num).toInt();
    }
    return {'income': income, 'expense': expense};
  }

  // ── INVOICES ────────────────────────────────────────────────────

  Future<List<InvoiceModel>> queryInvoices({InvoiceStatus? status, String? userId}) async {
    final d = await db;
    String where = '1=1';
    final args = <dynamic>[];
    if (userId != null) { where += ' AND user_id = ?'; args.add(userId); }
    if (status != null) { where += ' AND status = ?'; args.add(status.name); }
    final rows = await d.query('invoices', where: where, whereArgs: args, orderBy: 'created_at DESC');
    return rows.map(InvoiceModel.fromMap).toList();
  }

  Future<InvoiceModel?> getInvoice(String id) async {
    final d = await db;
    final rows = await d.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return InvoiceModel.fromMap(rows.first);
  }

  Future<void> insertInvoice(InvoiceModel inv, String userId) async {
    final d = await db;
    final map = inv.toMap()..['user_id'] = userId;
    await d.insert('invoices', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateInvoice(InvoiceModel inv) async {
    final d = await db;
    await d.update('invoices', inv.toMap(), where: 'id = ?', whereArgs: [inv.id]);
  }

  Future<void> deleteInvoice(String id) async {
    final d = await db;
    await d.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> invoiceStats({String? userId}) async {
    final d = await db;
    final userFilter = userId != null ? 'WHERE user_id = ?' : '';
    final args = userId != null ? [userId] : [];
    final rows = await d.rawQuery(
      'SELECT status, COUNT(*) as cnt FROM invoices $userFilter GROUP BY status',
      args,
    );
    return {for (final r in rows) r['status'].toString(): (r['cnt'] as int)};
  }
}
