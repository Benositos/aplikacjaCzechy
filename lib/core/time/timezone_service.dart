import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/local/database.dart' show UserProfile;
import '../../data/repositories/profile_repository.dart';

/// Single source of truth for "what time/date are we operating in".
///
/// Three resolution paths:
///   * mode 0 (phone)   → use device's local time directly (no tz lookup)
///   * mode 1 (gps)     → use the saved customTimezoneId (filled by GPS detect)
///   * mode 2 (custom)  → use the saved customTimezoneId (filled by user pick)
///
/// Modes 1 and 2 share storage but differ in how the value got there.
class TzContext {
  TzContext._({required this.location, required this.modeLabel});

  /// `null` means "use device local time" (phone mode or fallback).
  final tz.Location? location;
  final String modeLabel;

  /// IANA name of the active timezone — passed to platform channels so the
  /// Kotlin side can attribute Health Connect records to the right local day.
  String get zoneId => location?.name ?? DateTime.now().timeZoneName;

  /// "Now" in the active timezone.
  DateTime now() =>
      location == null ? DateTime.now() : tz.TZDateTime.now(location!);

  /// Midnight (start of [date]) in the active timezone.
  DateTime dayStart(DateTime date) => location == null
      ? DateTime(date.year, date.month, date.day)
      : tz.TZDateTime(location!, date.year, date.month, date.day);

  /// First day of the month containing [date], in the active timezone.
  DateTime monthStart(DateTime date) => location == null
      ? DateTime(date.year, date.month, 1)
      : tz.TZDateTime(location!, date.year, date.month, 1);
}

class TimezoneService {
  TimezoneService._();

  static bool _initialised = false;

  static Future<void> init() async {
    if (_initialised) return;
    tz_data.initializeTimeZones();
    _initialised = true;
  }

  static TzContext fromProfile(UserProfile? profile) {
    if (profile == null) {
      return TzContext._(location: null, modeLabel: 'phone');
    }
    switch (profile.timezoneMode) {
      case 1: // GPS
      case 2: // Custom
        final id = profile.customTimezoneId;
        if (id == null || id.isEmpty) {
          return TzContext._(location: null, modeLabel: 'phone');
        }
        try {
          return TzContext._(
            location: tz.getLocation(id),
            modeLabel: profile.timezoneMode == 1 ? 'gps' : 'custom',
          );
        } catch (_) {
          // Fallback if the stored id is unknown (corrupt or removed from DB).
          return TzContext._(location: null, modeLabel: 'phone');
        }
      default:
        return TzContext._(location: null, modeLabel: 'phone');
    }
  }
}

/// Watch this — emits a fresh [TzContext] whenever profile.timezoneMode or
/// profile.customTimezoneId changes. UI and repositories should read it via
/// `ref.watch(tzContextProvider)` rather than calling `DateTime.now()`.
final tzContextProvider = Provider<TzContext>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  return TimezoneService.fromProfile(profile);
});
