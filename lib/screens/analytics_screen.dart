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
  ExpenseCategory? _selectedCategoryFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyAnalyticsReport(SavageBotState botState) {
    HapticFeedback.mediumImpact();
    final buffer = StringBuffer();
    buffer.writeln(
      '📊 BÁO CÁO TÀI CHÍNH SAVAGEBOT • ${botState.groupName.toUpperCase()}',
    );
    buffer.writeln(
      '• Đã chi tháng này: ${HybridNlpService.formatVnd(botState.totalSpentThisMonth)} / ${HybridNlpService.formatVnd(botState.monthlyBudget)} (${(botState.monthlyBudgetUsedRatio * 100).round()}%)',
    );
    buffer.writeln(
      '• Hạn mức an toàn hôm nay: ${HybridNlpService.formatVnd(botState.dailySafeToSpend)}',
    );
    buffer.writeln(
      '• Đường băng sinh tồn: ${botState.predictedRunwayDays} ngày',
    );
    if (botState.topSpendingCategory != null) {
      final topCat = botState.topSpendingCategory!;
      final topAmt = botState.categoryTotals[topCat] ?? 0;
      buffer.writeln(
        '• Danh mục ngốn nhiều nhất: ${topCat.emoji} ${topCat.labelVi} (${HybridNlpService.formatVnd(topAmt)})',
      );
    }
    if (botState.transactions.isNotEmpty) {
      buffer.writeln('--- Giao dịch gần đây (${botState.transactions.length} GD) ---');
      for (final tx in botState.transactions.reversed.take(10)) {
        buffer.writeln(
          '• ${tx.category.emoji} ${tx.title}: -${HybridNlpService.formatVnd(tx.amountVnd)} (${tx.payerName})',
        );
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.emerald,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        content: const Text(
          'Đã sao chép báo cáo phân tích ví vào bộ nhớ tạm! 📊📋',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _handleDeleteTransaction(
    String txId,
    SavageBotNotifier notifier,
  ) {
    HapticFeedback.mediumImpact();
    final deleted = notifier.deleteTransaction(txId);
    if (deleted != null && mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.darkElevatedSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          content: Text(
            'Đã xóa "${deleted.transaction.title}" (${HybridNlpService.formatVnd(deleted.transaction.amountVnd)})',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          action: SnackBarAction(
            label: 'Hoàn tác',
            textColor: AppColors.emerald,
            onPressed: () {
              notifier.restoreDeletedTransaction(
                deleted.transaction,
                linkedSplit: deleted.linkedSplit,
              );
            },
          ),
        ),
      );
    }
  }

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
    final Color secondarySurface = AppColors.secondarySurface(isDark);
    final Color borderColor = AppColors.border(isDark);
    final Color textPrimary = AppColors.textPrimary(isDark);
    final Color textSecondary = AppColors.textSecondary(isDark);

    final List<String> filterOptions = ['Tất cả', ...botState.members];
    if (!filterOptions.contains(_selectedMemberFilter)) {
      _selectedMemberFilter = 'Tất cả';
    }

    final categoryTotals = botState.categoryTotals;
    final int totalSpent = botState.totalSpentThisMonth.clamp(1, 999999999);
    final ExpenseCategory? topCat = botState.topSpendingCategory;

    final String cleanQuery = _searchQuery.trim().toLowerCase();
    final filteredTransactions = botState.transactions.where((tx) {
      if (_selectedMemberFilter != 'Tất cả' &&
          tx.payerName != _selectedMemberFilter) {
        return false;
      }
      if (_selectedCategoryFilter != null &&
          tx.category != _selectedCategoryFilter) {
        return false;
      }
      if (cleanQuery.isNotEmpty) {
        final matchTitle = tx.title.toLowerCase().contains(cleanQuery);
        final matchPayer = tx.payerName.toLowerCase().contains(cleanQuery);
        final matchCat =
            tx.category.labelVi.toLowerCase().contains(cleanQuery);
        if (!matchTitle && !matchPayer && !matchCat) return false;
      }
      return true;
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
            // 0. Executive KPI Headline Strip (3 Cards)
            Row(
              children: [
                Expanded(
                  child: _KpiSummaryCard(
                    label: 'Tổng đã chi',
                    value: HybridNlpService.formatCompactVnd(
                      botState.totalSpentThisMonth,
                    ),
                    subtext:
                        '${(botState.monthlyBudgetUsedRatio * 100).round()}% ngân sách',
                    accentColor: botState.monthlyBudgetUsedRatio > 0.8
                        ? AppColors.rose
                        : AppColors.emerald,
                    cardSurface: cardSurface,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiSummaryCard(
                    label: 'TB / Giao dịch',
                    value: HybridNlpService.formatCompactVnd(
                      botState.averageTransactionVnd,
                    ),
                    subtext: '${botState.transactions.length} giao dịch',
                    accentColor: AppColors.violetLight,
                    cardSurface: cardSurface,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiSummaryCard(
                    label: 'Top ngốn tiền',
                    value: topCat != null
                        ? '${topCat.emoji} ${HybridNlpService.formatCompactVnd(categoryTotals[topCat] ?? 0)}'
                        : '0đ',
                    subtext: topCat != null ? topCat.labelVi : 'Chưa phát sinh',
                    accentColor: topCat?.color ?? AppColors.amber,
                    cardSurface: cardSurface,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

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
                        maxY: maxBudgetM,
                        clipData: const FlClipData.none(),
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

            // 2. Category Breakdown Progress Bars (Interactive: tap to filter ledger)
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
                        child: Text(
                          'Cơ Cấu Chi Tiêu Theo Danh Mục',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      if (_selectedCategoryFilter != null)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCategoryFilter = null);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedCategoryFilter!.color
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Bỏ lọc ${_selectedCategoryFilter!.emoji} ✕',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _selectedCategoryFilter!.color,
                              ),
                            ),
                          ),
                        )
                      else if (botState.totalSpentThisMonth > 0)
                        Text(
                          'Chạm mục để lọc',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (botState.totalSpentThisMonth == 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Chưa có dữ liệu chi tiêu tháng này. Ghi khoản đầu tiên ở Tab AI Trợ Lý để xem biểu đồ phân bổ nhé!',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    )
                  else
                    ...ExpenseCategory.values.map((cat) {
                      final amount = categoryTotals[cat] ?? 0;
                      if (amount == 0) return const SizedBox.shrink();
                      final pct = (amount / totalSpent).clamp(0.0, 1.0);
                      final bool isSelectedCat =
                          _selectedCategoryFilter == cat;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedCategoryFilter =
                                  isSelectedCat ? null : cat;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelectedCat ? 8 : 0,
                              vertical: isSelectedCat ? 6 : 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelectedCat
                                  ? cat.color.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${cat.emoji} ${cat.labelVi}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isSelectedCat
                                              ? FontWeight.w900
                                              : FontWeight.w700,
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
                                    backgroundColor: secondarySurface,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      cat.color,
                                    ),
                                  ),
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
            const SizedBox(height: 14),

            // 2.5 Roommate Contribution Breakdown (Group Mode only)
            if (botState.members.length > 1 &&
                botState.totalSpentThisMonth > 0) ...[
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
                          child: Text(
                            'Đóng Góp Chi Tiêu Theo Thành Viên',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          'Chạm để lọc sổ',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...botState.members.map((member) {
                      final spent = botState.payerTotals[member] ?? 0;
                      final pct = (spent / totalSpent).clamp(0.0, 1.0);
                      final bool isSelectedMember =
                          _selectedMemberFilter == member;
                      final bool isTreasurer = member == botState.treasurerName;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedMemberFilter =
                                  isSelectedMember ? 'Tất cả' : member;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelectedMember ? 8 : 0,
                              vertical: isSelectedMember ? 6 : 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelectedMember
                                  ? AppColors.violet.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isTreasurer ? '👑 $member' : '👤 $member',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isSelectedMember
                                              ? FontWeight.w900
                                              : FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${HybridNlpService.formatVnd(spent)} (${(pct * 100).toStringAsFixed(0)}%)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.violetLight,
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
                                    backgroundColor: secondarySurface,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      AppColors.violet,
                                    ),
                                  ),
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
              const SizedBox(height: 14),
            ],

            // 3. Overflow-Safe Filterable & Searchable Group Ledger
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Sổ Giao Dịch ${botState.groupName} (${filteredTransactions.length})',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: () => _copyAnalyticsReport(botState),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.ios_share_rounded,
                              size: 12,
                              color: AppColors.emerald,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Xuất báo cáo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (botState.transactions.isNotEmpty) ...[
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm món chi tiêu, danh mục, người chi...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 16,
                                color: textSecondary,
                              ),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: cardSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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
            if (filteredTransactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 30,
                      color: textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      botState.transactions.isEmpty
                          ? 'Chưa có giao dịch nào'
                          : 'Không tìm thấy giao dịch phù hợp bộ lọc',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      botState.transactions.isEmpty
                          ? 'Mọi khoản bạn ghi bằng text, giọng nói hoặc quét bill sẽ tự động hiện tại đây.'
                          : 'Hãy thử xóa từ khóa tìm kiếm hoặc chọn lại danh mục/thành viên.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...filteredTransactions.reversed.map((tx) {
                final timeText = DateFormat('HH:mm').format(tx.timestamp);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Dismissible(
                    key: ValueKey('ledger_tx_${tx.id}'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) =>
                        _handleDeleteTransaction(tx.id, notifier),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: AppColors.rose.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: AppColors.rose.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Vuốt để xóa',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.rose,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.rose,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
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
                        onDelete: () =>
                            _handleDeleteTransaction(tx.id, notifier),
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
                                        tx.isSettled
                                            ? 'Đã chốt'
                                            : 'Chờ gạch nợ',
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
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 13.5,
                                    color: textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _handleDeleteTransaction(
                                      tx.id,
                                      notifier,
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 15,
                                        color: AppColors.rose,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
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

class _KpiSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final Color accentColor;
  final Color cardSurface;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const _KpiSummaryCard({
    required this.label,
    required this.value,
    required this.subtext,
    required this.accentColor,
    required this.cardSurface,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
