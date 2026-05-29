import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/time/timezone_service.dart';
import 'data/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TimezoneService.init();
  await NotificationService.instance.initialize();
  runApp(
    const ProviderScope(
      child: CalmaApp(),
    ),
  );
}
