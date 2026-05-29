import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database.dart';
import '../../features/steps/steps_controller.dart';
import 'milestone_evaluator.dart';

/// Listens to today's step provider. Each time the value changes, asks
/// [MilestoneEvaluator] to fire any newly-crossed step milestones.
///
/// Reading this provider once (from `app.dart`) keeps it alive for the
/// lifetime of the ProviderScope. It's a side-effecting "watcher" — the void
/// return value is just to satisfy Riverpod's typing.
///
/// Note: foreground-only. Background workmanager is intentionally deferred —
/// we can wire it in later when we find a Flutter 3.44-compatible version.
final milestoneWatcherProvider = Provider<void>((ref) {
  final evaluator = ref.watch(milestoneEvaluatorProvider);

  ref.listen<AsyncValue<StepEntry?>>(todayStepsProvider, (prev, next) {
    final steps = next.valueOrNull?.steps;
    if (steps == null) return;
    if (prev?.valueOrNull?.steps == steps) return;
    evaluator.evaluateSteps(currentSteps: steps);
  });
});
