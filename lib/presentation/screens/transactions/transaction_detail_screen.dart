import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/transaction_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});
  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  TransactionModel? _tx;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tx = await context.read<AppProvider>().getTransaction(widget.transactionId);
    if (mounted) setState(() { _tx = tx; _loading = false; });
  }

  Future<void> _cancelTransaction(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hủy giao dịch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Lý do hủy:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(hintText: 'Nhập lý do...'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Không')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Hủy giao dịch'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<AppProvider>().cancelTransaction(_tx!.id, reason: reasonCtrl.text.trim());
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = context.watch<AuthProvider>().isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giao dịch'),
        actions: [
          if (_tx != null && _tx!.isPosted && isOwner)
            IconButton(
              icon: const Icon(Icons.cancel, color: AppColors.expense),
              onPressed: () => _cancelTransaction(context),
              tooltip: 'Hủy giao dịch',
            ),
          if (_tx != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('/transactions/edit/${_tx!.id}'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tx == null
              ? const Center(child: Text('Không tìm thấy giao dịch'))
              : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final t = _tx!;

    return Stack(fit: StackFit.expand, children: [
      // Dimmed background
      GestureDetector(
        onTap: () => context.pop(),
        child: Container(color: Colors.black.withValues(alpha: 0.4)),
      ),
      // Centered invoice card
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: _InvoiceSummaryCard(transaction: t),
        ),
      ),
    ]);
  }
}

class _InvoiceSummaryCard extends StatelessWidget {
  final TransactionModel transaction;
  const _InvoiceSummaryCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isIncome = t.type == TransactionType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            const Icon(Icons.receipt_long, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Chi tiết hóa đơn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
              onPressed: () => context.push('/transactions/edit/${t.id}'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
        // ── Body ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            _row('Tiêu đề', t.title),
            _row('Loại', isIncome ? 'Thu tiền' : 'Chi tiền', valueColor: color),
            _row('Danh mục', t.category.label),
            _row('Số tiền', Formatters.currency(t.amount), valueColor: color, bold: true),
            _row('Ngày', Formatters.date(t.date)),
            // Status badge
            _row('Trạng thái', t.isPosted ? 'Đang hoạt động' : 'Đã hủy',
              valueColor: t.isPosted ? AppColors.income : AppColors.expense, bold: true),
            if (t.isCancelled && t.cancelReason != null && t.cancelReason!.isNotEmpty)
              _row('Lý do hủy', t.cancelReason!),
            if (t.description != null && t.description!.isNotEmpty)
              _row('Ghi chú', t.description!),
          ]),
        ),
        // ── Footer ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: Row(children: [
            const Text('Tổng thanh toán:', style: TextStyle(fontSize: 13)),
            const Spacer(),
            Text(
              Formatters.currency(t.amount),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _row(String label, String value, {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
      ]),
    );
  }
}
