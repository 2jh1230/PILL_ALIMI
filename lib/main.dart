// main.dart

import 'package:flutter/material.dart';
import 'home_page.dart'; // 같은 lib 폴더에 있을 경우 상대 경로로 import

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(), // 여기서 직접 연결
    );
  }
}
