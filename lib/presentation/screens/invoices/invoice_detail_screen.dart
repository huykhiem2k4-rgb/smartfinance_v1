import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/invoice_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});
  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  InvoiceModel? _invoice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final inv = await context.read<AppProvider>().getInvoice(widget.invoiceId);
    if (mounted) setState(() => _invoice = inv);
  }

  Future<void> _updateStatus(InvoiceStatus newStatus) async {
    if (_invoice == null) return;
    final updated = _invoice!.copyWith(status: newStatus);
    await context.read<AppProvider>().updateInvoice(updated);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == InvoiceStatus.approved ? 'Đã duyệt hóa đơn' : 'Đã từ chối hóa đơn'),
          backgroundColor: newStatus == InvoiceStatus.approved ? AppColors.income : AppColors.expense,
        ),
      );
    }
  }

  static const _companyName = 'SmartFinance';
  static const _companyTaxCode = '0123456789';
  static const _companyAddress = '123 Nguyen Hue, District 1, HCMC';
  static const _companyPhone = '028 1234 5678';
  static const _companyBankAccount = '1234567890123';

  static String _numberToWords(int amount) {
    if (amount == 0) return 'Khong dong';
    final ones = ['', 'mot', 'hai', 'ba', 'bon', 'nam', 'sau', 'bay', 'tam', 'chin'];

    String readThreeDigits(int n) {
      if (n == 0) return '';
      final h = n ~/ 100;
      final r = n % 100;
      final t = r ~/ 10;
      final u = r % 10;
      final buf = StringBuffer();
      if (h > 0) {
        buf.write('${ones[h]} tram');
      }
      if (r > 0 && r < 10) {
        if (h > 0) buf.write(' le ');
        buf.write(ones[r]);
      } else if (r >= 10 && r < 20) {
        if (h > 0) buf.write(' muoi ');
        final teeenWords = ['muoi', 'muoi mot', 'muoi hai', 'muoi ba', 'muoi bon', 'muoi nam',
            'muoi sau', 'muoi bay', 'muoi tam', 'muoi chin'];
        buf.write(teeenWords[r - 10]);
      } else if (r >= 20) {
        buf.write(' muoi');
        if (t > 1) buf.write(' ${ones[t]}');
        if (u > 0) buf.write(' ${ones[u]}');
      }
      return buf.toString();
    }

    final parts = <String>[];
    if (amount >= 1000000000) {
      final b = amount ~/ 1000000000;
      parts.add('${readThreeDigits(b)} ty');
      amount %= 1000000000;
    }
    if (amount >= 1000000) {
      final m = amount ~/ 1000000;
      parts.add('${readThreeDigits(m)} trieu');
      amount %= 1000000;
    }
    if (amount >= 1000) {
      final t = amount ~/ 1000;
      parts.add('${readThreeDigits(t)} nghin');
      amount %= 1000;
    }
    if (amount > 0) {
      parts.add(readThreeDigits(amount));
    }
    final result = parts.where((p) => p.isNotEmpty).join(' ');
    return '${result[0].toUpperCase()}${result.substring(1)} dong';
  }

  Future<void> _exportPdf() async {
    final inv = _invoice!;

    // Load partner info
    final partners = context.read<AppProvider>().partners;
    final partner = inv.partnerId != null
        ? partners.where((p) => p.partnerId == inv.partnerId).firstOrNull
        : null;

    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final bold = pw.Font.ttf(boldData);

    final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));
    final now = inv.invoiceDate;

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (pw.Context ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // ── PART 1: COMPANY HEADER ──
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_companyName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 4),
            pw.Text('Mã số thuế: $_companyTaxCode', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Địa chỉ: $_companyAddress', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Điện thoại: $_companyPhone', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Số tài khoản: $_companyBankAccount', style: const pw.TextStyle(fontSize: 10)),
          ]),
        ]),
        pw.Divider(color: PdfColors.blue900, thickness: 2),
        pw.SizedBox(height: 10),

        // ── PART 2: INVOICE TITLE ──
        pw.Center(child: pw.Text('HÓA ĐƠN GIÁ TRỊ GIA TĂNG', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 6),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(_formatFullDate(now), style: const pw.TextStyle(fontSize: 10)),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Ký hiệu: 1K22TAB', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Số: ${inv.invoiceNumber}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ]),
        ]),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),

        // ── PART 3: BUYER INFO ──
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _labelValue('Họ tên người mua:', partner?.partnerName ?? 'N/A'),
            _labelValue('Tên đơn vị:', partner?.partnerName ?? 'N/A'),
            _labelValue('Địa chỉ:', partner?.address ?? 'N/A'),
            _labelValue('Mã số thuế:', partner?.taxCode ?? 'N/A'),
          ])),
          pw.SizedBox(width: 20),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _labelValue('Hình thức thanh toán:', 'TM/CK'),
            _labelValue('Số hợp đồng:', ''),
            _labelValue('Loại tiền:', 'VND'),
          ])),
        ]),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),

        // ── PART 4: ITEMS TABLE ──
        pw.Text('CHI TIẾT HÀNG HÓA, DỊCH VỤ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
          headerAlignment: pw.Alignment.center,
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.center,
          cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.center, 3: pw.Alignment.center, 4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight},
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          headers: ['STT', 'Tên hàng hóa, dịch vụ', 'ĐVT', 'Số lượng', 'Đơn giá', 'Thành tiền'],
          columnWidths: {0: const pw.FlexColumnWidth(0.5), 1: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(0.7), 3: const pw.FlexColumnWidth(0.7), 4: const pw.FlexColumnWidth(1.3), 5: const pw.FlexColumnWidth(1.5)},
          data: inv.items.isNotEmpty
              ? inv.items.asMap().entries.map((e) => [
                    '${e.key + 1}',
                    e.value.name,
                    e.value.unit ?? 'cái',
                    '${e.value.quantity}',
                    Formatters.currency(e.value.unitPrice),
                    Formatters.currency(e.value.total),
                  ]).toList()
              : List.generate(10, (i) => ['${i + 1}', '', '', '', '', '']),
        ),
        pw.SizedBox(height: 12),

        // ── PART 5: TOTALS ──
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            _totalRow('Cộng tiền hàng:', Formatters.currency(inv.subtotal)),
            pw.SizedBox(height: 2),
            _totalRow('Thuế suất GTGT (${inv.vatRate.label}):', ''),
            _totalRow('Tiền thuế GTGT:', Formatters.currency(inv.vatAmount)),
            pw.Divider(color: PdfColors.grey400),
            _totalRow('TỔNG TIỀN THANH TOÁN:', Formatters.currency(inv.totalAmount), bold: true),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'Bằng chữ: ${_numberToWords(inv.totalAmount)}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic),
              ),
            ),
          ]),
        ),
        pw.SizedBox(height: 20),

        // ── PART 6: SIGNATURES ──
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(children: [
            pw.Text('Người mua hàng', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text('(Chữ ký số nếu có)', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ]),
          pw.Column(children: [
            pw.Text('Người bán hàng', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text('(Ký tên, đóng dấu)', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ]),
        ]),
        pw.Spacer(),

        // ── PART 7: FOOTER ──
        pw.Divider(color: PdfColors.grey400),
        pw.Center(child: pw.Text(
          'SmartFinance © ${DateTime.now().year} — Hóa đơn được tạo tự động',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        )),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  static pw.Widget _labelValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(width: 90, child: pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
        pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
      ]),
    );
  }

  static pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    ]);
  }

  static String _formatFullDate(DateTime dt) => 'Ngày ${dt.day} tháng ${dt.month} năm ${dt.year}';

  @override
  Widget build(BuildContext context) {
    if (_invoice == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final inv = _invoice!;
    final statusColor = _statusColor(inv.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(inv.invoiceNumber),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: _exportPdf, tooltip: 'Xuất PDF'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(_statusIcon(inv.status), color: statusColor, size: 26),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(inv.status.label, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
            ]),
          ),
          const SizedBox(height: 14),

          _Section('Thông tin hóa đơn', Column(children: [
            _InfoRow('Số hóa đơn', inv.invoiceNumber),
            _InfoRow('Nhà cung cấp', inv.ocrText ?? 'Không rõ'),
            _InfoRow('Ngày lập', Formatters.date(inv.invoiceDate)),
            _InfoRow('Ghi chú', inv.note ?? ''),
          ])),
          const SizedBox(height: 12),

          _Section('Chi tiết hóa đơn & VAT', Column(children: [
            if (inv.items.isNotEmpty) ...[
              ...inv.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  const Icon(Icons.circle, size: 5, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13))),
                  Text('${item.quantity}x ${Formatters.shortAmount(item.unitPrice)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Text(Formatters.currency(item.total), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              )),
              const Divider(),
            ],
            _AmountRow('Tiền hàng (chưa VAT)', inv.subtotal, Colors.grey),
            _AmountRow('Thuế VAT (${inv.vatRate.label})', inv.vatAmount, AppColors.warning),
            _AmountRow('TỔNG THANH TOÁN', inv.totalAmount, AppColors.primary, bold: true),
          ])),
          const SizedBox(height: 12),

          if (inv.ocrText != null && inv.ocrText!.isNotEmpty)
            _Section('Kết quả OCR', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 12),
              Text(inv.ocrText!, style: const TextStyle(fontSize: 13, height: 1.6)),
            ])),

          if (inv.status == InvoiceStatus.pending && context.read<AuthProvider>().isAdmin) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Duyệt'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.income, foregroundColor: Colors.white),
                onPressed: () => _updateStatus(InvoiceStatus.approved),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel),
                label: const Text('Từ chối'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
                onPressed: () => _updateStatus(InvoiceStatus.rejected),
              )),
            ]),
          ],

          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Color _statusColor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.approved: return AppColors.income;
      case InvoiceStatus.rejected: return AppColors.expense;
      case InvoiceStatus.draft: return Colors.grey;
      case InvoiceStatus.pending: return AppColors.warning;
    }
  }

  IconData _statusIcon(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.approved: return Icons.check_circle;
      case InvoiceStatus.rejected: return Icons.cancel;
      case InvoiceStatus.draft: return Icons.edit_note;
      case InvoiceStatus.pending: return Icons.hourglass_empty;
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section(this.title, this.child);
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
    const SizedBox(height: 10),
    child,
  ])));
}

class _InfoRow extends StatelessWidget {
  final String label; final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
    ]),
  );
}

class _AmountRow extends StatelessWidget {
  final String label; final int amount; final Color color; final bool bold;
  const _AmountRow(this.label, this.amount, this.color, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 14 : 13))),
      Text(Formatters.currency(amount), style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color, fontSize: bold ? 15 : 13)),
    ]),
  );
}
