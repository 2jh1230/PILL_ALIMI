import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Pill {
  final String pillname;
  final double pillcount;
  final List<String> pilltakingtime = ['breakfast', 'lunch', 'dinner'];

  Pill({required this.pillname, required this.pillcount});
}

class MedicalServices extends StatefulWidget {
  @override
  _MedicalServicesState createState() => _MedicalServicesState();
}

class _MedicalServicesState extends State<MedicalServices> {
  List<bool> isSelected = [false, false, false];

  TextEditingController nameController = TextEditingController();
  TextEditingController countController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('알약 등록')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 알약 이름 입력
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: '알약 이름',
                hintText: '여기에 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            // 알약 개수 입력
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: '알약 개수',
                hintText: '숫자만 입력',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            // 식사 시간 선택 (가로 3칸)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) {
                List<String> labels = ['아침', '점심', '저녁'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isSelected[index] = !isSelected[index]; // 상태 토글
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 6),
                      height: 60,
                      decoration: BoxDecoration(
                        color:
                            isSelected[index] ? Colors.blue : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black),
                      ),
                      child: Center(
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            fontSize: 18,
                            color:
                                isSelected[index] ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
