import 'package:flutter/material.dart';
import '../models/medicine_model.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart'; // [추가] 알림 서비스 임포트
import 'add_pill_screen.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Medicine> _medicineList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    final list = await DatabaseHelper().getMedicines();
    if (mounted) {
      setState(() {
        _medicineList = list;
        _isLoading = false;
      });
    }
  }

  // 둥근 알약 모양 토스트 메시지
  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.warning_amber_rounded : Icons.check_circle,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFFF6B6B) : const Color(0xFFFF7E67),
        shape: const StadiumBorder(),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 약 수정 로직
  void _editMedicine(Medicine medicine) async {
    // [수정 포인트] 기존 약 정보를 AddPillScreen으로 넘길 때 '알림 시간(alarmTimes)'도 같이 보냅니다.
    Map<String, dynamic> currentData = {
      'dosage': medicine.dosage,
      'freq': medicine.dailyFrequency,
      'days': medicine.durationDays,
      'when': medicine.takeTime,
      'alarmTimes':
          medicine.notificationTimes, // 👈 이 부분이 추가되어야 수정 화면에 시간이 뜹니다.
    };

    // 수정 화면으로 이동 (isEditMode: true)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPillScreen(
          isEditMode: true,
          initialName: medicine.name,
          initialImage: medicine.imagePath,
          parsedData: currentData,
        ),
      ),
    );

    // 수정된 데이터가 돌아오면 DB 업데이트 및 알림 갱신
    if (result != null && result is Map<String, dynamic>) {
      Medicine updatedMedicine = Medicine(
        id: medicine.id,
        name: result['name'],
        type: result['type'],
        imagePath: result['imagePath'],
        dosage: double.tryParse(result['dosage'].toString()),
        dailyFrequency: int.tryParse(result['freq'].toString()),
        durationDays: int.tryParse(result['days'].toString()),
        takeTime: result['when'],
        storageMethod: medicine.storageMethod,
        startDate: medicine.startDate,
        notificationTimes: (result['alarmTimes'] as List<TimeOfDay>)
            .map(
              (t) =>
                  "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}",
            )
            .toList(),
      );

      await DatabaseHelper().updateMedicine(updatedMedicine);

      // [추가] 알림 갱신 로직
      // 1. 기존 알림 모두 취소 (약 하나당 최대 5개 알림 가정)
      for (int i = 0; i < 5; i++) {
        await NotificationService().cancelNotification(medicine.id! * 100 + i);
      }

      // 2. 새로운 알림 예약
      if (updatedMedicine.notificationTimes != null) {
        for (int i = 0; i < updatedMedicine.notificationTimes!.length; i++) {
          String timeStr = updatedMedicine.notificationTimes![i];
          List<String> parts = timeStr.split(':');
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);

          await NotificationService().scheduleDailyNotification(
            id: medicine.id! * 100 + i,
            title: "약 드실 시간이에요! 💊",
            body: "${updatedMedicine.name} 복용 시간입니다.",
            hour: hour,
            minute: minute,
          );
        }
      }

      _loadMedicines(); // 목록 새로고침
      _showToast("약 정보와 알림이 수정되었습니다.");
    }
  }

  void _deleteMedicine(int id, String name) async {
    await DatabaseHelper().deleteMedicine(id);
    await DatabaseHelper().insertLog("'$name' 약 삭제됨");

    // [추가] 등록된 알림 취소
    for (int i = 0; i < 5; i++) {
      await NotificationService().cancelNotification(id * 100 + i);
    }

    _loadMedicines();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                '삭제 완료',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFFFF7E67),
          shape: StadiumBorder(),
          behavior: SnackBarBehavior.floating,
          width: 180,
          duration: Duration(seconds: 1),
          elevation: 0,
        ),
      );
    }
  }

  void _showMedicineDetail(Medicine medicine) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (medicine.imagePath != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9999).withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: medicine.imagePath!.startsWith('http')
                            ? Image.network(
                                medicine.imagePath!,
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.medication,
                                  size: 80,
                                  color: Color(0xFFFF9999),
                                ),
                              )
                            : Image.file(
                                File(medicine.imagePath!),
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.medication,
                                  size: 80,
                                  color: Color(0xFFFF9999),
                                ),
                              ),
                      ),
                    ),
                  Text(
                    medicine.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D2817),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: medicine.type == MedicineType.pill
                          ? const Color(0xFFFFE8E6)
                          : const Color(0xFFFFDFDF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: medicine.type == MedicineType.pill
                            ? const Color(0xFFFF9999)
                            : const Color(0xFFFFC0C0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          medicine.type == MedicineType.pill
                              ? Icons.medication
                              : Icons.local_drink,
                          size: 18,
                          color: medicine.type == MedicineType.pill
                              ? const Color(0xFFFF9999)
                              : const Color(0xFFFFC0C0),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          medicine.type == MedicineType.pill ? "알약" : "시럽",
                          style: TextStyle(
                            color: medicine.type == MedicineType.pill
                                ? const Color(0xFFFF9999)
                                : const Color(0xFFFFC0C0),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(thickness: 1, color: Color(0xFFE8D4CF)),
                  ),
                  _buildDetailRow(
                    Icons.medical_services_outlined,
                    "1회 복용량",
                    medicine.type == MedicineType.pill
                        ? "${medicine.dosage?.toStringAsFixed(0) ?? '?'} 정"
                        : "${medicine.dosage ?? '?'} ml",
                  ),
                  _buildDetailRow(
                    Icons.sync,
                    "1일 복용 횟수",
                    "${medicine.dailyFrequency ?? '-'}회",
                  ),
                  _buildDetailRow(
                    Icons.calendar_today,
                    "투약 일수",
                    "${medicine.durationDays ?? '-'}일분",
                  ),
                  if (medicine.type == MedicineType.syrup)
                    _buildDetailRow(
                      Icons.thermostat,
                      "보관 방법",
                      medicine.storageMethod == 'fridge' ? "냉장보관" : "실온보관",
                    ),
                  _buildDetailRow(
                    Icons.access_alarm,
                    "복용 시점",
                    _translateTakeTime(medicine.takeTime),
                  ),
                  _buildDetailRow(
                    Icons.notifications_active_outlined,
                    "알림 시간",
                    (medicine.notificationTimes == null ||
                            medicine.notificationTimes!.isEmpty)
                        ? "설정 안함"
                        : medicine.notificationTimes!.join(", "),
                  ),
                  _buildDetailRow(
                    Icons.login,
                    "시작일",
                    medicine.startDate != null
                        ? "${medicine.startDate!.year}.${medicine.startDate!.month}.${medicine.startDate!.day}"
                        : "정보 없음",
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      // 수정 버튼 (왼쪽)
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _editMedicine(medicine);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                              side: const BorderSide(color: Colors.grey),
                            ),
                          ),
                          child: const Text(
                            "수정",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 확인 버튼 (오른쪽)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9999),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "확인",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFFFF9999)),
          const SizedBox(width: 15),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF9A7E7E), fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF3D2817),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _translateTakeTime(String? takeTime) {
    if (takeTime == 'afterMeal30') return '식후 30분';
    if (takeTime == 'beforeMeal30') return '식전 30분';
    if (takeTime == 'beforeSleep') return '취침 전';
    if (takeTime == 'instant') return '식후 즉시';
    return takeTime ?? '-';
  }

  String _buildSimpleDescription(Medicine medicine) {
    if (medicine.type == MedicineType.pill) {
      String dosageStr = medicine.dosage?.toString() ?? '?';
      if (dosageStr.endsWith('.0')) dosageStr = dosageStr.split('.')[0];
      return "1회 $dosageStr정 ∙ 1일 ${medicine.dailyFrequency ?? '?'}회";
    } else {
      return "1회 ${medicine.dosage}ml";
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _medicineList.isEmpty
            ? const Center(
                child: Text(
                  "등록된 약이 없습니다.\n'등록' 탭에서 약을 추가해보세요!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _medicineList.length,
                itemBuilder: (context, index) {
                  final medicine = _medicineList[index];
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    shadowColor: const Color(0xFFFF9999).withOpacity(0.2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => _showMedicineDetail(medicine),
                      child: Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: medicine.type == MedicineType.pill
                                  ? const Color(0xFFFFE8E6)
                                  : const Color(0xFFFFDFDF),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: medicine.imagePath != null &&
                                    medicine.imagePath!.isNotEmpty
                                ? (medicine.imagePath!.startsWith('http')
                                    ? Image.network(
                                        medicine.imagePath!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          medicine.type == MedicineType.pill
                                              ? Icons.medication
                                              : Icons.local_drink,
                                          color:
                                              medicine.type == MedicineType.pill
                                                  ? const Color(0xFFFF9999)
                                                  : const Color(0xFFFFC0C0),
                                          size: 28,
                                        ),
                                      )
                                    : Image.file(
                                        File(medicine.imagePath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          medicine.type == MedicineType.pill
                                              ? Icons.medication
                                              : Icons.local_drink,
                                          color:
                                              medicine.type == MedicineType.pill
                                                  ? const Color(0xFFFF9999)
                                                  : const Color(0xFFFFC0C0),
                                          size: 28,
                                        ),
                                      ))
                                : Icon(
                                    medicine.type == MedicineType.pill
                                        ? Icons.medication
                                        : Icons.local_drink,
                                    color: medicine.type == MedicineType.pill
                                        ? const Color(0xFFFF9999)
                                        : const Color(0xFFFFC0C0),
                                    size: 28,
                                  ),
                          ),
                          title: Text(
                            medicine.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF3D2817),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE8E6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "⏰ ${_translateTakeTime(medicine.takeTime)}",
                                    style: const TextStyle(
                                      color: Color(0xFFFF9999),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _buildSimpleDescription(medicine),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF666666),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Color(0xFFBFBFBF),
                            ),
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
                                            color: const Color(0xFFFFF5F0),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.delete_forever_rounded,
                                            size: 32,
                                            color: Color(0xFFFF7E67),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          "약 삭제하기",
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3D2817),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          "'${medicine.name}'\n이 약을 정말 삭제하시겠습니까?",
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
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: const Color(
                                                    0xFF9A7E7E,
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    vertical: 14,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
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
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  _deleteMedicine(
                                                    medicine.id!,
                                                    medicine.name,
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFFFF7E67,
                                                  ),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    vertical: 14,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                ),
                                                child: const Text(
                                                  "삭제",
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
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
  }
}
