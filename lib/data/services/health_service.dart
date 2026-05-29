import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SDK status from `HealthConnectClient.getSdkStatus`.
enum HealthSdkStatus {
  unavailable,
  needsUpdate,
  available,
}

class HealthService {
  static const _channel = MethodChannel('com.calma.health');

  Future<HealthSdkStatus> sdkStatus() async {
    try {
      final code = await _channel.invokeMethod<int>('sdkStatus');
      return switch (code) {
        3 => HealthSdkStatus.available,
        2 => HealthSdkStatus.needsUpdate,
        _ => HealthSdkStatus.unavailable,
      };
    } catch (_) {
      return HealthSdkStatus.unavailable;
    }
  }

  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns step totals per day, keyed by local midnight DateTime in the
  /// timezone identified by [zoneId] (Kotlin attributes each record to a
  /// local day using `ZoneId.of(zoneId)`).
  Future<Map<DateTime, int>> getStepsForRange(
    DateTime start,
    DateTime end, {
    required String zoneId,
  }) async {
    try {
      final raw = await _channel.invokeListMethod<Object?>('getStepsForRange', {
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
        'zoneId': zoneId,
      });
      if (raw == null) return const {};
      final result = <DateTime, int>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final dateMs = (item['dateMs'] as num?)?.toInt();
        final steps = (item['steps'] as num?)?.toInt();
        if (dateMs == null || steps == null) continue;
        result[DateTime.fromMillisecondsSinceEpoch(dateMs)] = steps;
      }
      return result;
    } catch (_) {
      return const {};
    }
  }
}

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());
