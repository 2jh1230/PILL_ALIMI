import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../main.dart';
import 'check_pill_list_screen.dart';
import '../services/ocr_service.dart';
import '../services/api_service.dart';
import '../services/db_helper.dart'; // [필수 추가] DB 사용

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final OcrService _ocrService = OcrService();
  final ApiService _apiService = ApiService();
  bool _isScanning = false;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      _initializeControllerFuture = _controller!.initialize();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  // [추가] 토스트 메시지 함수
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

  Future<void> _processImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return;

      originalImage = img.bakeOrientation(originalImage);

      int cropWidth = (originalImage.width * 0.8).toInt();
      int cropHeight = (cropWidth * 1.5).toInt();

      if (cropHeight > originalImage.height) {
        cropHeight = (originalImage.height * 0.8).toInt();
        cropWidth = (cropHeight / 1.5).toInt();
      }

      int x = (originalImage.width - cropWidth) ~/ 2;
      int y = (originalImage.height - cropHeight) ~/ 2;

      img.Image processed = img.copyCrop(
        originalImage,
        x: x,
        y: y,
        width: cropWidth,
        height: cropHeight,
      );

      processed = img.grayscale(processed);
      processed = img.adjustColor(processed, contrast: 1.5);

      await imageFile.writeAsBytes(img.encodeJpg(processed, quality: 100));
    } catch (e) {
      if (kDebugMode) print("이미지 처리 실패: $e");
    }
  }

  Future<void> _takePicture() async {
    if (_isScanning) return;

    // [추가] 1. 오늘 사용 횟수 체크
    int todayCount = await DatabaseHelper().getTodayScanCount();
    if (todayCount >= 3) {
      _showToast("하루 무료 이용 횟수(3회)를 모두 사용했습니다.\n내일 다시 이용해주세요!", isError: true);
      return;
    }

    try {
      await _initializeControllerFuture;

      // [추가] 2. 횟수 차감 (사용 기록 저장)
      // 사진 촬영을 시작하면 횟수를 차감합니다.
      await DatabaseHelper().logScan();

      setState(() {
        _isScanning = true;
        _statusMessage = "스캔 보정 중... (오늘 남은 횟수: ${2 - todayCount}회)";
      });

      final image = await _controller!.takePicture();
      await _processImage(image.path);

      setState(() => _statusMessage = "AI가 약 목록을 분석 중...");

      final String extractedText = await _ocrService.extractText(image.path);
      if (kDebugMode) {
        print("📝 [DEBUG] OCR 추출 텍스트:\n$extractedText");
        print("--------------------------------------------------");
      }

      List<Map<String, dynamic>> detectedPills = [];
      try {
        detectedPills = await _ocrService.parseWithGroq(extractedText);
      } catch (e) {
        if (kDebugMode) print("❌ AI 파싱 실패: $e");
      }

      if (detectedPills.isEmpty) {
        if (kDebugMode) print("⚠️ AI 응답 없음. 기존 정규식 파싱 시도.");
        var fallbackResult = _ocrService.parseMultiPills(extractedText);
        detectedPills = fallbackResult['pills'];
      }

      List<Map<String, dynamic>> verifiedPills = [];

      if (detectedPills.isNotEmpty) {
        setState(
          () => _statusMessage = "공공데이터 API 조회 중...",
        );
        if (kDebugMode) {
          print("🔎 5. 공공데이터 API 검색 시작 (총 ${detectedPills.length}개 항목)");
        }

        for (var pill in detectedPills) {
          String keyword = pill['searchKeyword'];
          if (kDebugMode) print("   👉 검색 키워드: [$keyword]");

          if (keyword.isNotEmpty) {
            try {
              final results = await _apiService.searchPills(keyword);
              if (kDebugMode) {
                print("      ✅ API 검색 결과: ${results.length}건 발견");
              }

              if (results.isNotEmpty) {
                pill['name'] = results[0]['ITEM_NAME'];
                pill['imagePath'] = results[0]['ITEM_IMAGE'];
                verifiedPills.add(pill);
                if (kDebugMode) {
                  print("      ✨ 매칭 성공! 최종 등록명: ${pill['name']}");
                }
              } else {
                if (kDebugMode) print("      🗑️ 결과 없음 (목록에서 제외됨)");
              }
            } catch (e) {
              if (kDebugMode) print("      ❌ 검색 에러 ($keyword): $e");
            }
          }
        }
      }

      if (kDebugMode) {
        print("🏁 6. 최종 확인 목록 생성 완료 (${verifiedPills.length}개)");
      }

      if (!mounted) return;
      setState(() => _isScanning = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CheckPillListScreen(
            scannedPills: verifiedPills,
            imagePath: image.path,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) print("🔥 전체 프로세스 에러: $e");
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cameras.isEmpty) {
      return const Scaffold(body: Center(child: Text("카메라 없음")));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CameraPreview(_controller!),
                ),
                if (_isScanning)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFFFF9999),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Column(
                  children: [
                    Expanded(
                      child: Container(color: Colors.black.withOpacity(0.5)),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 450,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                        Container(
                          width: 300,
                          height: 450,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFFF9999),
                              width: 3.0,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: EdgeInsets.all(10.0),
                                child: Icon(
                                  Icons.crop_free,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(10.0),
                                child: Text(
                                  "약봉투 표를 박스에 맞춰주세요",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 450,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: _takePicture,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 50,
                  left: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
