import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../models/transaction_model.dart';
import '../models/invoice_model.dart';
import '../models/user_model.dart';

class LocalDatasource {
  static final LocalDatasource _instance = LocalDatasource._internal();
  factory LocalDatasource() => _instance;
  LocalDatasource._internal() {
    _initFfi();
  }

  void _initFfi() {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      // Mobile: use default sqflite (no FFI override)
      return;
    } else {
      // Desktop: Linux, macOS, Windows
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    const dbName = 'smartfinance_v5.db';
    final database = await openDatabase(
      kIsWeb ? dbName : join(await getDatabasesPath(), dbName),
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await database.execute('PRAGMA foreign_keys = ON');
    return database;
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
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
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
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE audit_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        old_value TEXT,
        new_value TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await _seed(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS invoice_items (
          id TEXT PRIMARY KEY,
          invoice_id TEXT NOT NULL,
          name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price INTEGER NOT NULL,
          amount INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_logs (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          action TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          old_value TEXT,
          new_value TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
      final invoices = await db.query('invoices');
      for (final inv in invoices) {
        final itemsJson = inv['items_json'] as String? ?? '';
        if (itemsJson.isNotEmpty) {
          final items = itemsJson.split('~~~');
          for (final item in items) {
            final parts = item.split('|||');
            if (parts.length == 3) {
              await db.insert('invoice_items', {
                'id': const Uuid().v4(),
                'invoice_id': inv['id'],
                'name': parts[0],
                'quantity': int.tryParse(parts[1]) ?? 1,
                'unit_price': int.tryParse(parts[2]) ?? 0,
                'amount': (int.tryParse(parts[1]) ?? 1) * (int.tryParse(parts[2]) ?? 0),
                'created_at': DateTime.now().toIso8601String(),
              });
            }
          }
        }
      }
    }
  }

  Future<void> _seed(Database db) async {
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

    final invoices = [
      {
        'id': 'inv01', 'user_id': 'u_admin',
        'invoice_number': 'HD-2026-001', 'vendor': 'Công ty TNHH Thiết bị VP',
        'vendor_tax_code': '0123456789', 'subtotal': 13636364, 'vat_rate': 'vat10',
        'invoice_date': DateTime(y, m, 5).toIso8601String(),
        'due_date': DateTime(y, m, 20).toIso8601String(),
        'status': 'approved', 'ai_confidence': 0.94,
        'ai_notes': 'Hóa đơn hợp lệ (94%)',
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
        'ai_notes': 'Hóa đơn đáng ngờ (23%)',
        'items_json': 'Hàng hóa không xác định|||1|||41000000',
        'image_path': null, 'created_at': DateTime(y, m - 1, 30).toIso8601String(),
      },
    ];
    for (final inv in invoices) {
      await db.insert('invoices', inv);
    }

    final seedItems = [
      {'invoice_id': 'inv01', 'name': 'Máy in HP LaserJet', 'quantity': 2, 'unit_price': 5000000},
      {'invoice_id': 'inv01', 'name': 'Mực in HP', 'quantity': 4, 'unit_price': 909091},
      {'invoice_id': 'inv02', 'name': 'Dịch vụ Cloud Server tháng 6', 'quantity': 1, 'unit_price': 2963000},
      {'invoice_id': 'inv03', 'name': 'Hàng hóa không xác định', 'quantity': 1, 'unit_price': 41000000},
    ];
    for (final item in seedItems) {
      await db.insert('invoice_items', {
        'id': const Uuid().v4(),
        'invoice_id': item['invoice_id'],
        'name': item['name'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'amount': (item['quantity'] as int) * (item['unit_price'] as int),
        'created_at': DateTime.now().toIso8601String(),
      });
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
    await d.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> updateUser(UserModel user) async {
    final d = await db;
    await d.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> deleteUser(String id) async {
    final d = await db;
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

  Future<TransactionModel?> getTransactionById(String id) async {
    final d = await db;
    final rows = await d.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return TransactionModel.fromMap(rows.first);
  }

  Future<void> insertTransaction(TransactionModel t, String userId) async {
    final d = await db;
    final map = t.toMap()..['user_id'] = userId;
    await d.insert('transactions', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTransaction(TransactionModel t) async {
    final d = await db;
    await d.update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
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
    final invoices = <InvoiceModel>[];
    for (final row in rows) {
      final items = await getInvoiceItems(row['id'] as String);
      invoices.add(InvoiceModel.fromMap(row, items: items));
    }
    return invoices;
  }

  Future<List<Map<String, dynamic>>> getInvoicesRaw() async {
    final d = await db;
    return d.query('invoices', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getTransactionsRaw() async {
    final d = await db;
    return d.query('transactions', orderBy: 'date DESC');
  }

  Future<InvoiceModel?> getInvoice(String id) async {
    final d = await db;
    final rows = await d.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final items = await getInvoiceItems(id);
    return InvoiceModel.fromMap(rows.first, items: items);
  }

  Future<void> insertInvoice(InvoiceModel inv, String userId) async {
    final d = await db;
    final map = inv.toMap()..['user_id'] = userId;
    map.remove('items_json');
    await d.insert('invoices', map, conflictAlgorithm: ConflictAlgorithm.replace);
    for (final item in inv.items) {
      await d.insert('invoice_items', {
        'id': const Uuid().v4(),
        'invoice_id': inv.id,
        'name': item.name,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'amount': item.total,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> updateInvoice(InvoiceModel inv) async {
    final d = await db;
    final map = inv.toMap();
    map.remove('items_json');
    await d.update('invoices', map, where: 'id = ?', whereArgs: [inv.id]);
    await d.delete('invoice_items', where: 'invoice_id = ?', whereArgs: [inv.id]);
    for (final item in inv.items) {
      await d.insert('invoice_items', {
        'id': const Uuid().v4(),
        'invoice_id': inv.id,
        'name': item.name,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'amount': item.total,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
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

  // ── INVOICE ITEMS ──────────────────────────────────────────────

  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) async {
    final d = await db;
    final rows = await d.query('invoice_items', where: 'invoice_id = ?', whereArgs: [invoiceId]);
    return rows.map((r) => InvoiceItem(
      name: r['name'] as String,
      quantity: (r['quantity'] as num).toInt(),
      unitPrice: (r['unit_price'] as num).toInt(),
    )).toList();
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
    final d = await db;
    await d.insert('audit_logs', {
      'id': const Uuid().v4(),
      'user_id': userId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'old_value': oldValue,
      'new_value': newValue,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({String? userId, String? entityType}) async {
    final d = await db;
    String where = '1=1';
    final args = <dynamic>[];
    if (userId != null) { where += ' AND user_id = ?'; args.add(userId); }
    if (entityType != null) { where += ' AND entity_type = ?'; args.add(entityType); }
    return d.query('audit_logs', where: where, whereArgs: args, orderBy: 'created_at DESC');
  }
}
