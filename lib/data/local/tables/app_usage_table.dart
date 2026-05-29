import 'package:drift/drift.dart';

@DataClassName('AppUsageEntry')
class AppUsageTable extends Table {
  @override
  String get tableName => 'app_usage';

  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get packageName => text()();
  TextColumn get appLabel => text().nullable()();
  IntColumn get minutesUsed => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {date, packageName},
      ];
}
