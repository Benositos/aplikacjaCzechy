import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/health_service.dart';
import '../../data/services/usage_service.dart';
import '../../shared/widgets/section_label.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final repo = ref.read(profileRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space6,
            3,
            AppTheme.space6,
            AppTheme.space6,
          ),
          children: [
            const HeroAccentStripe(accent: AppColors.accentAmber),
            const SizedBox(height: AppTheme.space4),
            const SectionLabel(text: '04 · SETTINGS', accent: AppColors.accentAmber),
            const SizedBox(height: AppTheme.space3),
            Text('Calibrate.', style: theme.textTheme.headlineLarge),
            const SizedBox(height: AppTheme.space8),

            const _SectionLabel('GOAL'),
            _GoalSlider(
              value: profile?.dailyStepGoal ?? 8000,
              onChanged: repo.setDailyStepGoal,
            ),

            const SizedBox(height: AppTheme.space8),
            const _SectionLabel('NOTIFICATIONS'),
            _SwitchRow(
              title: 'Milestone notifications',
              subtitle:
                  'Gentle nudges when you cross a milestone (e.g. 75% of step goal, 2h screen time).',
              value: profile?.notificationsEnabled ?? true,
              onChanged: repo.setNotificationsEnabled,
            ),

            const SizedBox(height: AppTheme.space8),
            const _SectionLabel('APPEARANCE'),
            _ThemePicker(
              current: profile?.themeMode ?? 0,
              onSelected: repo.setThemeMode,
            ),

            const SizedBox(height: AppTheme.space8),
            const _SectionLabel('PERMISSIONS'),
            const _PermissionsBlock(),

            const SizedBox(height: AppTheme.space8),
            const _SectionLabel('ABOUT'),
            const _AboutBlock(),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.accentAmber,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _GoalSlider extends StatelessWidget {
  const _GoalSlider({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

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
              f.format(value),
              style: AppTextStyles.mono(fontSize: 32, fontWeight: FontWeight.w600).copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppTheme.space2),
            Text('steps / day', style: theme.textTheme.bodyMedium),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(2000, 20000),
          min: 2000,
          max: 20000,
          divisions: 36,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.current, required this.onSelected});
  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Chip(label: 'System', selected: current == 0, onTap: () => onSelected(0))),
        const SizedBox(width: AppTheme.space2),
        Expanded(child: _Chip(label: 'Light', selected: current == 1, onTap: () => onSelected(1))),
        const SizedBox(width: AppTheme.space2),
        Expanded(child: _Chip(label: 'Dark', selected: current == 2, onTap: () => onSelected(2))),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AnimatedContainer(
        duration: AppTheme.motionDefault,
        curve: AppTheme.motionCurve,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? theme.colorScheme.onSurface : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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

class _PermissionsBlock extends ConsumerStatefulWidget {
  const _PermissionsBlock();

  @override
  ConsumerState<_PermissionsBlock> createState() => _PermissionsBlockState();
}

class _PermissionsBlockState extends ConsumerState<_PermissionsBlock>
    with WidgetsBindingObserver {
  bool _health = false;
  HealthSdkStatus _healthSdk = HealthSdkStatus.unavailable;
  bool _usage = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final hs = ref.read(healthServiceProvider);
    final us = ref.read(usageServiceProvider);
    final results = await Future.wait([
      hs.sdkStatus(),
      hs.hasPermission(),
      us.hasPermission(),
    ]);
    if (!mounted) return;
    setState(() {
      _healthSdk = results[0] as HealthSdkStatus;
      _health = _healthSdk == HealthSdkStatus.available && (results[1] as bool);
      _usage = results[2] as bool;
      _refreshing = false;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _regrantHealth() async {
    final svc = ref.read(healthServiceProvider);
    final sdk = await svc.sdkStatus();
    if (sdk != HealthSdkStatus.available) {
      _snack(sdk == HealthSdkStatus.needsUpdate
          ? 'Health Connect needs update'
          : 'Health Connect unavailable on this device');
      return;
    }
    final granted = await svc.requestPermission();
    await _refresh();
    if (!mounted) return;
    _snack(granted
        ? 'Health Connect: granted'
        : 'Health Connect: not granted — try again or open phone Settings');
  }

  Future<void> _openUsageSettings() async {
    await ref.read(usageServiceProvider).openSettings();
    if (!mounted) return;
    _snack('Usage Access settings opened — toggle Calma, then come back');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PermRow(
          label: 'Health Connect',
          granted: _health,
          actionLabel: 'Re-grant',
          onAction: _regrantHealth,
        ),
        const SizedBox(height: AppTheme.space2),
        _PermRow(
          label: 'Usage Access',
          granted: _usage,
          actionLabel: 'Settings',
          onAction: _openUsageSettings,
        ),
      ],
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.label,
    required this.granted,
    required this.actionLabel,
    required this.onAction,
  });
  final String label;
  final bool granted;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space3),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(
            granted ? 'granted' : 'not granted',
            style: AppTextStyles.bodySmall.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _AboutBlock extends StatelessWidget {
  const _AboutBlock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/logo/wordmark.png',
            height: 56,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            color: theme.colorScheme.onSurface,
            colorBlendMode: BlendMode.srcIn,
          ),
          const SizedBox(height: AppTheme.space2),
          Text('Calma · Version 0.2.0', style: theme.textTheme.bodySmall),
          const SizedBox(height: AppTheme.space3),
          Text(
            'Local-only. No accounts. Data lives on this device.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
