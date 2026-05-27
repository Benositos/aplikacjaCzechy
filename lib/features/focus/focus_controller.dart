import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart' show AppUsageEntry;
import '../../data/repositories/screen_time_repository.dart';

final focusMonthOffsetProvider = StateProvider<int>((_) => 0);

final focusMonthStartProvider = Provider<DateTime>((ref) {
  final offset = ref.watch(focusMonthOffsetProvider);
  final now = DateTime.now();
  return DateTime(now.year, now.month + offset, 1);
});

final todayUsageProvider = StreamProvider.autoDispose<List<AppUsageEntry>>((ref) {
  final repo = ref.watch(screenTimeRepositoryProvider);
  Future.microtask(() => repo.refreshToday());
  return repo.watchDate(DateTime.now());
});

final monthlyUsageProvider = StreamProvider.autoDispose<List<AppUsageEntry>>((ref) {
  final monthStart = ref.watch(focusMonthStartProvider);
  final repo = ref.watch(screenTimeRepositoryProvider);
  Future.microtask(() => repo.refreshMonth(monthStart));
  return repo.watchMonth(monthStart);
});
