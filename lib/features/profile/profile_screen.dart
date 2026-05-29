import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../data/repositories/profile_repository.dart';
import '../../shared/widgets/section_label.dart';
import 'profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _editingName = false;
  bool _nameInitialised = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    await ref.read(profileRepositoryProvider).setAvatarPath(picked.path);
  }

  Future<void> _saveName() async {
    final trimmed = _nameController.text.trim();
    await ref.read(profileRepositoryProvider).setName(trimmed.isEmpty ? null : trimmed);
    setState(() => _editingName = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final statsAsync = ref.watch(lifetimeStatsProvider);
    final streakAsync = ref.watch(streakProvider);
    final recordsAsync = ref.watch(personalRecordsProvider);
    final achievements = ref.watch(achievementsProvider);

    if (profile != null && !_nameInitialised) {
      _nameController.text = profile.name ?? '';
      _nameInitialised = true;
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space6,
            3,
            AppTheme.space6,
            AppTheme.space6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HeroAccentStripe(accent: AppColors.accentGreen),
              const SizedBox(height: AppTheme.space4),
              const SectionLabel(text: '03 · PROFILE', accent: AppColors.accentGreen),
              const SizedBox(height: AppTheme.space3),
              Text('You.', style: theme.textTheme.headlineLarge),

              const SizedBox(height: AppTheme.space8),
              Row(
                children: [
                  _Avatar(path: profile?.avatarPath, onTap: _pickAvatar),
                  const SizedBox(width: AppTheme.space4),
                  Expanded(
                    child: _editingName
                        ? _NameField(
                            controller: _nameController,
                            onSubmitted: (_) => _saveName(),
                            onSave: _saveName,
                            onCancel: () {
                              _nameController.text = profile?.name ?? '';
                              setState(() => _editingName = false);
                            },
                          )
                        : _NameDisplay(
                            name: profile?.name,
                            onEdit: () => setState(() => _editingName = true),
                          ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.space12),
              _Heading('LIFETIME'),
              const SizedBox(height: AppTheme.space3),
              statsAsync.when(
                loading: () => const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  'Could not load stats: $e',
                  style: theme.textTheme.bodySmall,
                ),
                data: (stats) => _Stats(stats: stats),
              ),

              const SizedBox(height: AppTheme.space8),
              _Heading('STREAK'),
              const SizedBox(height: AppTheme.space3),
              streakAsync.when(
                loading: () => const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('—', style: theme.textTheme.bodySmall),
                data: (streak) => _StreakBlock(streak: streak),
              ),

              const SizedBox(height: AppTheme.space8),
              _Heading('PERSONAL RECORDS'),
              const SizedBox(height: AppTheme.space3),
              recordsAsync.when(
                loading: () => const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('—', style: theme.textTheme.bodySmall),
                data: (records) => _RecordsBlock(records: records),
              ),

              const SizedBox(height: AppTheme.space8),
              _Heading('ACHIEVEMENTS'),
              const SizedBox(height: AppTheme.space3),
              _AchievementsGrid(achievements: achievements),

              const SizedBox(height: AppTheme.space6),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.accentGreen,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.path, required this.onTap});
  final String? path;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          image: (path != null && File(path!).existsSync())
              ? DecorationImage(image: FileImage(File(path!)), fit: BoxFit.cover)
              : null,
        ),
        child: (path == null || !File(path!).existsSync())
            ? Icon(
                Icons.add_a_photo_outlined,
                size: 24,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              )
            : null,
      ),
    );
  }
}

class _NameDisplay extends StatelessWidget {
  const _NameDisplay({required this.name, required this.onEdit});
  final String? name;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name ?? 'Add your name',
                style: name == null
                    ? theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      )
                    : theme.textTheme.headlineMedium,
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.onSubmitted,
    required this.onSave,
    required this.onCancel,
  });
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Your name',
              border: UnderlineInputBorder(),
            ),
            style: Theme.of(context).textTheme.headlineMedium,
            onSubmitted: onSubmitted,
          ),
        ),
        IconButton(onPressed: onCancel, icon: const Icon(Icons.close)),
        IconButton(onPressed: onSave, icon: const Icon(Icons.check)),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});
  final LifetimeStats stats;
  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.decimalPattern('en_US');
    final hours = stats.totalScreenMinutes ~/ 60;
    final minutes = stats.totalScreenMinutes % 60;
    final screenStr = hours == 0 ? '${minutes}m' : '${f.format(hours)}h ${minutes}m';
    return Row(
      children: [
        Expanded(child: _StatCell(label: 'STEPS', value: f.format(stats.totalSteps))),
        Expanded(child: _StatCell(label: 'SCREEN', value: screenStr)),
        Expanded(child: _StatCell(label: 'DAYS', value: stats.daysTracked.toString())),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.mono(fontSize: 18, fontWeight: FontWeight.w600).copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _StreakBlock extends StatelessWidget {
  const _StreakBlock({required this.streak});
  final StreakInfo streak;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.accentGreen,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      streak.current.toString(),
                      style: AppTextStyles.mono(fontSize: 36, fontWeight: FontWeight.w600).copyWith(
                        color: streak.current > 0
                            ? AppColors.accentGreen
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space2),
                    Text(
                      streak.current == 1 ? 'day' : 'days',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: theme.colorScheme.outlineVariant,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: AppTheme.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LONGEST',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        streak.longest.toString(),
                        style: AppTextStyles.mono(fontSize: 24, fontWeight: FontWeight.w500).copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space2),
                      Text(
                        streak.longest == 1 ? 'day' : 'days',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsBlock extends StatelessWidget {
  const _RecordsBlock({required this.records});
  final PersonalRecords records;

  String _fmtMinutes(int m) {
    final h = m ~/ 60;
    final mm = m % 60;
    return h == 0 ? '${mm}m' : '${h}h ${mm.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = NumberFormat.decimalPattern('en_US');
    final dateFmt = DateFormat('MMM d');

    final rows = <_RecordRowData>[
      _RecordRowData(
        label: 'Best step day',
        value: records.bestStepCount > 0 ? f.format(records.bestStepCount) : '—',
        sub: records.bestStepDay != null ? dateFmt.format(records.bestStepDay!) : '',
      ),
      _RecordRowData(
        label: 'Lowest screen day',
        value: records.lowestScreenMinutes > 0
            ? _fmtMinutes(records.lowestScreenMinutes)
            : '—',
        sub: records.lowestScreenDay != null ? dateFmt.format(records.lowestScreenDay!) : '',
      ),
      _RecordRowData(
        label: 'Best month',
        value: records.bestMonthSteps > 0 ? f.format(records.bestMonthSteps) : '—',
        sub: '',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _RecordRow(data: rows[i]),
            if (i != rows.length - 1)
              Divider(color: theme.colorScheme.outlineVariant, height: 1),
          ],
        ],
      ),
    );
  }
}

class _RecordRowData {
  _RecordRowData({required this.label, required this.value, required this.sub});
  final String label;
  final String value;
  final String sub;
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.data});
  final _RecordRowData data;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space3),
      child: Row(
        children: [
          Expanded(child: Text(data.label, style: theme.textTheme.bodyLarge)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.value,
                style: AppTextStyles.mono(fontSize: 16, fontWeight: FontWeight.w600).copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (data.sub.isNotEmpty)
                Text(data.sub, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementsGrid extends StatelessWidget {
  const _AchievementsGrid({required this.achievements});
  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppTheme.space2;
        final maxW = constraints.maxWidth;
        final cardWidth = (maxW - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final a in achievements)
              SizedBox(width: cardWidth, child: _AchievementCard(achievement: a)),
          ],
        );
      },
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});
  final Achievement achievement;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = achievement.unlocked;
    const accent = AppColors.accentGreen;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: unlocked ? accent.withValues(alpha: 0.06) : null,
        border: Border.all(
          color: unlocked ? accent.withValues(alpha: 0.4) : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                unlocked ? Icons.check_circle : Icons.lock_outline,
                size: 16,
                color: unlocked
                    ? accent
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(width: AppTheme.space2),
              Expanded(
                child: Text(
                  achievement.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: unlocked
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space1),
          Text(
            achievement.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: unlocked
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
