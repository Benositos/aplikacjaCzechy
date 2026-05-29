import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../data/local/database.dart' show StepEntry;
import '../../data/repositories/profile_repository.dart';
import '../../data/services/health_service.dart';
import '../../shared/widgets/permission_banner.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/skeleton.dart';
import 'steps_controller.dart';

class StepsScreen extends ConsumerStatefulWidget {
  const StepsScreen({super.key});

  @override
  ConsumerState<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends ConsumerState<StepsScreen>
    with WidgetsBindingObserver {
  bool? _permissionGranted; // null = checking

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final svc = ref.read(healthServiceProvider);
    final sdk = await svc.sdkStatus();
    final granted = sdk == HealthSdkStatus.available && await svc.hasPermission();
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final todayAsync = ref.watch(todayStepsProvider);
    final offset = ref.watch(stepsMonthOffsetProvider);
    final monthStart = ref.watch(stepsMonthStartProvider);
    final monthlyAsync = ref.watch(monthlyStepsProvider);

    final goal = profile?.dailyStepGoal ?? 8000;
    final todayCount = todayAsync.valueOrNull?.steps ?? 0;
    final progress = goal > 0 ? (todayCount / goal).clamp(0.0, 1.5) : 0.0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space6,
            3,
            AppTheme.space6,
            AppTheme.space6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HeroAccentStripe(accent: AppColors.accentCyan),
              const SizedBox(height: AppTheme.space4),
              const SectionLabel(text: '01 · STEPS', accent: AppColors.accentCyan),
              const SizedBox(height: AppTheme.space3),
              Text('Today.', style: Theme.of(context).textTheme.headlineLarge),

              if (_permissionGranted == false) ...[
                const SizedBox(height: AppTheme.space4),
                PermissionBanner(
                  accent: AppColors.accentCyan,
                  title: 'Health Connect not granted',
                  description:
                      'Grant access to read your step count. Without it this tab stays empty.',
                  actionLabel: 'Open Settings',
                  onAction: PermissionBanner.goToSettings(context),
                ),
              ],

              const SizedBox(height: AppTheme.space6),
              _TodayHero(count: todayCount, goal: goal, progress: progress),

              const SizedBox(height: AppTheme.space8),
              _MonthSwitcher(
                offset: offset,
                onChanged: (v) => ref.read(stepsMonthOffsetProvider.notifier).state = v,
              ),
              const SizedBox(height: AppTheme.space4),
              monthlyAsync.when(
                loading: () => const ChartSkeleton(),
                error: (e, _) => SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'Could not read steps.\n$e',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (entries) => _MonthlyChart(
                  entries: entries,
                  monthStart: monthStart,
                  goal: goal,
                ),
              ),

              const SizedBox(height: AppTheme.space6),
              monthlyAsync.maybeWhen(
                data: (entries) => _StatsRow(entries: entries),
                orElse: () => const _StatsSkeleton(),
              ),

              const SizedBox(height: AppTheme.space6),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.count, required this.goal, required this.progress});
  final int count;
  final int goal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = NumberFormat.decimalPattern('en_US');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              f.format(count),
              style: AppTextStyles.mono(fontSize: 56, fontWeight: FontWeight.w600).copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppTheme.space3),
            Text(
              '/ ${f.format(goal)}',
              style: AppTextStyles.mono(fontSize: 20).copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space2),
        Text(
          progress >= 1.0
              ? 'goal reached'
              : 'steps · ${(progress * 100).toStringAsFixed(0)}% of goal',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppTheme.space3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: theme.colorScheme.outlineVariant,
            valueColor: const AlwaysStoppedAnimation(AppColors.accentCyan),
          ),
        ),
      ],
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({required this.offset, required this.onChanged});
  final int offset;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MonthChip(label: 'Current month', selected: offset == 0, onTap: () => onChanged(0)),
        const SizedBox(width: AppTheme.space2),
        _MonthChip(label: 'Previous month', selected: offset == -1, onTap: () => onChanged(-1)),
      ],
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: AnimatedContainer(
        duration: AppTheme.motionDefault,
        curve: AppTheme.motionCurve,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space3,
          vertical: AppTheme.space2,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? theme.colorScheme.onSurface : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          color: selected ? theme.colorScheme.onSurface.withValues(alpha: 0.04) : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({
    required this.entries,
    required this.monthStart,
    required this.goal,
  });
  final List<StepEntry> entries;
  final DateTime monthStart;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth = DateUtils.getDaysInMonth(monthStart.year, monthStart.month);
    final byDay = {for (final e in entries) e.date.day: e.steps};
    final maxValue = [...byDay.values, goal].fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxValue * 1.15).clamp(1000, double.infinity).toDouble();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceBetween,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: goal.toDouble(),
                color: theme.colorScheme.outline,
                strokeWidth: 1,
                dashArray: const [4, 4],
              ),
            ],
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  final day = value.toInt();
                  // In 31-day months, hide "30" because the "31" label sits
                  // right next to it and they visually collide.
                  final hideFiveMark = daysInMonth == 31 && day == 30;
                  final isFiveMark = day % 5 == 0 && !hideFiveMark;
                  if (day != 1 && !isFiveMark && day != daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      day.toString(),
                      style: AppTextStyles.mono(fontSize: 10).copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.onSurface,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tooltipMargin: 8,
              getTooltipItem: (group, _, rod, _) {
                return BarTooltipItem(
                  '${group.x.toString().padLeft(2, '0')} · ${rod.toY.toInt()} steps',
                  AppTextStyles.mono(fontSize: 11).copyWith(
                    color: theme.colorScheme.surface,
                  ),
                );
              },
            ),
          ),
          barGroups: List.generate(daysInMonth, (i) {
            final day = i + 1;
            final value = (byDay[day] ?? 0).toDouble();
            return BarChartGroupData(
              x: day,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: 6,
                  borderRadius: BorderRadius.circular(2),
                  color: value >= goal
                      ? AppColors.accentCyan
                      : AppColors.accentCyan.withValues(alpha: 0.4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.entries});
  final List<StepEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(
        'No data yet for this month.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final f = NumberFormat.decimalPattern('en_US');
    final daysWithData = entries.where((e) => e.steps > 0).toList();
    final total = entries.fold<int>(0, (a, e) => a + e.steps);
    final avg = daysWithData.isEmpty ? 0 : (total / daysWithData.length).round();
    final best = entries.fold<int>(0, (a, e) => e.steps > a ? e.steps : a);
    return Row(
      children: [
        _Stat(label: 'AVERAGE', value: f.format(avg)),
        const SizedBox(width: AppTheme.space6),
        _Stat(label: 'BEST DAY', value: f.format(best)),
        const SizedBox(width: AppTheme.space6),
        _Stat(label: 'TOTAL', value: f.format(total)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.mono(fontSize: 18, fontWeight: FontWeight.w600).copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Skeleton(height: 36)),
        SizedBox(width: AppTheme.space6),
        Expanded(child: Skeleton(height: 36)),
        SizedBox(width: AppTheme.space6),
        Expanded(child: Skeleton(height: 36)),
      ],
    );
  }
}
