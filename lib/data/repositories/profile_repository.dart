import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database.dart';
import '../local/database_provider.dart';

class ProfileRepository {
  ProfileRepository(this._db);

  final AppDatabase _db;

  Stream<UserProfile> watch() {
    return (_db.select(_db.profileTable)..where((t) => t.id.equals(1))).watchSingle();
  }

  Future<UserProfile> read() {
    return (_db.select(_db.profileTable)..where((t) => t.id.equals(1))).getSingle();
  }

  Future<void> _update(ProfileTableCompanion companion) async {
    await (_db.update(_db.profileTable)..where((t) => t.id.equals(1))).write(
      companion.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> markOnboardingComplete() =>
      _update(const ProfileTableCompanion(onboardingComplete: Value(true)));

  Future<void> setDailyStepGoal(int goal) =>
      _update(ProfileTableCompanion(dailyStepGoal: Value(goal)));

  Future<void> setName(String? name) =>
      _update(ProfileTableCompanion(name: Value(name)));

  Future<void> setAvatarPath(String? path) =>
      _update(ProfileTableCompanion(avatarPath: Value(path)));

  Future<void> setThemeMode(int mode) =>
      _update(ProfileTableCompanion(themeMode: Value(mode)));

  Future<void> setNotificationsEnabled(bool enabled) =>
      _update(ProfileTableCompanion(notificationsEnabled: Value(enabled)));

  Future<void> setTimezoneMode(int mode) =>
      _update(ProfileTableCompanion(timezoneMode: Value(mode)));

  Future<void> setCustomTimezone(String? id) =>
      _update(ProfileTableCompanion(customTimezoneId: Value(id)));
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(databaseProvider));
});

final profileProvider = StreamProvider<UserProfile>((ref) {
  return ref.watch(profileRepositoryProvider).watch();
});
