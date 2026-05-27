import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/profile_repository.dart';
import 'data/services/milestone_watcher.dart';

class CalmaApp extends ConsumerWidget {
  const CalmaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    // Side-effecting provider — listens to today providers and fires milestone
    // notifications on threshold crossings. Foreground-only for now.
    ref.watch(milestoneWatcherProvider);
    final themeMode = switch (profile?.themeMode ?? 0) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'Calma',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
