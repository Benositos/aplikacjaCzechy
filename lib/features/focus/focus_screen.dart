import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../data/local/database.dart' show AppUsageEntry;
import '../../data/services/usage_service.dart';
import '../../shared/widgets/permission_banner.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/skeleton.dart';
import 'focus_controller.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with WidgetsBindingObserver {
  bool? _permissionGranted;

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
    final granted = await ref.read(usageServiceProvider).hasPermission();
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayUsageProvider);
    final offset = ref.watch(focusMonthOffsetProvider);
    final monthStart = ref.watch(focusMonthStartProvider);
    final monthlyAsync = ref.watch(monthlyUsageProvider);

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
              const HeroAccentStripe(accent: AppColors.accentMagenta),
              const SizedBox(height: AppTheme.space4),
              const SectionLabel(text: '02 · FOCUS', accent: AppColors.accentMagenta),
              const SizedBox(height: AppTheme.space3),
              Text('Today.', style: Theme.of(context).textTheme.headlineLarge),

              if (_permissionGranted == false) ...[
                const SizedBox(height: AppTheme.space4),
                PermissionBanner(
                  accent: AppColors.accentMagenta,
                  title: 'Usage Access not granted',
                  description:
                      'Grant access in system Settings to see your screen time. This tab stays empty until then.',
                  actionLabel: 'Open Settings',
                  onAction: PermissionBanner.goToSettings(context),
                ),
              ],

              const SizedBox(height: AppTheme.space6),
              todayAsync.when(
                loading: () => const Skeleton(height: 72),
                error: (e, _) => Text(
                  'Could not read screen time.\nGrant Usage Access in Settings to continue.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                data: (entries) => _TodayHero(entries: entries),
              ),

              const SizedBox(height: AppTheme.space8),
              Text(
                'TOP APPS TODAY',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.accentMagenta,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              todayAsync.maybeWhen(
                data: (entries) => _TopApps(entries: entries),
                orElse: () => const _TopAppsSkeleton(),
              ),

              const SizedBox(height: AppTheme.space8),
              _MonthSwitcher(
                offset: offset,
                onChanged: (v) => ref.read(focusMonthOffsetProvider.notifier).state = v,
              ),
              const SizedBox(height: AppTheme.space4),
              monthlyAsync.when(
                loading: () => const ChartSkeleton(),
                error: (e, _) => SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'Could not read usage.\n$e',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (entries) => _MonthlyChart(entries: entries, monthStart: monthStart),
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

String _formatDuration(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.entries});
  final List<AppUsageEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMinutes = entries.fold<int>(0, (a, e) => a + e.minutesUsed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDuration(totalMinutes),
          style: AppTextStyles.mono(fontSize: 56, fontWeight: FontWeight.w600).copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppTheme.space2),
        Text(
          totalMinutes == 0
              ? 'no screen time recorded today'
              : 'across ${entries.length} app${entries.length == 1 ? '' : 's'}',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _TopApps extends StatelessWidget {
  const _TopApps({required this.entries});
  final List<AppUsageEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return Text(
        'No usage recorded yet today.',
        style: theme.textTheme.bodySmall,
      );
    }
    final top = entries.take(5).toList();
    return Column(
      children: [
        for (final e in top) ...[
          _AppRow(entry: e),
          if (e != top.last)
            Divider(color: theme.colorScheme.outlineVariant, height: 1),
        ],
      ],
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.entry});
  final AppUsageEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = entry.appLabel ?? entry.packageName.split('.').last;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          Text(
            _formatDuration(entry.minutesUsed),
            style: AppTextStyles.mono(fontSize: 14, fontWeight: FontWeight.w500).copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopAppsSkeleton extends StatelessWidget {
  const _TopAppsSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.space3),
          child: Skeleton(height: 20),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.space3),
          child: Skeleton(height: 20),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.space3),
          child: Skeleton(height: 20),
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
  const _MonthlyChart({required this.entries, required this.monthStart});
  final List<AppUsageEntry> entries;
  final DateTime monthStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth = DateUtils.getDaysInMonth(monthStart.year, monthStart.month);
    final perDay = <int, int>{};
    for (final e in entries) {
      perDay.update(e.date.day, (v) => v + e.minutesUsed, ifAbsent: () => e.minutesUsed);
    }
    perDay.updateAll((_, v) => v > 1440 ? 1440 : v);
    final maxValue = perDay.values.fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxValue * 1.15).clamp(60, double.infinity).toDouble();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceBetween,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
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
                  if (day != 1 && day % 5 != 0 && day != daysInMonth) {
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
                  '${group.x.toString().padLeft(2, '0')} · ${_formatDuration(rod.toY.toInt())}',
                  AppTextStyles.mono(fontSize: 11).copyWith(
                    color: theme.colorScheme.surface,
                  ),
                );
              },
            ),
          ),
          barGroups: List.generate(daysInMonth, (i) {
            final day = i + 1;
            final value = (perDay[day] ?? 0).toDouble();
            return BarChartGroupData(
              x: day,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: 6,
                  borderRadius: BorderRadius.circular(2),
                  color: AppColors.accentMagenta.withValues(alpha: value > 0 ? 0.9 : 0.2),
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
  final List<AppUsageEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(
        'No data yet for this month.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final perDay = <int, int>{};
    for (final e in entries) {
      perDay.update(e.date.day, (v) => v + e.minutesUsed, ifAbsent: () => e.minutesUsed);
    }
    perDay.updateAll((_, v) => v > 1440 ? 1440 : v);
    final totalMinutes = perDay.values.fold<int>(0, (a, b) => a + b);
    final daysWithData = perDay.length;
    final avgPerDay = daysWithData == 0 ? 0 : (totalMinutes / daysWithData).round();
    final longest = perDay.values.fold<int>(0, (a, b) => b > a ? b : a);
    return Row(
      children: [
        _Stat(label: 'AVG / DAY', value: _formatDuration(avgPerDay)),
        const SizedBox(width: AppTheme.space6),
        _Stat(label: 'LONGEST', value: _formatDuration(longest)),
        const SizedBox(width: AppTheme.space6),
        _Stat(label: 'TOTAL', value: _formatDuration(totalMinutes)),
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
