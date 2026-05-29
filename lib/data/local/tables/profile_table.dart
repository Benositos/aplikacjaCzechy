import 'package:drift/drift.dart';

/// Single-row table — only ever id=1.
@DataClassName('UserProfile')
class ProfileTable extends Table {
  @override
  String get tableName => 'profile';

  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get name => text().nullable()();
  TextColumn get avatarPath => text().nullable()();
  IntColumn get dailyStepGoal => integer().withDefault(const Constant(8000))();
  BoolColumn get onboardingComplete => boolean().withDefault(const Constant(false))();

  /// 0 = system, 1 = light, 2 = dark
  IntColumn get themeMode => integer().withDefault(const Constant(0))();

  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(true))();

  /// 0 = phone (use system timezone),
  /// 1 = gps (auto-detect once via location, then use saved id),
  /// 2 = custom (user-picked from list).
  /// Modes 1 and 2 share the same storage (customTimezoneId); they only differ
  /// in HOW the value got there.
  IntColumn get timezoneMode => integer().withDefault(const Constant(0))();

  /// IANA timezone id (e.g., "Europe/Lisbon"). Null when mode = 0 (phone).
  TextColumn get customTimezoneId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
