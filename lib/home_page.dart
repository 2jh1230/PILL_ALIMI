import 'package:flutter/material.dart';
import 'medical_services.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("PILL ALIMI"),
          actions: [
            IconButton(
              icon: const Icon(Icons.medical_services),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MedicalServices()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                print('Search 눌림');
              },
            ),
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                print('알림 눌림');
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                print('설정 눌림');
              },
            ),
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () {
                print('계정 눌림');
              },
            ),
          ],
        ),
      ),
    );
  }
}
