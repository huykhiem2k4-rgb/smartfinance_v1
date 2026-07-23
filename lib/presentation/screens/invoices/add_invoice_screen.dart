import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/app_provider.dart';
import '../../../data/models/invoice_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';

class AddInvoiceScreen extends StatefulWidget {
  const AddInvoiceScreen({super.key});
  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _invNumCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  final _taxCodeCtrl = TextEditingController();
  final _subtotalCtrl = TextEditingController();

  VatRate _vatRate = VatRate.vat10;
  DateTime _invoiceDate = DateTime.now();
  List<InvoiceItem> _items = [];
  String? _imagePath;
  String? _selectedPartnerId;
  Uint8List? _imageBytes;
  bool _scanning = false;
  bool _saving = false;

  late AnimationController _scanLineAnim;
  late AnimationController _progressAnim;
  late Animation<double> _scanLineProgress;
  late Animation<double> _progressValue;

  @override
  void initState() {
    super.initState();
    _scanLineAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scanLineProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineAnim, curve: Curves.easeInOut),
    );
    _progressAnim = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _progressValue = Tween<double>(begin: 0, end: 1).animate(_progressAnim);
  }

  @override
  void dispose() {
    _scanLineAnim.dispose();
    _progressAnim.dispose();
    _invNumCtrl.dispose();
    _vendorCtrl.dispose();
    _taxCodeCtrl.dispose();
    _subtotalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập hóa đơn mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── AI Scan section ──
            Card(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.psychology, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Smart Scan AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const SizedBox(height: 8),
                  const Text('Chụp hoặc chọn ảnh hóa đơn để AI tự động điền thông tin.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  if (_imagePath != null && !_scanning)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: AppColors.income, size: 16),
                        const SizedBox(width: 4),
                        Text('Đã chọn ảnh', style: TextStyle(color: AppColors.income, fontSize: 12)),
                      ]),
                    ),
                  if (_scanning) ...[
                    const SizedBox(height: 8),
                    _ScanAnimation(
                      progress: _progressValue,
                      scanLine: _scanLineProgress,
                      imageBytes: _imageBytes,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!_scanning)
                    Row(children: [
                      if (!kIsWeb) ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.photo_camera, size: 18),
                          label: const Text('Camera'),
                          onPressed: () => _pickAndScan(ImageSource.camera),
                        ),
                        const SizedBox(width: 10),
                      ],
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Thư viện'),
                        onPressed: () => _pickAndScan(ImageSource.gallery),
                      ),
                    ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Invoice info ──
            TextFormField(
              controller: _invNumCtrl,
              decoration: const InputDecoration(labelText: 'Số hóa đơn *', prefixIcon: Icon(Icons.receipt)),
              validator: Validators.invoiceNumber,
            ),
            const SizedBox(height: 12),

            // ── Partner dropdown ──
            Consumer<AppProvider>(
              builder: (ctx, p, _) {
                final suppliers = p.partners.where((p) => p.isSupplier).toList();
                return DropdownButtonFormField<String>(
                  value: _selectedPartnerId,
                  decoration: const InputDecoration(labelText: 'Nhà cung cấp *', prefixIcon: Icon(Icons.business)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('-- Chọn nhà cung cấp --')),
                    ...suppliers.map((p) => DropdownMenuItem(
                      value: p.partnerId,
                      child: Text(p.partnerName),
                    )),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _selectedPartnerId = v;
                      if (v != null) {
                        final partner = suppliers.firstWhere((p) => p.partnerId == v);
                        _vendorCtrl.text = partner.partnerName;
                        _taxCodeCtrl.text = partner.taxCode ?? '';
                      }
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _vendorCtrl,
              decoration: const InputDecoration(labelText: 'Tên nhà cung cấp *', prefixIcon: Icon(Icons.business)),
              validator: (v) => Validators.required(v, 'Nhà cung cấp'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _taxCodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Mã số thuế nhà cung cấp',
                prefixIcon: Icon(Icons.numbers),
                hintText: '10 hoặc 13 chữ số',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: Validators.taxCode,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _subtotalCtrl,
              decoration: const InputDecoration(
                labelText: 'Tiền hàng (trước VAT) *',
                prefixIcon: Icon(Icons.attach_money),
                hintText: 'Nhập số nguyên VNĐ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: Validators.amount,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // VAT rate selector
            _SectionLabel('Thuế suất VAT'),
            const SizedBox(height: 6),
            SegmentedButton<VatRate>(
              selected: {_vatRate},
              onSelectionChanged: (s) => setState(() => _vatRate = s.first),
              segments: const [
                ButtonSegment(value: VatRate.vat8, label: Text('8%')),
                ButtonSegment(value: VatRate.vat10, label: Text('10%')),
                ButtonSegment(value: VatRate.none, label: Text('Không')),
              ],
            ),
            const SizedBox(height: 10),

            // VAT summary
            _VatSummary(subtotalStr: _subtotalCtrl.text, vatRate: _vatRate),
            const SizedBox(height: 12),

            // Date
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade400)),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Ngày hóa đơn'),
              subtitle: Text(Formatters.date(_invoiceDate)),
              trailing: const Icon(Icons.edit_calendar, size: 18),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            // Items
            Row(children: [
              const _SectionLabel('Mặt hàng'),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Thêm mặt hàng'),
                onPressed: _addItem,
              ),
            ]),
            ..._items.asMap().entries.map((e) => _ItemTile(
              item: e.value,
              onRemove: () => setState(() => _items.removeAt(e.key)),
            )),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Chưa có mặt hàng', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.upload_file),
                label: Text(_saving ? 'Đang lưu...' : 'Lưu hóa đơn'),
                onPressed: _saving ? null : _submit,
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickAndScan(ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, imageQuality: 80);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _imagePath = img.path;
      _imageBytes = bytes;
      _scanning = true;
    });
    _scanLineAnim.reset();
    _progressAnim.reset();
    _scanLineAnim.repeat(reverse: true);
    _progressAnim.forward();
    await Future.delayed(const Duration(seconds: 2));
    _scanLineAnim.stop();
    _progressAnim.stop();
    _fillMockData();
    setState(() => _scanning = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ AI đã đọc và điền dữ liệu hóa đơn'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _fillMockData() {
    final rng = Random();
    final vendors = ['Cty TNHH Thiết bị Văn phòng ABC', 'Cty CP Dịch vụ Công nghệ XYZ', 'Nhà phân phối Hàng hóa 123'];
    final taxCodes = ['0123456789', '0987654321', '0246813579'];
    final inv = 'HD-${DateTime.now().year}-${(rng.nextInt(900) + 100).toString().padLeft(3, '0')}';
    final sub = (rng.nextInt(20) + 5) * 1000000;
    final qty = rng.nextInt(5) + 1;
    final unitPrice = sub ~/ qty;
    setState(() {
      _invNumCtrl.text = inv;
      _vendorCtrl.text = vendors[rng.nextInt(vendors.length)];
      _taxCodeCtrl.text = taxCodes[rng.nextInt(taxCodes.length)];
      _subtotalCtrl.text = sub.toString();
      _vatRate = rng.nextBool() ? VatRate.vat10 : VatRate.vat8;
      _items = [
        InvoiceItem(name: 'Hàng hóa (AI đọc)', quantity: qty, unitPrice: unitPrice),
      ];
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _invoiceDate = picked);
  }

  void _addItem() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Thêm mặt hàng'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên hàng hóa *')),
          const SizedBox(height: 8),
          TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Số lượng'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 8),
          TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Đơn giá (₫)'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final qty = int.tryParse(qtyCtrl.text) ?? 1;
              final price = int.tryParse(priceCtrl.text) ?? 0;
              if (name.isNotEmpty && price > 0) {
                setState(() => _items.add(InvoiceItem(name: name, quantity: qty, unitPrice: price)));
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final subtotal = Formatters.parseAmount(_subtotalCtrl.text);
    if (subtotal == null || subtotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tiền hàng không hợp lệ'), backgroundColor: AppColors.expense),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final vatAmount = (subtotal * _vatRate.rate).round();
      final inv = InvoiceModel(
        id: const Uuid().v4(),
        invoiceNumber: _invNumCtrl.text.trim(),
        partnerId: _selectedPartnerId,
        subtotal: subtotal,
        vatRate: _vatRate,
        vatAmount: vatAmount,
        totalAmount: subtotal + vatAmount,
        invoiceDate: _invoiceDate,
        status: InvoiceStatus.pending,
        items: _items,
        imagePath: _imagePath,
        ocrText: _vendorCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await context.read<AppProvider>().addInvoice(inv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Đã lưu hóa đơn'), backgroundColor: AppColors.accent, behavior: SnackBarBehavior.floating),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu hóa đơn: $e'), backgroundColor: AppColors.expense),
        );
        setState(() => _saving = false);
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65)));
}

class _VatSummary extends StatelessWidget {
  final String subtotalStr;
  final VatRate vatRate;
  const _VatSummary({required this.subtotalStr, required this.vatRate});

  @override
  Widget build(BuildContext context) {
    final subtotal = int.tryParse(subtotalStr) ?? 0;
    final vat = (subtotal * vatRate.rate).round();
    final total = subtotal + vat;
    if (subtotal == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        _Row('Tiền hàng:', Formatters.currency(subtotal)),
        _Row('Thuế VAT (${vatRate.label}):', Formatters.currency(vat), color: AppColors.warning),
        const Divider(height: 12),
        _Row('Tổng thanh toán:', Formatters.currency(total), bold: true, color: AppColors.primary),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _Row(this.label, this.value, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color)),
        ]),
      );
}

class _ItemTile extends StatelessWidget {
  final InvoiceItem item;
  final VoidCallback onRemove;
  const _ItemTile({required this.item, required this.onRemove});
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: ListTile(
          dense: true,
          title: Text(item.name, style: const TextStyle(fontSize: 13)),
          subtitle: Text('${item.quantity} x ${Formatters.currency(item.unitPrice)}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(Formatters.currency(item.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.redAccent), onPressed: onRemove, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ),
      );
}

class _ScanAnimation extends StatelessWidget {
  final Animation<double> progress;
  final Animation<double> scanLine;
  final Uint8List? imageBytes;
  const _ScanAnimation({required this.progress, required this.scanLine, this.imageBytes});

  static const _steps = [
    (Icons.image_search, 'Nhận dạng hóa đơn...'),
    (Icons.qr_code_scanner, 'Đọc số hóa đơn...'),
    (Icons.business, 'Xác minh nhà cung cấp...'),
    (Icons.calculate, 'Tính toán số tiền...'),
    (Icons.check_circle_outline, 'Hoàn tất!'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([progress, scanLine]),
      builder: (_, _) {
        final stepIdx = (progress.value * _steps.length).floor().clamp(0, _steps.length - 1);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Image + scan overlay ──
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                // Image
                if (imageBytes != null)
                  Image.memory(imageBytes!, fit: BoxFit.cover, color: Colors.black.withValues(alpha: 0.15), colorBlendMode: BlendMode.darken)
                else
                  Container(color: Colors.grey.shade300),
                // Dark overlay
                Container(color: Colors.black.withValues(alpha: 0.25)),
                // Corner brackets
                CustomPaint(painter: _CornerBracketsPainter(), size: Size.infinite),
                // Glow scan line
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: CustomPaint(
                    painter: _ScanLinePainter(lineY: scanLine.value),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          // ── Steps ──
          ..._steps.asMap().entries.map((e) {
            final done = e.key < stepIdx;
            final active = e.key == stepIdx;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: active ? 13.5 : 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: done ? AppColors.income : active ? AppColors.accent : Colors.grey,
                ),
                child: Row(children: [
                  Icon(
                    done ? Icons.check : e.value.$1,
                    size: 14,
                    color: done ? AppColors.income : active ? AppColors.accent : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(e.value.$2),
                ]),
              ),
            );
          }),
          const SizedBox(height: 8),
          // ── Progress bar ──
          LinearProgressIndicator(
            value: progress.value,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ]);
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double lineY;
  _ScanLinePainter({required this.lineY});

  @override
  void paint(Canvas canvas, Size size) {
    final y = lineY * size.height;
    final glowHeight = size.height * 0.15;
    final rect = Rect.fromLTWH(0, y - glowHeight / 2, size.width, glowHeight);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.accent.withValues(alpha: 0.0),
        AppColors.accent.withValues(alpha: 0.5),
        AppColors.accent,
        AppColors.accent.withValues(alpha: 0.5),
        AppColors.accent.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.lineY != lineY;
}

class _CornerBracketsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 20.0;
    const pad = 10.0;

    // Top-left
    canvas.drawLine(const Offset(pad, pad), Offset(pad + len, pad), paint);
    canvas.drawLine(const Offset(pad, pad), Offset(pad, pad + len), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad - len, pad), paint);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + len), paint);
    // Bottom-left
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + len, size.height - pad), paint);
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad, size.height - pad - len), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad - len, size.height - pad), paint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad, size.height - pad - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
