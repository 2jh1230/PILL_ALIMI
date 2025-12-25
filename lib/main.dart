import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:camera/camera.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/search_pill_screen.dart';
import 'screens/add_selection_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/pharmacy_map_screen.dart';
import 'services/notification_service.dart';
import 'services/db_helper.dart';
import 'models/medicine_model.dart';

List<CameraDescription> cameras = [];
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await MobileAds.instance.initialize();

  await NotificationService().init();
  await NotificationService().requestPermissions();

  await _restoreScheduledNotifications();

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    if (kDebugMode) print('Camera Error: $e');
  }

  await FlutterNaverMap().init(
    clientId: dotenv.env['NAVER_CLIENT_ID'] ?? '',
    onAuthFailed: (ex) {
      if (kDebugMode) print("********* 네이버 지도 인증 실패: $ex *********");
    },
  );

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await initializeDateFormatting();

  runApp(const MyApp());
}

Future<void> _restoreScheduledNotifications() async {
  if (kDebugMode) print("🔄 저장된 알림 복구 시작...");
  try {
    final List<Medicine> medicines = await DatabaseHelper().getMedicines();
    int count = 0;

    for (var medicine in medicines) {
      if (medicine.notificationTimes != null &&
          medicine.notificationTimes!.isNotEmpty) {
        for (int i = 0; i < medicine.notificationTimes!.length; i++) {
          String timeStr = medicine.notificationTimes![i];
          List<String> parts = timeStr.split(':');
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);

          int notificationId = (medicine.id! * 100) + i;

          await NotificationService().scheduleDailyNotification(
            id: notificationId,
            title: "약 드실 시간이에요! 💊",
            body: "${medicine.name} 복용 시간입니다.",
            hour: hour,
            minute: minute,
            payload: medicine.id.toString(), // [추가] 약 ID 전달
          );
          count++;
        }
      }
    }
    if (kDebugMode) print("✅ 총 $count개의 알림이 재설정되었습니다.");
  } catch (e) {
    if (kDebugMode) print("❌ 알림 복구 중 오류 발생: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: '알약 알리미',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF9999),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFFFFB3A7),
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF9999),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFFF9999),
          unselectedItemColor: Color(0xFFBFBFBF),
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          color: Colors.white,
          shadowColor: const Color(0xFFFF9999).withOpacity(0.15),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFF5F0),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFFFD4CC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFFFD4CC), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFFF9999), width: 2),
          ),
          prefixIconColor: const Color(0xFFFF9999),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3D2817),
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3D2817),
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3D2817),
          ),
          bodyMedium: TextStyle(fontSize: 16, color: Color(0xFF666666)),
        ),
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  Key _homeScreenKey = UniqueKey();
  Key _calendarScreenKey = UniqueKey();

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  final List<String> _titles = [
    "오늘의 복용 약",
    "복용 기록 달력",
    "약 등록하기",
    "약 검색",
    "약국 찾기",
  ];

  @override
  void initState() {
    super.initState();
    _loadBannerAd();

    // 앱이 켜지고 화면이 다 그려진 직후에 경고창 띄우기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWarningDialog();
    });
  }

  // 주의사항 팝업 함수
  void _showWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 바깥을 눌러도 안 닫히게 설정 (확인 버튼 강제)
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF9999), size: 28),
              SizedBox(width: 8),
              Text(
                "주의사항",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Color(0xFF3D2817),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "이 앱은 복약 관리를 돕는 보조 수단이며,\n"
                "의사나 약사의 전문적인 의학적 판단을\n"
                "대체할 수 없습니다.",
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF3D2817),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "정확한 진단 및 처방은 반드시 전문의와\n상담하시기 바랍니다.",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Color(0xFF9A7E7E),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // 팝업 닫기
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9999),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "확인했습니다",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          if (kDebugMode) print('광고 로드 실패: $err');
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;

      if (index == 0) {
        _homeScreenKey = UniqueKey();
      } else if (index == 1) {
        _calendarScreenKey = UniqueKey();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // 홈, 달력, 등록, 검색 (상태 유지를 위해 IndexedStack 사용)
                Offstage(
                  offstage: _selectedIndex == 4, // 지도가 켜지면 나머지 화면은 숨김 처리
                  child: IndexedStack(
                    index:
                        _selectedIndex == 4 ? 0 : _selectedIndex, // 인덱스 에러 방지
                    children: [
                      HomeScreen(key: _homeScreenKey),
                      CalendarScreen(key: _calendarScreenKey),
                      const AddSelectionScreen(),
                      const SearchPillScreen(),
                    ],
                  ),
                ),

                // 지도 (선택되었을 때만 화면에 그려서 충돌 방지)
                if (_selectedIndex == 4) const PharmacyMapScreen(),
              ],
            ),
          ),

          // 배너 광고 영역
          if (_isBannerAdReady && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFFFF9999),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: '달력',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: '등록',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '검색'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: '약국'),
        ],
      ),
    );
  }
}
