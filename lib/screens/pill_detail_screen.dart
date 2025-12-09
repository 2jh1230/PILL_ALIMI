import 'package:flutter/material.dart';
import 'add_pill_screen.dart';

class PillDetailScreen extends StatelessWidget {
  final Map<String, dynamic> pillData;

  const PillDetailScreen({super.key, required this.pillData});

  @override
  Widget build(BuildContext context) {
    final String name = pillData['ITEM_NAME'] ?? '이름 없음';
    final String? imageUrl = pillData['ITEM_IMAGE'];
    final String className = pillData['CLASS_NAME'] ?? '분류 없음';
    final String chart = pillData['CHART'] ?? '정보 없음';
    final String entpName = pillData['ENTP_NAME'] ?? '제조사 정보 없음';

    return Scaffold(
      appBar: AppBar(title: const Text("약 상세 정보")),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9999).withOpacity(0.15),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 200,
                                  width: 200,
                                  color: const Color(0xFFFFF5F0),
                                  child: const Icon(
                                    Icons.medication,
                                    size: 80,
                                    color: Color(0xFFFF9999),
                                  ),
                                ),
                              )
                            : Container(
                                height: 200,
                                width: 200,
                                color: const Color(0xFFFFF5F0),
                                child: const Icon(
                                  Icons.medication,
                                  size: 80,
                                  color: Color(0xFFFF9999),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D2817),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entpName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9A7E7E),
                    ),
                  ),
                  const Divider(
                    height: 40,
                    thickness: 1,
                    color: Color(0xFFE8D4CF),
                  ),
                  _buildInfoRow("분류", className),
                  const SizedBox(height: 15),
                  _buildInfoRow("성상(모양)", chart),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddPillScreen(
                        initialName: name,
                        initialImage: imageUrl,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9999),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  "내 약통에 등록하기",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF9A7E7E),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF3D2817),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
