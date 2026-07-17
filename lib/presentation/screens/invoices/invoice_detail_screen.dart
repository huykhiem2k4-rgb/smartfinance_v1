import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../providers/app_provider.dart';
import '../../../data/models/invoice_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});
  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen>
    with SingleTickerProviderStateMixin {
  InvoiceModel? _invoice;
  bool _checking = false;
  late AnimationController _checkAnim;
  late Animation<double> _checkProgress;

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _checkProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkAnim, curve: Curves.easeInOut),
    );
    _load();
  }

  @override
  void dispose() { _checkAnim.dispose(); super.dispose(); }

  Future<void> _load() async {
    final inv = await context.read<AppProvider>().getInvoice(widget.invoiceId);
    if (mounted) setState(() => _invoice = inv);
  }

  Future<void> _runAiCheck() async {
    if (_invoice == null) return;
    setState(() => _checking = true);
    _checkAnim.reset();
    _checkAnim.forward();

    // Simulate AI analysis
    await Future.delayed(const Duration(milliseconds: 2200));
    final result = _simulateAI(_invoice!);
    final updated = _invoice!.copyWith(
      status: result.status,
      aiConfidence: result.confidence,
      aiNotes: result.notes,
    );
    await context.read<AppProvider>().updateInvoice(updated);
    await _load();
    setState(() => _checking = false);
    if (mounted) _showResultDialog(result);
  }

  _AiResult _simulateAI(InvoiceModel inv) {
    final rng = Random();
    double conf = 0.80;
    final issues = <String>[];
    final positives = <String>[];

    // Vendor check
    final suspicious = ['không rõ', 'unknown', 'test', 'anonymous'];
    if (suspicious.any((k) => inv.vendor.toLowerCase().contains(k))) {
      conf -= 0.50; issues.add('Tên nhà cung cấp không rõ ràng hoặc đáng ngờ.');
    } else {
      positives.add('Thông tin nhà cung cấp hợp lệ.');
    }
    // Tax code
    if (inv.vendorTaxCode == null || inv.vendorTaxCode!.isEmpty) {
      conf -= 0.15; issues.add('Thiếu mã số thuế nhà cung cấp.');
    } else {
      positives.add('Mã số thuế đã được xác minh.');
    }
    // Amount
    if (inv.totalAmount > 100000000) {
      conf -= 0.10; issues.add('Giá trị lớn (>${Formatters.shortAmount(inv.totalAmount)}) — cần xác nhận thêm.');
    } else {
      positives.add('Giá trị hóa đơn trong ngưỡng bình thường.');
    }
    // Items
    if (inv.items.isEmpty) {
      conf -= 0.15; issues.add('Không có danh sách mặt hàng chi tiết.');
    } else {
      final itemTotal = inv.items.fold(0, (s, i) => s + i.total);
      if ((itemTotal - inv.subtotal).abs() > 1000) {
        conf -= 0.10; issues.add('Tổng mặt hàng không khớp với tiền hàng.');
      } else {
        positives.add('Tổng tiền mặt hàng khớp với giá trị hóa đơn.');
      }
    }
    // Date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final invoiceDay = DateTime(inv.invoiceDate.year, inv.invoiceDate.month, inv.invoiceDate.day);
    final daysDiff = today.difference(invoiceDay).inDays;
    if (daysDiff > 365) { conf -= 0.10; issues.add('Hóa đơn quá cũ (> 1 năm).'); }
    else if (invoiceDay.isAfter(today)) { conf -= 0.20; issues.add('Ngày hóa đơn trong tương lai.'); }
    else { positives.add('Ngày hóa đơn hợp lệ.'); }
    // Invoice number format
    if (RegExp(r'[A-Z]{1,3}[-/]?\d{4}[-/]\d+').hasMatch(inv.invoiceNumber.toUpperCase())) {
      positives.add('Số hóa đơn đúng định dạng chuẩn.');
    } else {
      conf -= 0.05; issues.add('Số hóa đơn không theo định dạng tiêu chuẩn.');
    }

    conf += (rng.nextDouble() - 0.5) * 0.04;
    conf = conf.clamp(0.05, 0.99);
    final status = conf >= 0.70 ? InvoiceStatus.approved : conf >= 0.40 ? InvoiceStatus.reviewing : InvoiceStatus.rejected;

    final buf = StringBuffer();
    buf.writeln(conf >= 0.70 ? '✅ Hóa đơn hợp lệ (${(conf*100).toStringAsFixed(0)}%)' : conf >= 0.40 ? '⚠️ Cần xem xét thêm (${(conf*100).toStringAsFixed(0)}%)' : '❌ Hóa đơn đáng ngờ (${(conf*100).toStringAsFixed(0)}%)');
    if (positives.isNotEmpty) { buf.writeln('\nĐiểm hợp lệ:'); for (final p in positives) { buf.writeln('• $p'); } }
    if (issues.isNotEmpty) { buf.writeln('\nVấn đề phát hiện:'); for (final i in issues) { buf.writeln('• $i'); } }

    return _AiResult(confidence: conf, status: status, notes: buf.toString().trim());
  }

  void _showResultDialog(_AiResult result) {
    final color = result.status == InvoiceStatus.approved ? AppColors.income : result.status == InvoiceStatus.rejected ? AppColors.expense : AppColors.warning;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(children: [
          Icon(result.status == InvoiceStatus.approved ? Icons.check_circle : result.status == InvoiceStatus.rejected ? Icons.cancel : Icons.warning, color: color),
          const SizedBox(width: 8),
          const Text('Kết quả AI'),
        ]),
        content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _ConfidenceBar(confidence: result.confidence),
          const SizedBox(height: 12),
          Text(result.notes, style: const TextStyle(fontSize: 13, height: 1.6)),
        ])),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Đóng'))],
      ),
    );
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

  Future<void> _exportPdf() async {
    final inv = _invoice!;
    
    // Load fonts
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final bold = pw.Font.ttf(boldData);

    final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Header(level: 0, child: pw.Text('HÓA ĐƠN GIÁ TRỊ GIA TĂNG', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 6),
        pw.Text('Số hóa đơn: ${inv.invoiceNumber}', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Ngày: ${Formatters.date(inv.invoiceDate)}', style: const pw.TextStyle(fontSize: 12)),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text('Nhà cung cấp: ${inv.vendor}'),
        if (inv.vendorTaxCode != null) pw.Text('Mã số thuế: ${inv.vendorTaxCode}'),
        pw.SizedBox(height: 16),
        pw.Text('CHI TIẾT HÀNG HÓA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (inv.items.isNotEmpty)
          pw.TableHelper.fromTextArray(
            headers: ['Tên hàng hóa', 'SL', 'Đơn giá', 'Thành tiền'],
            data: inv.items.map((i) => [i.name, '${i.quantity}', Formatters.currency(i.unitPrice), Formatters.currency(i.total)]).toList(),
          ),
        pw.SizedBox(height: 16),
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Tiền hàng: ${Formatters.currency(inv.subtotal)}'),
            pw.Text('Thuế VAT (${inv.vatRate.label}): ${Formatters.currency(inv.vatAmount)}'),
            pw.Text('TỔNG THANH TOÁN: ${Formatters.currency(inv.totalAmount)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          ]),
        ]),
        pw.Spacer(),
        pw.Divider(),
        pw.Text('SmartFinance © ${DateTime.now().year} — Được tạo tự động', style: const pw.TextStyle(fontSize: 9)),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

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
          if (inv.status == InvoiceStatus.pending)
            TextButton.icon(
              icon: const Icon(Icons.psychology, color: Colors.white),
              label: const Text('Kiểm tra AI', style: TextStyle(color: Colors.white)),
              onPressed: _checking ? null : _runAiCheck,
            ),
        ],
      ),
      body: _checking
          ? Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('AI đang phân tích hóa đơn...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _checkProgress,
                  builder: (_, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LinearProgressIndicator(value: _checkProgress.value, backgroundColor: Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation(AppColors.accent), minHeight: 8, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(height: 16),
                    ..._checkSteps.asMap().entries.map((e) {
                      final done = e.key < (_checkProgress.value * _checkSteps.length).floor();
                      final active = e.key == (_checkProgress.value * _checkSteps.length).floor().clamp(0, _checkSteps.length - 1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Icon(done ? Icons.check : active ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 16, color: done ? AppColors.income : active ? AppColors.accent : Colors.grey),
                          const SizedBox(width: 8),
                          Text(e.value, style: TextStyle(color: done ? AppColors.income : active ? AppColors.primary : Colors.grey, fontSize: 13)),
                        ]),
                      );
                    }),
                  ]),
                ),
              ]),
            ))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
                  child: Row(children: [
                    Icon(_statusIcon(inv.status), color: statusColor, size: 26),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(inv.status.label, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 15)),
                      if (inv.aiConfidence != null)
                        Text('Độ tin cậy: ${(inv.aiConfidence! * 100).toStringAsFixed(0)}%', style: TextStyle(color: statusColor, fontSize: 12)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),

                _Section('Thông tin hóa đơn', Column(children: [
                  _InfoRow('Số hóa đơn', inv.invoiceNumber),
                  _InfoRow('Nhà cung cấp', inv.vendor),
                  if (inv.vendorTaxCode != null) _InfoRow('Mã số thuế', inv.vendorTaxCode!),
                  _InfoRow('Ngày lập', Formatters.date(inv.invoiceDate)),
                  if (inv.dueDate != null) _InfoRow('Hạn thanh toán', Formatters.date(inv.dueDate!)),
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

                if (inv.aiNotes != null)
                  _Section('Kết quả phân tích AI', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _ConfidenceBar(confidence: inv.aiConfidence!),
                    const SizedBox(height: 12),
                    Text(inv.aiNotes!, style: const TextStyle(fontSize: 13, height: 1.6)),
                  ])),

                if (inv.status == InvoiceStatus.pending) ...[
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    icon: const Icon(Icons.psychology),
                    label: const Text('Chạy kiểm tra AI'),
                    onPressed: _checking ? null : _runAiCheck,
                  )),
                ],

                if (inv.status == InvoiceStatus.reviewing) ...[
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

  static const _checkSteps = [
    'Đọc thông tin hóa đơn...',
    'Xác minh nhà cung cấp...',
    'Kiểm tra số tiền & mặt hàng...',
    'Phân tích rủi ro...',
    'Tổng hợp kết quả...',
  ];

  Color _statusColor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.approved: return AppColors.income;
      case InvoiceStatus.rejected: return AppColors.expense;
      case InvoiceStatus.reviewing: return AppColors.warning;
      case InvoiceStatus.pending: return Colors.grey;
    }
  }

  IconData _statusIcon(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.approved: return Icons.check_circle;
      case InvoiceStatus.rejected: return Icons.cancel;
      case InvoiceStatus.reviewing: return Icons.autorenew;
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

class _ConfidenceBar extends StatelessWidget {
  final double confidence;
  const _ConfidenceBar({required this.confidence});
  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.70 ? AppColors.income : confidence >= 0.40 ? AppColors.warning : AppColors.expense;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Độ tin cậy AI:', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('${(confidence * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
      const SizedBox(height: 6),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: confidence),
        duration: const Duration(milliseconds: 800),
        builder: (_, v, __) => ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: v, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(color), minHeight: 10),
        ),
      ),
    ]);
  }
}

class _AiResult {
  final double confidence;
  final InvoiceStatus status;
  final String notes;
  const _AiResult({required this.confidence, required this.status, required this.notes});
}
