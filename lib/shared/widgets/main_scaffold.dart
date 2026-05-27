import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// App shell: persistent top header with the wordmark + bottom nav with 4
/// icon-only tabs. Labels are intentionally hidden — icons carry meaning.
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerTheme.color ?? theme.colorScheme.outline;

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space6,
                vertical: AppTheme.space3,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: dividerColor, width: 1),
                ),
              ),
              child: Center(
                child: Image.asset(
                  'assets/logo/wordmark.png',
                  height: MediaQuery.of(context).size.height * 0.10,
                  fit: BoxFit.contain,
                  color: theme.colorScheme.onSurface,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: dividerColor, width: 1),
            ),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.directions_walk_outlined),
                selectedIcon: Icon(Icons.directions_walk),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.hourglass_top_outlined),
                selectedIcon: Icon(Icons.hourglass_top),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
