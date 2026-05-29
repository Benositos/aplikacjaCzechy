import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

enum LocationResult {
  permissionDenied,
  servicesDisabled,
  timeout,
  resolveFailed,
}

class LocationDetection {
  const LocationDetection.success(this.timezoneId) : error = null;
  const LocationDetection.failure(this.error) : timezoneId = null;

  final String? timezoneId;
  final LocationResult? error;

  bool get isSuccess => timezoneId != null;
}

/// GPS → IANA timezone resolution.
///
/// We don't bundle a full coordinate-to-timezone polygon database (no good
/// offline Flutter package exists for this in 2026). Instead we use a curated
/// region table that covers the populated parts of Europe, the Americas, and
/// major Asian/Pacific markets, with a UTC-offset fallback for everything
/// else. Imprecise on country borders but good enough for the use case.
class LocationService {
  static const _utcOffsetFallback = <int, String>{
    -12: 'Pacific/Wake',
    -11: 'Pacific/Pago_Pago',
    -10: 'Pacific/Honolulu',
    -9: 'America/Anchorage',
    -8: 'America/Los_Angeles',
    -7: 'America/Denver',
    -6: 'America/Chicago',
    -5: 'America/New_York',
    -4: 'America/Halifax',
    -3: 'America/Sao_Paulo',
    -2: 'Atlantic/South_Georgia',
    -1: 'Atlantic/Azores',
    0: 'Europe/London',
    1: 'Europe/Berlin',
    2: 'Europe/Helsinki',
    3: 'Europe/Moscow',
    4: 'Asia/Dubai',
    5: 'Asia/Karachi',
    6: 'Asia/Dhaka',
    7: 'Asia/Bangkok',
    8: 'Asia/Hong_Kong',
    9: 'Asia/Tokyo',
    10: 'Australia/Sydney',
    11: 'Pacific/Noumea',
    12: 'Pacific/Auckland',
  };

  Future<LocationDetection> detectTimezone() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationDetection.failure(LocationResult.servicesDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const LocationDetection.failure(LocationResult.permissionDenied);
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return const LocationDetection.failure(LocationResult.timeout);
    }

    final tzId = _coordsToTimezone(position.latitude, position.longitude);
    return LocationDetection.success(tzId);
  }

  String _coordsToTimezone(double lat, double lon) {
    // Continental Europe + Iberia + British Isles + Nordics
    if (lat >= 35 && lat <= 72 && lon >= -10 && lon <= 45) {
      if (lon < -6) return 'Europe/Lisbon'; // Portugal / westernmost Spain
      if (lon < 1 && lat < 44) return 'Europe/Madrid'; // mainland Spain
      if (lon < 2 && lat >= 49) return 'Europe/London'; // UK / Ireland
      if (lon < 8 && lat >= 49) return 'Europe/Paris';
      if (lon < 8) return 'Europe/Paris'; // France south
      if (lon < 16 && lat >= 53) return 'Europe/Berlin'; // North-central
      if (lon < 16) return 'Europe/Rome'; // Italy / Austria south
      if (lon < 26 && lat >= 49) return 'Europe/Warsaw'; // Poland / Baltics
      if (lon < 26) return 'Europe/Athens'; // SE Europe
      if (lon < 33) return 'Europe/Istanbul';
      return 'Europe/Moscow';
    }
    // North America
    if (lat >= 24 && lat <= 70 && lon >= -170 && lon <= -50) {
      if (lon < -130) return 'America/Anchorage';
      if (lon < -114) return 'America/Los_Angeles';
      if (lon < -100) return 'America/Denver';
      if (lon < -85) return 'America/Chicago';
      return 'America/New_York';
    }
    // Latin America (rough)
    if (lat >= -55 && lat < 24 && lon >= -120 && lon <= -30) {
      if (lon < -90) return 'America/Mexico_City';
      if (lon < -60) return 'America/Bogota';
      return 'America/Sao_Paulo';
    }
    // Australia / NZ
    if (lat <= -10 && lat >= -50 && lon >= 110 && lon <= 180) {
      if (lon < 135) return 'Australia/Perth';
      if (lon < 165) return 'Australia/Sydney';
      return 'Pacific/Auckland';
    }
    // East / Southeast Asia
    if (lat >= -15 && lat <= 55 && lon >= 90 && lon <= 145) {
      if (lon < 102) return 'Asia/Bangkok';
      if (lon < 122) return 'Asia/Shanghai';
      if (lon < 135) return 'Asia/Tokyo';
      return 'Asia/Tokyo';
    }
    // South Asia
    if (lat >= 5 && lat <= 35 && lon >= 60 && lon <= 90) {
      return 'Asia/Mumbai';
    }
    // Middle East
    if (lat >= 15 && lat <= 40 && lon >= 35 && lon <= 60) {
      return 'Asia/Dubai';
    }
    // Africa
    if (lat >= -35 && lat <= 37 && lon >= -20 && lon <= 50) {
      if (lon < 10) return 'Africa/Lagos';
      if (lat > 25) return 'Africa/Cairo';
      return 'Africa/Johannesburg';
    }
    // Fallback: UTC offset from longitude.
    final offset = (lon / 15).round().clamp(-12, 12);
    return _utcOffsetFallback[offset] ?? 'UTC';
  }
}

final locationServiceProvider = Provider<LocationService>((_) => LocationService());
