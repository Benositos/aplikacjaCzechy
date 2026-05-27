import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One record per app per day, ready to be persisted.
class AppUsageRecord {
  const AppUsageRecord({
    required this.packageName,
    required this.duration,
    this.label,
  });

  final String packageName;
  final Duration duration;
  final String? label;
}

class UsageService {
  static const _channel = MethodChannel('com.calma.usage');

  static const _ignoredPackages = <String>{
    'com.calma.calma',
    'android',
    'com.android.systemui',
    'com.android.settings',
    'com.android.settings.intelligence',
    // Samsung One UI
    'com.sec.android.app.launcher',
    'com.samsung.android.app.launcher',
    'com.samsung.android.honeyboard',
    'com.sec.android.inputmethod',
    'com.samsung.android.app.cocktailbarservice',
    'com.samsung.android.app.aodservice',
    'com.samsung.android.scloud',
    'com.samsung.android.lool',
    'com.samsung.android.dialer',
    'com.samsung.android.incallui',
    // Pixel / AOSP
    'com.google.android.apps.nexuslauncher',
    'com.android.launcher',
    'com.android.launcher3',
    // Motorola
    'com.motorola.launcher3',
    'com.motorola.timeweatherwidget',
    // Other vendor launchers
    'com.miui.home',
    'com.miui.systemui',
    'com.oppo.launcher',
    'com.realme.launcher',
    'com.oneplus.launcher',
    'com.huawei.android.launcher',
    // Keyboards
    'com.google.android.inputmethod.latin',
  };

  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (_) {}
  }

  /// Query [start..end] (half-open). Caller passes timezone-aware boundaries.
  Future<List<AppUsageRecord>> queryRange(DateTime start, DateTime end) async {
    try {
      final raw = await _channel.invokeListMethod<Object?>('queryUsage', {
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      });
      if (raw == null || raw.isEmpty) return const [];

      final records = <AppUsageRecord>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final pkg = item['package'] as String?;
        if (pkg == null || pkg.isEmpty) continue;
        if (_ignoredPackages.contains(pkg)) continue;

        final millis = (item['millis'] as num?)?.toInt() ?? 0;
        if (millis < 5000) continue; // skip < 5s noise
        final label = item['label'] as String?;
        records.add(AppUsageRecord(
          packageName: pkg,
          duration: Duration(milliseconds: millis),
          label: label,
        ));
      }
      records.sort((a, b) => b.duration.compareTo(a.duration));
      return records;
    } catch (_) {
      return const [];
    }
  }
}

final usageServiceProvider = Provider<UsageService>((ref) => UsageService());
