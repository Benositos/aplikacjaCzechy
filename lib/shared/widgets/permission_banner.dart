import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/text_styles.dart';

/// Banner that explains why a tab is empty and offers a one-tap path to fix it.
/// Used by Steps when Health Connect isn't granted and Focus when Usage Access
/// isn't granted.
class PermissionBanner extends StatelessWidget {
  const PermissionBanner({
    super.key,
    required this.accent,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final Color accent;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  /// Shortcut: deep-link the user to Settings → Permissions section.
  static VoidCallback goToSettings(BuildContext context) {
    return () => context.go(AppRoutes.settings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: accent),
              const SizedBox(width: AppTheme.space2),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleLarge.copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space2),
          Text(description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppTheme.space3),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
