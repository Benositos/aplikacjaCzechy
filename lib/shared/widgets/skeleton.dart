import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Static placeholder box used while data is loading.
/// Calm Dense aesthetic: no rainbow shimmer animation, just a soft neutral
/// surface that hints "something will land here".
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusSm),
      ),
    );
  }
}

/// Skeleton variant matching the chart card footprint on Steps / Focus tabs.
class ChartSkeleton extends StatelessWidget {
  const ChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeleton(height: 200);
  }
}
