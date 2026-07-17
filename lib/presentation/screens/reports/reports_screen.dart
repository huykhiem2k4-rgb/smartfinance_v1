import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../providers/app_provider.dart';
import '../../widgets/cash_flow_chart.dart';
import '../../widgets/summary_card.dart';
import '../../../data/models/transaction_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _incomeBreakdown = [];
  List<Map<String, dynamic>> _expenseBreakdown = [];
  Map<String, int> _invoiceStats = {};
  bool _loaded = false;
  FilterPeriod _activePeriod = FilterPeriod.thisMonth;
  bool _showLineChart = false;

  static const _incomeColors = [AppColors.income, Color(0xFF66BB6A), Color(0xFF26A69A), Color(0xFF42A5F5)];
  static const _expenseColors = [AppColors.expense, Color(0xFFEF9A9A), Color(0xFFFF7043), Color(0xFFFFB74D), Color(0xFF9575CD), Color(0xFF78909C)];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loaded = false);
    final p = context.read<AppProvider>();
    final results = await Future.wait([
      p.getCategoryBreakdown(TransactionType.income),
      p.getCategoryBreakdown(TransactionType.expense),
      p.getInvoiceStats(),
    ]);
    if (mounted) {
      setState(() {
        _incomeBreakdown = results[0] as List<Map<String, dynamic>>;
        _expenseBreakdown = results[1] as List<Map<String, dynamic>>;
        _invoiceStats = results[2] as Map<String, int>;
        _loaded = true;
      });
    }
  }

  Future<void> _changePeriod(FilterPeriod p) async {
    _activePeriod = p;
    await context.read<AppProvider>().setFilterPeriod(p);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    return Consumer<AppProvider>(
      builder: (ctx, p, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Báo cáo & Thống kê'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              onPressed: () => _exportPdf(p),
              tooltip: 'Xuất PDF',
            ),
          ],
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Period filter ──
                      _PeriodFilter(active: _activePeriod, onChanged: _changePeriod),
                      const SizedBox(height: 14),

                      // ── Summary ──
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: _SummaryRow(key: ValueKey(_activePeriod), income: p.totalIncome, expense: p.totalExpense, net: p.netCashFlow),
                      ),
                      const SizedBox(height: 14),

                      // ── Cash flow trend ──
                      _Card(
                        title: 'Dòng tiền 6 tháng',
                        trailing: Row(children: [
                          _dot(AppColors.income), const SizedBox(width: 4), const Text('Thu', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 10),
                          _dot(AppColors.expense), const SizedBox(width: 4), const Text('Chi', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: Icon(_showLineChart ? Icons.bar_chart : Icons.show_chart, size: 20),
                            onPressed: () => setState(() => _showLineChart = !_showLineChart),
                            tooltip: _showLineChart ? 'Biểu đồ cột' : 'Biểu đồ đường',
                          ),
                        ]),
                        child: SizedBox(
                          height: 200,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: p.trend.isEmpty
                                ? const Center(child: Text('Không có dữ liệu'))
                                : _showLineChart
                                    ? CashFlowLineChart(key: ValueKey('line${p.trend.hashCode}'), trend: p.trend)
                                    : CashFlowBarChart(key: ValueKey('bar${p.trend.hashCode}'), trend: p.trend),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Income breakdown ──
                      _Card(
                        title: 'Cơ cấu thu nhập',
                        child: _incomeBreakdown.isEmpty
                            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Không có dữ liệu')))
                            : _PieSection(data: _incomeBreakdown, colors: _incomeColors),
                      ),
                      const SizedBox(height: 14),

                      // ── Expense breakdown ──
                      _Card(
                        title: 'Cơ cấu chi phí',
                        child: _expenseBreakdown.isEmpty
                            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Không có dữ liệu')))
                            : _PieSection(data: _expenseBreakdown, colors: _expenseColors),
                      ),
                      const SizedBox(height: 14),

                      // ── Invoice stats ──
                      _Card(
                        title: 'Thống kê hóa đơn',
                        child: isWide
                            ? _InvoiceStatsTable(stats: _invoiceStats)
                            : Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                                _InvStat('Chờ duyệt', _invoiceStats['pending'] ?? 0, Colors.grey),
                                _InvStat('Đã duyệt', _invoiceStats['approved'] ?? 0, AppColors.income),
                                _InvStat('Từ chối', _invoiceStats['rejected'] ?? 0, AppColors.expense),
                              ]),
                      ),
                      const SizedBox(height: 14),

                      // ── Transaction details table (Desktop) ──
                      if (isWide) ...[
                        _Card(
                          title: 'Chi tiết giao dịch',
                          child: _TransactionDataTable(transactions: p.transactions),
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (!isWide) const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _dot(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)));

  Future<void> _exportPdf(AppProvider p) async {
    // Load fonts
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final bold = pw.Font.ttf(boldData);

    final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));
    final now = DateTime.now();
    const periodLabels = {FilterPeriod.thisMonth: 'Tháng này', FilterPeriod.lastMonth: 'Tháng trước', FilterPeriod.allTime: 'Toàn kỳ'};
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Header(level: 0, child: pw.Text('BÁO CÁO DÒNG TIỀN — SMARTFINANCE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 6),
        pw.Text('Ngày xuất: ${Formatters.dateTime(now)}'),
        pw.Text('Kỳ báo cáo: ${periodLabels[_activePeriod]}'),
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Text('TỔNG QUAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Chỉ tiêu', 'Số tiền (VNĐ)'],
          data: [
            ['Tổng thu', Formatters.currency(p.totalIncome)],
            ['Tổng chi', Formatters.currency(p.totalExpense)],
            ['Dòng tiền ròng', Formatters.currency(p.netCashFlow)],
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('CHI TIẾT GIAO DỊCH (tối đa 20 giao dịch)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Tiêu đề', 'Loại', 'Danh mục', 'Số tiền', 'Ngày'],
          data: p.transactions.take(20).map((t) => [
            t.title,
            t.type == TransactionType.income ? 'Thu' : 'Chi',
            t.category.label,
            Formatters.currency(t.amount),
            Formatters.date(t.date),
          ]).toList(),
        ),
        pw.SizedBox(height: 16),
        pw.Text('THỐNG KÊ HÓA ĐƠN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Trạng thái', 'Số lượng'],
          data: [
            ['Chờ duyệt', '${_invoiceStats['pending'] ?? 0}'],
            ['Đã duyệt', '${_invoiceStats['approved'] ?? 0}'],
            ['Từ chối', '${_invoiceStats['rejected'] ?? 0}'],
          ],
        ),
        pw.Spacer(),
        pw.Divider(),
        pw.Text('SmartFinance © ${now.year} — Báo cáo tự động', style: const pw.TextStyle(fontSize: 9)),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}

class _PeriodFilter extends StatelessWidget {
  final FilterPeriod active;
  final ValueChanged<FilterPeriod> onChanged;
  const _PeriodFilter({required this.active, required this.onChanged});

  static const _labels = {
    FilterPeriod.thisMonth: 'Tháng này',
    FilterPeriod.lastMonth: 'Tháng trước',
    FilterPeriod.allTime: 'Toàn kỳ',
  };

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    child: SegmentedButton<FilterPeriod>(
      key: ValueKey(active),
      selected: {active},
      onSelectionChanged: (s) => onChanged(s.first),
      segments: FilterPeriod.values.map((f) => ButtonSegment(value: f, label: Text(_labels[f]!, style: const TextStyle(fontSize: 12)))).toList(),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  final int income, expense, net;
  const _SummaryRow({super.key, required this.income, required this.expense, required this.net});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: SummaryCard(title: 'Tổng Thu', amount: income, icon: Icons.trending_up, color: AppColors.income)),
    const SizedBox(width: 8),
    Expanded(child: SummaryCard(title: 'Tổng Chi', amount: expense, icon: Icons.trending_down, color: AppColors.expense)),
    const SizedBox(width: 8),
    Expanded(child: SummaryCard(title: 'Lợi nhuận', amount: net, icon: Icons.account_balance, color: net >= 0 ? AppColors.income : AppColors.expense)),
  ]);
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Card({required this.title, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const Spacer(),
      if (trailing != null) trailing!,
    ]),
    const SizedBox(height: 12),
    child,
  ])));
}

class _PieSection extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final List<Color> colors;
  const _PieSection({required this.data, required this.colors});
  @override
  Widget build(BuildContext context) {
    final total = data.fold<int>(0, (s, d) => s + (d['total'] as int));
    return Column(children: [
      SizedBox(height: 180, child: CategoryPieChart(data: data, colors: colors)),
      const SizedBox(height: 10),
      ...data.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[e.key % colors.length], borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(
            TransactionCategory.values.firstWhere((c) => c.name == e.value['category'], orElse: () => TransactionCategory.otherExpense).label,
            style: const TextStyle(fontSize: 12),
          )),
          Text(Formatters.shortAmount(e.value['total'] as int), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text('(${total > 0 ? ((e.value['total'] as int) / total * 100).toStringAsFixed(0) : 0}%)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      )),
    ]);
  }
}

class _InvStat extends StatelessWidget {
  final String label; final int count; final Color color;
  const _InvStat(this.label, this.count, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: count),
      duration: const Duration(milliseconds: 600),
      builder: (_, v, __) => Text('$v', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
    ),
    Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
  ]);
}

class _InvoiceStatsTable extends StatelessWidget {
  final Map<String, int> stats;
  const _InvoiceStatsTable({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Trạng thái')),
          DataColumn(label: Text('Số lượng'), numeric: true),
        ],
        rows: [
          _statRow('Chờ duyệt', stats['pending'] ?? 0, Colors.grey),
          _statRow('Đã duyệt', stats['approved'] ?? 0, AppColors.income),
          _statRow('Từ chối', stats['rejected'] ?? 0, AppColors.expense),
        ],
      ),
    );
  }

  DataRow _statRow(String label, int count, Color color) {
    return DataRow(cells: [
      DataCell(Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: color))),
      DataCell(Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color))),
    ]);
  }
}

class _TransactionDataTable extends StatelessWidget {
  final List<TransactionModel> transactions;
  const _TransactionDataTable({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('Không có giao dịch')),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columns: const [
          DataColumn(label: Text('Tiêu đề')),
          DataColumn(label: Text('Loại')),
          DataColumn(label: Text('Danh mục')),
          DataColumn(label: Text('Số tiền'), numeric: true),
          DataColumn(label: Text('Ngày')),
        ],
        rows: transactions.map((t) {
          final isIncome = t.type == TransactionType.income;
          return DataRow(
            cells: [
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
          ]);
        }).toList(),
      ),
    );
  }
}
