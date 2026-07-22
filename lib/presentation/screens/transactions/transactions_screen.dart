import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/transaction_tile.dart';
import '../../../data/models/transaction_model.dart';
import '../../../core/theme/app_theme.dart';

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
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _viewTransaction(TransactionModel t) {
    context.push('/transactions/${t.id}');
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch'),
        toolbarHeight: isLandscape ? 40 : null,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          labelPadding: EdgeInsets.symmetric(horizontal: isLandscape ? 10 : 16),
          tabs: const [Tab(text: 'Thu tiền'), Tab(text: 'Chi tiền')],
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
              _TxList(transactions: p.transactions.where((t) => t.type == TransactionType.income).toList(), onDelete: p.deleteTransaction, onTap: (t) => _viewTransaction(t)),
              _TxList(transactions: p.transactions.where((t) => t.type == TransactionType.expense).toList(), onDelete: p.deleteTransaction, onTap: (t) => _viewTransaction(t)),
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
  final void Function(TransactionModel) onTap;

  const _TxList({required this.transactions, required this.onDelete, required this.onTap});

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

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: transactions.length,
      itemBuilder: (_, i) => TransactionTile(
        transaction: transactions[i],
        onDelete: () => onDelete(transactions[i].id),
        onTap: () => onTap(transactions[i]),
      ),
    );
  }
}
