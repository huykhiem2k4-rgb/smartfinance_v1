import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../models/transaction_model.dart';
import '../models/invoice_model.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../models/partner_model.dart';
import '../models/notification_model.dart';

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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    if (!kIsWeb) {
      await database.execute('PRAGMA foreign_keys = ON');
    }
    return database;
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── 1. users ──
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        full_name TEXT,
        email TEXT UNIQUE,
        phone TEXT,
        avatar_url TEXT,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    // ── 2. categories ──
    await db.execute('''
      CREATE TABLE categories (
        category_id TEXT PRIMARY KEY,
        category_name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    // ── 3. partners ──
    await db.execute('''
      CREATE TABLE partners (
        partner_id TEXT PRIMARY KEY,
        partner_name TEXT NOT NULL,
        partner_type TEXT NOT NULL,
        tax_code TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        created_at TEXT NOT NULL
      )
    ''');
    // ── 4. transactions ──
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        created_by TEXT,
        category_id TEXT,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        receipt_image_url TEXT,
        image_path TEXT,
        status TEXT NOT NULL DEFAULT 'POSTED',
        cancel_reason TEXT,
        cancelled_by TEXT,
        cancelled_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
        FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE SET NULL
      )
    ''');
    // ── 5. invoices ──
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        partner_id TEXT,
        created_by TEXT,
        invoice_number TEXT NOT NULL,
        invoice_type TEXT NOT NULL DEFAULT 'IN',
        subtotal INTEGER NOT NULL,
        vat_rate TEXT NOT NULL,
        vat_amount INTEGER NOT NULL DEFAULT 0,
        total_amount INTEGER NOT NULL DEFAULT 0,
        invoice_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'DRAFT',
        image_path TEXT,
        pdf_url TEXT,
        ocr_text TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (partner_id) REFERENCES partners(partner_id) ON DELETE SET NULL,
        FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');
    // ── 6. invoice_items ──
    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        item_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit TEXT,
        unit_price INTEGER NOT NULL,
        line_total INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');
    // ── 7. invoice_approvals ──
    await db.execute('''
      CREATE TABLE invoice_approvals (
        approval_id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        approved_by TEXT NOT NULL,
        action TEXT NOT NULL,
        comment TEXT,
        approved_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
        FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    // ── 8. notifications ──
    await db.execute('''
      CREATE TABLE notifications (
        notification_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        reference_id TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    // ── 9. activity_logs ──
    await db.execute('''
      CREATE TABLE activity_logs (
        log_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        module TEXT NOT NULL,
        action_type TEXT NOT NULL,
        reference_id TEXT,
        description TEXT,
        entity_type TEXT,
        entity_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await _seed(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: create invoice_items + audit_logs, migrate items_json
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

    // v2 → v3: full schema upgrade — 9 tables
    if (oldVersion < 3) {
      // ── 1. users: add email, phone, avatar_url, status, updated_at ──
      final userCols = await db.rawQuery("PRAGMA table_info(users)");
      final userColNames = userCols.map((c) => c['name'] as String).toSet();
      if (!userColNames.contains('email')) {
        await db.execute("ALTER TABLE users ADD COLUMN email TEXT");
      }
      if (!userColNames.contains('phone')) {
        await db.execute("ALTER TABLE users ADD COLUMN phone TEXT");
      }
      if (!userColNames.contains('avatar_url')) {
        await db.execute("ALTER TABLE users ADD COLUMN avatar_url TEXT");
      }
      if (!userColNames.contains('status')) {
        await db.execute("ALTER TABLE users ADD COLUMN status TEXT NOT NULL DEFAULT 'ACTIVE'");
      }
      if (!userColNames.contains('updated_at')) {
        await db.execute("ALTER TABLE users ADD COLUMN updated_at TEXT");
      }

      // ── 2. categories: create new ──
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          category_id TEXT PRIMARY KEY,
          category_name TEXT NOT NULL,
          type TEXT NOT NULL,
          icon TEXT,
          color TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      // ── 3. partners: create new ──
      await db.execute('''
        CREATE TABLE IF NOT EXISTS partners (
          partner_id TEXT PRIMARY KEY,
          partner_name TEXT NOT NULL,
          partner_type TEXT NOT NULL,
          tax_code TEXT,
          phone TEXT,
          email TEXT,
          address TEXT,
          status TEXT NOT NULL DEFAULT 'ACTIVE',
          created_at TEXT NOT NULL
        )
      ''');

      // ── 4. transactions: add created_by, category_id, receipt_image_url, status, cancel fields, updated_at ──
      final txCols = await db.rawQuery("PRAGMA table_info(transactions)");
      final txColNames = txCols.map((c) => c['name'] as String).toSet();
      if (!txColNames.contains('created_by')) {
        await db.execute("ALTER TABLE transactions ADD COLUMN created_by TEXT");
      }
      if (!txColNames.contains('category_id')) {
        await db.execute("ALTER TABLE transactions ADD COLUMN category_id TEXT");
      }
      if (!txColNames.contains('receipt_image_url')) {
        await db.execute("ALTER TABLE transactions ADD COLUMN receipt_image_url TEXT");
      }
      if (!txColNames.contains('status')) {
        await db.execute("ALTER TABLE transactions ADD COLUMN status TEXT NOT NULL DEFAULT 'POSTED'");
      }
      if (!txColNames.contains('cancel_reason')) {
        await db.execute("ALTER TABLE transactions ADD COLUMN cancel_reason TEXT");
      }
      if (!txColNames.contains('cancelled_by')) {
        await db.execute("ALTER TABLE transactions ADD COLUMN cancelled_by TEXT");
      }
      if (!txColNames.contains('cancelled_at')) {
        await db.execute("ALTER TABLE transactions ADD COLUMN cancelled_at TEXT");
      }
      if (!txColNames.contains('created_at')) {
        await db.execute("ALTER TABLE transactions ADD COLUMN created_at TEXT NOT NULL DEFAULT ''");
      }
      if (!txColNames.contains('updated_at')) {
        await db.execute("ALTER TABLE transactions ADD COLUMN updated_at TEXT");
      }
      // Migrate user_id → created_by
      await db.execute("UPDATE transactions SET created_by = user_id WHERE created_by IS NULL");

      // ── 5. invoices: rebuild with new schema ──
      await _rebuildInvoicesTable(db);

      // ── 6. invoice_items: rebuild with unit + line_total ──
      await _rebuildInvoiceItemsTable(db);

      // ── 7. invoice_approvals: create new ──
      await db.execute('''
        CREATE TABLE IF NOT EXISTS invoice_approvals (
          approval_id TEXT PRIMARY KEY,
          invoice_id TEXT NOT NULL,
          approved_by TEXT NOT NULL,
          action TEXT NOT NULL,
          comment TEXT,
          approved_at TEXT NOT NULL,
          FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
          FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');

      // ── 8. notifications: create new ──
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          notification_id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          type TEXT NOT NULL,
          reference_id TEXT,
          is_read INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');

      // ── 9. activity_logs: rename from audit_logs ──
      await _rebuildActivityLogsTable(db);

      // ── Seed categories + partners ──
      await _seedCategoriesAndPartners(db);
    }
  }

  Future<void> _rebuildInvoicesTable(Database db) async {
    // Save old data
    final oldInvoices = await db.query('invoices');
    // Drop old
    await db.execute('DROP TABLE IF EXISTS invoices');
    // Create new
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        partner_id TEXT,
        created_by TEXT,
        invoice_number TEXT NOT NULL,
        invoice_type TEXT NOT NULL DEFAULT 'IN',
        subtotal INTEGER NOT NULL,
        vat_rate TEXT NOT NULL,
        vat_amount INTEGER NOT NULL DEFAULT 0,
        total_amount INTEGER NOT NULL DEFAULT 0,
        invoice_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'DRAFT',
        image_path TEXT,
        pdf_url TEXT,
        ocr_text TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (partner_id) REFERENCES partners(partner_id) ON DELETE SET NULL,
        FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');
    // Migrate data
    for (final inv in oldInvoices) {
      final subtotal = (inv['subtotal'] as num?)?.toInt() ?? 0;
      final vatRateStr = inv['vat_rate'] as String? ?? 'none';
      double vatPercent = 0;
      if (vatRateStr == 'vat10') vatPercent = 10;
      else if (vatRateStr == 'vat8') vatPercent = 8;
      final vatAmount = (subtotal * vatPercent / 100).round();
      // Find partner by tax_code
      String? partnerId;
      final taxCode = inv['vendor_tax_code'] as String?;
      if (taxCode != null && taxCode.isNotEmpty) {
        final pRows = await db.query('partners', where: 'tax_code = ?', whereArgs: [taxCode]);
        if (pRows.isNotEmpty) partnerId = pRows.first['partner_id'] as String;
      }
      await db.insert('invoices', {
        'id': inv['id'],
        'user_id': inv['user_id'],
        'partner_id': partnerId,
        'created_by': inv['user_id'],
        'invoice_number': inv['invoice_number'],
        'invoice_type': 'IN',
        'subtotal': subtotal,
        'vat_rate': vatRateStr,
        'vat_amount': vatAmount,
        'total_amount': subtotal + vatAmount,
        'invoice_date': inv['invoice_date'],
        'status': _mapOldInvoiceStatus(inv['status'] as String? ?? 'pending'),
        'image_path': inv['image_path'],
        'ocr_text': inv['ai_notes'] as String?,
        'created_at': inv['created_at'] ?? DateTime.now().toIso8601String(),
      });
    }
  }

  String _mapOldInvoiceStatus(String old) {
    switch (old) {
      case 'pending': return 'PENDING';
      case 'approved': return 'APPROVED';
      case 'rejected': return 'REJECTED';
      case 'reviewing': return 'PENDING';
      default: return 'DRAFT';
    }
  }

  Future<void> _rebuildInvoiceItemsTable(Database db) async {
    final oldItems = await db.query('invoice_items');
    await db.execute('DROP TABLE IF EXISTS invoice_items');
    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        item_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit TEXT,
        unit_price INTEGER NOT NULL,
        line_total INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');
    for (final item in oldItems) {
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final price = (item['unit_price'] as num?)?.toInt() ?? 0;
      await db.insert('invoice_items', {
        'id': item['id'],
        'invoice_id': item['invoice_id'],
        'item_name': item['name'] ?? item['item_name'] ?? '',
        'quantity': qty,
        'unit': 'cái',
        'unit_price': price,
        'line_total': qty * price,
        'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _rebuildActivityLogsTable(Database db) async {
    final oldLogs = <Map<String, dynamic>>[];
    try {
      oldLogs.addAll(await db.query('audit_logs'));
    } catch (_) {}
    await db.execute('DROP TABLE IF EXISTS audit_logs');
    await db.execute('''
      CREATE TABLE activity_logs (
        log_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        module TEXT NOT NULL,
        action_type TEXT NOT NULL,
        reference_id TEXT,
        description TEXT,
        entity_type TEXT,
        entity_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    for (final log in oldLogs) {
      final entityType = log['entity_type'] as String? ?? 'SYSTEM';
      final action = log['action'] as String? ?? 'CREATE';
      await db.insert('activity_logs', {
        'log_id': log['id'],
        'user_id': log['user_id'],
        'module': entityType.toUpperCase(),
        'action_type': action.toUpperCase(),
        'reference_id': log['entity_id'],
        'description': log['new_value'],
        'entity_type': entityType,
        'entity_id': log['entity_id'],
        'created_at': log['created_at'] ?? DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _seedCategoriesAndPartners(Database db) async {
    final now = DateTime.now().toIso8601String();
    final categories = [
      {'category_id': 'cat_income_sales', 'category_name': 'Doanh thu bán hàng', 'type': 'INCOME', 'icon': 'shopping_cart', 'color': '#4CAF50', 'created_at': now},
      {'category_id': 'cat_income_service', 'category_name': 'Doanh thu dịch vụ', 'type': 'INCOME', 'icon': 'work', 'color': '#2196F3', 'created_at': now},
      {'category_id': 'cat_income_invest', 'category_name': 'Thu đầu tư', 'type': 'INCOME', 'icon': 'trending_up', 'color': '#FF9800', 'created_at': now},
      {'category_id': 'cat_income_other', 'category_name': 'Thu nhập khác', 'type': 'INCOME', 'icon': 'attach_money', 'color': '#9C27B0', 'created_at': now},
      {'category_id': 'cat_expense_salary', 'category_name': 'Lương nhân viên', 'type': 'EXPENSE', 'icon': 'people', 'color': '#F44336', 'created_at': now},
      {'category_id': 'cat_expense_rent', 'category_name': 'Thuê mặt bằng', 'type': 'EXPENSE', 'icon': 'home', 'color': '#E91E63', 'created_at': now},
      {'category_id': 'cat_expense_util', 'category_name': 'Điện nước Internet', 'type': 'EXPENSE', 'icon': 'bolt', 'color': '#FF5722', 'created_at': now},
      {'category_id': 'cat_expense_supply', 'category_name': 'Văn phòng phẩm', 'type': 'EXPENSE', 'icon': 'inventory_2', 'color': '#795548', 'created_at': now},
      {'category_id': 'cat_expense_mkt', 'category_name': 'Marketing & Quảng cáo', 'type': 'EXPENSE', 'icon': 'campaign', 'color': '#607D8B', 'created_at': now},
      {'category_id': 'cat_expense_tax', 'category_name': 'Thuế & Phí', 'type': 'EXPENSE', 'icon': 'receipt_long', 'color': '#9E9E9E', 'created_at': now},
      {'category_id': 'cat_expense_other', 'category_name': 'Chi phí khác', 'type': 'EXPENSE', 'icon': 'more_horiz', 'color': '#757575', 'created_at': now},
    ];
    for (final c in categories) {
      await db.insert('categories', c, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final partners = [
      {'partner_id': 'p_partner1', 'partner_name': 'Công ty TNHH Thiết bị VP', 'partner_type': 'SUPPLIER', 'tax_code': '0123456789', 'phone': '02812345678', 'email': 'info@thietbivp.vn', 'address': '123 Nguyễn Huệ, Q1, TP.HCM', 'status': 'ACTIVE', 'created_at': now},
      {'partner_id': 'p_partner2', 'partner_name': 'Cty CP Dịch vụ Cloud XYZ', 'partner_type': 'SUPPLIER', 'tax_code': '0987654321', 'phone': '02887654321', 'email': 'support@cloudxyz.vn', 'address': '456 Lê Lợi, Q3, TP.HCM', 'status': 'ACTIVE', 'created_at': now},
    ];
    for (final p in partners) {
      await db.insert('partners', p, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seed(Database db) async {
    final now = DateTime.now().toIso8601String();
    final adminHash = UserModel.hashPassword('admin123');
    final userHash = UserModel.hashPassword('user123');

    // ── Seed categories ──
    await _seedCategoriesAndPartners(db);

    // ── Seed users (v3 schema with email, phone, status) ──
    await db.insert('users', {
      'id': 'u_admin',
      'username': 'admin',
      'password_hash': adminHash,
      'role': 'OWNER',
      'full_name': 'Quản trị viên',
      'email': 'admin@smartfinance.vn',
      'phone': '0901000001',
      'status': 'ACTIVE',
      'created_at': now,
    });
    await db.insert('users', {
      'id': 'u_user1',
      'username': 'user1',
      'password_hash': userHash,
      'role': 'ACCOUNTANT',
      'full_name': 'Nguyễn Văn A',
      'email': 'user1@smartfinance.vn',
      'phone': '0901000002',
      'status': 'ACTIVE',
      'created_at': now,
    });
    await db.insert('users', {
      'id': 'u_user2',
      'username': 'user2',
      'password_hash': userHash,
      'role': 'ACCOUNTANT',
      'full_name': 'Trần Thị B',
      'email': 'user2@smartfinance.vn',
      'phone': '0901000003',
      'status': 'ACTIVE',
      'created_at': now,
    });

    final m = DateTime.now().month;
    final y = DateTime.now().year;

    // ── Seed transactions (v3 schema) ──
    final transactions = [
      {'id': 't01', 'user_id': 'u_admin', 'created_by': 'u_user1', 'category_id': 'cat_income_sales', 'title': 'Doanh thu bán hàng T$m', 'amount': 85000000, 'type': 'income', 'category': 'sales', 'description': 'Doanh thu tháng $m/$y', 'date': DateTime(y, m, 5).toIso8601String(), 'receipt_image_url': null, 'image_path': null, 'status': 'POSTED', 'cancel_reason': null, 'cancelled_by': null, 'cancelled_at': null, 'created_at': now, 'updated_at': null},
      {'id': 't02', 'user_id': 'u_admin', 'created_by': 'u_admin', 'category_id': 'cat_expense_salary', 'title': 'Lương nhân viên T$m', 'amount': 32000000, 'type': 'expense', 'category': 'salary', 'description': 'Lương tháng $m/$y', 'date': DateTime(y, m, 1).toIso8601String(), 'receipt_image_url': null, 'image_path': null, 'status': 'POSTED', 'cancel_reason': null, 'cancelled_by': null, 'cancelled_at': null, 'created_at': now, 'updated_at': null},
      {'id': 't03', 'user_id': 'u_admin', 'created_by': 'u_admin', 'category_id': 'cat_expense_rent', 'title': 'Thuê văn phòng T$m', 'amount': 12000000, 'type': 'expense', 'category': 'rent', 'description': 'Văn phòng Q1', 'date': DateTime(y, m, 2).toIso8601String(), 'receipt_image_url': null, 'image_path': null, 'status': 'POSTED', 'cancel_reason': null, 'cancelled_by': null, 'cancelled_at': null, 'created_at': now, 'updated_at': null},
      {'id': 't04', 'user_id': 'u_user1', 'created_by': 'u_user1', 'category_id': 'cat_income_service', 'title': 'Doanh thu dịch vụ tư vấn', 'amount': 25000000, 'type': 'income', 'category': 'serviceRevenue', 'description': 'Hợp đồng ABC Corp', 'date': DateTime(y, m, 8).toIso8601String(), 'receipt_image_url': null, 'image_path': null, 'status': 'POSTED', 'cancel_reason': null, 'cancelled_by': null, 'cancelled_at': null, 'created_at': now, 'updated_at': null},
      {'id': 't05', 'user_id': 'u_user1', 'created_by': 'u_user1', 'category_id': 'cat_expense_mkt', 'title': 'Chi phí Marketing', 'amount': 8500000, 'type': 'expense', 'category': 'marketing', 'description': 'Facebook & Google Ads', 'date': DateTime(y, m, 10).toIso8601String(), 'receipt_image_url': null, 'image_path': null, 'status': 'POSTED', 'cancel_reason': null, 'cancelled_by': null, 'cancelled_at': null, 'created_at': now, 'updated_at': null},
      {'id': 't06', 'user_id': 'u_user1', 'created_by': 'u_user1', 'category_id': 'cat_expense_util', 'title': 'Điện nước văn phòng', 'amount': 2800000, 'type': 'expense', 'category': 'utilities', 'description': 'Hóa đơn điện nước', 'date': DateTime(y, m, 7).toIso8601String(), 'receipt_image_url': null, 'image_path': null, 'status': 'POSTED', 'cancel_reason': null, 'cancelled_by': null, 'cancelled_at': null, 'created_at': now, 'updated_at': null},
      {'id': 't07', 'user_id': 'u_admin', 'created_by': 'u_user1', 'category_id': 'cat_income_sales', 'title': 'Doanh thu bán hàng T${m - 1}', 'amount': 72000000, 'type': 'income', 'category': 'sales', 'description': 'Doanh thu tháng ${m - 1}/$y', 'date': DateTime(y, m - 1, 28).toIso8601String(), 'receipt_image_url': null, 'image_path': null, 'status': 'POSTED', 'cancel_reason': null, 'cancelled_by': null, 'cancelled_at': null, 'created_at': now, 'updated_at': null},
      {'id': 't08', 'user_id': 'u_admin', 'created_by': 'u_admin', 'category_id': 'cat_expense_salary', 'title': 'Lương nhân viên T${m - 1}', 'amount': 31000000, 'type': 'expense', 'category': 'salary', 'description': 'Lương tháng ${m - 1}/$y', 'date': DateTime(y, m - 1, 5).toIso8601String(), 'receipt_image_url': null, 'image_path': null, 'status': 'POSTED', 'cancel_reason': null, 'cancelled_by': null, 'cancelled_at': null, 'created_at': now, 'updated_at': null},
      {'id': 't09', 'user_id': 'u_user2', 'created_by': 'u_user2', 'category_id': 'cat_income_service', 'title': 'Doanh thu dịch vụ T${m - 1}', 'amount': 18000000, 'type': 'income', 'category': 'serviceRevenue', 'description': 'Dịch vụ tháng ${m - 1}', 'date': DateTime(y, m - 1, 15).toIso8601String(), 'receipt_image_url': null, 'image_path': null, 'status': 'POSTED', 'cancel_reason': null, 'cancelled_by': null, 'cancelled_at': null, 'created_at': now, 'updated_at': null},
      {'id': 't10', 'user_id': 'u_user2', 'created_by': 'u_user2', 'category_id': 'cat_expense_supply', 'title': 'Mua văn phòng phẩm', 'amount': 1500000, 'type': 'expense', 'category': 'supplies', 'description': 'Văn phòng phẩm', 'date': DateTime(y, m, 3).toIso8601String(), 'receipt_image_url': null, 'image_path': null, 'status': 'POSTED', 'cancel_reason': null, 'cancelled_by': null, 'cancelled_at': null, 'created_at': now, 'updated_at': null},
      {'id': 't11', 'user_id': 'u_admin', 'created_by': 'u_admin', 'category_id': 'cat_income_invest', 'title': 'Thu từ đầu tư', 'amount': 15000000, 'type': 'income', 'category': 'investment', 'description': 'Lãi tiền gửi ngân hàng', 'date': DateTime(y, m - 2, 20).toIso8601String(), 'receipt_image_url': null, 'image_path': null, 'status': 'POSTED', 'cancel_reason': null, 'cancelled_by': null, 'cancelled_at': null, 'created_at': now, 'updated_at': null},
      {'id': 't12', 'user_id': 'u_user1', 'created_by': 'u_user1', 'category_id': 'cat_expense_tax', 'title': 'Nộp thuế VAT', 'amount': 5500000, 'type': 'expense', 'category': 'tax', 'description': 'Thuế GTGT quý 2', 'date': DateTime(y, m - 1, 25).toIso8601String(), 'receipt_image_url': null, 'image_path': null, 'status': 'POSTED', 'cancel_reason': null, 'cancelled_by': null, 'cancelled_at': null, 'created_at': now, 'updated_at': null},
    ];
    for (final t in transactions) {
      await db.insert('transactions', t);
    }

    // ── Seed invoices (v3 schema) ──
    final invoices = [
      {
        'id': 'inv01', 'user_id': 'u_admin', 'partner_id': 'p_partner1', 'created_by': 'u_user1',
        'invoice_number': 'HD-2026-001', 'invoice_type': 'IN',
        'subtotal': 13636364, 'vat_rate': 'vat10', 'vat_amount': 1363636, 'total_amount': 15000000,
        'invoice_date': DateTime(y, m, 5).toIso8601String(),
        'status': 'APPROVED', 'image_path': null, 'pdf_url': null,
        'ocr_text': 'Máy in HP LaserJet x2, Mực in HP x4',
        'note': null, 'created_at': DateTime(y, m, 5).toIso8601String(), 'updated_at': null,
      },
      {
        'id': 'inv02', 'user_id': 'u_user1', 'partner_id': 'p_partner2', 'created_by': 'u_user1',
        'invoice_number': 'HD-2026-002', 'invoice_type': 'IN',
        'subtotal': 2963000, 'vat_rate': 'vat8', 'vat_amount': 237040, 'total_amount': 3200040,
        'invoice_date': DateTime(y, m, 8).toIso8601String(),
        'status': 'PENDING', 'image_path': null, 'pdf_url': null,
        'ocr_text': 'Dịch vụ Cloud Server tháng 6',
        'note': null, 'created_at': DateTime(y, m, 8).toIso8601String(), 'updated_at': null,
      },
      {
        'id': 'inv03', 'user_id': 'u_user2', 'partner_id': null, 'created_by': 'u_user2',
        'invoice_number': 'HDxx-999', 'invoice_type': 'IN',
        'subtotal': 41000000, 'vat_rate': 'vat10', 'vat_amount': 4100000, 'total_amount': 45100000,
        'invoice_date': DateTime(y, m - 1, 30).toIso8601String(),
        'status': 'REJECTED', 'image_path': null, 'pdf_url': null,
        'ocr_text': 'Hàng hóa không xác định',
        'note': 'Hóa đơn đáng ngờ — cần xác minh', 'created_at': DateTime(y, m - 1, 30).toIso8601String(), 'updated_at': null,
      },
    ];
    for (final inv in invoices) {
      await db.insert('invoices', inv);
    }

    // ── Seed invoice_items (v3 schema) ──
    final seedItems = [
      {'invoice_id': 'inv01', 'item_name': 'Máy in HP LaserJet', 'quantity': 2, 'unit': 'cái', 'unit_price': 5000000},
      {'invoice_id': 'inv01', 'item_name': 'Mực in HP', 'quantity': 4, 'unit': 'hộp', 'unit_price': 909091},
      {'invoice_id': 'inv02', 'item_name': 'Dịch vụ Cloud Server tháng 6', 'quantity': 1, 'unit': 'tháng', 'unit_price': 2963000},
      {'invoice_id': 'inv03', 'item_name': 'Hàng hóa không xác định', 'quantity': 1, 'unit': 'cái', 'unit_price': 41000000},
    ];
    for (final item in seedItems) {
      final qty = item['quantity'] as int;
      final price = item['unit_price'] as int;
      await db.insert('invoice_items', {
        'id': const Uuid().v4(),
        'invoice_id': item['invoice_id'],
        'item_name': item['item_name'],
        'quantity': qty,
        'unit': item['unit'],
        'unit_price': price,
        'line_total': qty * price,
        'created_at': now,
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
    String? status,
  }) async {
    final d = await db;
    String where = '1=1';
    final args = <dynamic>[];
    if (userId != null) { where += ' AND user_id = ?'; args.add(userId); }
    if (from != null) { where += ' AND date >= ?'; args.add(from.toIso8601String()); }
    if (to != null)   { where += ' AND date <= ?'; args.add(to.toIso8601String()); }
    if (type != null) { where += ' AND type = ?'; args.add(type.name); }
    if (status != null) { where += ' AND status = ?'; args.add(status); }
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
    final map = t.toMap()
      ..['user_id'] = userId
      ..['created_by'] = userId
      ..['created_at'] = DateTime.now().toIso8601String();
    await d.insert('transactions', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTransaction(TransactionModel t) async {
    final d = await db;
    final map = t.toMap()..['updated_at'] = DateTime.now().toIso8601String();
    await d.update('transactions', map, where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> cancelTransaction(String id, {required String cancelledBy, required String reason}) async {
    final d = await db;
    await d.update('transactions', {
      'status': 'CANCELLED',
      'cancelled_by': cancelledBy,
      'cancel_reason': reason,
      'cancelled_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
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

  Future<List<InvoiceModel>> queryInvoices({InvoiceStatus? status, String? userId, String? invoiceType}) async {
    final d = await db;
    String where = '1=1';
    final args = <dynamic>[];
    if (userId != null) { where += ' AND user_id = ?'; args.add(userId); }
    if (status != null) { where += ' AND status = ?'; args.add(status.name); }
    if (invoiceType != null) { where += ' AND invoice_type = ?'; args.add(invoiceType); }
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
    final map = inv.toMap()
      ..['user_id'] = userId
      ..['created_by'] = userId
      ..['created_at'] = DateTime.now().toIso8601String();
    await d.insert('invoices', map, conflictAlgorithm: ConflictAlgorithm.replace);
    for (final item in inv.items) {
      await d.insert('invoice_items', {
        'id': const Uuid().v4(),
        'invoice_id': inv.id,
        'item_name': item.name,
        'quantity': item.quantity,
        'unit': item.unit ?? 'cái',
        'unit_price': item.unitPrice,
        'line_total': item.total,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> updateInvoice(InvoiceModel inv) async {
    final d = await db;
    final map = inv.toMap()..['updated_at'] = DateTime.now().toIso8601String();
    await d.update('invoices', map, where: 'id = ?', whereArgs: [inv.id]);
    await d.delete('invoice_items', where: 'invoice_id = ?', whereArgs: [inv.id]);
    for (final item in inv.items) {
      await d.insert('invoice_items', {
        'id': const Uuid().v4(),
        'invoice_id': inv.id,
        'item_name': item.name,
        'quantity': item.quantity,
        'unit': item.unit ?? 'cái',
        'unit_price': item.unitPrice,
        'line_total': item.total,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> updateInvoiceStatus(String id, String status) async {
    final d = await db;
    await d.update('invoices', {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
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
    return {for (final r in rows) (r['status'] as String).toLowerCase(): (r['cnt'] as int)};
  }

  // ── INVOICE ITEMS ──────────────────────────────────────────────

  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) async {
    final d = await db;
    final rows = await d.query('invoice_items', where: 'invoice_id = ?', whereArgs: [invoiceId]);
    return rows.map((r) => InvoiceItem(
      name: r['item_name'] as String? ?? r['name'] as String? ?? '',
      quantity: (r['quantity'] as num).toInt(),
      unitPrice: (r['unit_price'] as num).toInt(),
      unit: r['unit'] as String?,
    )).toList();
  }

  // ── INVOICE APPROVALS ──────────────────────────────────────────

  Future<void> insertInvoiceApproval({
    required String invoiceId,
    required String approvedBy,
    required String action,
    String? comment,
  }) async {
    final d = await db;
    await d.insert('invoice_approvals', {
      'approval_id': const Uuid().v4(),
      'invoice_id': invoiceId,
      'approved_by': approvedBy,
      'action': action,
      'comment': comment,
      'approved_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getInvoiceApprovals(String invoiceId) async {
    final d = await db;
    return d.query('invoice_approvals', where: 'invoice_id = ?', whereArgs: [invoiceId], orderBy: 'approved_at DESC');
  }

  // ── CATEGORIES ─────────────────────────────────────────────────

  Future<List<CategoryModel>> getAllCategories() async {
    final d = await db;
    final rows = await d.query('categories', orderBy: 'type ASC, category_name ASC');
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<CategoryModel?> getCategoryById(String id) async {
    final d = await db;
    final rows = await d.query('categories', where: 'category_id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return CategoryModel.fromMap(rows.first);
  }

  Future<void> insertCategory(CategoryModel cat) async {
    final d = await db;
    await d.insert('categories', cat.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCategory(CategoryModel cat) async {
    final d = await db;
    await d.update('categories', cat.toMap(), where: 'category_id = ?', whereArgs: [cat.categoryId]);
  }

  Future<void> deleteCategory(String id) async {
    final d = await db;
    await d.delete('categories', where: 'category_id = ?', whereArgs: [id]);
  }

  // ── PARTNERS ───────────────────────────────────────────────────

  Future<List<PartnerModel>> getAllPartners() async {
    final d = await db;
    final rows = await d.query('partners', orderBy: 'partner_name ASC');
    return rows.map(PartnerModel.fromMap).toList();
  }

  Future<PartnerModel?> getPartnerById(String id) async {
    final d = await db;
    final rows = await d.query('partners', where: 'partner_id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return PartnerModel.fromMap(rows.first);
  }

  Future<PartnerModel?> getPartnerByTaxCode(String taxCode) async {
    final d = await db;
    final rows = await d.query('partners', where: 'tax_code = ?', whereArgs: [taxCode]);
    if (rows.isEmpty) return null;
    return PartnerModel.fromMap(rows.first);
  }

  Future<void> insertPartner(PartnerModel partner) async {
    final d = await db;
    await d.insert('partners', partner.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updatePartner(PartnerModel partner) async {
    final d = await db;
    await d.update('partners', partner.toMap(), where: 'partner_id = ?', whereArgs: [partner.partnerId]);
  }

  Future<void> deletePartner(String id) async {
    final d = await db;
    await d.delete('partners', where: 'partner_id = ?', whereArgs: [id]);
  }

  // ── NOTIFICATIONS ──────────────────────────────────────────────

  Future<void> insertNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? referenceId,
  }) async {
    final d = await db;
    await d.insert('notifications', {
      'notification_id': const Uuid().v4(),
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'reference_id': referenceId,
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<NotificationModel>> getNotifications(String userId, {bool? unreadOnly}) async {
    final d = await db;
    String where = 'user_id = ?';
    final args = <dynamic>[userId];
    if (unreadOnly == true) { where += ' AND is_read = 0'; }
    final rows = await d.query('notifications', where: where, whereArgs: args, orderBy: 'created_at DESC');
    return rows.map(NotificationModel.fromMap).toList();
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    final d = await db;
    final result = await d.rawQuery(
      'SELECT COUNT(*) as cnt FROM notifications WHERE user_id = ? AND is_read = 0',
      [userId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<void> markNotificationRead(String notificationId) async {
    final d = await db;
    await d.update('notifications', {'is_read': 1}, where: 'notification_id = ?', whereArgs: [notificationId]);
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final d = await db;
    await d.update('notifications', {'is_read': 1}, where: 'user_id = ?', whereArgs: [userId]);
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
    final d = await db;
    await d.insert('activity_logs', {
      'log_id': const Uuid().v4(),
      'user_id': userId,
      'module': module,
      'action_type': actionType,
      'reference_id': referenceId,
      'description': description,
      'entity_type': entityType,
      'entity_id': entityId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getActivityLogs({
    String? userId,
    String? module,
    String? actionType,
  }) async {
    final d = await db;
    String where = '1=1';
    final args = <dynamic>[];
    if (userId != null) { where += ' AND user_id = ?'; args.add(userId); }
    if (module != null) { where += ' AND module = ?'; args.add(module); }
    if (actionType != null) { where += ' AND action_type = ?'; args.add(actionType); }
    return d.query('activity_logs', where: where, whereArgs: args, orderBy: 'created_at DESC');
  }

  // ── LEGACY AUDIT LOGS (kept for backward compat) ───────────────

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
}
