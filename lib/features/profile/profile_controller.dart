import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/timezone_service.dart';
import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import '../../data/repositories/profile_repository.dart';

class LifetimeStats {
  const LifetimeStats({
    required this.totalSteps,
    required this.totalScreenMinutes,
    required this.daysTracked,
  });

  final int totalSteps;
  final int totalScreenMinutes;
  final int daysTracked;
}

class StreakInfo {
  const StreakInfo({required this.current, required this.longest});
  final int current;
  final int longest;
}

class PersonalRecords {
  const PersonalRecords({
    required this.bestStepDay,
    required this.bestStepCount,
    required this.lowestScreenDay,
    required this.lowestScreenMinutes,
    required this.bestMonthSteps,
  });

  final DateTime? bestStepDay;
  final int bestStepCount;
  final DateTime? lowestScreenDay;
  final int lowestScreenMinutes;
  final int bestMonthSteps;
}

class Achievement {
  const Achievement({
    required this.key,
    required this.title,
    required this.description,
    required this.unlocked,
  });

  final String key;
  final String title;
  final String description;
  final bool unlocked;
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// All-time totals — sum of steps, sum of screen minutes, distinct days tracked.
final lifetimeStatsProvider = StreamProvider<LifetimeStats>((ref) {
  final db = ref.watch(databaseProvider);

  final stepsSum = db.stepsTable.steps.sum();
  // Only count days that actually have steps — `refreshMonth` writes a row
  // for every day in the month (with 0 for empty days) so the chart can
  // render empty bars, but those 0-step rows shouldn't bump "DAYS TRACKED".
  final stepsDays = db.stepsTable.id.count(
    filter: db.stepsTable.steps.isBiggerThanValue(0),
  );
  final stepsQuery = db.selectOnly(db.stepsTable)..addColumns([stepsSum, stepsDays]);

  final minutesSum = db.appUsageTable.minutesUsed.sum();
  final minutesQuery = db.selectOnly(db.appUsageTable)..addColumns([minutesSum]);

  return Stream.multi((controller) async {
    Future<void> emit() async {
      final s = await stepsQuery.getSingle();
      final m = await minutesQuery.getSingle();
      controller.add(LifetimeStats(
        totalSteps: s.read(stepsSum) ?? 0,
        totalScreenMinutes: m.read(minutesSum) ?? 0,
        daysTracked: s.read(stepsDays) ?? 0,
      ));
    }

    final subA = stepsQuery.watchSingle().listen((_) => emit());
    final subB = minutesQuery.watchSingle().listen((_) => emit());
    controller.onCancel = () async {
      await subA.cancel();
      await subB.cancel();
    };
    await emit();
  });
});

/// Current streak — consecutive days *ending today* with steps >= goal.
/// Longest streak — the longest such run anywhere in the history.
final streakProvider = StreamProvider<StreakInfo>((ref) {
  final db = ref.watch(databaseProvider);
  final profile = ref.watch(profileProvider).valueOrNull;
  final tz = ref.watch(tzContextProvider);
  final goal = profile?.dailyStepGoal ?? 8000;

  final query = db.select(db.stepsTable)..orderBy([(t) => OrderingTerm.asc(t.date)]);

  return query.watch().map((entries) {
    if (entries.isEmpty) return const StreakInfo(current: 0, longest: 0);

    final hitDays = <DateTime>{
      for (final e in entries)
        if (e.steps >= goal) _dayOnly(e.date),
    };

    int longest = 0;
    int run = 0;
    DateTime? prev;
    final sorted = hitDays.toList()..sort();
    for (final day in sorted) {
      if (prev != null && day.difference(prev).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
      prev = day;
    }

    int current = 0;
    var cursor = _dayOnly(tz.now());
    while (hitDays.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return StreakInfo(current: current, longest: longest);
  });
});

final personalRecordsProvider = StreamProvider<PersonalRecords>((ref) {
  final db = ref.watch(databaseProvider);
  return Stream.multi((controller) async {
    Future<void> emit() async {
      final stepsEntries = await db.select(db.stepsTable).get();
      final usageEntries = await db.select(db.appUsageTable).get();

      StepEntry? bestStep;
      for (final e in stepsEntries) {
        if (bestStep == null || e.steps > bestStep.steps) bestStep = e;
      }

      final perDay = <DateTime, int>{};
      for (final e in usageEntries) {
        final day = _dayOnly(e.date);
        perDay.update(day, (v) => v + e.minutesUsed, ifAbsent: () => e.minutesUsed);
      }
      MapEntry<DateTime, int>? lowestScreen;
      for (final entry in perDay.entries) {
        if (entry.value < 1) continue;
        if (lowestScreen == null || entry.value < lowestScreen.value) {
          lowestScreen = entry;
        }
      }

      final perMonth = <String, int>{};
      for (final e in stepsEntries) {
        final key = '${e.date.year}-${e.date.month}';
        perMonth.update(key, (v) => v + e.steps, ifAbsent: () => e.steps);
      }
      final bestMonth = perMonth.values.fold<int>(0, (a, b) => b > a ? b : a);

      controller.add(PersonalRecords(
        bestStepDay: bestStep?.date,
        bestStepCount: bestStep?.steps ?? 0,
        lowestScreenDay: lowestScreen?.key,
        lowestScreenMinutes: lowestScreen?.value ?? 0,
        bestMonthSteps: bestMonth,
      ));
    }

    final subA = db.select(db.stepsTable).watch().listen((_) => emit());
    final subB = db.select(db.appUsageTable).watch().listen((_) => emit());
    controller.onCancel = () async {
      await subA.cancel();
      await subB.cancel();
    };
    await emit();
  });
});

final achievementsProvider = Provider<List<Achievement>>((ref) {
  final lifetime = ref.watch(lifetimeStatsProvider).valueOrNull;
  final streak = ref.watch(streakProvider).valueOrNull;
  final records = ref.watch(personalRecordsProvider).valueOrNull;

  return [
    Achievement(
      key: 'first_step',
      title: 'Started moving',
      description: 'First day of tracked steps',
      unlocked: (lifetime?.daysTracked ?? 0) >= 1,
    ),
    Achievement(
      key: 'first_10k',
      title: 'Ten thousand',
      description: 'A day with 10,000+ steps',
      unlocked: (records?.bestStepCount ?? 0) >= 10000,
    ),
    Achievement(
      key: 'week_streak',
      title: 'Week strong',
      description: '7-day streak hitting your goal',
      unlocked: (streak?.longest ?? 0) >= 7,
    ),
    Achievement(
      key: 'month_streak',
      title: 'Month strong',
      description: '30-day streak hitting your goal',
      unlocked: (streak?.longest ?? 0) >= 30,
    ),
    Achievement(
      key: 'centurion',
      title: 'Centurion',
      description: '100,000 lifetime steps',
      unlocked: (lifetime?.totalSteps ?? 0) >= 100000,
    ),
    Achievement(
      key: 'half_million',
      title: 'Half million',
      description: '500,000 lifetime steps',
      unlocked: (lifetime?.totalSteps ?? 0) >= 500000,
    ),
    Achievement(
      key: 'off_grid',
      title: 'Off the grid',
      description: 'A day under 1h of screen time',
      unlocked: (records?.lowestScreenMinutes ?? 999) > 0 &&
          (records?.lowestScreenMinutes ?? 999) < 60,
    ),
    Achievement(
      key: 'big_month',
      title: 'Big month',
      description: '200,000 steps in a single month',
      unlocked: (records?.bestMonthSteps ?? 0) >= 200000,
    ),
  ];
});
