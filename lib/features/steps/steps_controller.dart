import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/timezone_service.dart';
import '../../data/local/database.dart' show StepEntry;
import '../../data/repositories/steps_repository.dart';

/// 0 = current month, -1 = previous month.
final stepsMonthOffsetProvider = StateProvider<int>((_) => 0);

final stepsMonthStartProvider = Provider<DateTime>((ref) {
  final offset = ref.watch(stepsMonthOffsetProvider);
  final tz = ref.watch(tzContextProvider);
  final now = tz.now();
  return tz.dayStart(DateTime(now.year, now.month + offset, 1));
});

final monthlyStepsProvider = StreamProvider.autoDispose<List<StepEntry>>((ref) {
  final monthStart = ref.watch(stepsMonthStartProvider);
  final repo = ref.watch(stepsRepositoryProvider);
  final tz = ref.watch(tzContextProvider);
  Future.microtask(() => repo.refreshMonth(monthStart, tz));
  return repo.watchMonth(monthStart, tz);
});

final todayStepsProvider = StreamProvider.autoDispose<StepEntry?>((ref) {
  final repo = ref.watch(stepsRepositoryProvider);
  final tz = ref.watch(tzContextProvider);
  Future.microtask(() => repo.refreshToday(tz));
  return repo.watchDate(tz.now(), tz);
});
