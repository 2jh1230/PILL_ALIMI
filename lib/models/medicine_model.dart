import 'dart:convert'; // JSON 변환을 위해 추가

enum MedicineType { pill, syrup }

enum TakeTime { afterMeal30, beforeMeal30, beforeSleep, instant }

enum StorageMethod { room, fridge }

class Medicine {
  final int? id;
  final String name;
  final MedicineType type;
  final String? imagePath;
  final double? dosage;
  final String? takeTime;
  final int? dailyFrequency;
  final int? durationDays;
  final String? storageMethod;
  final DateTime? startDate;
  final List<String>?
  notificationTimes; // [추가] 알림 시간 목록 (예: ["08:00", "13:00"])

  Medicine({
    this.id,
    required this.name,
    required this.type,
    this.imagePath,
    this.dosage,
    this.takeTime,
    this.dailyFrequency,
    this.durationDays,
    this.storageMethod,
    this.startDate,
    this.notificationTimes, // [추가]
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'imagePath': imagePath,
      'dosage': dosage,
      'takeTime': takeTime,
      'dailyFrequency': dailyFrequency,
      'durationDays': durationDays,
      'storageMethod': storageMethod,
      'startDate': startDate?.toIso8601String(),
      // [추가] 리스트를 JSON 문자열로 변환하여 저장
      'notificationTimes': notificationTimes != null
          ? jsonEncode(notificationTimes)
          : null,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      name: map['name'],
      type: map['type'] == 'MedicineType.pill'
          ? MedicineType.pill
          : MedicineType.syrup,
      imagePath: map['imagePath'],
      dosage: map['dosage'],
      takeTime: map['takeTime'],
      dailyFrequency: map['dailyFrequency'],
      durationDays: map['durationDays'],
      storageMethod: map['storageMethod'],
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'])
          : null,
      // [추가] JSON 문자열을 다시 리스트로 변환
      notificationTimes: map['notificationTimes'] != null
          ? List<String>.from(jsonDecode(map['notificationTimes']))
          : [],
    );
  }
}
