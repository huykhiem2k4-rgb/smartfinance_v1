-- ============================================================
-- SmartFinance DB v5: Thêm bảng invoice_items + audit_logs
-- ============================================================

-- 1. Bảng invoice_items (tách từ items_json trong invoices)
CREATE TABLE IF NOT EXISTS invoice_items (
  id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  invoice_id  TEXT NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  name        TEXT NOT NULL DEFAULT '',
  quantity    INTEGER NOT NULL DEFAULT 1,
  unit_price  INTEGER NOT NULL DEFAULT 0,
  amount      INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- 2. Bảng audit_logs (nhật ký thay đổi)
CREATE TABLE IF NOT EXISTS audit_logs (
  id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id     TEXT NOT NULL REFERENCES users(id),
  action      TEXT NOT NULL,           -- 'insert', 'update', 'delete'
  entity_type TEXT NOT NULL,           -- 'transaction', 'invoice', 'user'
  entity_id   TEXT NOT NULL,
  old_value   JSONB,                   -- JSON snapshot trước khi sửa
  new_value   JSONB,                   -- JSON snapshot sau khi sửa
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- 3. RLS policies
ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- invoice_items: Everyone can access (same as invoices)
CREATE POLICY "invoice_items_all" ON invoice_items
  FOR ALL USING (true);

-- audit_logs: Everyone can access (same as invoices)
CREATE POLICY "audit_logs_all" ON audit_logs
  FOR ALL USING (true);

-- 4. Indexes
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice_id ON invoice_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
