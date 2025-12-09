import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'add_pill_screen.dart';
import 'pill_detail_screen.dart';

class SearchToAddScreen extends StatefulWidget {
  const SearchToAddScreen({super.key});

  @override
  State<SearchToAddScreen> createState() => _SearchToAddScreenState();
}

class _SearchToAddScreenState extends State<SearchToAddScreen> {
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

  void _goToManualEntry() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddPillScreen(initialName: _searchController.text),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("약 검색하여 등록")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "등록할 약 이름을 입력하세요",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      // 1. 검색 결과 리스트 표시
                      ..._searchResults.map((pill) {
                        final String name = pill['ITEM_NAME'] ?? '이름 없음';
                        final String? imageUrl = pill['ITEM_IMAGE'];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          shadowColor: const Color(0xFFFF9999).withOpacity(0.1),
                          child: ListTile(
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFFFFF5F0),
                              ),
                              child: imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.medication,
                                              color: Color(0xFFFF9999),
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.medication,
                                      color: Color(0xFFFF9999),
                                    ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3D2817),
                              ),
                            ),
                            subtitle: Text(
                              pill['CLASS_NAME'] ?? pill['CHART'] ?? '',
                              style: const TextStyle(
                                color: Color(0xFF9A7E7E),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PillDetailScreen(pillData: pill),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),

                      // 2. [수정됨] 검색 결과가 있든 없든, 리스트 맨 아래에 항상 표시
                      Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F0),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFFFD4CC),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "찾으시는 알약이 없으신가요?",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Color(0xFF3D2817),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "아래 버튼을 눌러 직접 정보를 입력하고\n약을 등록할 수 있습니다.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF9A7E7E),
                              ),
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton.icon(
                              onPressed: _goToManualEntry,
                              icon: const Icon(Icons.edit_note),
                              label: const Text("직접 작성하여 등록"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF9999),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 하단 여백 추가 (키보드에 가려지지 않게)
                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
