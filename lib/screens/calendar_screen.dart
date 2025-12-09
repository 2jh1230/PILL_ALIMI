import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/medicine_model.dart';
import '../services/db_helper.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // 달력 형식
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // 현재 보고 있는 달
  DateTime _focusedDay = DateTime.now();

  // 선택된 날짜 (초기값: 오늘)
  DateTime _selectedDay = DateTime.now();

  List<Medicine> _allMedicines = [];
  List<Medicine> _selectedMedicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    final list = await DatabaseHelper().getMedicines();

    if (!mounted) return;

    setState(() {
      _allMedicines = list;
      _isLoading = false;
      // 초기 선택된 날짜(오늘)의 약 목록 갱신
      _selectedMedicines = _getMedicinesForDay(_selectedDay);
    });
  }

  // 특정 날짜에 복용해야 하는 약 리스트 반환
  List<Medicine> _getMedicinesForDay(DateTime day) {
    return _allMedicines.where((medicine) {
      if (medicine.startDate == null) return false;

      final start = DateTime(
        medicine.startDate!.year,
        medicine.startDate!.month,
        medicine.startDate!.day,
      );
      final target = DateTime(day.year, day.month, day.day);

      if (medicine.durationDays == null) {
        return !target.isBefore(start);
      }

      final end = start.add(Duration(days: medicine.durationDays! - 1));
      return !target.isBefore(start) && !target.isAfter(end);
    }).toList();
  }

  String _translateTakeTime(String? takeTime) {
    if (takeTime == 'afterMeal30') return '식후 30분';
    if (takeTime == 'beforeMeal30') return '식전 30분';
    if (takeTime == 'beforeSleep') return '취침 전';
    if (takeTime == 'instant') return '식후 즉시';
    return takeTime ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold 없이 Column 반환 (메인 통합 구조)
    return Column(
      children: [
        TableCalendar<Medicine>(
          locale: 'ko_KR',
          firstDay: DateTime(2020, 1, 1),
          lastDay: DateTime(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,

          daysOfWeekHeight: 30.0,
          rowHeight: 52.0,

          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            headerMargin: EdgeInsets.only(bottom: 10.0),
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D2817),
            ),
            leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFFFF9999)),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: Color(0xFFFF9999),
            ),
          ),

          calendarStyle: CalendarStyle(
            cellMargin: const EdgeInsets.all(4.0),
            cellAlignment: Alignment.center,
            todayDecoration: BoxDecoration(
              color: const Color(0xFFFF9999).withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: Color(0xFFFF9999),
              shape: BoxShape.circle,
            ),
            weekendTextStyle: const TextStyle(color: Colors.red),
            // markerDecoration은 아래 builder를 쓰면 무시될 수 있으나 기본값으로 둠
            markerDecoration: const BoxDecoration(
              color: Color(0xFF9A7E7E),
              shape: BoxShape.circle,
            ),
          ),

          // 약 목록 로더
          eventLoader: _getMedicinesForDay,

          // [수정 포인트] 마커(점) 커스터마이징
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              // 약(events)이 하나라도 있으면 점 1개만 표시
              if (events.isNotEmpty) {
                return Positioned(
                  bottom: 8, // 날짜 숫자 아래 위치
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF9A7E7E), // 점 색상 (갈색 톤)
                    ),
                    width: 6.0, // 점 크기
                    height: 6.0,
                  ),
                );
              }
              return const SizedBox(); // 약 없으면 아무것도 안 그림
            },
          ),

          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedMedicines = _getMedicinesForDay(selectedDay);
              });
            }
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() => _calendarFormat = format);
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        ),

        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE8D4CF)),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _selectedMedicines.isEmpty
              ? Center(
                  child: Text(
                    "${_selectedDay.month}월 ${_selectedDay.day}일엔\n복용 예정인 약이 없어요!",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _selectedMedicines.length,
                  itemBuilder: (context, index) {
                    final medicine = _selectedMedicines[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      shadowColor: const Color(0xFFFF9999).withOpacity(0.1),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: medicine.type == MedicineType.pill
                              ? const Color(0xFFFFE8E6)
                              : const Color(0xFFFFDFDF),
                          child: Icon(
                            medicine.type == MedicineType.pill
                                ? Icons.medication
                                : Icons.local_drink,
                            color: medicine.type == MedicineType.pill
                                ? const Color(0xFFFF9999)
                                : const Color(0xFFFFC0C0),
                          ),
                        ),
                        title: Text(
                          medicine.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3D2817),
                          ),
                        ),
                        subtitle: Text(
                          "⏰ ${_translateTakeTime(medicine.takeTime)}",
                          style: const TextStyle(color: Color(0xFF9A7E7E)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
