import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/timezone_service.dart';
import '../local/database.dart';
import '../local/database_provider.dart';
import '../services/health_service.dart';

class StepsRepository {
  StepsRepository(this._db, this._health);

  final AppDatabase _db;
  final HealthService _health;

  Stream<List<StepEntry>> watchMonth(DateTime monthStart, TzContext tz) {
    final monthStartDay = tz.monthStart(monthStart);
    final nextMonthStart = tz.monthStart(
      DateTime(monthStart.year, monthStart.month + 1, 1),
    );
    return (_db.select(_db.stepsTable)
          ..where((t) => t.date.isBetweenValues(monthStartDay, nextMonthStart))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  Stream<StepEntry?> watchDate(DateTime date, TzContext tz) {
    // tz.dayStart matches the keys we write — naked DateTime constructor here
    // would silently use system local timezone and miss rows under other tz.
    final dayStart = tz.dayStart(date);
    return (_db.select(_db.stepsTable)..where((t) => t.date.equals(dayStart)))
        .watchSingleOrNull();
  }

  Future<void> refreshToday(TzContext tz) async {
    final now = tz.now();
    final dayStart = tz.dayStart(now);
    final dayEnd = DateTime.fromMillisecondsSinceEpoch(
      dayStart.millisecondsSinceEpoch + const Duration(days: 1).inMilliseconds,
    );
    final perDay = await _health.getStepsForRange(dayStart, dayEnd, zoneId: tz.zoneId);
    final steps = perDay[dayStart] ?? 0;
    await _upsert(dayStart, steps);
  }

  /// Refreshes every day in the month containing [monthStart] up to (and
  /// including) today. Future days in the month are skipped.
  Future<void> refreshMonth(DateTime monthStart, TzContext tz) async {
    final monthStartDay = tz.monthStart(monthStart);
    final nextMonthStart = DateTime.fromMillisecondsSinceEpoch(
      _addMonths(monthStartDay, 1).millisecondsSinceEpoch,
    );
    final today = tz.dayStart(tz.now());
    final clampedEnd = nextMonthStart.isAfter(
      DateTime.fromMillisecondsSinceEpoch(
        today.millisecondsSinceEpoch + const Duration(days: 1).inMilliseconds,
      ),
    )
        ? DateTime.fromMillisecondsSinceEpoch(
            today.millisecondsSinceEpoch + const Duration(days: 1).inMilliseconds,
          )
        : nextMonthStart;

    final perDay = await _health.getStepsForRange(monthStartDay, clampedEnd, zoneId: tz.zoneId);
    final now = DateTime.now();

    final lastDay = DateTime.fromMillisecondsSinceEpoch(
      clampedEnd.millisecondsSinceEpoch - const Duration(days: 1).inMilliseconds,
    );
    var cursor = monthStartDay;
    await _db.batch((b) {
      while (!cursor.isAfter(lastDay)) {
        b.insert(
          _db.stepsTable,
          StepsTableCompanion.insert(
            date: cursor,
            steps: Value(perDay[cursor] ?? 0),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
        cursor = DateTime.fromMillisecondsSinceEpoch(
          cursor.millisecondsSinceEpoch + const Duration(days: 1).inMilliseconds,
        );
      }
    });
  }

  Future<void> _upsert(DateTime dayStart, int steps) async {
    await _db.into(_db.stepsTable).insertOnConflictUpdate(
          StepsTableCompanion.insert(
            date: dayStart,
            steps: Value(steps),
            updatedAt: DateTime.now(),
          ),
        );
  }

  DateTime _addMonths(DateTime d, int months) {
    var y = d.year;
    var m = d.month + months;
    while (m > 12) {
      m -= 12;
      y++;
    }
    while (m < 1) {
      m += 12;
      y--;
    }
    return DateTime(y, m, d.day);
  }
}

final stepsRepositoryProvider = Provider<StepsRepository>((ref) {
  return StepsRepository(
    ref.watch(databaseProvider),
    ref.watch(healthServiceProvider),
  );
});
