import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/savage_bot_provider.dart';
import '../services/hybrid_nlp_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/edit_transaction_dialog.dart';

/// Tab 3: Dynamic Survival Runway Analytics, Category Breakdown & Group Ledger.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedMemberFilter = 'Tất cả';

  List<FlSpot> _buildRunwaySpots(SavageBotState botState) {
    final double budgetM = botState.monthlyBudget / 1000000.0;
    final double remainingM = botState.remainingMonthlyBudget / 1000000.0;
    final double spentM = (budgetM - remainingM).clamp(0.0, budgetM);

    // Current day checkpoint (day 10) reflects real remaining budget,
    // and future trajectory projects linearly from active spending velocity.
    final double velocityPerDayM = math.max(
      spentM / 10.0,
      (botState.dailyBaseAllowance * 0.72) / 1000000.0,
    );

    double projectAt(int day) {
      if (day <= 0) return budgetM;
      if (day <= 10) {
        final ratio = day / 10.0;
        return (budgetM - spentM * ratio).clamp(0.0, budgetM);
      }
      return (remainingM - velocityPerDayM * (day - 10)).clamp(0.0, budgetM);
    }

    return [
      FlSpot(1, projectAt(0)),
      FlSpot(5, projectAt(5)),
      FlSpot(10, projectAt(10)),
      FlSpot(15, projectAt(15)),
      FlSpot(20, projectAt(20)),
      FlSpot(25, projectAt(25)),
      FlSpot(30, projectAt(30)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final botState = ref.watch(savageBotProvider);
    final notifier = ref.read(savageBotProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardSurface = AppColors.surface(isDark);
    final Color borderColor = AppColors.border(isDark);
    final Color textPrimary = AppColors.textPrimary(isDark);
    final Color textSecondary = AppColors.textSecondary(isDark);

    final List<String> filterOptions = ['Tất cả', ...botState.members];
    if (!filterOptions.contains(_selectedMemberFilter)) {
      _selectedMemberFilter = 'Tất cả';
    }

    final categoryTotals = botState.categoryTotals;
    final int totalSpent = botState.totalSpentThisMonth.clamp(1, 999999999);

    final filteredTransactions = botState.transactions.where((tx) {
      if (_selectedMemberFilter == 'Tất cả') return true;
      return tx.payerName == _selectedMemberFilter;
    }).toList();

    final double maxBudgetM =
        math.max(1.0, botState.monthlyBudget / 1000000.0);
    final runwaySpots = _buildRunwaySpots(botState);
    final Color runwayColor = botState.predictedRunwayDays <= 10
        ? AppColors.rose
        : AppColors.emerald;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            // 1. Dynamic 30-Day Runway Trajectory Chart Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dự Báo Đường Băng Sinh Tồn',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Còn lại: ${HybridNlpService.formatVnd(botState.remainingMonthlyBudget)} / ${HybridNlpService.formatVnd(botState.monthlyBudget)}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: runwayColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${botState.predictedRunwayDays} ngày',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: runwayColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 148,
                    child: LineChart(
                      LineChartData(
                        minX: 1,
                        maxX: 30,
                        minY: 0,
                        maxY: maxBudgetM * 1.08,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxBudgetM / 2,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: borderColor.withValues(alpha: 0.6),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 38,
                              interval: maxBudgetM / 2,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toStringAsFixed(1)}M',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval: 10,
                              getTitlesWidget: (value, meta) {
                                final day = value.toInt();
                                if (day != 1 &&
                                    day != 10 &&
                                    day != 20 &&
                                    day != 30) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    day == 10 ? 'Hôm nay' : 'N$day',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: day == 10
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: day == 10
                                          ? runwayColor
                                          : textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) {
                              return spots.map((spot) {
                                final vnd = (spot.y * 1000000).round();
                                return LineTooltipItem(
                                  'Ngày ${spot.x.toInt()}\n${HybridNlpService.formatCompactVnd(vnd)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: runwaySpots,
                            isCurved: true,
                            preventCurveOverShooting: true,
                            color: runwayColor,
                            barWidth: 3.2,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                final isToday = spot.x.toInt() == 10;
                                return FlDotCirclePainter(
                                  radius: isToday ? 4.5 : 2.5,
                                  color: isToday ? Colors.white : runwayColor,
                                  strokeWidth: isToday ? 2.5 : 0,
                                  strokeColor: runwayColor,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: runwayColor.withValues(alpha: 0.14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Category Breakdown Progress Bars
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cơ Cấu Chi Tiêu Theo Danh Mục',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...ExpenseCategory.values.map((cat) {
                    final amount = categoryTotals[cat] ?? 0;
                    if (amount == 0) return const SizedBox.shrink();
                    final pct = (amount / totalSpent).clamp(0.0, 1.0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${cat.emoji} ${cat.labelVi}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${HybridNlpService.formatVnd(amount)} (${(pct * 100).toStringAsFixed(0)}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: cat.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 7,
                              backgroundColor:
                                  AppColors.secondarySurface(isDark),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(cat.color),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Overflow-Safe Filterable Group Ledger
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sổ Giao Dịch ${botState.groupName}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filterOptions.map((filter) {
                      final active = _selectedMemberFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedMemberFilter = filter);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: active ? AppColors.emerald : cardSurface,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: active ? AppColors.emerald : borderColor,
                              ),
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: active ? Colors.white : textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...filteredTransactions.reversed.map((tx) {
              final timeText = DateFormat('HH:mm').format(tx.timestamp);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  onTap: () => showEditTransactionDialog(
                    context: context,
                    transaction: tx,
                    members: botState.members,
                    onSave: ({
                      required title,
                      required amountVnd,
                      required category,
                      required payerName,
                    }) {
                      notifier.editTransaction(
                        tx.id,
                        title: title,
                        amountVnd: amountVnd,
                        category: category,
                        payerName: payerName,
                      );
                    },
                    onDelete: () => notifier.deleteTransaction(tx.id),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: tx.category.color.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              tx.category.emoji,
                              style: const TextStyle(fontSize: 19),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tx.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '${tx.payerName} • $timeText',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (tx.isSettled
                                              ? AppColors.emerald
                                              : AppColors.amber)
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      tx.isSettled ? 'Đã chốt' : 'Chờ gạch nợ',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: tx.isSettled
                                            ? AppColors.emerald
                                            : AppColors.amber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '-${HybridNlpService.formatVnd(tx.amountVnd)}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.rose,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
