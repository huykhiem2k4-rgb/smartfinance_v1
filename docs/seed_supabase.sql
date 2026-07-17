-- Tạm tắt RLS để insert seed data
ALTER TABLE public.transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices DISABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  admin_id UUID := '552c86f0-c646-4a6a-bb3e-41d81cf345f1';
  user1_id UUID := '8373ed50-0c90-4a9c-8060-0a1ed00405d6';
  user2_id UUID := '94a87e5a-d3ee-4f86-808c-21280778b9b0';
  now_date TIMESTAMPTZ := now();
BEGIN

INSERT INTO public.transactions (id, user_id, title, amount, type, category, description, date, created_at, updated_at) VALUES
(gen_random_uuid(), admin_id, 'Doanh thu bán hàng tháng 7', 85000000, 'income', 'sales', 'Doanh thu tháng 7/2026', '2026-07-05', now_date, now_date),
(gen_random_uuid(), admin_id, 'Lương nhân viên tháng 7', 32000000, 'expense', 'salary', 'Lương tháng 7/2026', '2026-07-01', now_date, now_date),
(gen_random_uuid(), admin_id, 'Thuê văn phòng tháng 7', 12000000, 'expense', 'rent', 'Văn phòng Q3', '2026-07-02', now_date, now_date),
(gen_random_uuid(), admin_id, 'Doanh thu bán hàng tháng 6', 72000000, 'income', 'sales', 'Doanh thu tháng 6/2026', '2026-06-28', now_date, now_date),
(gen_random_uuid(), admin_id, 'Lương nhân viên tháng 6', 31000000, 'expense', 'salary', 'Lương tháng 6/2026', '2026-06-05', now_date, now_date),
(gen_random_uuid(), admin_id, 'Thu từ đầu tư', 15000000, 'income', 'investment', 'Lãi tiền gửi ngân hàng', '2026-05-20', now_date, now_date),
(gen_random_uuid(), user1_id, 'Doanh thu dịch vụ tư vấn', 25000000, 'income', 'serviceRevenue', 'Hợp đồng ABC Corp', '2026-07-08', now_date, now_date),
(gen_random_uuid(), user1_id, 'Chi phí Marketing', 8500000, 'expense', 'marketing', 'Facebook & Google Ads', '2026-07-10', now_date, now_date),
(gen_random_uuid(), user1_id, 'Điện nước văn phòng', 2800000, 'expense', 'utilities', 'Hóa đơn điện nước', '2026-07-07', now_date, now_date),
(gen_random_uuid(), user1_id, 'Nộp thuế VAT', 5500000, 'expense', 'tax', 'Thuế GTGT quý 2', '2026-06-25', now_date, now_date),
(gen_random_uuid(), user2_id, 'Doanh thu dịch vụ tháng 6', 18000000, 'income', 'serviceRevenue', 'Dịch vụ tháng 6', '2026-06-15', now_date, now_date),
(gen_random_uuid(), user2_id, 'Mua văn phòng phẩm', 1500000, 'expense', 'supplies', 'Văn phòng phẩm', '2026-07-03', now_date, now_date);

INSERT INTO public.invoices (id, user_id, invoice_number, vendor, vendor_tax_code, subtotal, vat_rate, invoice_date, due_date, status, ai_confidence, ai_notes, items_json, created_at, updated_at) VALUES
(gen_random_uuid(), admin_id, 'HD-2026-001', 'Công ty TNHH Thiết bị VP', '0123456789', 13636364, 'vat10', '2026-07-05', '2026-07-20', 'approved', 0.94, 'Hóa đơn hợp lệ (94%)', 'Máy in HP LaserJet|||2|||5000000~~~Mực in HP|||4|||909091', now_date, now_date),
(gen_random_uuid(), user1_id, 'HD-2026-002', 'Cty CP Dịch vụ Cloud XYZ', '0987654321', 2963000, 'vat8', '2026-07-08', '2026-07-25', 'pending', NULL, NULL, 'Dịch vụ Cloud Server tháng 6|||1|||2963000', now_date, now_date),
(gen_random_uuid(), user2_id, 'HDxx-999', 'Nhà cung cấp Không rõ', NULL, 41000000, 'vat10', '2026-06-30', '2026-07-15', 'rejected', 0.23, 'Hóa đơn đáng ngờ (23%)', 'Hàng hóa không xác định|||1|||41000000', now_date, now_date);

END $$;

-- Bật lại RLS sau khi insert xong
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
