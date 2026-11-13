import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/savage_bot_provider.dart';
import '../services/hybrid_nlp_service.dart';
import '../theme/app_tokens.dart';

class JudgePitchSheet extends ConsumerWidget {
  const JudgePitchSheet({super.key});

  static const List<({String title, String badge, String body})> _sixPillars = [
    (
      title: '1. Problem Analysis (25%)',
      badge: 'TAM 20M • 82.8% Churn',
      body:
          '• Market Sizing: TAM 15–20M Vietnamese Gen Z, SAM 2.2M university students, SOM 50k–100k Year-1 adopters.\n'
          '• Primary Research (N=180): 82.8% abandon manual expense trackers within 7 days due to tedious categorization & lack of emotional payoff.',
    ),
    (
      title: '2. Value Proposition (20%)',
      badge: '<2s Entry • Closed-Loop',
      body:
          '• <2s colloquial Vietnamese text & voice logging ("1 củ rưỡi", "55 ca", "trà sữa năm mươi lăm nghìn").\n'
          '• Dual-Persona behavioral feedback (Savage Roast vs. Coach) + instant closed-loop NAPAS 247 VietQR roommate split.',
    ),
    (
      title: '3. Stakeholder Map',
      badge: 'Decree 13/2023/ND-CP',
      body:
          '• Core Users: Dorm & off-campus Gen Z students.\n'
          '• Distribution Partners: University Student Unions & Campus Clubs.\n'
          '• Ecosystem: Hyperlocal F&B/convenience merchants & Regulators (full compliance with Vietnam Decree 13/2023/ND-CP on personal data protection).',
    ),
    (
      title: '4. MVP Architecture (20%)',
      badge: 'Tier-1 0đ + EMVCo QR',
      body:
          '• Hybrid NLP Router: ~76%+ queries execute on-device via Tier-1 Regex (<2ms, 0 VND API cost); complex receipts/queries escalate to Tier-2 Vision/LLM.\n'
          '• Real EMVCo NAPAS 247 VietQR generator with CRC-16/CCITT-FALSE checksum for live banking app verification.',
    ),
    (
      title: '5. Viability & GTM (20%)',
      badge: 'CAC <6k • LTV 18–24m',
      body:
          '• Viral Loop: "Roast My Spending" shareable dorm challenges drive organic CAC < 6,000 VND.\n'
          '• 3-Phase Rollout: Phase 1 Swinburne & Cau Giay Dorms (5k MAU) → Phase 2 Hanoi/HCMC Clusters (30k MAU) → Phase 3 Nationwide Student Pro SaaS (100k+ MAU).',
    ),
    (
      title: '6. Risk & Mitigation',
      badge: 'Cost Cap & Safety',
      body:
          '• LLM Token Spike Risk → Throttled by Tier-1 local regex routing & daily Tier-2 quota caps.\n'
          '• Tone Sensitivity Risk → 1-tap toggle between Savage Roast and Gentle Coach.\n'
          '• Privacy Risk → Local-first storage architecture with zero raw banking credential retention.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final botState = ref.watch(savageBotProvider);
    final notifier = ref.read(savageBotProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double mau = botState.simulatedMau;
    const double conversionRate = 0.035; // 3.5% Student Pro conversion
    const int proPriceVnd = 19000;
    const int fixedMonthlyInfraVnd = 12500000;
    const int avgMonthlyQueriesPerMau = 10;

    final int paidUsers = (mau * conversionRate).round();
    final int monthlyMrr = paidUsers * proPriceVnd;

    final double tier1Ratio = botState.tier1RatioPercent;
    final double tier2Ratio = (100.0 - tier1Ratio).clamp(5.0, 95.0);
    final int variableApiCost =
        (mau * (tier2Ratio / 100.0) * avgMonthlyQueriesPerMau * 110).round();
    final int monthlyInfraAndApiCost = fixedMonthlyInfraVnd + variableApiCost;
    final int breakEvenPaidUsers =
        (monthlyInfraAndApiCost / proPriceVnd).ceil();
    final int netOperatingProfit = monthlyMrr - monthlyInfraAndApiCost;
    final bool isBreakEvenReached = paidUsers >= breakEvenPaidUsers;

    final double maxChartY = math.max(
          1000000.0,
          math.max(monthlyMrr, monthlyInfraAndApiCost).toDouble(),
        ) *
        1.25;

    final Color bgColor =
        isDark ? AppColors.darkNavigationBg : const Color(0xFFFBFBF9);
    final Color cardColor =
        isDark ? AppColors.darkElevatedSurface : Colors.white;
    final Color borderColor =
        isDark ? AppColors.darkBorderStrong : AppColors.lightBorder;
    final Color textPrimary = AppColors.textPrimary(isDark);
    final Color textSecondary = AppColors.textSecondary(isDark);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Banner
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.emerald,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Swin-Biz Rockstar 2026 • Judge Console',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Grand Final Defense Dossier • Real-Time Unit Economics',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card 1: Live Hybrid NLP Cost Ratio Telemetry
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '1. Hybrid NLP Cost Ratio (Live)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${tier1Ratio.toStringAsFixed(1)}% @ 0đ API',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emeraldDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: SizedBox(
                      height: 12,
                      child: Row(
                        children: [
                          Expanded(
                            flex: tier1Ratio.round().clamp(1, 99),
                            child: Container(color: AppColors.emerald),
                          ),
                          Expanded(
                            flex: (100 - tier1Ratio.round()).clamp(1, 99),
                            child: Container(color: AppColors.violet),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        '🟢 Tier-1 Regex (${botState.tier1QueryCount} logs • 0đ)',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '🟣 Tier-2 OCR/LLM (${botState.tier2QueryCount} logs • 110đ)',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Card 2: Interactive Dynamic Unit Economics Stress-Test
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '2. Dynamic Unit Economics',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (isBreakEvenReached
                                    ? AppColors.emerald
                                    : AppColors.rose)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            isBreakEvenReached
                                ? 'Break-Even ($paidUsers / $breakEvenPaidUsers Pro)'
                                : 'Pre-BE ($paidUsers / $breakEvenPaidUsers Pro)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isBreakEvenReached
                                  ? AppColors.emeraldDark
                                  : AppColors.roseDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Simulated MAU (3.5% Pro @ 19k):',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ),
                      Text(
                        '${mau.round()} MAU',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.emerald,
                      thumbColor: AppColors.emerald,
                      inactiveTrackColor:
                          AppColors.emerald.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      min: 1000,
                      max: 100000,
                      divisions: 99,
                      value: mau,
                      onChanged: (val) => notifier.updateSimulatedMau(val),
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'CAC (Dorm Viral)',
                          value: '< 6.000đ',
                          accent: AppColors.emerald,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricTile(
                          label: 'Student LTV',
                          value: '18–24 mo',
                          accent: AppColors.violet,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricTile(
                          label: 'Live Break-Even',
                          value: '$breakEvenPaidUsers Pro',
                          accent: AppColors.amber,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 132,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxChartY,
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 38,
                              getTitlesWidget: (value, meta) {
                                final labels = [
                                  'MRR\n(${HybridNlpService.formatCompactVnd(monthlyMrr)})',
                                  'Infra + AI\n(${HybridNlpService.formatCompactVnd(monthlyInfraAndApiCost)})',
                                  netOperatingProfit >= 0
                                      ? 'Net Profit\n(+${HybridNlpService.formatCompactVnd(netOperatingProfit)})'
                                      : 'Net Loss\n(${HybridNlpService.formatCompactVnd(netOperatingProfit)})',
                                ];
                                final idx = value.toInt();
                                if (idx < 0 || idx >= labels.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    labels[idx],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: idx == 2 && netOperatingProfit < 0
                                          ? AppColors.rose
                                          : textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: monthlyMrr.toDouble(),
                                color: AppColors.emerald,
                                width: 28,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 1,
                            barRods: [
                              BarChartRodData(
                                toY: monthlyInfraAndApiCost.toDouble(),
                                color: AppColors.rose,
                                width: 28,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 2,
                            barRods: [
                              BarChartRodData(
                                toY: netOperatingProfit > 0
                                    ? netOperatingProfit.toDouble()
                                    : 0.0,
                                color: AppColors.violet,
                                width: 28,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: 6 Mandatory Swin-Biz Proposal Pillars (Collapsible)
            Text(
              '3. Swin-Biz Executive Dossier (6 Mandatory Pillars)',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ..._sixPillars.map((pillar) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: borderColor),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pillar.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.violet.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            pillar.badge,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.violetLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          pillar.body,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
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

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final bool isDark;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
