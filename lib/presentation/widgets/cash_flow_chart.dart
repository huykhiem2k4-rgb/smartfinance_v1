import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

class CashFlowBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> trend;
  const CashFlowBarChart({super.key, required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox.shrink();
    final maxVal = trend.fold<double>(0, (m, d) {
      final i = (d['income'] as int).toDouble();
      final e = (d['expense'] as int).toDouble();
      return [m, i, e].reduce((a, b) => a > b ? a : b);
    });
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.25,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
              '${rodIndex == 0 ? "Thu" : "Chi"}\n${Formatters.shortAmount((rod.toY).toInt())}',
              TextStyle(
                color: rodIndex == 0 ? AppColors.income : AppColors.expense,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= trend.length) return const SizedBox();
                final dt = trend[i]['month'] as DateTime;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('T${dt.month}', style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (v, _) {
                if (v == 0) return const SizedBox();
                return Text(Formatters.shortAmount(v.toInt()), style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: trend.asMap().entries.map((e) => BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(toY: (e.value['income'] as int).toDouble(), color: AppColors.income, width: 9, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            BarChartRodData(toY: (e.value['expense'] as int).toDouble(), color: AppColors.expense, width: 9, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ],
        )).toList(),
      ),
    );
  }
}

class CashFlowLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> trend;
  const CashFlowLineChart({super.key, required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox.shrink();
    final maxVal = trend.fold<double>(0, (m, d) {
      final i = (d['income'] as int).toDouble();
      final e = (d['expense'] as int).toDouble();
      return [m, i, e].reduce((a, b) => a > b ? a : b);
    });
    final spots = trend.asMap().entries.map((e) {
      final x = e.key.toDouble();
      final y = (e.value['income'] as int).toDouble();
      final y2 = (e.value['expense'] as int).toDouble();
      return [FlSpot(x, y), FlSpot(x, y2)];
    }).toList();

    return LineChart(
      LineChartData(
        maxY: maxVal * 1.25,
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots.map((e) => e[0]).toList(),
            isCurved: true,
            color: AppColors.income,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.income.withValues(alpha: 0.1),
            ),
          ),
          LineChartBarData(
            spots: spots.map((e) => e[1]).toList(),
            isCurved: true,
            color: AppColors.expense,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.expense.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              final isIncome = spot.barIndex == 0;
              return LineTooltipItem(
                '${isIncome ? "Thu" : "Chi"}\n${Formatters.shortAmount(spot.y.toInt())}',
                TextStyle(
                  color: isIncome ? AppColors.income : AppColors.expense,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              );
            }).toList(),
          ),
          handleBuiltInTouches: true,
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= trend.length) return const SizedBox();
                final dt = trend[i]['month'] as DateTime;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('T${dt.month}', style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (v, _) {
                if (v == 0) return const SizedBox();
                return Text(Formatters.shortAmount(v.toInt()), style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class CategoryPieChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final List<Color> colors;
  const CategoryPieChart({super.key, required this.data, required this.colors});

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const Center(child: Text('Không có dữ liệu'));
    final total = widget.data.fold<int>(0, (s, d) => s + (d['total'] as int));

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 38,
        pieTouchData: PieTouchData(
          touchCallback: (event, resp) {
            if (!event.isInterestedForInteractions || resp == null) {
              setState(() => _touched = null);
              return;
            }
            setState(() => _touched = resp.touchedSection?.touchedSectionIndex);
          },
        ),
        sections: widget.data.asMap().entries.map((e) {
          final isTouched = e.key == _touched;
          final pct = total > 0 ? (e.value['total'] as int) / total * 100 : 0;
          return PieChartSectionData(
            color: widget.colors[e.key % widget.colors.length],
            value: (e.value['total'] as int).toDouble(),
            title: '${pct.toStringAsFixed(0)}%',
            radius: isTouched ? 65 : 55,
            titleStyle: TextStyle(
              fontSize: isTouched ? 13 : 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: isTouched
                ? _Tooltip(Formatters.shortAmount(e.value['total'] as int))
                : null,
            badgePositionPercentageOffset: 1.3,
          );
        }).toList(),
      ),
    );
  }
}

class _Tooltip extends StatelessWidget {
  final String text;
  const _Tooltip(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
      );
}
