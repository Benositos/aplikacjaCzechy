import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart' show StepEntry;
import '../../data/repositories/steps_repository.dart';

/// 0 = current month, -1 = previous month.
final stepsMonthOffsetProvider = StateProvider<int>((_) => 0);

final stepsMonthStartProvider = Provider<DateTime>((ref) {
  final offset = ref.watch(stepsMonthOffsetProvider);
  final now = DateTime.now();
  return DateTime(now.year, now.month + offset, 1);
});

final monthlyStepsProvider = StreamProvider.autoDispose<List<StepEntry>>((ref) {
  final monthStart = ref.watch(stepsMonthStartProvider);
  final repo = ref.watch(stepsRepositoryProvider);
  Future.microtask(() => repo.refreshMonth(monthStart));
  return repo.watchMonth(monthStart);
});

final todayStepsProvider = StreamProvider.autoDispose<StepEntry?>((ref) {
  final repo = ref.watch(stepsRepositoryProvider);
  Future.microtask(() => repo.refreshToday());
  return repo.watchDate(DateTime.now());
});
