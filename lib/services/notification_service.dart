import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final String _channelId = 'daily_pill_channel_id_v3';

  Future<void> init() async {
    tz.initializeTimeZones();

    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (e) {
      if (kDebugMode) print("⚠️ 한국 시간대 설정 실패, UTC로 설정합니다.");
      tz.setLocalLocation(tz.UTC);
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      ),
      onDidReceiveNotificationResponse: (details) {
        if (kDebugMode) print("🔔 알림 클릭됨: ${details.payload}");
      },
    );
    if (kDebugMode) print("✅ 알림 서비스 초기화 완료 (Channel ID: $_channelId)");
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      final bool? notiGranted =
          await androidImplementation?.requestNotificationsPermission();
      final bool? alarmGranted =
          await androidImplementation?.requestExactAlarmsPermission();

      if (kDebugMode) {
        print("🔔 알림 권한 상태: 알림($notiGranted), 정확한 알림($alarmGranted)");
      }
    } else if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> showTestNotification() async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      '약 복용 알림',
      channelDescription: '매일 정해진 시간에 약 복용 알림을 보냅니다.',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _flutterLocalNotificationsPlugin.show(
      777,
      '테스트 알림 🔔',
      '알림이 정상적으로 작동하고 있습니다!',
      NotificationDetails(
          android: androidDetails, iOS: const DarwinNotificationDetails()),
    );
    if (kDebugMode) print("🔔 테스트 알림 발송 요청됨");
  }

  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final scheduledDate = _nextInstanceOfTime(hour, minute);

    if (kDebugMode) {
      print("📅 알림 예약됨: ID=$id, 시간=${scheduledDate.toString().split('.')[0]}");
    }

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            '약 복용 알림',
            channelDescription: '매일 정해진 시간에 약 복용 알림을 보냅니다.',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) print("❌ 알림 예약 에러: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
    if (kDebugMode) print("🗑️ 알림 취소됨: ID=$id");
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
