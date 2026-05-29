import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/timezone_service.dart';
import '../../data/local/database.dart' show AppUsageEntry;
import '../../data/repositories/screen_time_repository.dart';

final focusMonthOffsetProvider = StateProvider<int>((_) => 0);

final focusMonthStartProvider = Provider<DateTime>((ref) {
  final offset = ref.watch(focusMonthOffsetProvider);
  final tz = ref.watch(tzContextProvider);
  final now = tz.now();
  return tz.dayStart(DateTime(now.year, now.month + offset, 1));
});

final todayUsageProvider = StreamProvider.autoDispose<List<AppUsageEntry>>((ref) {
  final repo = ref.watch(screenTimeRepositoryProvider);
  final tz = ref.watch(tzContextProvider);
  Future.microtask(() => repo.refreshToday(tz));
  return repo.watchDate(tz.now(), tz);
});

final monthlyUsageProvider = StreamProvider.autoDispose<List<AppUsageEntry>>((ref) {
  final monthStart = ref.watch(focusMonthStartProvider);
  final repo = ref.watch(screenTimeRepositoryProvider);
  final tz = ref.watch(tzContextProvider);
  Future.microtask(() => repo.refreshMonth(monthStart, tz));
  return repo.watchMonth(monthStart, tz);
});
