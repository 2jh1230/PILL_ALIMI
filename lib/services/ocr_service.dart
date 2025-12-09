import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env 적용 가정
import 'package:flutter/foundation.dart'; // [추가]

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.korean,
  );

  // .env에서 키 가져오기
  final String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
  final String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  Future<String> extractText(String imagePath) async {
    try {
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      return recognizedText.text;
    } catch (e) {
      if (kDebugMode) print('❌ OCR 텍스트 추출 에러: $e');
      return '';
    }
  }

  // [Groq] AI 파싱
  Future<List<Map<String, dynamic>>> parseWithGroq(String ocrText) async {
    if (kDebugMode) {
      print(
          "🔑 현재 설정된 API 키 앞부분: ${_apiKey.length > 10 ? _apiKey.substring(0, 10) + '...' : '키 없음'}");
    }

    if (_apiKey.startsWith('gsk_') == false) {
      if (kDebugMode) print("⚠️ Groq API 키가 설정되지 않았거나 형식이 잘못되었습니다.");
      return [];
    }

    try {
      if (kDebugMode) print("🚀 1. Groq AI(Llama3)에 요청 전송 중...");

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': '''
당신은 약국 약봉투 분석 전문가입니다. OCR 텍스트에서 약 정보를 추출해 JSON 리스트로 반환하세요.
응답은 오직 JSON 형식의 리스트만 반환해야 합니다. 설명이나 마크다운은 포함하지 마세요.

[규칙]
1. name: 약 이름 (특수문자, 괄호 내용 제거)
2. dosage: 1회 투약량 (숫자만, 기본값 "1")
3. freq: 1일 투약횟수 (숫자만, 기본값 "3")
4. days: 투약일수 (숫자만, 기본값 "3")
5. when: 'afterMeal30'(식후30분), 'beforeMeal30'(식전30분), 'beforeSleep'(취침전), 'instant'(식후즉시). (기본값 'afterMeal30')
6. searchKeyword: API 검색을 위한 핵심 키워드.
   - 괄호()와 그 안의 내용은 무조건 삭제하세요.
   - 숫자(용량)는 반드시 포함하세요.
   - '정', '캡슐', '서방정', '연질캡슐', '시럽' 같은 제형 명칭은 절대 삭제하지 말고 유지하세요.
   - 오직 단위(mg, ml, g, 밀리그람 등)만 삭제하세요.

[출력 예시]
[
  {"name": "오구멘틴정625mg", "searchKeyword": "오구멘틴정625", "dosage": "1", "freq": "3", "days": "3", "when": "afterMeal30"}
]
'''
            },
            {'role': 'user', 'content': ocrText}
          ],
          'temperature': 0.1,
          'response_format': {'type': 'json_object'}
        }),
      );

      if (kDebugMode) print("📡 2. Groq 응답 상태 코드: ${response.statusCode}");

      if (response.statusCode == 200) {
        String responseBody = utf8.decode(response.bodyBytes);
        if (kDebugMode) print("📜 3. Groq 원본 응답 내용:\n$responseBody");

        final data = jsonDecode(responseBody);
        String content = data['choices'][0]['message']['content'];

        int startList = content.indexOf('[');
        int startObj = content.indexOf('{');
        int start = -1;
        int end = -1;

        if (startList != -1 && (startObj == -1 || startList < startObj)) {
          start = startList;
          end = content.lastIndexOf(']') + 1;
        } else if (startObj != -1) {
          start = startObj;
          end = content.lastIndexOf('}') + 1;
        }

        if (start != -1 && end != -1) {
          content = content.substring(start, end);
        }

        dynamic decodedData;
        try {
          decodedData = jsonDecode(content);
        } catch (e) {
          if (kDebugMode) print("⚠️ JSON 파싱 실패, 원본 콘텐츠로 재시도합니다: $e");
          return [];
        }

        List<dynamic> jsonList = [];
        if (decodedData is List) {
          jsonList = decodedData;
        } else if (decodedData is Map) {
          if (kDebugMode) print("⚠️ AI가 단일 객체를 반환했습니다. 리스트로 변환합니다.");
          jsonList = [decodedData];
        } else {
          if (kDebugMode)
            print("❌ 알 수 없는 데이터 형식입니다: ${decodedData.runtimeType}");
          return [];
        }

        if (kDebugMode)
          print("📦 4. 파싱된 약 리스트 (${jsonList.length}개): $jsonList");

        return jsonList.map((item) {
          return {
            'name': item['name']?.toString() ?? '',
            'searchKeyword': item['searchKeyword']?.toString() ?? '',
            'dosage': item['dosage']?.toString() ?? '1',
            'freq': item['freq']?.toString() ?? '3',
            'days': item['days']?.toString() ?? '3',
            'when': item['when']?.toString() ?? 'afterMeal30',
          };
        }).toList();
      } else {
        if (kDebugMode) print("❌ Groq 오류 발생: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      if (kDebugMode) print("🔥 Groq 연결 실패 (네트워크/코드 오류): $e");
      return [];
    }
  }

  // [기존 정규식 로직]
  Map<String, dynamic> parseMultiPills(String text) {
    List<Map<String, dynamic>> pills = [];
    Set<String> addedKeys = {};
    String commonWhen = 'afterMeal30';
    List<String> lines = text.split('\n');

    for (String line in lines) {
      String clean = line.replaceAll(' ', '');
      if (clean.contains('식후')) {
        commonWhen = clean.contains('즉시') ? 'instant' : 'afterMeal30';
      } else if (clean.contains('식전'))
        commonWhen = 'beforeMeal30';
      else if (clean.contains('취침')) commonWhen = 'beforeSleep';
    }

    for (String line in lines) {
      String cleanLine = line.trim();
      RegExp tableRowRegex = RegExp(r'^(.*?)\s+(\d+)\s+(\d+)\s+(\d+)$');
      Match? match = tableRowRegex.firstMatch(cleanLine);

      if (match != null) {
        String rawName = match.group(1) ?? '';
        String dosage = match.group(2) ?? '1';
        String freq = match.group(3) ?? '3';
        String days = match.group(4) ?? '3';
        String searchKeyword = _cleanPillName(rawName);

        if (!_isBannedWord(searchKeyword) &&
            !_isDuplicate(searchKeyword, addedKeys)) {
          pills.add({
            'name': rawName.trim(),
            'searchKeyword': searchKeyword,
            'dosage': dosage,
            'freq': freq,
            'days': days,
            'when': commonWhen,
          });
          addedKeys.add(searchKeyword);
        }
      }
    }

    if (pills.isEmpty) {
      for (String line in lines) {
        String clean = line.replaceAll(' ', '');
        if (clean.endsWith('정') ||
            clean.endsWith('캡슐') ||
            clean.endsWith('캅셀') ||
            clean.endsWith('시럽') ||
            clean.contains('mg')) {
          String searchKeyword = _cleanPillName(line.trim());
          if (!_isBannedWord(searchKeyword) &&
              !_isDuplicate(searchKeyword, addedKeys)) {
            pills.add({
              'name': line.trim(),
              'searchKeyword': searchKeyword,
              'dosage': '1',
              'freq': '3',
              'days': '3',
              'when': commonWhen,
            });
            addedKeys.add(searchKeyword);
          }
        }
      }
    }
    return {'pills': pills, 'commonWhen': commonWhen};
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);
    for (int i = 0; i < t.length + 1; i++) v0[i] = i;
    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < t.length + 1; j++) v0[j] = v1[j];
    }
    return v1[t.length];
  }

  bool _isDuplicate(String newName, Set<String> existingNames) {
    if (existingNames.contains(newName)) return true;
    for (String existing in existingNames) {
      if ((existing.length - newName.length).abs() > 2) continue;
      int distance = _levenshtein(existing, newName);
      if (distance <= (existing.length > 4 ? 1 : 0)) return true;
    }
    return false;
  }

  bool _isBannedWord(String keyword) {
    if (keyword.length < 2) return true;
    if (RegExp(r'^[0-9]+$').hasMatch(keyword)) return true;
    const List<String> bannedList = [
      '약품명',
      '약명',
      '처방약',
      '복약안내',
      '주의사항',
      '식후',
      '식전',
      '취침',
      '투약량',
      '횟수',
      '일수',
      '보관',
      '보험',
      '급여',
      '비급여',
      '금액',
      '합계',
      '시럽',
      '주사',
      '백색',
      '황색',
      '원형',
      '타원형'
    ];
    for (String banned in bannedList) {
      if (keyword == banned ||
          (keyword.length <= 4 && keyword.contains(banned))) return true;
    }
    return false;
  }

  String _cleanPillName(String rawName) {
    String clean = rawName
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '');
    clean = clean.replaceAllMapped(
      RegExp(r'(\d+)\s*(mg|ml|g|Mg|Ml|G|k|K|l|L|캡슐|정|캅셀)',
          caseSensitive: false),
      (Match m) => '${m[1]}',
    );
    clean = clean.replaceAll(RegExp(r'[^\w가-힣\s\d]'), '');
    return clean.trim();
  }

  void dispose() {
    _textRecognizer.close();
  }
}
