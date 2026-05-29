import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/health_service.dart';
import '../../shared/widgets/section_label.dart';
import 'onboarding_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(onboardingControllerProvider.notifier).refresh();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _requestHealth() async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final sdk = await controller.requestHealth();
    if (!mounted) return;
    switch (sdk) {
      case HealthSdkStatus.available:
        final granted = ref.read(onboardingControllerProvider).healthGranted;
        _snack(granted
            ? 'Health Connect: granted'
            : 'Health Connect: not granted — open phone Settings to allow manually');
        break;
      case HealthSdkStatus.needsUpdate:
        _snack('Health Connect needs update — install from Play Store');
        break;
      case HealthSdkStatus.unavailable:
        _snack('Health Connect not available on this device');
        break;
    }
  }

  Future<void> _openUsageSettings() async {
    await ref.read(onboardingControllerProvider.notifier).openUsageSettings();
    if (!mounted) return;
    _snack('Usage Access settings opened — toggle Calma, then come back');
  }

  Future<void> _onContinue() async {
    final state = ref.read(onboardingControllerProvider);
    final repo = ref.read(profileRepositoryProvider);
    await repo.setDailyStepGoal(state.dailyStepGoal);
    await repo.markOnboardingComplete();
    if (mounted) context.go(AppRoutes.steps);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final profile = ref.watch(profileProvider).valueOrNull;
    if (profile != null && state.dailyStepGoal == 8000 && profile.dailyStepGoal != 8000) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.setStepGoal(profile.dailyStepGoal);
      });
    }
    final f = NumberFormat.decimalPattern('en_US');

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.space8),
              Center(
                child: Image.asset(
                  'assets/logo/logo.png',
                  height: MediaQuery.of(context).size.height * 0.25,
                  fit: BoxFit.contain,
                  color: theme.colorScheme.onSurface,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              const HeroAccentStripe(accent: AppColors.accentCyan),
              const SizedBox(height: AppTheme.space4),
              const SectionLabel(text: 'WELCOME', accent: AppColors.accentCyan),
              const SizedBox(height: AppTheme.space3),
              Text('Calma.', style: theme.textTheme.displayMedium),
              const SizedBox(height: AppTheme.space3),
              Text(
                'Track your steps and screen time. Calm, deliberate, yours.',
                style: theme.textTheme.bodyLarge,
              ),

              const SizedBox(height: AppTheme.space12),
              _PermissionRow(
                index: '01',
                title: 'Health Connect',
                description: state.healthSdkStatus == HealthSdkStatus.unavailable
                    ? 'Not available on this device — steps stay zero.'
                    : state.healthSdkStatus == HealthSdkStatus.needsUpdate
                        ? 'Update Health Connect via Play Store, then try again.'
                        : 'For step counting. We read step totals from Health Connect.',
                granted: state.healthGranted,
                actionLabel: 'Grant access',
                onAction: _requestHealth,
              ),
              const SizedBox(height: AppTheme.space4),
              _PermissionRow(
                index: '02',
                title: 'Usage Access',
                description: 'For screen time. Opens system settings — toggle "Usage access" for Calma.',
                granted: state.usageGranted,
                actionLabel: 'Open settings',
                onAction: _openUsageSettings,
              ),

              const SizedBox(height: AppTheme.space8),
              Text(
                '03',
                style: AppTextStyles.labelSmall.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppTheme.space2),
              Text('Daily step goal', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppTheme.space2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    f.format(state.dailyStepGoal),
                    style: AppTextStyles.mono(fontSize: 36, fontWeight: FontWeight.w600).copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space2),
                  Text('steps / day', style: theme.textTheme.bodyMedium),
                ],
              ),
              Slider(
                value: state.dailyStepGoal.toDouble(),
                min: 2000,
                max: 20000,
                divisions: 36,
                onChanged: (v) => controller.setStepGoal(v.round()),
              ),

              const SizedBox(height: AppTheme.space8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onContinue,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppTheme.space2),
                    child: Text('Continue'),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space2),
              Text(
                'You can change goal and grant permissions later in Settings.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.space6),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.index,
    required this.title,
    required this.description,
    required this.granted,
    required this.actionLabel,
    required this.onAction,
  });

  final String index;
  final String title;
  final String description;
  final bool granted;
  final String actionLabel;
  final VoidCallback onAction;

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
          Row(
            children: [
              Text(
                index,
                style: AppTextStyles.labelSmall.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: AppTheme.space2),
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              if (granted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Granted',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.accentGreen,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space2),
          Text(description, style: theme.textTheme.bodyMedium),
          if (!granted) ...[
            const SizedBox(height: AppTheme.space3),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
