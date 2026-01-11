import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kDebugMode
import 'package:google_mobile_ads/google_mobile_ads.dart'; // [추가] 광고 패키지
import 'dart:async';
import 'dart:io';
import '../models/medicine_model.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import 'add_pill_screen.dart';

class CheckPillListScreen extends StatefulWidget {
  final List<Map<String, dynamic>> scannedPills;
  final String? imagePath;

  const CheckPillListScreen({
    super.key,
    required this.scannedPills,
    this.imagePath,
  });

  @override
  State<CheckPillListScreen> createState() => _CheckPillListScreenState();
}

class _CheckPillListScreenState extends State<CheckPillListScreen> {
  late List<Map<String, dynamic>> _pills;

  // [추가] 전면 광고 관련 변수
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _pills = List.from(widget.scannedPills);
    // [추가] 화면 진입 시 광고 미리 로드
    _loadInterstitialAd();
  }

  // [추가] 전면 광고 로드 함수
  void _loadInterstitialAd() {
    InterstitialAd.load(
      // 실제 전면 광고 ID
      adUnitId: 'ca-app-pub-8532932981674379/9913383492',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (kDebugMode) print('✅ 전면 광고 로드 성공');
          _interstitialAd = ad;
          _isAdLoaded = true;

          // 광고 닫았을 때의 동작 설정
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              if (kDebugMode) print('광고 닫힘 -> 홈으로 이동');
              ad.dispose();
              _goToHome(); // 광고 닫으면 홈으로
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              if (kDebugMode) print('광고 표시 실패: $err');
              ad.dispose();
              _goToHome(); // 실패해도 홈으로
            },
          );
        },
        onAdFailedToLoad: (err) {
          if (kDebugMode) print('❌ 전면 광고 로드 실패: $err');
          _isAdLoaded = false;
        },
      ),
    );
  }

  @override
  void dispose() {
    _interstitialAd?.dispose(); // [추가] 메모리 해제
    super.dispose();
  }

  // [추가] 홈으로 이동하는 함수 (중복 제거용)
  void _goToHome() {
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isError ? Icons.warning_amber_rounded : Icons.check_circle,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  textAlign: TextAlign.center),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFFF6B6B) : const Color(0xFFFF7E67),
        shape: const StadiumBorder(),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _editPill(int index) async {
    final pill = _pills[index];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPillScreen(
          isEditMode: true,
          initialName: pill['name'],
          initialImage: pill['imagePath'] ?? widget.imagePath,
          parsedData: pill,
          shouldReturnData: true,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _pills[index] = {
          ..._pills[index],
          'name': result['name'],
          'dosage': result['dosage'],
          'freq': result['freq'],
          'days': result['days'],
          'when': result['when'],
          'imagePath': result['imagePath'],
        };
      });
    }
  }

  void _navigateToAddManual() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPillScreen(
          shouldReturnData: true,
          initialImage: null,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _pills.add(result);
      });
      _showToast("'${result['name']}' 추가되었습니다.");
    }
  }

  void _showSearchAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _SearchPillBottomSheet(
            onPillSelected: (Map<String, dynamic> pillData) {
              setState(() {
                _pills.add({
                  'name': pillData['ITEM_NAME'] ?? '이름 없음',
                  'imagePath': pillData['ITEM_IMAGE'],
                  'dosage': '1',
                  'freq': '3',
                  'days': '3',
                  'when': 'afterMeal30',
                });
              });
              Navigator.pop(context);
              _showToast("'${pillData['ITEM_NAME']}' 목록에 추가됨");
            },
            onAddManual: () {
              Navigator.pop(context);
              _navigateToAddManual();
            },
          ),
        );
      },
    );
  }

  // [수정] 저장하기 버튼 로직
  Future<void> _registerAll() async {
    if (_pills.isEmpty) return;

    int successCount = 0;
    final notificationService = NotificationService();

    // 1. 데이터 저장 진행
    for (var pill in _pills) {
      try {
        Medicine newMedicine = Medicine(
          name: pill['name'] ?? '이름 없음',
          type: MedicineType.pill,
          imagePath: pill['imagePath'] ?? widget.imagePath,
          dosage: double.tryParse(pill['dosage'].toString()) ?? 1.0,
          dailyFrequency: int.tryParse(pill['freq'].toString()) ?? 3,
          durationDays: int.tryParse(pill['days'].toString()) ?? 3,
          takeTime: pill['when'] ?? 'afterMeal30',
          storageMethod: 'room',
          startDate: DateTime.now(),
          notificationTimes: [],
        );

        int newMedicineId = await DatabaseHelper().insertMedicine(newMedicine);
        await DatabaseHelper().insertLog("'${newMedicine.name}' 약 등록됨");

        if (newMedicine.notificationTimes != null) {
          for (int i = 0; i < newMedicine.notificationTimes!.length; i++) {
            String timeStr = newMedicine.notificationTimes![i];
            List<String> parts = timeStr.split(':');
            int hour = int.parse(parts[0]);
            int minute = int.parse(parts[1]);
            int notificationId = newMedicineId * 100 + i;

            await notificationService.scheduleDailyNotification(
              id: notificationId,
              title: "약 드실 시간이에요! 💊",
              body: "${newMedicine.name} 복용 시간입니다.",
              hour: hour,
              minute: minute,
              payload: newMedicineId.toString(), // [추가] 약 ID 전달
            );
          }
        }
        successCount++;
      } catch (e) {
        if (kDebugMode) print("저장 실패: ${pill['name']} - $e");
      }
    }

    if (!mounted) return;

    // 2. 토스트 메시지 표시
    _showToast("$successCount개의 약이 내 약통에 추가되었습니다! 💊");

    // 3. [핵심] 광고가 준비되었으면 보여주고, 아니면 바로 홈으로 이동
    if (_isAdLoaded && _interstitialAd != null) {
      if (kDebugMode) print("📺 광고 표시 시작");
      _interstitialAd!.show();
    } else {
      if (kDebugMode) print("⏭️ 광고 준비 안됨, 바로 홈으로");
      // 약간의 딜레이 후 이동 (토스트 볼 시간)
      Future.delayed(const Duration(milliseconds: 500), () {
        _goToHome();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("약 목록 확인")),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFFFF5F0),
            child: const Row(
              children: [
                Icon(Icons.touch_app, color: Color(0xFFFF9999)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "목록을 밀어서 삭제하거나, 눌러서 수정하세요.\n빠진 약이 있다면 아래에서 추가할 수 있습니다.",
                    style: TextStyle(color: Color(0xFF3D2817), fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _pills.isEmpty
                ? const Center(child: Text("목록이 비어있습니다."))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pills.length,
                    itemBuilder: (context, index) {
                      final pill = _pills[index];
                      final hasImage = pill['imagePath'] != null;

                      return Dismissible(
                        key: UniqueKey(),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          setState(() {
                            _pills.removeAt(index);
                          });
                          _showToast("삭제되었습니다.");
                        },
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white, size: 30),
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _editPill(index),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF5F0),
                                      borderRadius: BorderRadius.circular(12),
                                      image: hasImage
                                          ? DecorationImage(
                                              image: pill['imagePath']
                                                      .startsWith('http')
                                                  ? NetworkImage(
                                                      pill['imagePath'])
                                                  : FileImage(File(
                                                          pill['imagePath']))
                                                      as ImageProvider,
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: !hasImage
                                        ? const Icon(Icons.medication,
                                            color: Color(0xFFFF9999))
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pill['name'] ?? "이름 없음",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF3D2817),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${pill['days']}일분 / 하루 ${pill['freq']}회",
                                          style: const TextStyle(
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.edit,
                                      size: 16, color: Color(0xFFFF9999)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _showSearchAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("약 추가하기"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF9999),
                      side: const BorderSide(color: Color(0xFFFF9999)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _registerAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9999),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      "내 약통에 ${_pills.length}개 저장하기",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPillBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onPillSelected;
  final VoidCallback onAddManual;

  const _SearchPillBottomSheet({
    required this.onPillSelected,
    required this.onAddManual,
  });

  @override
  State<_SearchPillBottomSheet> createState() => _SearchPillBottomSheetState();
}

class _SearchPillBottomSheetState extends State<_SearchPillBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      var results = await ApiService().searchPills(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
            margin: const EdgeInsets.only(bottom: 20),
          ),
          const Text(
            "약 추가하기",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "약 이름을 검색하세요",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFFFF5F0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("검색 결과가 없습니다.",
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: widget.onAddManual,
                              icon: const Icon(Icons.edit_note),
                              label: const Text("직접 입력해서 추가하기"),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFF9999),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final pill = _searchResults[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: const Color(0xFFFFF5F0),
                              ),
                              child: pill['ITEM_IMAGE'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        pill['ITEM_IMAGE'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.medication,
                                                color: Color(0xFFFF9999)),
                                      ),
                                    )
                                  : const Icon(Icons.medication,
                                      color: Color(0xFFFF9999)),
                            ),
                            title: Text(pill['ITEM_NAME'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(pill['CLASS_NAME'] ?? '',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => widget.onPillSelected(pill),
                          );
                        },
                      ),
          ),
          if (_searchResults.isEmpty && _searchController.text.isEmpty)
            Center(
              child: TextButton.icon(
                onPressed: widget.onAddManual,
                icon: const Icon(Icons.edit_note),
                label: const Text("검색 없이 직접 입력하기"),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF9A7E7E),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
