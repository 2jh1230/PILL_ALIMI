import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/medicine_model.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';

class AddPillScreen extends StatefulWidget {
  final String? initialName;
  final String? initialImage;
  final Map<String, dynamic>? parsedData;
  final bool isEditMode;

  // [추가] DB 저장 없이 데이터만 반환할지 여부 (목록 확인 화면용)
  final bool shouldReturnData;

  const AddPillScreen({
    super.key,
    this.initialName,
    this.initialImage,
    this.parsedData,
    this.isEditMode = false,
    this.shouldReturnData = false, // 기본값 false
  });

  @override
  State<AddPillScreen> createState() => _AddPillScreenState();
}

class _AddPillScreenState extends State<AddPillScreen> {
  late TextEditingController _nameController;
  final _dosageController = TextEditingController();
  final _dailyFreqController = TextEditingController();
  final _durationController = TextEditingController();

  MedicineType _selectedType = MedicineType.pill;
  TakeTime _selectedTakeTime = TakeTime.afterMeal30;
  StorageMethod _selectedStorage = StorageMethod.room;

  final List<TimeOfDay> _alarmTimes = [];

  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? "");

    if (widget.initialImage != null) {
      if (!widget.initialImage!.startsWith('http')) {
        _pickedImage = File(widget.initialImage!);
      }
    }

    if (widget.parsedData != null) {
      final data = widget.parsedData!;
      if (data['dosage'] != null)
        _dosageController.text = data['dosage'].toString();
      if (data['days'] != null)
        _durationController.text = data['days'].toString();
      if (data['freq'] != null)
        _dailyFreqController.text = data['freq'].toString();

      if (data['when'] != null) {
        String when = data['when'].toString();
        if (when == 'afterMeal30')
          _selectedTakeTime = TakeTime.afterMeal30;
        else if (when == 'beforeMeal30')
          _selectedTakeTime = TakeTime.beforeMeal30;
        else if (when == 'beforeSleep')
          _selectedTakeTime = TakeTime.beforeSleep;
        else if (when == 'instant') _selectedTakeTime = TakeTime.instant;
      }

      if (data['alarmTimes'] != null) {
        final List<dynamic> times = data['alarmTimes'];
        for (var t in times) {
          if (t is String) {
            final parts = t.split(':');
            if (parts.length == 2) {
              _alarmTimes.add(TimeOfDay(
                  hour: int.parse(parts[0]), minute: int.parse(parts[1])));
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _dailyFreqController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
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
                    textAlign: TextAlign.center)),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFFF6B6B) : const Color(0xFFFF7E67),
        shape: const StadiumBorder(),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        elevation: 4,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _pickedImage = File(image.path);
        });
      }
    } catch (e) {
      _showToast("사진을 불러오지 못했습니다.", isError: true);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: Color(0xFFFF9999)),
                title: const Text("갤러리에서 가져오기"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFFF9999)),
                title: const Text("사진 촬영"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSelectionSheet(
      {required String title,
      required List<String> options,
      required Function(int index) onSelected}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D2817))),
            ),
            const Divider(height: 1),
            ...List.generate(options.length, (index) {
              return ListTile(
                title: Text(options[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16)),
                onTap: () {
                  onSelected(index);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // [수정] _handleSave 로직 변경
  void _handleSave() async {
    if (_nameController.text.isEmpty) {
      _showToast("약 이름을 입력해주세요!", isError: true);
      return;
    }

    String? finalImagePath;
    if (_pickedImage != null) {
      finalImagePath = _pickedImage!.path;
    } else {
      finalImagePath = widget.initialImage;
    }

    // 공통 데이터 맵 생성
    Map<String, dynamic> resultData = {
      'name': _nameController.text,
      'imagePath': finalImagePath,
      'dosage': _dosageController.text,
      'freq': _dailyFreqController.text,
      'days': _durationController.text,
      'when': _selectedTakeTime.toString().split('.').last,
      'type': _selectedType,
      'alarmTimes': _alarmTimes,
    };

    // 1. 수정 모드이거나, 목록 확인 화면에서 직접 추가 모드일 경우 (DB 저장 안 함)
    if (widget.isEditMode || widget.shouldReturnData) {
      Navigator.pop(context, resultData);
      return;
    }

    // 2. [기존 로직] 신규 등록 로직 (DB 저장)
    List<String> formattedTimes = _alarmTimes.map((time) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return "$hour:$minute";
    }).toList();

    Medicine newMedicine = Medicine(
      name: _nameController.text,
      type: _selectedType,
      imagePath: finalImagePath,
      dosage: double.tryParse(_dosageController.text),
      takeTime: _selectedTakeTime.toString().split('.').last,
      dailyFrequency: int.tryParse(_dailyFreqController.text),
      durationDays: int.tryParse(_durationController.text),
      storageMethod: _selectedStorage.toString().split('.').last,
      startDate: DateTime.now(),
      notificationTimes: formattedTimes,
    );

    int newMedicineId = await DatabaseHelper().insertMedicine(newMedicine);
    await DatabaseHelper().insertLog("'${_nameController.text}' 약 등록됨");

    // 알림 설정 로직 (기존과 동일)
    final notificationService = NotificationService();
    for (int i = 0; i < _alarmTimes.length; i++) {
      final time = _alarmTimes[i];
      int notificationId = newMedicineId * 100 + i;
      await notificationService.scheduleDailyNotification(
        id: notificationId,
        title: "약 드실 시간이에요! 💊",
        body: "${_nameController.text} 복용 시간입니다.",
        hour: time.hour,
        minute: time.minute,
      );
    }

    if (mounted) {
      _showToast("약 등록 및 알림 설정 완료!");
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
    }
  }

  void _showTimePicker() {
    if (_alarmTimes.length >= 5) {
      _showToast("알림은 최대 5개까지만 설정 가능합니다.", isError: true);
      return;
    }
    DateTime tempPickedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF7F7F7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _alarmTimes
                              .add(TimeOfDay.fromDateTime(tempPickedDate));
                          _alarmTimes.sort((a, b) => (a.hour * 60 + a.minute)
                              .compareTo(b.hour * 60 + b.minute));
                        });
                        Navigator.pop(context);
                      },
                      child: const Text("완료",
                          style: TextStyle(
                              color: Color(0xFFFF9999),
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime.now(),
                  use24hFormat: false,
                  onDateTimeChanged: (DateTime newDate) {
                    tempPickedDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputRow(
      {required String label, required Widget child, String? suffixText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
              width: 105,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D2817)))),
          const SizedBox(width: 10),
          Expanded(child: child),
          if (suffixText != null) ...[
            const SizedBox(width: 10),
            Text(suffixText,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3D2817))),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectBox({required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFFFD4CC)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    textAlign: TextAlign.end)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down, color: Color(0xFFFF9999)),
          ],
        ),
      ),
    );
  }

  String _getTypeString() => _selectedType == MedicineType.pill ? "알약" : "시럽";
  String _getTakeTimeString() {
    switch (_selectedTakeTime) {
      case TakeTime.afterMeal30:
        return "식후 30분";
      case TakeTime.beforeMeal30:
        return "식전 30분";
      case TakeTime.beforeSleep:
        return "취침 전";
      case TakeTime.instant:
        return "식후 즉시";
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? displayImage;
    if (_pickedImage != null) {
      displayImage = FileImage(_pickedImage!);
    } else if (widget.initialImage != null) {
      if (widget.initialImage!.startsWith('http')) {
        displayImage = NetworkImage(widget.initialImage!);
      } else {
        displayImage = FileImage(File(widget.initialImage!));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditMode ? "정보 수정" : "약 추가하기")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _showImagePickerOptions,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F0),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: const Color(0xFFFF9999), width: 1.5),
                    image: displayImage != null
                        ? DecorationImage(
                            image: displayImage, fit: BoxFit.cover)
                        : null,
                  ),
                  child: displayImage == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                color: Color(0xFFFF9999), size: 32),
                            SizedBox(height: 4),
                            Text("사진 등록",
                                style: TextStyle(
                                    color: Color(0xFFFF9999),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))
                          ],
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildInputRow(
                label: "🏷️ 약 이름",
                child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(hintText: "이름 입력"))),
            _buildInputRow(
                label: "💊 약 종류",
                child: _buildSelectBox(
                    text: _getTypeString(),
                    onTap: () {
                      _showSelectionSheet(
                          title: "약 종류를 선택하세요",
                          options: ["알약", "시럽"],
                          onSelected: (index) {
                            setState(() {
                              _selectedType = index == 0
                                  ? MedicineType.pill
                                  : MedicineType.syrup;
                            });
                          });
                    })),
            _buildInputRow(
                label: "📏 복용 량",
                child: TextField(
                    controller: _dosageController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    decoration: InputDecoration(hintText: "예: 1")),
                suffixText: _selectedType == MedicineType.pill ? "정(알)" : "ml"),
            _buildInputRow(
                label: "⏰ 복용 시기",
                child: _buildSelectBox(
                    text: _getTakeTimeString(),
                    onTap: () {
                      _showSelectionSheet(
                          title: "언제 드시나요?",
                          options: ["식후 30분", "식전 30분", "식후 즉시", "취침 전"],
                          onSelected: (index) {
                            setState(() {
                              if (index == 0)
                                _selectedTakeTime = TakeTime.afterMeal30;
                              if (index == 1)
                                _selectedTakeTime = TakeTime.beforeMeal30;
                              if (index == 2)
                                _selectedTakeTime = TakeTime.instant;
                              if (index == 3)
                                _selectedTakeTime = TakeTime.beforeSleep;
                            });
                          });
                    })),
            _buildInputRow(
                label: "🔄 1일 횟수",
                child: TextField(
                    controller: _dailyFreqController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    decoration: InputDecoration(hintText: "예: 3")),
                suffixText: "회"),
            _buildInputRow(
                label: "📅 복용 일 수",
                child: TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    decoration: InputDecoration(hintText: "예: 3")),
                suffixText: "일"),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("알림 시간 설정",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D2817))),
              Text("${_alarmTimes.length} / 5",
                  style: const TextStyle(
                      color: Color(0xFF9A7E7E), fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _alarmTimes.map((time) {
                    return Chip(
                        label: Text(time.format(context),
                            style: const TextStyle(
                                color: Color(0xFF3D2817),
                                fontWeight: FontWeight.w600)),
                        backgroundColor: const Color(0xFFFFF5F0),
                        side: BorderSide.none,
                        deleteIcon: const Icon(Icons.close,
                            size: 18, color: Color(0xFFFF9999)),
                        onDeleted: () =>
                            setState(() => _alarmTimes.remove(time)));
                  }).toList()),
            ),
            const SizedBox(height: 15),
            SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                    onPressed: _showTimePicker,
                    icon: const Icon(Icons.add_alarm),
                    label: const Text("알약 알림 시간 추가 +"),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF9999),
                        side: const BorderSide(color: Color(0xFFFF9999)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))))),
            const SizedBox(height: 40),
            SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                    onPressed: _handleSave,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                        widget.isEditMode
                            ? "수정 완료"
                            : (widget.shouldReturnData ? "목록에 추가" : "약 저장하기"),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9999),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder()))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
