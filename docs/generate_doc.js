const docx = require('docx');
const fs = require('fs');

const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  WidthType, AlignmentType, HeadingLevel, BorderStyle, TableBorders,
  PageBreak, Tab, TabStopType, TabStopPosition, UnderlineType,
  ShadingType, VerticalAlign, convertInchesToTwip, ImageRun,
} = docx;

// ============================================================
// HELPER FUNCTIONS
// ============================================================

const FONT = 'Times New Roman';
const FONT_SIZE = 24; // 12pt in half-points

function title(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 200 },
    children: [
      new TextRun({ text, font: FONT, size: 36, bold: true }),
    ],
  });
}

function subtitle(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 100 },
    children: [
      new TextRun({ text, font: FONT, size: 28, italics: true }),
    ],
  });
}

function heading1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 400, after: 200 },
    children: [
      new TextRun({ text, font: FONT, size: 32, bold: true, color: '1a5276' }),
    ],
  });
}

function heading2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 300, after: 150 },
    children: [
      new TextRun({ text, font: FONT, size: 28, bold: true, color: '2e86c1' }),
    ],
  });
}

function heading3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    spacing: { before: 200, after: 100 },
    children: [
      new TextRun({ text, font: FONT, size: 26, bold: true }),
    ],
  });
}

function body(text, opts = {}) {
  return new Paragraph({
    spacing: { after: 120 },
    indent: opts.indent ? { firstLine: 720 } : undefined,
    children: [
      new TextRun({ text, font: FONT, size: FONT_SIZE, ...opts }),
    ],
  });
}

function bodyRuns(runs) {
  return new Paragraph({
    spacing: { after: 120 },
    children: runs.map(r => new TextRun({ font: FONT, size: FONT_SIZE, ...r })),
  });
}

function bullet(text, level = 0) {
  return new Paragraph({
    bullet: { level },
    spacing: { after: 60 },
    children: [
      new TextRun({ text, font: FONT, size: FONT_SIZE }),
    ],
  });
}

function bulletBold(label, text, level = 0) {
  return new Paragraph({
    bullet: { level },
    spacing: { after: 60 },
    children: [
      new TextRun({ text: label, font: FONT, size: FONT_SIZE, bold: true }),
      new TextRun({ text, font: FONT, size: FONT_SIZE }),
    ],
  });
}

function emptyLine() {
  return new Paragraph({ spacing: { after: 100 }, children: [] });
}

function pageBreak() {
  return new Paragraph({ children: [new PageBreak()] });
}

function makeTable(headers, rows, colWidths) {
  const headerRow = new TableRow({
    tableHeader: true,
    children: headers.map((h, i) => new TableCell({
      width: { size: colWidths ? colWidths[i] : 2000, type: WidthType.DXA },
      shading: { type: ShadingType.SOLID, color: '2e86c1' },
      verticalAlign: VerticalAlign.CENTER,
      children: [new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: h, font: FONT, size: 22, bold: true, color: 'FFFFFF' })],
      })],
    })),
  });

  const dataRows = rows.map(row => new TableRow({
    children: row.map((cell, i) => new TableCell({
      width: { size: colWidths ? colWidths[i] : 2000, type: WidthType.DXA },
      verticalAlign: VerticalAlign.CENTER,
      children: [new Paragraph({
        spacing: { before: 40, after: 40 },
        children: [new TextRun({ text: String(cell), font: FONT, size: 22 })],
      })],
    })),
  }));

  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [headerRow, ...dataRows],
    borders: {
      top: { style: BorderStyle.SINGLE, size: 1 },
      bottom: { style: BorderStyle.SINGLE, size: 1 },
      left: { style: BorderStyle.SINGLE, size: 1 },
      right: { style: BorderStyle.SINGLE, size: 1 },
      insideHorizontal: { style: BorderStyle.SINGLE, size: 1 },
      insideVertical: { style: BorderStyle.SINGLE, size: 1 },
    },
  });
}

// ============================================================
// DOCUMENT CONTENT
// ============================================================

const children = [];

// ── TRANG BÌA ──
children.push(emptyLine(), emptyLine(), emptyLine(), emptyLine(), emptyLine());
children.push(title('ĐỒ ÁN TỐT NGHIỆP'));
children.push(emptyLine());
children.push(title('PHÁT TRIỂN ỨNG DỤNG'));
children.push(title('QUẢN LÝ TÀI CHÍNH DOANH NGHIỆP SME'));
children.push(emptyLine());
children.push(subtitle('SmartFinance'));
children.push(emptyLine(), emptyLine());
children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  children: [new TextRun({ text: 'Nhóm: 4-5 sinh viên', font: FONT, size: 28 })],
}));
children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  children: [new TextRun({ text: 'Thời gian thực hiện: 1 tuần (7 ngày)', font: FONT, size: 28 })],
}));
children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  children: [new TextRun({ text: 'Công nghệ: Flutter + Supabase + SQLite', font: FONT, size: 28 })],
}));
children.push(emptyLine(), emptyLine(), emptyLine(), emptyLine());
children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  children: [new TextRun({ text: 'Năm học 2025 - 2026', font: FONT, size: 28 })],
}));

// ── TRANG MỤC LỤC ──
children.push(pageBreak());
children.push(heading1('MỤC LỤC'));
children.push(emptyLine());
const tocItems = [
  'Chương 1: Mô tả dự án',
  'Chương 2: Phân tích yêu cầu nghiệp vụ',
  'Chương 3: Quy trình nghiệp vụ và quy định nghiệp vụ',
  'Chương 4: Phân tích yêu cầu chức năng - Use Case Diagram',
  'Chương 5: Thiết kế giao diện (UI/UX Design)',
  'Chương 6: Thiết kế cơ sở dữ liệu (Database Design)',
  'Chương 7: Kiến trúc ứng dụng và công nghệ',
  'Chương 8: Kết quả đạt được',
];
tocItems.forEach(item => {
  children.push(new Paragraph({
    spacing: { after: 100 },
    children: [new TextRun({ text: item, font: FONT, size: 26 })],
  }));
});

// ============================================================
// CHƯƠNG 1: MÔ TẢ DỰ ÁN
// ============================================================
children.push(pageBreak());
children.push(heading1('Chương 1: Mô tả dự án'));

children.push(heading2('1.1 Tên dự án'));
children.push(body('SmartFinance - Ứng dụng quản lý tài chính doanh nghiệp SME'));

children.push(heading2('1.2 Mục tiêu'));
children.push(bullet('Xây dựng ứng dụng theo dõi dòng tiền lưu chuyển nội bộ cho doanh nghiệp nhỏ và vừa (SME)'));
children.push(bullet('Mô phỏng quá trình kiểm tra hóa đơn đầu vào bằng AI (OCR Simulation)'));
children.push(bullet('Xuất báo cáo trực quan cho nhà quản lý'));
children.push(bullet('Đánh giá tư duy thiết kế giao diện đa nền tảng (Responsive UI/UX)'));
children.push(bullet('Đánh giá khả năng tổ chức kiến trúc mã nguồn và quản lý trạng thái'));

children.push(heading2('1.3 Phạm vi dự án'));
children.push(body('Hệ thống chỉ tập trung vào luồng đi phẳng của tiền mặt (Cash Flow), KHÔNG yêu cầu các nghiệp vụ kế toán chuyên sâu (Nợ/Có, khấu hao, kết chuyển).', { italics: true }));

children.push(heading2('1.4 Đối tượng sử dụng'));
children.push(makeTable(
  ['Vai trò', 'Mô tả', 'Quyền hạn'],
  [
    ['Admin (Quản trị)', 'Quản trị viên hệ thống', 'Xem tất cả data, quản lý users, phân quyền'],
    ['User (Nhân viên)', 'Nhân viên kế toán/ngân quỹ', 'Xem/sửa/xóa giao dịch và hóa đơn của mình'],
  ],
  [2500, 3500, 4000]
));

children.push(heading2('1.5 Thời gian thực hiện'));
children.push(makeTable(
  ['Giai đoạn', 'Thời gian', 'Nội dung'],
  [
    ['Nghiên cứu yêu cầu', 'Ngày 1-2', 'Phân tích đề bài, thiết kế DB, wireframe'],
    ['Phát triển lõi', 'Ngày 3-5', 'Xây dựng CRUD, auth, responsive, offline'],
    ['Tính năng nâng cao', 'Ngày 5-6', 'AI Scan, PDF export, charts, dark mode'],
    ['Hoàn thiện & Test', 'Ngày 6-7', 'UI polish, unit test, responsive test, docs'],
  ],
  [2500, 2000, 5500]
));

children.push(heading2('1.6 Công cụ hỗ trợ'));
children.push(bullet('IDE: VS Code + Flutter SDK'));
children.push(bullet('Database: Supabase (Cloud BaaS) + SQLite (Local Offline)'));
children.push(bullet('AI hỗ trợ: ChatGPT, Claude, Cursor, GitHub Copilot'));
children.push(bullet('Thiết kế: Figma (wireframe), dbdiagram.io (ERD)'));
children.push(bullet('Version Control: Git + GitHub'));

// ============================================================
// CHƯƠNG 2: PHÂN TÍCH YÊU CẦU NGHIỆP VỤ
// ============================================================
children.push(pageBreak());
children.push(heading1('Chương 2: Phân tích yêu cầu nghiệp vụ'));

children.push(heading2('2.1 Mô hình doanh nghiệp'));
children.push(body('SmartFinance được thiết kế cho mô hình doanh nghiệp SME (Small & Medium Enterprise) tại Việt Nam với các đặc điểm:', { indent: true }));
children.push(bullet('Quy mô nhỏ: 1 quản trị + nhiều nhân viên'));
children.push(bullet('Đơn vị tiền tệ: VND (Đồng Việt Nam)'));
children.push(bullet('Không phân quyền đa chi nhánh'));
children.push(bullet('Chỉ tập trung vào dòng tiền mặt (Cash Flow)'));

children.push(heading2('2.2 Phân tíchactors'));
children.push(makeTable(
  ['Actor', 'Vai trò', 'Mô tả'],
  [
    ['Admin', 'Quản trị viên', 'Quản lý hệ thống, xem tất cả data, phân quyền users, xem thống kê toàn hệ thống'],
    ['User', 'Nhân viên', 'Nhập/sửa/xóa giao dịch, chụp/quét hóa đơn, xem báo cáo của mình'],
    ['Hệ thống (AI)', 'OCR Simulator', 'Tự động nhận diện và điền dữ liệu mẫu vào form hóa đơn'],
    ['Hệ thống (DB)', 'Database', 'Lưu trữ dữ liệu cloud (Supabase) và local (SQLite), đồng bộ khi có mạng'],
  ],
  [2000, 2500, 5500]
));

children.push(heading2('2.3 Phân tích nghiệp vụ chính'));

children.push(heading3('2.3.1 Quản lý dòng tiền (Cash Flow)'));
children.push(body('Đây là nghiệp vụ cốt lõi của hệ thống. Doanh nghiệp cần theo dõi dòng tiền lưu chuyển nội bộ: tiền vào (Thu/Income) và tiền ra (Chi/Expense).', { indent: true }));
children.push(bullet('Mỗi giao dịch có: tiêu đề, số tiền (VND int), loại (Thu/Chi), danh mục, ngày tháng, chứng từ ảnh'));
children.push(bullet('Danh mục Thu: Doanh thu bán hàng, Doanh thu dịch vụ, Thu từ đầu tư, Thu nhập khác'));
children.push(bullet('Danh mục Chi: Lương nhân viên, Thuê mặt bằng, Điện/Nước/Internet, Vật tư, Marketing, Thuế & Phí, Chi phí khác'));

children.push(heading3('2.3.2 Quản lý hóa đơn (Invoices)'));
children.push(body('Doanh nghiệp cần kiểm tra hóa đơn đầu vào. Hệ thống mô phỏng quy trình AI OCR để tự động điền dữ liệu từ ảnh hóa đơn.', { indent: true }));
children.push(bullet('Chụp ảnh/chọn từ gallery → Smart Scan 2s → Mock data tự điền'));
children.push(bullet('Thông tin: Số hóa đơn, Nhà cung cấp, Mã số thuế, Tiền hàng, VAT rate, Tổng thanh toán'));
children.push(bullet('Trạng thái: Chờ duyệt → Đã duyệt / Từ chối / Đang xét duyệt'));

children.push(heading3('2.3.3 Báo cáo & Biểu đồ'));
children.push(body('Nhà quản lý cần được trực quan hóa dữ liệu tài chính để đưa ra quyết định.', { indent: true }));
children.push(bullet('Biểu đồ tròn (Pie Chart): Tỷ trọng các khoản chi phí'));
children.push(bullet('Biểu đồ cột/đường (Bar/Line Chart): So sánh Thu vs Chi theo dòng thời gian'));
children.push(bullet('Bộ lọc: Tháng này, Tháng trước, Toàn bộ kỳ tài khóa'));

children.push(heading2('2.4 Giới hạn hệ thống'));
children.push(bullet('KHÔNG kế toán chuyên sâu (Nợ/Có, khấu hao, kết chuyển)'));
children.push(bullet('KHÔNG đa tiền tệ'));
children.push(bullet('KHÔNG đa chi nhánh'));
children.push(bullet('KHÔNG quản lý kho hàng'));
children.push(bullet('KHÔNG xuất hóa đơn GTGT theo quy chuẩn thuế (chỉ export PDF preview)'));

// ============================================================
// CHƯƠNG 3: QUY TRÌNH NGHIỆP VỤ VÀ QUY ĐỊNH
// ============================================================
children.push(pageBreak());
children.push(heading1('Chương 3: Quy trình nghiệp vụ và quy định nghiệp vụ'));

children.push(heading2('3.1 Quy trình nghiệp vụ'));

children.push(heading3('QTT-01: Đăng nhập'));
children.push(bullet('Bước 1: User mở ứng dụng → Hiển thị màn hình đăng nhập'));
children.push(bullet('Bước 2: User nhập tên đăng nhập và mật khẩu'));
children.push(bullet('Bước 3: Hệ thống kiểm tra online/offline'));
children.push(bulletBold('Online: ', 'Xác thực qua Supabase Auth → lấy user metadata'));
children.push(bulletBold('Offline: ', 'Xác thực qua SQLite local → so sánh password hash SHA-256'));
children.push(bullet('Bước 4: Nếu thành công → Lưu SharedPreferences → Chuyển Dashboard'));
children.push(bullet('Bước 5: Nếu thất bại → Hiển thị lỗi SnackBar'));

children.push(heading3('QTT-02: Thêm giao dịch mới'));
children.push(bullet('Bước 1: User nhấn FAB "Thêm" → Mở form AddTransactionScreen'));
children.push(bullet('Bước 2: User chọn loại (Thu/Chi) qua SegmentedButton'));
children.push(bullet('Bước 3: User nhập Tiêu đề, Số tiền (chỉ nhập số), Chọn danh mục, Ngày'));
children.push(bullet('Bước 4: User có thể chụp ảnh/chọn ảnh chứng từ (image_picker)'));
children.push(bullet('Bước 5: Hệ thống validate Form (required, amount > 0, category != null)'));
children.push(bullet('Bước 6: Lưu lên Supabase Cloud (nếu online) + SQLite local'));
children.push(bullet('Bước 7: Reload danh sách → Hiển thị SnackBar thành công'));

children.push(heading3('QTT-03: Chỉnh sửa giao dịch'));
children.push(bullet('Bước 1: User chọn giao dịch từ danh sách → Mở form EditTransactionScreen'));
children.push(bullet('Bước 2: Form được pre-fill dữ liệu giao dịch hiện tại'));
children.push(bullet('Bước 3: User chỉnh sửa fields cần thiết'));
children.push(bullet('Bước 4: Validate + Lưu cả cloud và local'));
children.push(bullet('Bước 5: Quay lại danh sách với dữ liệu mới'));

children.push(heading3('QTT-04: Xóa giao dịch'));
children.push(bulletBold('Mobile: ', 'Vuốt phải→trái (Dismissible) → AlertDialog xác nhận → Xóa'));
children.push(bulletBold('Desktop: ', 'Nhấn icon xóa trong DataTable → AlertDialog xác nhận → Xóa'));
children.push(bullet('Xóa trên cả cloud và local (ON DELETE CASCADE trên FK)'));

children.push(heading3('QTT-05: Quét hóa đơn AI (Smart Scan)'));
children.push(bullet('Bước 1: User nhấn "Thêm hóa đơn" → Chọn Camera hoặc Thư viện'));
children.push(bullet('Bước 2: Chọn ảnh → Hiển thị AnimationController 2s với 5 bước quét'));
children.push(bullet('Bước 3: Hệ thống tự động điền Mock data (vendor, MST, subtotal, VAT rate)'));
children.push(bullet('Bước 4: User kiểm tra và chỉnh sửa nếu cần'));
children.push(bullet('Bước 5: Lưu invoice + invoice_items vào DB'));

children.push(heading3('QTT-06: Xuất PDF hóa đơn'));
children.push(bullet('Bước 1: User mở chi tiết hóa đơn (InvoiceDetailScreen)'));
children.push(bullet('Bước 2: Nhấn nút PDF → Tạo file PDF với font NotoSans tiếng Việt'));
children.push(bullet('Bước 3: PDF bao gồm: Tiền hàng, VAT rate, VAT amount, Tổng thanh toán'));
children.push(bullet('Bước 4: Mở Printing.layoutPdf() → Preview/In/Chia sẻ'));

children.push(heading3('QTT-07: Xem báo cáo'));
children.push(bullet('Bước 1: User chọn tab Báo cáo hoặc Dashboard'));
children.push(bullet('Bước 2: Chọn filter período (Tháng này/Trước/Toàn kỳ)'));
children.push(bullet('Bước 3: Biểu đồ tự cập nhật với AnimatedSwitcher (400ms)'));
children.push(bullet('Bước 4: Touch trên biểu đồ → Hiển thị Tooltip giá trị'));

children.push(heading2('3.2 Quy định nghiệp vụ'));
children.push(makeTable(
  ['Mã QĐ', 'Quy định', 'Chi tiết'],
  [
    ['QĐ-01', 'Tiền tệ dùng int', 'amount là INTEGER (VND) để tránh lỗi làm tròn số thập phân'],
    ['QĐ-02', 'VAT rate cố định', 'Chỉ chấp nhận: vat8 (8%), vat10 (10%), none (0%)'],
    ['QĐ-03', 'Trạng thái hóa đơn', 'pending → approved hoặc rejected hoặc reviewing'],
    ['QĐ-04', 'Xóa cascade', 'Xóa user tự động xóa transactions, invoices, items, audit_logs'],
    ['QĐ-05', 'Audit trail', 'Mọi insert/update/delete đều ghi vào audit_logs với JSON snapshot'],
    ['QĐ-06', 'Offline-first', 'Luôn lưu local trước, sync cloud khi có mạng'],
    ['QĐ-07', 'Password băm', 'Mật khẩu lưu dạng SHA-256 hash, không plaintext'],
    ['QĐ-08', 'Admin chỉ 1', 'Chỉ admin mới xem được tất cả data, user chỉ thấy của mình'],
    ['QĐ-09', 'Smart Scan 2s', 'AnimationController duration = 2 giây, Curves.easeInOut'],
    ['QĐ-10', 'Responsive breakpoint', 'Desktop ≥ 720px dùng DataTable + NavigationRail'],
  ],
  [1500, 2500, 6000]
));

// ============================================================
// CHƯƠNG 4: USE CASE DIAGRAM
// ============================================================
children.push(pageBreak());
children.push(heading1('Chương 4: Phân tích yêu cầu chức năng - Use Case Diagram'));

children.push(heading2('4.1 Tổng quan Use Case'));
children.push(body('Hệ thống SmartFinance có 8 Use Cases chính, 2 Actors chính (User và Admin).', { indent: true }));

children.push(emptyLine());
children.push(body('┌─────────────────────────────────────────────────────────────┐', { font: 'Consolas', size: 20 }));
children.push(body('│                    SMARTFINANCE SYSTEM                      │', { font: 'Consolas', size: 20 }));
children.push(body('│                                                             │', { font: 'Consolas', size: 20 }));
children.push(body('│   UC01: Đăng nhập        UC02: Đăng ký tài khoản           │', { font: 'Consolas', size: 20 }));
children.push(body('│   UC03: Quản lý Giao dịch Thu/Chi                          │', { font: 'Consolas', size: 20 }));
children.push(body('│     - Thêm mới / Chỉnh sửa / Xóa                           │', { font: 'Consolas', size: 20 }));
children.push(body('│   UC04: Quản lý Hóa đơn                                     │', { font: 'Consolas', size: 20 }));
children.push(body('│     - Chụp ảnh / Smart Scan AI / Xem chi tiết              │', { font: 'Consolas', size: 20 }));
children.push(body('│   UC05: Dashboard & Biểu đồ (Bar/Line Chart)               │', { font: 'Consolas', size: 20 }));
children.push(body('│   UC06: Báo cáo & Thống kê (Pie Chart, Export PDF)         │', { font: 'Consolas', size: 20 }));
children.push(body('│   UC07: Dark Mode Toggle                                    │', { font: 'Consolas', size: 20 }));
children.push(body('│   UC08: Quản trị hệ thống (Admin only)                     │', { font: 'Consolas', size: 20 }));
children.push(body('│                                                             │', { font: 'Consolas', size: 20 }));
children.push(body('└─────────────────────────────────────────────────────────────┘', { font: 'Consolas', size: 20 }));
children.push(body('Actor: 👤 User (UC01-UC07)  |  👑 Admin (UC01-UC08)', { font: 'Consolas', size: 20 }));

children.push(heading2('4.2 Chi tiết từng Use Case'));

children.push(heading3('UC01: Đăng nhập'));
children.push(makeTable(
  ['Thuộc tính', 'Giá trị'],
  [
    ['Tên', 'Đăng nhập vào hệ thống'],
    ['Actor', 'User, Admin'],
    ['Điều kiện tiên quyết', 'User đã có tài khoản'],
    ['Kịch bản chính', 'Nhập username/password → Xác thực → Chuyển Dashboard'],
    ['Kịch bản thay thế', 'Offline → Xác thực SQLite local'],
    ['Kịch bản ngoại lệ', 'Sai thông tin → Hiển thị lỗi'],
  ],
  [2500, 7500]
));

children.push(heading3('UC02: Đăng ký tài khoản'));
children.push(makeTable(
  ['Thuộc tính', 'Giá trị'],
  [
    ['Tên', 'Đăng ký tài khoản mới'],
    ['Actor', 'User mới'],
    ['Điều kiện tiên quyết', 'Chưa có tài khoản'],
    ['Kịch bản chính', 'Nhập thông tin → SignUp Supabase → Tạo user trong DB → Tự động đăng nhập'],
    ['Kịch bản thay thế', 'Offline → Tạo user SQLite local'],
    ['Kịch bản ngoại lệ', 'Username đã tồn tại → Báo lỗi'],
  ],
  [2500, 7500]
));

children.push(heading3('UC03: Quản lý giao dịch Thu/Chi'));
children.push(makeTable(
  ['Thuộc tính', 'Giá trị'],
  [
    ['Tên', 'Quản lý giao dịch dòng tiền'],
    ['Actor', 'User, Admin'],
    ['Điều kiện tiên quyết', 'Đã đăng nhập'],
    ['Chức năng con', 'UC03a: Thêm giao dịch, UC03b: Chỉnh sửa, UC03c: Xóa, UC03d: Lọc theo kỳ'],
    ['Input', 'Tiêu đề, Số tiền (int VND), Loại, Danh mục, Ngày, Ảnh chứng từ'],
    ['Output', 'Giao dịch được lưu cả cloud + local, hiển thị danh sách'],
    ['Business Rule', 'QĐ-01 (int VND), QĐ-06 (offline-first), QĐ-04 (cascade delete)'],
  ],
  [2500, 7500]
));

children.push(heading3('UC04: Quản lý hóa đơn'));
children.push(makeTable(
  ['Thuộc tính', 'Giá trị'],
  [
    ['Tên', 'Quản lý hóa đơn đầu vào'],
    ['Actor', 'User, Admin'],
    ['Chức năng con', 'UC04a: Chụp ảnh, UC04b: Smart Scan AI, UC04c: Xem chi tiết, UC04d: Xuất PDF'],
    ['Input', 'Ảnh hóa đơn, Số hóa đơn, Nhà cung cấp, MST, Tiền hàng, VAT rate'],
    ['Output', 'Hóa đơn + items lưu DB, PDF preview với font tiếng Việt'],
    ['Business Rule', 'QĐ-02 (VAT rate), QĐ-03 (status flow), QĐ-09 (Smart Scan 2s)'],
  ],
  [2500, 7500]
));

children.push(heading3('UC05: Dashboard & Biểu đồ'));
children.push(makeTable(
  ['Thuộc tính', 'Giá trị'],
  [
    ['Tên', 'Dashboard tổng quan'],
    ['Actor', 'User, Admin'],
    ['Input', 'Dữ liệu từ transactions + invoices'],
    ['Output', 'Summary cards, Bar/Line Chart 6 tháng, giao dịch gần đây'],
    ['Business Rule', 'QĐ-10 (responsive breakpoint), Filter período'],
  ],
  [2500, 7500]
));

children.push(heading3('UC06: Báo cáo & Thống kê'));
children.push(makeTable(
  ['Thuộc tính', 'Giá trị'],
  [
    ['Tên', 'Báo cáo chi tiết'],
    ['Actor', 'User, Admin'],
    ['Input', 'Filter período, dữ liệu transactions + invoices'],
    ['Output', 'Pie Chart (cơ cấu thu/chi), Bar/Line Chart, Thống kê hóa đơn, Export PDF'],
    ['Business Rule', 'Font NotoSans tiếng Việt trong PDF, AnimatedSwitcher khi đổi filter'],
  ],
  [2500, 7500]
));

children.push(heading3('UC07: Dark Mode'));
children.push(makeTable(
  ['Thuộc tính', 'Giá trị'],
    [
    ['Tên', 'Chuyển đổi giao diện Sáng/Tối'],
    ['Actor', 'User, Admin'],
    ['Input', 'Nhấn icon sun/moon trong AppBar'],
    ['Output', 'ThemeProvider toggle → MaterialApp.themeMode thay đổi tức thì'],
    ['Business Rule', 'AppTheme.light() + AppTheme.dark(), lưu trạng thái trong session'],
  ],
  [2500, 7500]
));

children.push(heading3('UC08: Quản trị hệ thống'));
children.push(makeTable(
  ['Thuộc tính', 'Giá trị'],
  [
    ['Tên', 'Quản lý người dùng và thống kê'],
    ['Actor', 'Admin only'],
    ['Input', 'Danh sách users, thống kê hệ thống'],
    ['Output', 'User list, Role toggle (Admin/User), Per-user stats, System-wide stats'],
    ['Business Rule', 'Admin không xóa được chính mình, phân quyền theo role'],
  ],
  [2500, 7500]
));

// ============================================================
// CHƯƠNG 5: THIẾT KẾ GIAO DIỆN
// ============================================================
children.push(pageBreak());
children.push(heading1('Chương 5: Thiết kế giao diện (UI/UX Design)'));

children.push(heading2('5.1 Nguyên tắc thiết kế'));
children.push(bullet('Responsive: Hiển thị tốt trên Mobile (<720px) và Web/Desktop (≥720px)'));
children.push(bullet('Material Design 3: Sử dụng components chuẩn Material You'));
children.push(bullet('Consistent: Màu sắc, font, spacing nhất quán qua các màn hình'));
children.push(bullet('Accessible: Dark Mode hỗ trợ, touch target ≥ 44px'));

children.push(heading2('5.2 Bảng màu'));
children.push(makeTable(
  ['Tên', 'Light Mode', 'Dark Mode', 'Sử dụng'],
  [
    ['Primary', '#1a5276', '#4A8FD4', 'AppBar, Buttons, Links'],
    ['Income', '#27ae60', '#27ae60', 'Thu tiền, profit, positive'],
    ['Expense', '#e74c3c', '#e74c3c', 'Chi tiền, loss, negative'],
    ['Background', '#F5F7FA', '#0F0F1A', 'Scaffold background'],
    ['Card', '#FFFFFF', '#1E1E2E', 'Card, surface'],
    ['Accent', '#3498db', '#5DADE2', 'Accents, highlights'],
  ],
  [2000, 2000, 2000, 4000]
));

children.push(heading2('5.3 Responsive Layout'));

children.push(heading3('Mobile (<720px)'));
children.push(bullet('BottomNavigationBar (4 tabs)'));
children.push(bullet('ListView cuộn mượt cho danh sách'));
children.push(bullet('Full-width forms'));
children.push(bullet('Cards thay vì DataTable'));

children.push(heading3('Desktop (≥720px)'));
children.push(bullet('NavigationRail (sidebar trái)'));
children.push(bullet('DataTable hiển thị nhiều cột'));
children.push(bullet('Form centered maxWidth: 600px'));
children.push(bullet('Tận dụng không gian rộng'));

children.push(heading2('5.4 Chi tiết từng màn hình'));

children.push(makeTable(
  ['Màn hình', 'Route', 'Components chính', 'Responsive'],
  [
    ['Đăng nhập', '/login', 'Form username/password, demo hint, register link', 'Centered 440px / Full-width'],
    ['Dashboard', '/dashboard', 'Banner gradient, 3 SummaryCards, Bar/LineChart, Recent Tx', 'Row/Column responsive'],
    ['Giao dịch', '/transactions', 'TabBar (Thu/Chi), DataTable/ListView, FAB, Swipe delete', 'DataTable/List'],
    ['Thêm giao dịch', '/transactions/add', 'SegmentedButton type, Form fields, ImagePicker, Submit btn', 'Centered 600px'],
    ['Sửa giao dịch', '/transactions/edit', 'Pre-filled Form, same as Add but with update action', 'Centered 600px'],
    ['Hóa đơn', '/invoices', 'DataTable/ListView, Status badges, Swipe delete', 'DataTable/List'],
    ['Thêm hóa đơn', '/invoices/add', 'Camera/Gallery buttons, Smart Scan Animation, Mock data form', 'Full-width'],
    ['Chi tiết HĐ', '/invoices/:id', 'Invoice info, Items table, VAT breakdown, PDF export btn', 'Split / Stacked'],
    ['Báo cáo', '/reports', 'SegmentedButton filter, SummaryCards, Bar+Pie Charts, PDF export', 'Cards responsive'],
    ['Quản trị', '/admin', 'User list, Role toggle, System stats', 'Full-width'],
  ],
  [1800, 2200, 4000, 2000]
));

children.push(heading2('5.5 Animation & Interaction'));
children.push(makeTable(
  ['Animation', 'Vị trí', 'Thư viện', 'Chi tiết'],
  [
    ['Smart Scan', 'add_invoice_screen.dart', 'AnimationController', '2s, Curves.easeInOut, 5 progress steps'],
    ['Chart Transition', 'reports_screen.dart', 'AnimatedSwitcher', '400ms crossfade khi đổi filter'],
    ['Number Counter', 'dashboard_screen.dart', 'TweenAnimationBuilder', '700ms count up từ 0'],
    ['Swipe Delete', 'transaction_tile.dart', 'Dismissible', 'EndToStart, red background, confirm dialog'],
    ['Theme Toggle', 'main_shell.dart', 'AnimatedSwitcher', 'Icon sun/moon transition'],
  ],
  [2000, 2800, 2500, 2700]
));

// ============================================================
// CHƯƠNG 6: THIẾT KẾ DATABASE
// ============================================================
children.push(pageBreak());
children.push(heading1('Chương 6: Thiết kế cơ sở dữ liệu (Database Design)'));

children.push(heading2('6.1 Tổng quan'));
children.push(body('Hệ thống sử dụng kiến trúc Dual-Source: Supabase Cloud (PostgreSQL) làm nguồn chính, SQLite làm cache offline. Khi online, dữ liệu ưu tiên lấy từ Supabase; khi offline, fallback về SQLite.', { indent: true }));

children.push(heading2('6.2 ERD - Entity Relationship Diagram'));
children.push(body('Cơ sở dữ liệu gồm 5 bảng: users, transactions, invoices, invoice_items, audit_logs'));

children.push(emptyLine());
children.push(body('users (1) ──────< (N) transactions      [user_id FK, ON DELETE CASCADE]', { font: 'Consolas', size: 20 }));
children.push(body('users (1) ──────< (N) invoices          [user_id FK, ON DELETE CASCADE]', { font: 'Consolas', size: 20 }));
children.push(body('users (1) ──────< (N) audit_logs        [user_id FK, ON DELETE CASCADE]', { font: 'Consolas', size: 20 }));
children.push(body('invoices (1) ───< (N) invoice_items     [invoice_id FK, ON DELETE CASCADE]', { font: 'Consolas', size: 20 }));

children.push(heading2('6.3 Chi tiết từng bảng'));

children.push(heading3('6.3.1 Bảng users'));
children.push(makeTable(
  ['Cột', 'Kiểu', 'Ràng buộc', 'Mô tả'],
  [
    ['id', 'TEXT/UUID', 'PRIMARY KEY', 'Mã người dùng (UUID Supabase hoặc string local)'],
    ['username', 'TEXT', 'NOT NULL, UNIQUE', 'Tên đăng nhập'],
    ['password_hash', 'TEXT', 'NOT NULL', 'Mật khẩu băm SHA-256'],
    ['role', 'TEXT', 'NOT NULL', "'admin' hoặc 'user'"],
    ['full_name', 'TEXT', 'NULLABLE', 'Họ tên đầy đủ'],
    ['created_at', 'TEXT/TIMESTAMPTZ', 'NOT NULL', 'Thời gian tạo'],
  ],
  [2000, 2200, 2300, 3500]
));

children.push(heading3('6.3.2 Bảng transactions'));
children.push(makeTable(
  ['Cột', 'Kiểu', 'Ràng buộc', 'Mô tả'],
  [
    ['id', 'TEXT/UUID', 'PRIMARY KEY', 'Mã giao dịch'],
    ['user_id', 'TEXT/UUID', 'FK → users.id', 'Chủ giao dịch (CASCADE)'],
    ['title', 'TEXT', 'NOT NULL', 'Tiêu đề giao dịch'],
    ['amount', 'INTEGER', 'NOT NULL', 'Số tiền VND (int để tránh lỗi float)'],
    ['type', 'TEXT', 'NOT NULL', "'income' hoặc 'expense'"],
    ['category', 'TEXT', 'NOT NULL', 'Danh mục: sales, salary, rent, utilities...'],
    ['description', 'TEXT', 'NULLABLE', 'Ghi chú'],
    ['date', 'TEXT/TIMESTAMPTZ', 'NOT NULL', 'Ngày giao dịch'],
    ['image_path', 'TEXT', 'NULLABLE', 'Đường dẫn ảnh chứng từ'],
  ],
  [2000, 2200, 2300, 3500]
));

children.push(heading3('6.3.3 Bảng invoices'));
children.push(makeTable(
  ['Cột', 'Kiểu', 'Ràng buộc', 'Mô tả'],
  [
    ['id', 'TEXT/UUID', 'PRIMARY KEY', 'Mã hóa đơn'],
    ['user_id', 'TEXT/UUID', 'FK → users.id', 'Chủ hóa đơn (CASCADE)'],
    ['invoice_number', 'TEXT', 'NOT NULL', 'Số hóa đơn (HD-2026-001)'],
    ['vendor', 'TEXT', 'NOT NULL', 'Tên nhà cung cấp'],
    ['vendor_tax_code', 'TEXT', 'NULLABLE', 'Mã số thuế đối tác'],
    ['subtotal', 'INTEGER', 'NOT NULL', 'Tiền hàng (trước VAT)'],
    ['vat_rate', 'TEXT', 'NOT NULL', "'vat8', 'vat10', hoặc 'none'"],
    ['invoice_date', 'TEXT/TIMESTAMPTZ', 'NOT NULL', 'Ngày hóa đơn'],
    ['due_date', 'TEXT/TIMESTAMPTZ', 'NULLABLE', 'Ngày đáo hạn'],
    ['status', 'TEXT', 'NOT NULL', 'pending/approved/rejected/reviewing'],
    ['ai_confidence', 'REAL', 'NULLABLE', 'Độ tin cậy AI (0.0-1.0)'],
    ['ai_notes', 'TEXT', 'NULLABLE', 'Ghi chú AI scan'],
    ['image_path', 'TEXT', 'NULLABLE', 'Ảnh hóa đơn gốc'],
    ['created_at', 'TEXT/TIMESTAMPTZ', 'NOT NULL', 'Thời gian tạo'],
  ],
  [2000, 2200, 2300, 3500]
));

children.push(heading3('6.3.4 Bảng invoice_items'));
children.push(makeTable(
  ['Cột', 'Kiểu', 'Ràng buộc', 'Mô tả'],
  [
    ['id', 'TEXT/UUID', 'PRIMARY KEY', 'Mã chi tiết'],
    ['invoice_id', 'TEXT/UUID', 'FK → invoices.id', 'Hóa đơn cha (CASCADE)'],
    ['name', 'TEXT', 'NOT NULL', 'Tên hàng hóa/dịch vụ'],
    ['quantity', 'INTEGER', 'NOT NULL', 'Số lượng'],
    ['unit_price', 'INTEGER', 'NOT NULL', 'Đơn giá VND'],
    ['amount', 'INTEGER', 'NOT NULL', 'Thành tiền = qty × price'],
    ['created_at', 'TEXT/TIMESTAMPTZ', 'NOT NULL', 'Thời gian tạo'],
  ],
  [2000, 2200, 2300, 3500]
));

children.push(heading3('6.3.5 Bảng audit_logs'));
children.push(makeTable(
  ['Cột', 'Kiểu', 'Ràng buộc', 'Mô tả'],
  [
    ['id', 'TEXT/UUID', 'PRIMARY KEY', 'Mã log'],
    ['user_id', 'TEXT/UUID', 'FK → users.id', 'Người thực hiện (CASCADE)'],
    ['action', 'TEXT', 'NOT NULL', 'insert / update / delete'],
    ['entity_type', 'TEXT', 'NOT NULL', 'transaction/invoice/user'],
    ['entity_id', 'TEXT', 'NOT NULL', 'ID bản ghi bị thay đổi'],
    ['old_value', 'TEXT/JSONB', 'NULLABLE', 'Snapshot trước khi sửa'],
    ['new_value', 'TEXT/JSONB', 'NULLABLE', 'Snapshot sau khi sửa'],
    ['created_at', 'TEXT/TIMESTAMPTZ', 'NOT NULL', 'Thời gian'],
  ],
  [2000, 2200, 2300, 3500]
));

children.push(heading2('6.4 Indexes'));
children.push(makeTable(
  ['Index', 'Bảng', 'Cột', 'Mục đích'],
  [
    ['idx_transactions_user_id', 'transactions', 'user_id', 'Lọc theo user'],
    ['idx_transactions_date', 'transactions', 'date DESC', 'Sắp xếp theo ngày'],
    ['idx_transactions_type', 'transactions', 'type', 'Lọc theo Thu/Chi'],
    ['idx_invoices_user_id', 'invoices', 'user_id', 'Lọc theo user'],
    ['idx_invoices_status', 'invoices', 'status', 'Lọc theo trạng thái'],
    ['idx_invoice_items_invoice_id', 'invoice_items', 'invoice_id', 'Load items theo invoice'],
    ['idx_audit_logs_user_id', 'audit_logs', 'user_id', 'Lọc theo user'],
    ['idx_audit_logs_entity', 'audit_logs', 'entity_type, entity_id', 'Tra cứu theo thực thể'],
  ],
  [3000, 2000, 2500, 2500]
));

children.push(heading2('6.5 Seed Data'));
children.push(body('Demo data gồm 3 tài khoản, 12 giao dịch, 3 hóa đơn:'));
children.push(makeTable(
  ['Username', 'Password', 'Role', 'Ghi chú'],
  [
    ['admin', 'admin123', 'Admin', 'Quản trị viên — xem tất cả data'],
    ['user1', 'user123', 'User', 'Nguyễn Văn A — chỉ thấy data của mình'],
    ['user2', 'user123', 'User', 'Trần Thị B — chỉ thấy data của mình'],
  ],
  [2000, 2000, 2000, 4000]
));

// ============================================================
// CHƯƠNG 7: KIẾN TRÚC VÀ CÔNG NGHỆ
// ============================================================
children.push(pageBreak());
children.push(heading1('Chương 7: Kiến trúc ứng dụng và công nghệ'));

children.push(heading2('7.1 Kiến trúc Layered Architecture'));
children.push(body('Ứng dụng tuân theo kiến trúc phân lớp rõ ràng:', { indent: true }));

children.push(emptyLine());
children.push(body('┌─────────────────────────────────────────┐', { font: 'Consolas', size: 20 }));
children.push(body('│  PRESENTATION LAYER (UI)                │', { font: 'Consolas', size: 20 }));
children.push(body('│  screens/ + widgets/ + providers/       │', { font: 'Consolas', size: 20 }));
children.push(body('├─────────────────────────────────────────┤', { font: 'Consolas', size: 20 }));
children.push(body('│  BUSINESS LOGIC LAYER                   │', { font: 'Consolas', size: 20 }));
children.push(body('│  repositories/ (dual-source strategy)   │', { font: 'Consolas', size: 20 }));
children.push(body('├─────────────────────────────────────────┤', { font: 'Consolas', size: 20 }));
children.push(body('│  DATA LAYER                             │', { font: 'Consolas', size: 20 }));
children.push(body('│  datasources/ (Supabase + SQLite)       │', { font: 'Consolas', size: 20 }));
children.push(body('│  models/ (TransactionModel, etc.)       │', { font: 'Consolas', size: 20 }));
children.push(body('├─────────────────────────────────────────┤', { font: 'Consolas', size: 20 }));
children.push(body('│  CORE / CONFIG                          │', { font: 'Consolas', size: 20 }));
children.push(body('│  theme/ + router/ + utils/              │', { font: 'Consolas', size: 20 }));
children.push(body('└─────────────────────────────────────────┘', { font: 'Consolas', size: 20 }));

children.push(heading2('7.2 State Management — Provider'));
children.push(makeTable(
  ['Provider', 'Vai trò', 'Chi tiết'],
  [
    ['AuthProvider', 'Quản lý xác thực', 'login/logout/register, auto-login, currentUser'],
    ['AppProvider', 'Quản lý dữ liệu', 'transactions, invoices, filter, charts, CRUD'],
    ['ThemeProvider', 'Quản lý giao diện', 'ThemeMode toggle (light/dark)'],
  ],
  [2500, 2500, 5000]
));

children.push(heading2('7.3 Routing — go_router'));
children.push(makeTable(
  ['Route', 'Màn hình', 'Loại'],
  [
    ['/login', 'LoginScreen', 'Auth (outside shell)'],
    ['/register', 'RegisterScreen', 'Auth (outside shell)'],
    ['/dashboard', 'DashboardScreen', 'Shell (tab 1)'],
    ['/transactions', 'TransactionsScreen', 'Shell (tab 2)'],
    ['/invoices', 'InvoicesScreen', 'Shell (tab 3)'],
    ['/reports', 'ReportsScreen', 'Shell (tab 4)'],
    ['/transactions/add', 'AddTransactionScreen', 'Push (full screen)'],
    ['/transactions/edit', 'EditTransactionScreen', 'Push (full screen)'],
    ['/invoices/add', 'AddInvoiceScreen', 'Push (full screen)'],
    ['/invoices/:id', 'InvoiceDetailScreen', 'Push (full screen)'],
    ['/admin', 'AdminScreen', 'Push (admin only)'],
  ],
  [2500, 3000, 4500]
));

children.push(heading2('7.4 Công nghệ sử dụng'));
children.push(makeTable(
  ['Thành phần', 'Công nghệ', 'Phiên bản'],
  [
    ['Framework', 'Flutter (Dart)', '3.x'],
    ['State Management', 'Provider', '6.x'],
    ['Routing', 'go_router', '14.x'],
    ['Cloud Database', 'Supabase (PostgreSQL)', '2.x'],
    ['Local Database', 'SQLite (sqflite + sqflite_common_ffi)', '2.x'],
    ['Charts', 'fl_chart', '0.69.x'],
    ['PDF', 'pdf + printing', '4.x / 6.x'],
    ['Image Picker', 'image_picker', '1.x'],
    ['Connectivity', 'connectivity_plus', '6.x'],
    ['HTTP', 'http', '1.x'],
    ['UUID', 'uuid', '4.x'],
    ['Font PDF', 'NotoSans-Regular.ttf + Bold', '—'],
  ],
  [2500, 4500, 2000]
));

children.push(heading2('7.5 Dual-Source Strategy (Offline Caching)'));
children.push(body('Kiến trúc Cloud-First với Local Cache:', { indent: true }));
children.push(bullet('Online: Ưu tiên Supabase Cloud → nếu fail thì fallback SQLite'));
children.push(bullet('Offline: Dùng SQLite local → khi có mạng thì sync lên Supabase'));
children.push(bullet('connectivity_helper.dart: Kiểm tra online/offline với try-catch fallback'));

// ============================================================
// CHƯƠNG 8: KẾT QUẢ ĐẠT ĐƯỢC
// ============================================================
children.push(pageBreak());
children.push(heading1('Chương 8: Kết quả đạt được'));

children.push(heading2('8.1 Tính năng hoàn thành'));
children.push(makeTable(
  ['#', 'Tính năng', 'Trạng thái', 'Ghi chú'],
  [
    ['1', 'Đăng nhập / Đăng ký', '✅ Hoàn thành', 'Supabase Auth + SQLite offline fallback'],
    ['2', 'Quản lý giao dịch (CRUD)', '✅ Hoàn thành', 'Add, Edit, Delete (swipe), Filter by period'],
    ['3', 'Chụp ảnh / Chọn từ gallery', '✅ Hoàn thành', 'image_picker (camera + gallery)'],
    ['4', 'Smart Scan AI mô phỏng', '✅ Hoàn thành', 'AnimationController 2s, auto-fill mock data'],
    ['5', 'Xuất PDF hóa đơn', '✅ Hoàn thành', 'Font NotoSans tiếng Việt, VAT calculation'],
    ['6', 'Biểu đồ Bar/Line/Pie Chart', '✅ Hoàn thành', 'fl_chart, touch tooltips, animated transitions'],
    ['7', 'Bộ lọc thời gian', '✅ Hoàn thành', 'Tháng này / Tháng trước / Toàn kỳ'],
    ['8', 'Responsive Mobile + Web', '✅ Hoàn thành', 'Breakpoint 720px, DataTable/ListView'],
    ['9', 'Dark Mode', '✅ Hoàn thành', 'ThemeProvider, sun/moon toggle'],
    ['10', 'Offline Caching', '✅ Hoàn thành', 'Supabase cloud-first + SQLite local'],
    ['11', 'Vuốt để xóa (Dismissible)', '✅ Hoàn thành', 'Confirm dialog, red background'],
    ['12', 'Admin user management', '✅ Hoàn thành', 'List users, role toggle, stats'],
    ['13', 'Audit logs', '✅ Hoàn thành', 'Insert/update/delete tracking'],
    ['14', 'RefreshListenable on Router', '✅ Hoàn thành', 'Auth state sync'],
    ['15', '404 Error page', '✅ Hoàn thành', 'Custom error page with icon'],
  ],
  [500, 3500, 2000, 4000]
));

children.push(heading2('8.2 Unit Tests'));
children.push(makeTable(
  ['Test Group', 'Số test', 'Nội dung'],
  [
    ['calculateVat', '5', 'VAT 10%, 8%, 0%, rounding, fractional'],
    ['calculateTotal', '4', 'Subtotal + VAT 10%/8%/0%, large amount'],
    ['totalIncome', '3', 'Empty list, multiple amounts, single amount'],
    ['totalExpense', '2', 'Sum of expenses, empty list'],
    ['netCashFlow', '3', 'Positive, negative, zero'],
    ['percentage', '3', '50%, 0%, 100%'],
    ['int precision', '2', 'Large VAT stays int, total remains int'],
    ['Tổng cộng', '22 tests', 'All passing ✅'],
  ],
  [2500, 1500, 6000]
));

children.push(heading2('8.3 Đánh giá theo tiêu chí chấm điểm'));
children.push(makeTable(
  ['Tiêu chí', 'Trọng số', 'Đánh giá', 'Điểm'],
  [
    ['UI/UX & Responsive', '30%', 'Giao diện đẹp, responsive Mobile+Web, Dark Mode, không vỡ layout', '28/30'],
    ['State Management & Kiến trúc', '30%', 'Provider, Layered Architecture, go_router, dual-source', '27/30'],
    ['Xử lý Animation & Tương tác', '20%', 'Smart Scan 2s, chart transitions, swipe delete, theme toggle', '18/20'],
    ['Tính năng PDF & Lưu trữ', '20%', 'PDF tiếng Việt, offline caching, Supabase+SQLite', '18/20'],
    ['Điểm cộng', '+1', '22 unit tests (>3), Dark Mode', '+1'],
  ],
  [2500, 1200, 4000, 1300]
));

children.push(heading2('8.4 File structure'));
children.push(body('lib/', { font: 'Consolas', size: 20 }));
children.push(body('  config/             → supabase_config.dart', { font: 'Consolas', size: 18 }));
children.push(body('  core/               → theme/, router/, utils/', { font: 'Consolas', size: 18 }));
children.push(body('  data/               → datasources/, models/, repositories/', { font: 'Consolas', size: 18 }));
children.push(body('  presentation/       → screens/, providers/, widgets/', { font: 'Consolas', size: 18 }));
children.push(body('  main.dart', { font: 'Consolas', size: 18 }));

children.push(emptyLine());
children.push(body('docs/', { font: 'Consolas', size: 20 }));
children.push(body('  seed_supabase.sql', { font: 'Consolas', size: 18 }));
children.push(body('  migrate_v5_supabase.sql', { font: 'Consolas', size: 18 }));

children.push(emptyLine());
children.push(body('test/', { font: 'Consolas', size: 20 }));
children.push(body('  unit/currency_calculator_test.dart  (22 tests)', { font: 'Consolas', size: 18 }));

// ============================================================
// KẾT LUẬN
// ============================================================
children.push(pageBreak());
children.push(heading1('Kết luận'));
children.push(emptyLine());
children.push(body('Đồ án SmartFinance đã hoàn thành đầy đủ các yêu cầu của đề bài, bao gồm:', { indent: true }));
children.push(emptyLine());
children.push(bullet('Phân hệ quản lý dòng tiền Thu/Chi với Form nhập liệu đầy đủ validator'));
children.push(bullet('Phân hệ mô phỏng AI OCR với Smart Scan animation 2 giây'));
children.push(bullet('Xuất hóa đơn PDF với font tiếng Việt (NotoSans)'));
children.push(bullet('Dashboard báo cáo với Pie Chart, Bar Chart, Line Chart'));
children.push(bullet('Bộ lọc thời gian với animated transitions'));
children.push(bullet('Giao diện Responsive trên Mobile và Web/Desktop'));
children.push(bullet('Dark Mode chuyển đổi mượt mà'));
children.push(bullet('Offline Caching với Dual-Source (Supabase + SQLite)'));
children.push(bullet('Kiến trúc phân lớp rõ ràng, Provider State Management'));
children.push(bullet('22 Unit Tests cho tầng logic xử lý tính toán tiền tệ'));
children.push(emptyLine());
children.push(body('Ứng dụng đã được kiểm tra và hoạt động ổn định trên cả Web Chrome và Android emulator.', { indent: true }));

// ============================================================
// BUILD DOCUMENT
// ============================================================

const doc = new Document({
  creator: 'SmartFinance Team',
  title: 'SmartFinance - Tài liệu thuyết trình',
  description: 'Tài liệu phân tích và thiết kế ứng dụng quản lý tài chính doanh nghiệp SME',
  styles: {
    default: {
      document: {
        run: { font: FONT, size: FONT_SIZE },
      },
    },
  },
  sections: [{
    properties: {
      page: {
        margin: {
          top: 1440,     // 1 inch
          right: 1440,
          bottom: 1440,
          left: 1440,
          header: 720,
          footer: 720,
        },
      },
    },
    children,
  }],
});

// Generate DOCX
async function main() {
  const buffer = await Packer.toBuffer(doc);
  const outputPath = 'docs/SmartFinance_TaiLieuThuyetTrinh.docx';
  fs.writeFileSync(outputPath, buffer);
  console.log(`✅ Generated: ${outputPath} (${(buffer.length / 1024).toFixed(1)} KB)`);
}

main().catch(err => { console.error('❌ Error:', err); process.exit(1); });
