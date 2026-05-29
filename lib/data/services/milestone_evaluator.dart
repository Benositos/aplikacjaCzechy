import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/timezone_service.dart';
import '../local/database.dart';
import '../local/database_provider.dart';
import '../repositories/profile_repository.dart';
import 'notification_service.dart';

/// Checks today's step total against milestone thresholds and fires a local
/// notification the *first* time each threshold is crossed today.
///
/// Steps-only by design: screen-time milestones are inherently negative
/// ("you've crossed 4h") and harder to frame motivationally, so we don't
/// notify on them.
class MilestoneEvaluator {
  MilestoneEvaluator(this._db, this._notifications, this._profileRepo, this._tz);

  final AppDatabase _db;
  final NotificationService _notifications;
  final ProfileRepository _profileRepo;
  final TzContext _tz;

  static const List<double> stepFractions = [0.75, 1.0, 1.5, 2.0];

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
      final String title;
      final String body;
      if (fraction >= 2.0) {
        title = 'Double the goal.';
        body = "200% — $currentSteps steps and counting.";
      } else if (fraction >= 1.5) {
        title = '150% of goal.';
        body = "You've doubled down — $currentSteps steps and counting.";
      } else if (fraction >= 1.0) {
        title = 'Goal reached.';
        body = "You hit today's step goal ($threshold).";
      } else {
        title = '$percent% there.';
        body = "You're at $percent% of today's step goal ($threshold).";
      }
      await _notifications.show(id: key.hashCode, title: title, body: body);
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

  DateTime _todayStart() => _tz.dayStart(_tz.now());
}

final milestoneEvaluatorProvider = Provider<MilestoneEvaluator>((ref) {
  return MilestoneEvaluator(
    ref.watch(databaseProvider),
    ref.watch(notificationServiceProvider),
    ref.watch(profileRepositoryProvider),
    ref.watch(tzContextProvider),
  );
});
