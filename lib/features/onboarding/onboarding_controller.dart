import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/health_service.dart';
import '../../data/services/usage_service.dart';

class OnboardingState {
  const OnboardingState({
    this.healthGranted = false,
    this.healthSdkStatus = HealthSdkStatus.unavailable,
    this.usageGranted = false,
    this.dailyStepGoal = 8000,
  });

  final bool healthGranted;
  final HealthSdkStatus healthSdkStatus;
  final bool usageGranted;
  final int dailyStepGoal;

  OnboardingState copyWith({
    bool? healthGranted,
    HealthSdkStatus? healthSdkStatus,
    bool? usageGranted,
    int? dailyStepGoal,
  }) {
    return OnboardingState(
      healthGranted: healthGranted ?? this.healthGranted,
      healthSdkStatus: healthSdkStatus ?? this.healthSdkStatus,
      usageGranted: usageGranted ?? this.usageGranted,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
    );
  }
}

class OnboardingController extends Notifier<OnboardingState> {
  late final HealthService _health;
  late final UsageService _usage;

  @override
  OnboardingState build() {
    _health = ref.watch(healthServiceProvider);
    _usage = ref.watch(usageServiceProvider);
    refresh();
    return const OnboardingState();
  }

  Future<void> refresh() async {
    final results = await Future.wait([
      _health.sdkStatus(),
      _health.hasPermission(),
      _usage.hasPermission(),
    ]);
    final sdk = results[0] as HealthSdkStatus;
    final healthGranted = sdk == HealthSdkStatus.available && (results[1] as bool);
    final usageGranted = results[2] as bool;
    state = state.copyWith(
      healthSdkStatus: sdk,
      healthGranted: healthGranted,
      usageGranted: usageGranted,
    );
  }

  Future<HealthSdkStatus> requestHealth() async {
    final sdk = await _health.sdkStatus();
    if (sdk != HealthSdkStatus.available) {
      state = state.copyWith(healthSdkStatus: sdk);
      return sdk;
    }
    final granted = await _health.requestPermission();
    state = state.copyWith(healthGranted: granted, healthSdkStatus: sdk);
    return sdk;
  }

  Future<void> openUsageSettings() async {
    await _usage.openSettings();
    // Status will refresh when app resumes (lifecycle observer in screen).
  }

  void setStepGoal(int goal) {
    state = state.copyWith(dailyStepGoal: goal);
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(OnboardingController.new);
