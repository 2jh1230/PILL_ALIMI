import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // [추가]
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class PharmacyMapScreen extends StatefulWidget {
  const PharmacyMapScreen({super.key});

  @override
  State<PharmacyMapScreen> createState() => _PharmacyMapScreenState();
}

class _PharmacyMapScreenState extends State<PharmacyMapScreen> {
  NaverMapController? _mapController;

  bool _isLoading = true;
  bool _showSearchButton = false;
  bool _isSearching = false;

  NLatLng _myLocation = const NLatLng(37.5665, 126.9780);
  NLatLng? _lastSearchedLocation;

  final Set<NMarker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _showToast(String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 150,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: ShapeDecoration(
                  color: isError
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFFFF7E67),
                  shape: const StadiumBorder(),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isError
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 2), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _myLocation = NLatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print("위치 에러: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchPharmacies() async {
    if (_mapController == null) return;

    setState(() {
      _showSearchButton = false;
      _isSearching = true;
    });

    final cameraPosition = _mapController!.nowCameraPosition;
    final NLatLng center = cameraPosition.target;
    _lastSearchedLocation = center;

    try {
      final pharmacies =
          await ApiService().getPharmacies(center.latitude, center.longitude);

      if (kDebugMode) {
        print("🔎 [디버깅] API 조회 결과: 총 ${pharmacies.length}개 수신");
      }

      final Set<NMarker> newMarkers = {};
      int openCount = 0;
      int closedCount = 0;
      int filteredCount = 0;

      for (var pharmacy in pharmacies) {
        double? lat = double.tryParse(pharmacy['latitude']?.toString() ??
            pharmacy['wgs84Lat']?.toString() ??
            '');
        double? lng = double.tryParse(pharmacy['longitude']?.toString() ??
            pharmacy['wgs84Lon']?.toString() ??
            '');

        if (lat != null && lng != null) {
          double distance = Geolocator.distanceBetween(
              center.latitude, center.longitude, lat, lng);

          if (distance > 2000) continue;

          filteredCount++;

          final bool isOpen = _isOpenNow(pharmacy);
          final String name = pharmacy['dutyName'] ?? '약국';
          final String id = pharmacy['hpid'] ?? pharmacy['dutyTel1'] ?? name;

          final marker = NMarker(
            id: id,
            position: NLatLng(lat, lng),
            size: const Size(30, 40),
            caption: NOverlayCaption(
              text: name,
              color: isOpen ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B),
              haloColor: Colors.white,
              textSize: 12,
            ),
          );

          if (isOpen) {
            marker.setIconTintColor(const Color(0xFF4CAF50));
            marker.setZIndex(100);
            openCount++;
          } else {
            marker.setIconTintColor(const Color(0xFFFF6B6B));
            marker.setZIndex(1);
            closedCount++;
          }

          marker.setOnTapListener((overlay) {
            _showPharmacySheet(pharmacy, isOpen);
          });

          newMarkers.add(marker);
        }
      }

      if (kDebugMode) {
        print(
            "📊 [최종 결과] 2km 이내 약국: $filteredCount개 (영업중: $openCount, 영업종료: $closedCount)");
      }

      if (mounted) {
        _mapController?.clearOverlays();
        _mapController?.addOverlayAll(newMarkers);

        setState(() {
          _isSearching = false;
          _markers.clear();
          _markers.addAll(newMarkers);
        });

        if (newMarkers.isEmpty) {
          _showToast("반경 2km 이내에 약국이 없습니다.", isError: true);
        } else {
          _showToast("2km 이내 약국 ${newMarkers.length}개를 찾았습니다.");
        }
      }
    } catch (e) {
      if (kDebugMode) print("❌ 약국 검색 중 오류: $e");
      if (mounted) setState(() => _isSearching = false);
    }
  }

  bool _isOpenNow(dynamic pharmacy) {
    String? startStr = pharmacy['startTime']?.toString();
    String? endStr = pharmacy['endTime']?.toString();

    if (startStr == null || endStr == null) {
      int weekday = DateTime.now().weekday;
      startStr = pharmacy['dutyTime${weekday}s']?.toString();
      endStr = pharmacy['dutyTime${weekday}c']?.toString();
    }

    if (startStr == null || endStr == null) return false;

    try {
      int now = int.parse(DateFormat('HHmm').format(DateTime.now()));
      int start = int.parse(startStr);
      int end = int.parse(endStr);

      if (end < start) {
        return now >= start || now <= end;
      }

      return now >= start && now <= end;
    } catch (e) {
      return false;
    }
  }

  void _showPharmacySheet(dynamic pharmacy, bool isOpen) {
    final String phone = pharmacy['dutyTel1'] ?? "전화번호 없음";
    final String address = pharmacy['dutyAddr'] ?? "주소 정보 없음";
    final String name = pharmacy['dutyName'] ?? "약국";

    String simpleAddress = address;
    List<String> addrParts = address.split(' ');
    if (addrParts.length >= 2) {
      int takeCount = addrParts.length >= 3 ? 3 : addrParts.length;
      simpleAddress = addrParts.sublist(0, takeCount).join(' ');
    }

    final String mapQuery = "$simpleAddress $name";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOpen ? "영업중" : "영업종료",
                        style: TextStyle(
                          color: isOpen ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoRow(Icons.location_on_outlined, address),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 20, color: Colors.grey),
                    const SizedBox(width: 10),
                    Text(
                      phone,
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xFF3D2817)),
                    ),
                    const Spacer(),
                    if (phone != "전화번호 없음")
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: phone));
                          _showToast("전화번호가 복사되었습니다.");
                        },
                        icon: const Icon(Icons.copy,
                            size: 20, color: Colors.grey),
                        tooltip: "번호 복사",
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    if (phone != "전화번호 없음")
                      IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              backgroundColor: Colors.white,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.phone_in_talk_rounded,
                                        size: 32,
                                        color: Color(0xFF4CAF50),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      "전화 걸기",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF3D2817),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "'$name'\n이 번호로 전화를 거시겠습니까?\n$phone",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF9A7E7E),
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  const Color(0xFF9A7E7E),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: const Text(
                                              "취소",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              Navigator.pop(ctx);
                                              final Uri launchUri = Uri(
                                                scheme: 'tel',
                                                path: phone.replaceAll('-', ''),
                                              );
                                              if (await canLaunchUrl(
                                                  launchUri)) {
                                                await launchUrl(launchUri);
                                              } else {
                                                _showToast(
                                                    "전화 걸기 기능을 사용할 수 없습니다.",
                                                    isError: true);
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF4CAF50),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: const Text(
                                              "통화",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.call,
                            size: 24, color: Colors.green),
                        tooltip: "전화 걸기",
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final Uri url = Uri.parse(
                          "https://map.naver.com/p/search/${Uri.encodeComponent(mapQuery)}");

                      try {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      } catch (e) {
                        _showToast("지도를 열 수 없습니다.", isError: true);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF03C75A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: const Color(0xFF03C75A),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text(
                      "네이버 지도로 자세히 보기",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      foregroundColor: Colors.black87,
                      elevation: 0,
                    ),
                    child: const Text("닫기"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, color: Color(0xFF3D2817)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFFF9999))),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _myLocation,
                zoom: 15,
              ),
              locationButtonEnable: true,
              indoorEnable: true,
              consumeSymbolTapEvents: false,
            ),
            onMapReady: (controller) {
              _mapController = controller;
            },
            onCameraChange: (reason, animated) {
              if (reason != NCameraUpdateReason.developer &&
                  !_showSearchButton) {
                if (_lastSearchedLocation == null) {
                  setState(() => _showSearchButton = true);
                  return;
                }
                final currentValues = _mapController!.nowCameraPosition.target;
                final dist = Geolocator.distanceBetween(
                    _lastSearchedLocation!.latitude,
                    _lastSearchedLocation!.longitude,
                    currentValues.latitude,
                    currentValues.longitude);

                if (dist > 1500) {
                  setState(() => _showSearchButton = true);
                }
              }
            },
          ),
          if (_showSearchButton)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _searchPharmacies,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.refresh, color: Color(0xFFFF9999), size: 18),
                        SizedBox(width: 8),
                        Text(
                          "이 지역에서 다시 검색",
                          style: TextStyle(
                            color: Color(0xFF3D2817),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_isSearching)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF9999)),
            ),
        ],
      ),
    );
  }
}
