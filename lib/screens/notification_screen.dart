import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/db_helper.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await DatabaseHelper().getLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteLog(int id) async {
    await DatabaseHelper().deleteLog(id);
    _loadLogs();
  }

  String _formatDate(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('MM/dd HH:mm').format(dateTime);
    } catch (e) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    // [수정] Scaffold와 AppBar 추가
    return Scaffold(
      appBar: AppBar(
        title: const Text("알림 기록"),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              "알림 기록이 없습니다.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          return Dismissible(
            key: Key(log['id'].toString()),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              _deleteLog(log['id']);
            },
            background: Container(
              color: const Color(0xFFFF7E67),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history,
                  color: Color(0xFFFF9999),
                  size: 20,
                ),
              ),
              title: Text(
                log['message'] ?? '',
                style: const TextStyle(
                  color: Color(0xFF3D2817),
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Text(
                _formatDate(log['timestamp']),
                style: const TextStyle(
                  color: Color(0xFF9A7E7E),
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
