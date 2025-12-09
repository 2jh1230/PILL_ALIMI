import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kDebugMode
import 'search_to_add_screen.dart';
import 'camera_screen.dart';
import '../services/db_helper.dart'; // [추가] DB 사용

class AddSelectionScreen extends StatefulWidget {
  const AddSelectionScreen({super.key});

  @override
  State<AddSelectionScreen> createState() => _AddSelectionScreenState();
}

class _AddSelectionScreenState extends State<AddSelectionScreen> {
  int _remainingCount = 3; // 기본값
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScanCount();
  }

  // [추가] 화면이 다시 보일 때마다 횟수 갱신 (탭 이동 등)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadScanCount();
  }

  // [추가] DB에서 오늘 사용 횟수 조회
  Future<void> _loadScanCount() async {
    try {
      int usedCount = await DatabaseHelper().getTodayScanCount();
      if (mounted) {
        setState(() {
          _remainingCount = 3 - usedCount;
          if (_remainingCount < 0) _remainingCount = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print("횟수 조회 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSelectionButton(
            context,
            icon: Icons.document_scanner_outlined,
            text: "약봉투 촬영해서 등록",
            subText: "네모난 칸에 맞춰 약봉투를 찍어보세요.",
            // [추가] 남은 횟수 표시 텍스트
            countText:
                _isLoading ? "..." : "( 일일 남은 횟수 : $_remainingCount / 3 )",
            isCountZero: _remainingCount <= 0,
            onTap: () async {
              // [수정] 카메라 화면으로 이동 후 돌아올 때 횟수 갱신
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CameraScreen()),
              );
              _loadScanCount(); // 돌아왔을 때 갱신
            },
            color: const Color(0xFFFF9999),
          ),
          const SizedBox(height: 30),
          _buildSelectionButton(
            context,
            icon: Icons.search,
            text: "약 이름 검색해서 등록",
            subText: "이름을 검색하거나 직접 입력합니다.",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchToAddScreen(),
                ),
              );
            },
            color: const Color(0xFF0B7FFF),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionButton(
    BuildContext context, {
    required IconData icon,
    required String text,
    required String subText,
    String? countText, // [추가] 횟수 표시용
    bool isCountZero = false, // [추가] 0회일 때 색상 변경용
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subText,
              style: const TextStyle(color: Color(0xFF9A7E7E), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            // [추가] 횟수 표시 부분
            if (countText != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCountZero
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  countText,
                  style: TextStyle(
                    color: isCountZero ? Colors.red : Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
