import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../main.dart'; // [필수] main.dart의 navigatorKey 접근용
import '../services/db_helper.dart'; // [필수] DB 접근용
import '../models/medicine_model.dart'; // [필수] 모델 접근용

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
      // [수정] 알림 탭 했을 때 실행되는 콜백 함수 추가
      onDidReceiveNotificationResponse: (NotificationResponse details) async {
        if (details.payload != null) {
          // payload에 담긴 약 ID(String)를 int로 변환하여 팝업 호출
          int medicineId = int.parse(details.payload!);
          _showMedicineDialog(medicineId);
        }
      },
    );
    if (kDebugMode) print("✅ 알림 서비스 초기화 완료 (Channel ID: $_channelId)");
  }

  // [추가] 팝업 띄우는 함수 (DB에서 정보 조회 후 Dialog 표시)
  Future<void> _showMedicineDialog(int medicineId) async {
    // 1. DB에서 해당 약 정보 가져오기
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [medicineId],
    );

    if (maps.isEmpty) return; // 약이 삭제되었거나 없으면 종료
    final medicine = Medicine.fromMap(maps.first);

    // 2. navigatorKey를 이용해 팝업 띄우기 (context 확보)
    if (navigatorKey.currentState?.context == null) return;

    showDialog(
      context: navigatorKey.currentState!.context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.alarm_on, size: 40, color: Color(0xFFFF9999)),
            const SizedBox(height: 10),
            const Text(
              "약 드실 시간이에요! 💊",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 약 이미지 (있으면 표시)
            if (medicine.imagePath != null)
              Container(
                height: 100,
                width: 100,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: const Color(0xFFFFF5F0),
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: medicine.imagePath!.startsWith('http')
                        ? NetworkImage(medicine.imagePath!)
                        : FileImage(File(medicine.imagePath!)) as ImageProvider,
                  ),
                ),
              ),
            Text(
              medicine.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3D2817),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              medicine.type == MedicineType.pill
                  ? "1회 ${medicine.dosage?.toStringAsFixed(0)}정 복용하세요."
                  : "1회 ${medicine.dosage}ml 복용하세요.",
              style: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 4),
            Text(
              "식사 여부: ${_translateTakeTime(medicine.takeTime)}",
              style: const TextStyle(color: Color(0xFF9A7E7E)),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9999),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("확인 (복용 완료)"),
            ),
          ),
        ],
      ),
    );
  }

  // 헬퍼 함수: 복용 시간 텍스트 변환
  String _translateTakeTime(String? takeTime) {
    if (takeTime == 'afterMeal30') return '식후 30분';
    if (takeTime == 'beforeMeal30') return '식전 30분';
    if (takeTime == 'beforeSleep') return '취침 전';
    if (takeTime == 'instant') return '식후 즉시';
    return takeTime ?? '-';
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

  // [수정] payload 파라미터 추가 (약 ID 전달용)
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String payload, // [필수] 이 부분이 추가되었습니다.
  }) async {
    final scheduledDate = _nextInstanceOfTime(hour, minute);

    if (kDebugMode) {
      print(
          "📅 알림 예약됨: ID=$id, 시간=${scheduledDate.toString().split('.')[0]}, Payload=$payload");
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
        payload: payload, // [필수] 알림에 약 ID 심기
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
