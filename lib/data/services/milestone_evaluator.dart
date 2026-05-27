import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database.dart';
import '../local/database_provider.dart';
import '../repositories/profile_repository.dart';
import 'notification_service.dart';

/// Checks today's step / screen time totals against milestone thresholds and
/// fires a local notification the *first* time each threshold is crossed today.
///
/// Defaults (not yet user-configurable):
///   Steps:       25 / 50 / 75 / 100 / 150 % of daily goal
///   Screen time: 60 / 120 / 180 / 240 minutes
class MilestoneEvaluator {
  MilestoneEvaluator(this._db, this._notifications, this._profileRepo);

  final AppDatabase _db;
  final NotificationService _notifications;
  final ProfileRepository _profileRepo;

  static const List<double> stepFractions = [0.25, 0.5, 0.75, 1.0, 1.5];
  static const List<int> screenTimeMinuteThresholds = [60, 120, 180, 240];

  Future<void> evaluateSteps({required int currentSteps}) async {
    final profile = await _profileRepo.read();
    if (!profile.notificationsEnabled) return;
    final goal = profile.dailyStepGoal;
    if (goal <= 0) return;

    final today = _todayStart();
    for (final fraction in stepFractions) {
      final threshold = (goal * fraction).round();
      if (currentSteps < threshold) continue;
      final key = 'steps_${(fraction * 100).round()}';
      if (await _hasFired(today, key)) continue;

      final percent = (fraction * 100).round();
      await _notifications.show(
        id: key.hashCode,
        title: fraction >= 1.0 ? 'Goal reached.' : '$percent% there.',
        body: fraction >= 1.5
            ? "You've doubled down — $currentSteps steps and counting."
            : "You're at $percent% of today's step goal ($threshold).",
      );
      await _logFired(today, key);
    }
  }

  Future<void> evaluateScreenTime({required int totalMinutesToday}) async {
    final profile = await _profileRepo.read();
    if (!profile.notificationsEnabled) return;

    final today = _todayStart();
    for (final minutes in screenTimeMinuteThresholds) {
      if (totalMinutesToday < minutes) continue;
      final key = 'screen_${minutes}m';
      if (await _hasFired(today, key)) continue;

      final hours = minutes ~/ 60;
      await _notifications.show(
        id: key.hashCode,
        title: '${hours}h of screen time today.',
        body: 'Gentle nudge — maybe a short break?',
      );
      await _logFired(today, key);
    }
  }

  Future<bool> _hasFired(DateTime day, String key) async {
    final result = await (_db.select(_db.milestoneFiredTable)
          ..where((t) => t.date.equals(day) & t.milestoneKey.equals(key))
          ..limit(1))
        .get();
    return result.isNotEmpty;
  }

  Future<void> _logFired(DateTime day, String key) async {
    await _db.into(_db.milestoneFiredTable).insert(
          MilestoneFiredTableCompanion.insert(
            date: day,
            milestoneKey: key,
            firedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

final milestoneEvaluatorProvider = Provider<MilestoneEvaluator>((ref) {
  return MilestoneEvaluator(
    ref.watch(databaseProvider),
    ref.watch(notificationServiceProvider),
    ref.watch(profileRepositoryProvider),
  );
});
