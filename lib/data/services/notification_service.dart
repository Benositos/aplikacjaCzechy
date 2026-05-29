import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  static const _channelId = 'milestones';
  static const _channelName = 'Milestones';
  static const _channelDescription =
      'Gentle nudges when you cross a daily step or screen time milestone.';

  Future<void> initialize() async {
    if (_initialised) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.defaultImportance,
      ),
    );
    // Quietly ask for POST_NOTIFICATIONS (Android 13+). Returns false on
    // older Android — which is fine, notifications work without runtime grant.
    await androidImpl?.requestNotificationsPermission();

    _initialised = true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialised) await initialize();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((_) {
  return NotificationService.instance;
});
