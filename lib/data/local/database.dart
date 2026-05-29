import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables/app_usage_table.dart';
import 'tables/milestone_fired_table.dart';
import 'tables/profile_table.dart';
import 'tables/steps_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  StepsTable,
  AppUsageTable,
  ProfileTable,
  MilestoneFiredTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          final now = DateTime.now();
          await into(profileTable).insert(
            ProfileTableCompanion.insert(
              createdAt: now,
              updatedAt: now,
            ),
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(profileTable, profileTable.timezoneMode);
            await m.addColumn(profileTable, profileTable.customTimezoneId);
          }
        },
      );

  /// Wipes all day-keyed cached data (steps, app usage, fired milestones).
  /// Called when the user changes time zone — old keys are aligned to the
  /// previous tz and would never match queries in the new one. Profile row
  /// is intentionally preserved.
  Future<void> wipeTimezoneScopedCaches() async {
    await transaction(() async {
      await delete(stepsTable).go();
      await delete(appUsageTable).go();
      await delete(milestoneFiredTable).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'calma.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
