import 'package:flutter/foundation.dart'; // kDebugMode용
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medicine_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'pill_allimi.db');

    return await openDatabase(
      path,
      // [수정] 버전 업 (4 -> 5)
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE medicines(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            imagePath TEXT,
            dosage REAL,
            takeTime TEXT,
            dailyFrequency INTEGER,
            durationDays INTEGER,
            storageMethod TEXT,
            startDate TEXT,
            notificationTimes TEXT 
          )
        ''');
        await db.execute('''
          CREATE TABLE notification_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message TEXT,
            timestamp TEXT
          )
        ''');
        // [추가] 스캔 기록 테이블 생성
        await db.execute('''
          CREATE TABLE scan_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scan_date TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE medicines ADD COLUMN startDate TEXT');
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE medicines ADD COLUMN notificationTimes TEXT',
          );
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE notification_logs(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              message TEXT,
              timestamp TEXT
            )
          ''');
        }
        // [추가] 버전 5 업그레이드 시 테이블 추가
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE scan_history(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              scan_date TEXT
            )
          ''');
        }
      },
    );
  }

  Future<int> insertMedicine(Medicine medicine) async {
    final db = await database;
    return await db.insert('medicines', medicine.toMap());
  }

  Future<List<Medicine>> getMedicines() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('medicines');
    return List.generate(maps.length, (i) {
      return Medicine.fromMap(maps[i]);
    });
  }

  Future<int> updateMedicine(Medicine medicine) async {
    final db = await database;
    return await db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<int> deleteMedicine(int id) async {
    final db = await database;
    return await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  // 로그 관련
  Future<int> insertLog(String message) async {
    final db = await database;
    final String timestamp = DateTime.now().toIso8601String();
    return await db.insert('notification_logs', {
      'message': message,
      'timestamp': timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> getLogs() async {
    final db = await database;
    return await db.query('notification_logs', orderBy: 'timestamp DESC');
  }

  Future<int> deleteLog(int id) async {
    final db = await database;
    return await db.delete(
      'notification_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // [추가] 오늘 스캔 횟수 조회
  Future<int> getTodayScanCount() async {
    final db = await database;
    // 오늘 날짜 (yyyy-MM-dd 형식)
    String today = DateTime.now().toIso8601String().split('T')[0];

    var result = await db.rawQuery(
        'SELECT COUNT(*) FROM scan_history WHERE scan_date = ?', [today]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // [추가] 스캔 기록 저장 (횟수 차감)
  Future<void> logScan() async {
    final db = await database;
    String today = DateTime.now().toIso8601String().split('T')[0];
    await db.insert('scan_history', {'scan_date': today});
  }
}
