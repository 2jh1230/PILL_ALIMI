import 'dart:convert';
import 'package:flutter/foundation.dart'; // [추가] kDebugMode 사용을 위해 임포트
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env 적용 가정

class ApiService {
  // .env에서 키를 가져오도록 수정된 상태라고 가정합니다.
  final String serviceKey = dotenv.env['PUBLIC_DATA_KEY'] ?? '';

  // 1. 공공데이터 알약 검색
  // Future<List<dynamic>> searchPills(String keyword) async {
  //   const String baseUrl =
  //       'https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService03/getMdcinGrnIdntfcInfoList03';

  //   String url = '$baseUrl?serviceKey=$serviceKey'
  //       '&item_name=${Uri.encodeQueryComponent(keyword)}'
  //       '&numOfRows=20&pageNo=1&type=json';

  //   try {
  //     final response = await http.get(Uri.parse(url));

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       if (data['body'] != null && data['body']['items'] != null) {
  //         return data['body']['items'];
  //       }
  //     } else {
  //       if (kDebugMode) {
  //         print('알약 검색 통신 에러: ${response.statusCode}');
  //       }
  //     }
  //     return [];
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('알약 검색 에러: $e');
  //     }
  //     return [];
  //   }
  // }

  // 1. 알약 검색 (내 개인 서버 사용)
  Future<List<dynamic>> searchPills(String keyword) async {
    // [중요] 내 오라클 클라우드 서버 주소
    final String baseUrl = dotenv.env['ORACLE_CLOUD'] ?? '';

    // 파라미터: name=검색어
    String url = '$baseUrl?name=${Uri.encodeQueryComponent(keyword)}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // 내 서버는 리스트 [...]를 바로 줍니다. 복잡한 body['items'] 필요 없음!
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data;
      } else {
        if (kDebugMode) {
          print('서버 통신 에러: ${response.statusCode}');
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('알약 검색 에러: $e');
      }
      return [];
    }
  }

  // 2. 약국 정보 조회 (위치 기반)
  Future<List<dynamic>> getPharmacies(double lat, double lng) async {
    const String baseUrl =
        'https://apis.data.go.kr/B552657/ErmctInsttInfoInqireService/getParmacyLcinfoInqire';

    String url = '$baseUrl?serviceKey=$serviceKey'
        '&WGS84_LON=$lng&WGS84_LAT=$lat'
        '&pageNo=1&numOfRows=100'
        '&_type=json';

    try {
      if (kDebugMode) {
        print('약국 API 요청: $url');
      }
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final bodyString = utf8.decode(response.bodyBytes);

        if (kDebugMode) {
          print(
              '📡 응답 데이터(앞부분): ${bodyString.length > 500 ? bodyString.substring(0, 500) : bodyString}');
        }

        try {
          final data = jsonDecode(bodyString);

          if (data['response'] != null &&
              data['response']['body'] != null &&
              data['response']['body']['items'] != null) {
            final itemsData = data['response']['body']['items'];

            if (kDebugMode) {
              print('📦 items 데이터 타입: ${itemsData.runtimeType}');
            }

            if (itemsData is List) {
              if (kDebugMode) print('✅ 약국 리스트 발견: ${itemsData.length}개');
              return itemsData;
            } else if (itemsData is Map) {
              if (itemsData.containsKey('item')) {
                final item = itemsData['item'];
                if (item is List) {
                  if (kDebugMode) print('✅ 약국 리스트(item) 발견: ${item.length}개');
                  return item;
                }
                if (item is Map) {
                  if (kDebugMode) print('✅ 약국 1개 발견');
                  return [item];
                }
              }
            } else {
              if (kDebugMode) print('⚠️ items가 비어있거나 형식이 다릅니다.');
            }
          } else {
            if (kDebugMode) print('⚠️ 데이터 구조가 예상과 다릅니다');
          }
        } catch (e) {
          if (kDebugMode) print('❌ JSON 파싱 실패: $e');
        }
      } else {
        if (kDebugMode) print('🔥 통신 에러: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('🚫 약국 검색 함수 에러: $e');
      return [];
    }
  }
}
