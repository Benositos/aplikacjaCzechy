import 'package:drift/drift.dart';

@DataClassName('MilestoneFired')
class MilestoneFiredTable extends Table {
  @override
  String get tableName => 'milestone_fired';

  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get milestoneKey => text()();
  DateTimeColumn get firedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {date, milestoneKey},
      ];
}
