import 'package:flutter/material.dart';

import '../../core/theme/text_styles.dart';

/// Pill-shaped section label tinted with the page's accent color.
/// Mirrors the "Calm Dense" sample: small badge with tinted background +
/// accent text, used to anchor each major section.
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: accent,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Thin accent stripe — used as a hero card top edge to telegraph the page's
/// mood color at a glance.
class HeroAccentStripe extends StatelessWidget {
  const HeroAccentStripe({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: const BorderRadius.all(Radius.circular(2)),
      ),
    );
  }
}
