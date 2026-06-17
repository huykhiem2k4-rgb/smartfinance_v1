import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/transaction_tile.dart';
import '../../../data/models/transaction_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          tabs: const [Tab(text: 'Tất cả'), Tab(text: 'Thu tiền'), Tab(text: 'Chi tiền')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transactions/add'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Thêm', style: TextStyle(color: Colors.white)),
      ),
      body: Consumer<AppProvider>(
        builder: (ctx, p, _) {
          return TabBarView(
            controller: _tabs,
            children: [
              _TxList(transactions: p.transactions, onDelete: p.deleteTransaction, isWide: isWide),
              _TxList(transactions: p.transactions.where((t) => t.type == TransactionType.income).toList(), onDelete: p.deleteTransaction, isWide: isWide),
              _TxList(transactions: p.transactions.where((t) => t.type == TransactionType.expense).toList(), onDelete: p.deleteTransaction, isWide: isWide),
            ],
          );
        },
      ),
    );
  }
}

class _TxList extends StatelessWidget {
  final List<TransactionModel> transactions;
  final Future<void> Function(String) onDelete;
  final bool isWide;

  const _TxList({required this.transactions, required this.onDelete, required this.isWide});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 10),
          Text('Chưa có giao dịch nào', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }

    if (isWide) {
      // Desktop table view
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Tiêu đề')),
              DataColumn(label: Text('Loại')),
              DataColumn(label: Text('Danh mục')),
              DataColumn(label: Text('Số tiền'), numeric: true),
              DataColumn(label: Text('Ngày')),
              DataColumn(label: Text('Xóa')),
            ],
            rows: transactions.map((t) {
              final isIncome = t.type == TransactionType.income;
              return DataRow(cells: [
                DataCell(Text(t.title, style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isIncome ? AppColors.income : AppColors.expense).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(isIncome ? 'Thu' : 'Chi',
                      style: TextStyle(color: isIncome ? AppColors.income : AppColors.expense, fontSize: 12)),
                )),
                DataCell(Text(t.category.label, style: const TextStyle(fontSize: 12))),
                DataCell(Text(
                  Formatters.currency(t.amount),
                  style: TextStyle(
                    color: isIncome ? AppColors.income : AppColors.expense,
                    fontWeight: FontWeight.bold,
                  ),
                )),
                DataCell(Text(Formatters.date(t.date), style: const TextStyle(fontSize: 12))),
                DataCell(IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  onPressed: () => _confirmDelete(context, t),
                )),
              ]);
            }).toList(),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: transactions.length,
      itemBuilder: (_, i) => TransactionTile(
        transaction: transactions[i],
        onDelete: () => onDelete(transactions[i].id),
      ),
    );
  }

  void _confirmDelete(BuildContext context, TransactionModel t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa "${t.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () { onDelete(t.id); Navigator.pop(context); },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
