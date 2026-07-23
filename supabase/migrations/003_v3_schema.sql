-- =====================================================
-- SmartFinance v3 Migration Script
-- 9 tables: users, categories, partners, transactions,
--            invoices, invoice_items, invoice_approvals,
--            notifications, activity_logs
-- =====================================================

-- 1. USERS (add columns)
ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'ACTIVE';
ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
-- Update role values
UPDATE users SET role = 'OWNER' WHERE role = 'admin';
UPDATE users SET role = 'ACCOUNTANT' WHERE role = 'user';

-- 2. CATEGORIES (new table)
CREATE TABLE IF NOT EXISTS categories (
  category_id TEXT PRIMARY KEY,
  category_name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('INCOME', 'EXPENSE')),
  icon TEXT,
  color TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default categories
INSERT INTO categories (category_id, category_name, type, icon, color, created_at) VALUES
  ('cat_income_sales', 'Doanh thu bán hàng', 'INCOME', 'shopping_cart', '#4CAF50', NOW()),
  ('cat_income_service', 'Doanh thu dịch vụ', 'INCOME', 'work', '#2196F3', NOW()),
  ('cat_income_invest', 'Thu đầu tư', 'INCOME', 'trending_up', '#FF9800', NOW()),
  ('cat_income_other', 'Thu nhập khác', 'INCOME', 'attach_money', '#9C27B0', NOW()),
  ('cat_expense_salary', 'Lương nhân viên', 'EXPENSE', 'people', '#F44336', NOW()),
  ('cat_expense_rent', 'Thuê mặt bằng', 'EXPENSE', 'home', '#E91E63', NOW()),
  ('cat_expense_util', 'Điện nước Internet', 'EXPENSE', 'bolt', '#FF5722', NOW()),
  ('cat_expense_supply', 'Văn phòng phẩm', 'EXPENSE', 'inventory_2', '#795548', NOW()),
  ('cat_expense_mkt', 'Marketing & Quảng cáo', 'EXPENSE', 'campaign', '#607D80', NOW()),
  ('cat_expense_tax', 'Thuế & Phí', 'EXPENSE', 'receipt_long', '#9E9E9E', NOW()),
  ('cat_expense_other', 'Chi phí khác', 'EXPENSE', 'more_horiz', '#757575', NOW())
ON CONFLICT (category_id) DO NOTHING;

-- 3. PARTNERS (new table)
CREATE TABLE IF NOT EXISTS partners (
  partner_id TEXT PRIMARY KEY,
  partner_name TEXT NOT NULL,
  partner_type TEXT NOT NULL CHECK (partner_type IN ('CUSTOMER', 'SUPPLIER')),
  tax_code TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  status TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default partners
INSERT INTO partners (partner_id, partner_name, partner_type, tax_code, phone, email, address, status, created_at) VALUES
  ('p_partner1', 'Công ty TNHH Thiết bị VP', 'SUPPLIER', '0123456789', '02812345678', 'info@thietbivp.vn', '123 Nguyễn Huệ, Q1, TP.HCM', 'ACTIVE', NOW()),
  ('p_partner2', 'Cty CP Dịch vụ Cloud XYZ', 'SUPPLIER', '0987654321', '02887654321', 'support@cloudxyz.vn', '456 Lê Lợi, Q3, TP.HCM', 'ACTIVE', NOW())
ON CONFLICT (partner_id) DO NOTHING;

-- 4. TRANSACTIONS (add columns)
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS created_by TEXT REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS category_id TEXT REFERENCES categories(category_id) ON DELETE SET NULL;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS receipt_image_url TEXT;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'POSTED';
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS cancel_reason TEXT;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS cancelled_by TEXT REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
-- Migrate user_id → created_by
UPDATE transactions SET created_by = user_id WHERE created_by IS NULL;

-- 5. INVOICES (rebuild)
-- Backup old data
CREATE TABLE IF NOT EXISTS invoices_backup AS SELECT * FROM invoices;
DROP TABLE IF EXISTS invoices CASCADE;
CREATE TABLE invoices (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  partner_id TEXT REFERENCES partners(partner_id) ON DELETE SET NULL,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  invoice_number TEXT NOT NULL,
  invoice_type TEXT NOT NULL DEFAULT 'IN' CHECK (invoice_type IN ('IN', 'OUT')),
  subtotal BIGINT NOT NULL,
  vat_rate TEXT NOT NULL,
  vat_amount BIGINT NOT NULL DEFAULT 0,
  total_amount BIGINT NOT NULL DEFAULT 0,
  invoice_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'ISSUED')),
  image_path TEXT,
  pdf_url TEXT,
  ocr_text TEXT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);
-- Migrate data
INSERT INTO invoices (id, user_id, created_by, invoice_number, invoice_type, subtotal, vat_rate, vat_amount, total_amount, invoice_date, status, image_path, ocr_text, created_at)
SELECT
  id, user_id, user_id as created_by, invoice_number, 'IN' as invoice_type,
  subtotal, vat_rate,
  CASE WHEN vat_rate = 'vat10' THEN (subtotal * 0.1)::BIGINT
       WHEN vat_rate = 'vat8' THEN (subtotal * 0.08)::BIGINT
       ELSE 0 END as vat_amount,
  subtotal + CASE WHEN vat_rate = 'vat10' THEN (subtotal * 0.1)::BIGINT
                  WHEN vat_rate = 'vat8' THEN (subtotal * 0.08)::BIGINT
                  ELSE 0 END as total_amount,
  invoice_date::DATE,
  CASE status
    WHEN 'pending' THEN 'PENDING'
    WHEN 'approved' THEN 'APPROVED'
    WHEN 'rejected' THEN 'REJECTED'
    ELSE 'DRAFT'
  END as status,
  image_path, ai_notes, created_at
FROM invoices_backup;
DROP TABLE IF EXISTS invoices_backup;

-- 6. INVOICE_ITEMS (rebuild)
CREATE TABLE IF NOT EXISTS invoice_items_backup AS SELECT * FROM invoice_items;
DROP TABLE IF EXISTS invoice_items CASCADE;
CREATE TABLE invoice_items (
  id TEXT PRIMARY KEY,
  invoice_id TEXT NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit TEXT,
  unit_price BIGINT NOT NULL,
  line_total BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO invoice_items (id, invoice_id, item_name, quantity, unit, unit_price, line_total, created_at)
SELECT id, invoice_id, name as item_name, quantity, 'cái' as unit, unit_price, amount as line_total, created_at
FROM invoice_items_backup;
DROP TABLE IF EXISTS invoice_items_backup;

-- 7. INVOICE_APPROVALS (new table)
CREATE TABLE IF NOT EXISTS invoice_approvals (
  approval_id TEXT PRIMARY KEY,
  invoice_id TEXT NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  approved_by TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (action IN ('APPROVE', 'REJECT')),
  comment TEXT,
  approved_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. NOTIFICATIONS (new table)
CREATE TABLE IF NOT EXISTS notifications (
  notification_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('TRANSACTION', 'INVOICE', 'SYSTEM')),
  reference_id TEXT,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. ACTIVITY_LOGS (rebuild from audit_logs)
CREATE TABLE IF NOT EXISTS activity_logs (
  log_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  module TEXT NOT NULL CHECK (module IN ('USER', 'TRANSACTION', 'INVOICE', 'PARTNER', 'CATEGORY', 'SYSTEM')),
  action_type TEXT NOT NULL CHECK (action_type IN ('CREATE', 'UPDATE', 'CANCEL', 'APPROVE', 'REJECT', 'LOGIN', 'LOGOUT')),
  reference_id TEXT,
  description TEXT,
  entity_type TEXT,
  entity_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Migrate audit_logs → activity_logs (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'audit_logs') THEN
    INSERT INTO activity_logs (log_id, user_id, module, action_type, reference_id, description, entity_type, entity_id, created_at)
    SELECT id, user_id, entity_type, action, entity_id, new_value, entity_type, entity_id, created_at
    FROM audit_logs;
    DROP TABLE audit_logs;
  END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoices_partner ON invoices(partner_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_activity_logs_user ON activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_module ON activity_logs(module);
