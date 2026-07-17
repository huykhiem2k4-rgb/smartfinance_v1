import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../../data/models/invoice_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/router/app_router.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      routeObserver.subscribe(this, ModalRoute.of(context)!);
      context.read<AppProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabs.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    context.read<AppProvider>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hóa đơn đầu vào'),
        toolbarHeight: isLandscape ? 40 : null,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: EdgeInsets.symmetric(horizontal: isLandscape ? 10 : 16),
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
          final pending = all.where((i) => i.status == InvoiceStatus.pending || i.status == InvoiceStatus.reviewing).toList();
          final approved = all.where((i) => i.status == InvoiceStatus.approved).toList();
          final rejected = all.where((i) => i.status == InvoiceStatus.rejected).toList();
          return TabBarView(
            controller: _tabs,
            children: [
              _InvoiceList(invoices: all),
              _InvoiceList(invoices: pending),
              _InvoiceList(invoices: approved),
              _InvoiceList(invoices: rejected),
            ],
          );
        },
      ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  final List<InvoiceModel> invoices;
  const _InvoiceList({required this.invoices});

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.description_outlined, size: 56, color: Colors.grey),
        SizedBox(height: 10),
        Text('Chưa có hóa đơn', style: TextStyle(color: Colors.grey)),
      ]));
    }
    final isWide = MediaQuery.of(context).size.width >= 720;
    if (isWide) {
      return _InvoiceDataTable(invoices: invoices);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: invoices.length,
      itemBuilder: (_, i) => _InvoiceCard(invoice: invoices[i]),
    );
  }
}

class _InvoiceDataTable extends StatelessWidget {
  final List<InvoiceModel> invoices;
  const _InvoiceDataTable({required this.invoices});

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: isLandscape ? 8 : 16),
      child: Card(
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: isLandscape ? 16 : 24,
          headingRowHeight: isLandscape ? 40 : 48,
          dataRowMinHeight: isLandscape ? 40 : 48,
          dataRowMaxHeight: isLandscape ? 48 : 56,
          headingRowColor: WidgetStateProperty.all(
            AppColors.primary.withValues(alpha: 0.08),
          ),
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
          columns: const [
            DataColumn(label: Text('Số HĐ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataColumn(label: Text('Nhà cung cấp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataColumn(label: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataColumn(label: Text('Tổng tiền (VAT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), numeric: true),
            DataColumn(label: Text('Ngày', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          ],
          rows: invoices.map((inv) {
            final statusColor = _statusColorFor(inv.status);
            final statusIcon = _statusIconFor(inv.status);
            return DataRow(
              onSelectChanged: (_) => context.push('/invoices/${inv.id}'),
              cells: [
                DataCell(Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                DataCell(Text(inv.vendor, style: const TextStyle(fontSize: 13))),
                DataCell(_StatusBadge(label: inv.status.label, color: statusColor, icon: statusIcon)),
                DataCell(Text(
                  Formatters.currency(inv.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                )),
                DataCell(Text(Formatters.date(inv.invoiceDate), style: const TextStyle(fontSize: 12, color: Colors.grey))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _statusColorFor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.approved: return AppColors.income;
      case InvoiceStatus.rejected: return AppColors.expense;
      case InvoiceStatus.reviewing: return AppColors.warning;
      case InvoiceStatus.pending: return Colors.grey;
    }
  }

  IconData _statusIconFor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.approved: return Icons.check_circle;
      case InvoiceStatus.rejected: return Icons.cancel;
      case InvoiceStatus.reviewing: return Icons.autorenew;
      case InvoiceStatus.pending: return Icons.hourglass_empty;
    }
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  const _InvoiceCard({required this.invoice});

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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push('/invoices/${invoice.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              _StatusBadge(label: invoice.status.label, color: _statusColor, icon: _statusIcon),
            ]),
            const SizedBox(height: 6),
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
          Flexible(
            child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}
