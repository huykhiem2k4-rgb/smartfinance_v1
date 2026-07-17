import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/app_provider.dart';
import '../../../data/models/transaction_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';

class EditTransactionScreen extends StatefulWidget {
  final String transactionId;
  const EditTransactionScreen({super.key, required this.transactionId});
  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;

  late TransactionType _type;
  late TransactionCategory _category;
  late DateTime _date;
  String? _imagePath;
  bool _saving = false;
  TransactionModel? _transaction;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _amountCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _type = TransactionType.income;
    _category = TransactionCategory.sales;
    _date = DateTime.now();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    final t = await context.read<AppProvider>().getTransaction(widget.transactionId);
    if (t == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy giao dịch'), backgroundColor: AppColors.expense),
        );
        context.pop();
      }
      return;
    }
    setState(() {
      _transaction = t;
      _titleCtrl.text = t.title;
      _amountCtrl.text = t.amount.toString();
      _descCtrl.text = t.description ?? '';
      _type = t.type;
      _category = t.category;
      _date = t.date;
      _imagePath = t.imagePath;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chỉnh sửa giao dịch')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa giao dịch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Type selector
            _SectionTitle('Loại giao dịch'),
            const SizedBox(height: 8),
            SegmentedButton<TransactionType>(
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                // If category doesn't match new type, reset to default
                if (_category.type != _type) {
                  _category = _type == TransactionType.income
                      ? TransactionCategory.sales
                      : TransactionCategory.salary;
                }
              }),
              segments: const [
                ButtonSegment(value: TransactionType.income, label: Text('Thu tiền'), icon: Icon(Icons.add_circle_outline)),
                ButtonSegment(value: TransactionType.expense, label: Text('Chi tiền'), icon: Icon(Icons.remove_circle_outline)),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Tiêu đề *', prefixIcon: Icon(Icons.title)),
              validator: (v) => Validators.required(v, 'Tiêu đề'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Số tiền (VNĐ) *',
                prefixIcon: Icon(Icons.attach_money),
                hintText: 'Ví dụ: 5000000',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: Validators.amount,
            ),
            if (_amountCtrl.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Text(
                  '= ${Formatters.currency(int.tryParse(_amountCtrl.text) ?? 0)}',
                  style: TextStyle(fontSize: 12, color: _type == TransactionType.income ? AppColors.income : AppColors.expense),
                ),
              ),
            const SizedBox(height: 12),

            // Category
            DropdownButtonFormField<TransactionCategory>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Danh mục *', prefixIcon: Icon(Icons.category)),
              items: TransactionCategory.values
                  .where((c) => c.type == _type)
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
              validator: (v) => v == null ? 'Chọn danh mục' : null,
            ),
            const SizedBox(height: 12),

            // Date
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Ngày giao dịch'),
              subtitle: Text(Formatters.date(_date)),
              trailing: const Icon(Icons.edit_calendar, size: 18),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.notes)),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Image (chứng từ)
            _SectionTitle('Chứng từ (tùy chọn)'),
            const SizedBox(height: 8),
            _ImagePicker(
              imagePath: _imagePath,
              onPicked: (path) => setState(() => _imagePath = path),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Đang lưu...' : 'Cập nhật'),
                onPressed: _saving ? null : _submit,
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final amount = Formatters.parseAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số tiền không hợp lệ'), backgroundColor: AppColors.expense),
      );
      setState(() => _saving = false);
      return;
    }
    try {
      final t = _transaction!.copyWith(
        title: _titleCtrl.text.trim(),
        amount: amount,
        type: _type,
        category: _category,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        date: _date,
        imagePath: _imagePath,
      );
      await context.read<AppProvider>().updateTransaction(t);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Đã cập nhật giao dịch'),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật giao dịch: $e'), backgroundColor: AppColors.expense),
        );
        setState(() => _saving = false);
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)));
}

class _ImagePicker extends StatelessWidget {
  final String? imagePath;
  final ValueChanged<String?> onPicked;
  const _ImagePicker({required this.imagePath, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (!kIsWeb) ...[
        OutlinedButton.icon(
          icon: const Icon(Icons.photo_camera),
          label: const Text('Camera'),
          onPressed: () => _pick(context, ImageSource.camera),
        ),
        const SizedBox(width: 10),
      ],
      OutlinedButton.icon(
        icon: const Icon(Icons.photo_library),
        label: const Text('Thư viện'),
        onPressed: () => _pick(context, ImageSource.gallery),
      ),
      if (imagePath != null) ...[
        const SizedBox(width: 10),
        const Icon(Icons.check_circle, color: AppColors.income, size: 20),
        const Text(' Đã chọn', style: TextStyle(fontSize: 12)),
      ],
    ]);
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, imageQuality: 80);
    if (img != null) onPicked(img.path);
  }
}
