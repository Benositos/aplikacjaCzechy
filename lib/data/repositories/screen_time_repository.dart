import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database.dart';
import '../local/database_provider.dart';
import '../services/usage_service.dart';

class ScreenTimeRepository {
  ScreenTimeRepository(this._db, this._usage);

  final AppDatabase _db;
  final UsageService _usage;

  Stream<List<AppUsageEntry>> watchDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    return (_db.select(_db.appUsageTable)
          ..where((t) => t.date.equals(dayStart))
          ..orderBy([(t) => OrderingTerm.desc(t.minutesUsed)]))
        .watch();
  }

  Stream<List<AppUsageEntry>> watchMonth(DateTime monthStart) {
    final monthStartDay = DateTime(monthStart.year, monthStart.month, 1);
    final nextMonthStart = DateTime(monthStart.year, monthStart.month + 1, 1);
    return (_db.select(_db.appUsageTable)
          ..where((t) => t.date.isBetweenValues(monthStartDay, nextMonthStart))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  Future<void> refreshToday() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final usage = await _usage.queryRange(dayStart, dayEnd);
    await _replaceDay(dayStart, usage);
  }

  Future<void> refreshMonth(DateTime monthStart) async {
    final monthStartDay = DateTime(monthStart.year, monthStart.month, 1);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var cursor = monthStartDay;
    while (!cursor.isAfter(today)) {
      final nextDay = cursor.add(const Duration(days: 1));
      if (cursor.month != monthStartDay.month) break;
      final usage = await _usage.queryRange(cursor, nextDay);
      await _replaceDay(cursor, usage);
      cursor = nextDay;
    }
  }

  Future<void> _replaceDay(DateTime day, List<AppUsageRecord> records) async {
    final dayStart = DateTime(day.year, day.month, day.day);
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
