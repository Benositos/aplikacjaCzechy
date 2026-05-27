import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database.dart';
import '../local/database_provider.dart';
import '../services/health_service.dart';

class StepsRepository {
  StepsRepository(this._db, this._health);

  final AppDatabase _db;
  final HealthService _health;

  Stream<List<StepEntry>> watchMonth(DateTime monthStart) {
    final monthStartDay = DateTime(monthStart.year, monthStart.month, 1);
    final nextMonthStart = DateTime(monthStart.year, monthStart.month + 1, 1);
    return (_db.select(_db.stepsTable)
          ..where((t) => t.date.isBetweenValues(monthStartDay, nextMonthStart))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  Stream<StepEntry?> watchDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    return (_db.select(_db.stepsTable)..where((t) => t.date.equals(dayStart)))
        .watchSingleOrNull();
  }

  Future<void> refreshToday() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final perDay = await _health.getStepsForRange(dayStart, dayEnd);
    final steps = perDay[dayStart] ?? 0;
    await _upsert(dayStart, steps);
  }

  /// Refreshes every day in the month containing [monthStart] up to (and
  /// including) today. Future days in the month are skipped.
  Future<void> refreshMonth(DateTime monthStart) async {
    final monthStartDay = DateTime(monthStart.year, monthStart.month, 1);
    final nextMonthStart = DateTime(monthStart.year, monthStart.month + 1, 1);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final clampedEnd =
        nextMonthStart.isAfter(today.add(const Duration(days: 1)))
            ? today.add(const Duration(days: 1))
            : nextMonthStart;

    final perDay = await _health.getStepsForRange(monthStartDay, clampedEnd);
    final lastDay = clampedEnd.subtract(const Duration(days: 1));
    final nowDt = DateTime.now();
    var cursor = monthStartDay;
    await _db.batch((b) {
      while (!cursor.isAfter(lastDay)) {
        b.insert(
          _db.stepsTable,
          StepsTableCompanion.insert(
            date: cursor,
            steps: Value(perDay[cursor] ?? 0),
            updatedAt: nowDt,
          ),
          mode: InsertMode.insertOrReplace,
        );
        cursor = cursor.add(const Duration(days: 1));
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
}

final stepsRepositoryProvider = Provider<StepsRepository>((ref) {
  return StepsRepository(
    ref.watch(databaseProvider),
    ref.watch(healthServiceProvider),
  );
});
