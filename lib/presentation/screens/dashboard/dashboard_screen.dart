import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/cash_flow_chart.dart';
import '../../widgets/transaction_tile.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (ctx, p, _) {
        if (p.isLoading && p.transactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final net = p.netCashFlow;
        final netPositive = net >= 0;
        final isWide = MediaQuery.of(context).size.width >= 720;

        return RefreshIndicator(
          onRefresh: p.loadAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Banner ──
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('Tháng ${Formatters.month(DateTime.now())}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const Spacer(),
                      _PeriodChip(),
                    ]),
                    const SizedBox(height: 8),
                    const Text('Dòng tiền ròng',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: net.abs()),
                      duration: const Duration(milliseconds: 700),
                      builder: (_, v, __) => Text(
                        Formatters.currency(v),
                        style: TextStyle(
                          color: netPositive ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(netPositive ? '▲ Dương — tốt' : '▼ Âm — cần xem lại',
                        style: TextStyle(
                            color: netPositive ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 12)),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Summary cards ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: isWide
                      ? Row(children: [
                          Expanded(child: SummaryCard(title: 'Tổng Thu', amount: p.totalIncome, icon: Icons.trending_up, color: AppColors.income, subtitle: 'Kỳ hiện tại')),
                          const SizedBox(width: 10),
                          Expanded(child: SummaryCard(title: 'Tổng Chi', amount: p.totalExpense, icon: Icons.trending_down, color: AppColors.expense, subtitle: 'Kỳ hiện tại')),
                          const SizedBox(width: 10),
                          Expanded(child: SummaryCard(title: 'Lợi nhuận', amount: net, icon: Icons.account_balance, color: netPositive ? AppColors.income : AppColors.expense, subtitle: 'Thu - Chi')),
                        ])
                      : Row(children: [
                          Expanded(child: SummaryCard(title: 'Tổng Thu', amount: p.totalIncome, icon: Icons.trending_up, color: AppColors.income)),
                          const SizedBox(width: 8),
                          Expanded(child: SummaryCard(title: 'Tổng Chi', amount: p.totalExpense, icon: Icons.trending_down, color: AppColors.expense)),
                        ]),
                ),

                const SizedBox(height: 16),

                // ── Chart ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Text('Xu hướng 6 tháng',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const Spacer(),
                            _Legend(AppColors.income, 'Thu'),
                            const SizedBox(width: 12),
                            _Legend(AppColors.expense, 'Chi'),
                          ]),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 180,
                            child: p.trend.isEmpty
                                ? const Center(child: CircularProgressIndicator())
                                : AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 400),
                                    child: CashFlowBarChart(key: ValueKey(p.trend.length), trend: p.trend),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Recent transactions ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    const Text('Giao dịch gần đây',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const Spacer(),
                    TextButton(
                        onPressed: () => context.go('/transactions'),
                        child: const Text('Xem tất cả', style: TextStyle(fontSize: 12))),
                  ]),
                ),

                if (p.transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Chưa có giao dịch')),
                  )
                else
                  ...p.transactions.take(5).map((t) => TransactionTile(
                        transaction: t,
                        onDelete: () => p.deleteTransaction(t.id),
                      )),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PeriodChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    const labels = {
      FilterPeriod.thisMonth: 'Tháng này',
      FilterPeriod.lastMonth: 'Tháng trước',
      FilterPeriod.allTime: 'Toàn kỳ',
    };
    return PopupMenuButton<FilterPeriod>(
      initialValue: p.filterPeriod,
      onSelected: (v) => p.setFilterPeriod(v),
      itemBuilder: (_) => FilterPeriod.values
          .map((f) => PopupMenuItem(value: f, child: Text(labels[f]!)))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Text(labels[p.filterPeriod]!,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]);
}
