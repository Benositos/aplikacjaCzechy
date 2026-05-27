import 'package:drift/drift.dart';

@DataClassName('StepEntry')
class StepsTable extends Table {
  @override
  String get tableName => 'steps';

  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime().unique()();
  IntColumn get steps => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
}
