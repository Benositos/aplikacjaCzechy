import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/timezone_service.dart';
import '../local/database.dart';
import '../local/database_provider.dart';
import '../services/usage_service.dart';

class ScreenTimeRepository {
  ScreenTimeRepository(this._db, this._usage);

  final AppDatabase _db;
  final UsageService _usage;

  Stream<List<AppUsageEntry>> watchDate(DateTime date, TzContext tz) {
    // Critical: use tz.dayStart() so the lookup key matches what _replaceDay
    // wrote. A naked DateTime(year, month, day) would silently fall back to
    // the system local timezone and miss rows persisted under a different tz.
    final dayStart = tz.dayStart(date);
    return (_db.select(_db.appUsageTable)
          ..where((t) => t.date.equals(dayStart))
          ..orderBy([(t) => OrderingTerm.desc(t.minutesUsed)]))
        .watch();
  }

  Stream<List<AppUsageEntry>> watchMonth(DateTime monthStart, TzContext tz) {
    final monthStartDay = tz.monthStart(monthStart);
    final nextMonthStart = tz.monthStart(
      DateTime(monthStart.year, monthStart.month + 1, 1),
    );
    return (_db.select(_db.appUsageTable)
          ..where((t) => t.date.isBetweenValues(monthStartDay, nextMonthStart))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  Future<void> refreshToday(TzContext tz) async {
    final now = tz.now();
    final dayStart = tz.dayStart(now);
    final dayEnd = DateTime.fromMillisecondsSinceEpoch(
      dayStart.millisecondsSinceEpoch + const Duration(days: 1).inMilliseconds,
    );
    final usage = await _usage.queryRange(dayStart, dayEnd);
    await _replaceDay(dayStart, usage);
  }

  Future<void> refreshMonth(DateTime monthStart, TzContext tz) async {
    final monthStartDay = tz.monthStart(monthStart);
    final today = tz.dayStart(tz.now());

    var cursor = monthStartDay;
    final lastCursor = today;
    while (!cursor.isAfter(lastCursor)) {
      final nextDay = DateTime.fromMillisecondsSinceEpoch(
        cursor.millisecondsSinceEpoch + const Duration(days: 1).inMilliseconds,
      );
      // Stop walking past current month.
      if (cursor.month != monthStartDay.month) break;
      final usage = await _usage.queryRange(cursor, nextDay);
      await _replaceDay(cursor, usage);
      cursor = nextDay;
    }
  }

  Future<void> _replaceDay(DateTime day, List<AppUsageRecord> records) async {
    // `day` is already a tz-aware dayStart (computed by callers via tz.dayStart),
    // so we don't reconstruct it — that would lose the tz alignment.
    final dayStart = day;
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.delete(_db.appUsageTable)..where((t) => t.date.equals(dayStart))).go();
      if (records.isEmpty) return;
      await _db.batch((b) {
        for (final record in records) {
          final minutes = record.duration.inMinutes;
          if (minutes < 1) continue;
          b.insert(
            _db.appUsageTable,
            AppUsageTableCompanion.insert(
              date: dayStart,
              packageName: record.packageName,
              appLabel: Value(record.label),
              minutesUsed: Value(minutes),
              updatedAt: now,
            ),
          );
        }
      });
    });
  }
}

final screenTimeRepositoryProvider = Provider<ScreenTimeRepository>((ref) {
  return ScreenTimeRepository(
    ref.watch(databaseProvider),
    ref.watch(usageServiceProvider),
  );
});
