import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../../data/models/invoice_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppProvider>().loadAll());
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hóa đơn đầu vào'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          isScrollable: true,
          tabs: const [Tab(text: 'Tất cả'), Tab(text: 'Chờ duyệt'), Tab(text: 'Đã duyệt'), Tab(text: 'Từ chối')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/invoices/add'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.upload_file, color: Colors.white),
        label: const Text('Nhập hóa đơn', style: TextStyle(color: Colors.white)),
      ),
      body: Consumer<AppProvider>(
        builder: (ctx, p, _) {
          final all = p.invoices;
          final pending = all.where((i) => i.status == InvoiceStatus.pending).toList();
          final approved = all.where((i) => i.status == InvoiceStatus.approved).toList();
          final rejected = all.where((i) => i.status == InvoiceStatus.rejected).toList();
          return TabBarView(
            controller: _tabs,
            children: [
              _InvoiceList(invoices: all, onDelete: p.deleteInvoice),
              _InvoiceList(invoices: pending, onDelete: p.deleteInvoice),
              _InvoiceList(invoices: approved, onDelete: p.deleteInvoice),
              _InvoiceList(invoices: rejected, onDelete: p.deleteInvoice),
            ],
          );
        },
      ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  final List<InvoiceModel> invoices;
  final Future<void> Function(String) onDelete;
  const _InvoiceList({required this.invoices, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.description_outlined, size: 56, color: Colors.grey),
        SizedBox(height: 10),
        Text('Chưa có hóa đơn', style: TextStyle(color: Colors.grey)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: invoices.length,
      itemBuilder: (_, i) => _InvoiceCard(invoice: invoices[i], onDelete: () => onDelete(invoices[i].id)),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onDelete;
  const _InvoiceCard({required this.invoice, required this.onDelete});

  Color get _statusColor {
    switch (invoice.status) {
      case InvoiceStatus.approved:  return AppColors.income;
      case InvoiceStatus.rejected:  return AppColors.expense;
      case InvoiceStatus.reviewing: return AppColors.warning;
      case InvoiceStatus.pending:   return Colors.grey;
    }
  }

  IconData get _statusIcon {
    switch (invoice.status) {
      case InvoiceStatus.approved:  return Icons.check_circle;
      case InvoiceStatus.rejected:  return Icons.cancel;
      case InvoiceStatus.reviewing: return Icons.autorenew;
      case InvoiceStatus.pending:   return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(invoice.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.expense, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_sweep, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Xóa hóa đơn?'),
          content: Text('Xóa "${invoice.invoiceNumber}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense), onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () => context.push('/invoices/${invoice.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.receipt_long, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                _StatusBadge(label: invoice.status.label, color: _statusColor, icon: _statusIcon),
              ]),
              const SizedBox(height: 4),
              Text(invoice.vendor, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                Text(Formatters.currency(invoice.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                const SizedBox(width: 8),
                Text('(VAT ${invoice.vatRate.label})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
                Text(Formatters.date(invoice.invoiceDate), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
              if (invoice.aiConfidence != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: invoice.aiConfidence,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(_statusColor),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 3),
                Text('AI: ${(invoice.aiConfidence! * 100).toStringAsFixed(0)}% tin cậy',
                    style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.w500)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusBadge({required this.label, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );
}
