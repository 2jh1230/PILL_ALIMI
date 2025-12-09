# 💊 알약 알리미 (Pill Allimi)

**AI 기반 스마트 복약 관리 및 약국 찾기 솔루션**

`알약 알리미`는 사용자가 처방받은 약을 쉽고 정확하게 관리할 수 있도록 돕는 Flutter 기반의 모바일 애플리케이션입니다. 약봉투를 카메라로 촬영하면 AI가 자동으로 텍스트를 분석하여 복약 정보를 등록해주며, 위치 기반으로 가까운 약국을 찾을 수 있습니다.

## ✨ 주요 기능 (Key Features)

  * **📷 스마트 약봉투 스캔 (AI OCR)**
      * Google ML Kit와 Groq(Llama-3)를 활용하여 약봉투 사진에서 약 이름, 복용 횟수, 일수 등을 자동으로 추출합니다.
      * 하루 3회 무료 스캔 기능을 제공하며, 스캔 후 부족한 정보는 공공데이터 API와 대조하여 보정합니다.
  * **⏰ 복약 알림 서비스**
      * 식전/식후/취침 전 등 복용 시점에 맞춰 로컬 푸시 알림을 제공합니다.
      * 약마다 개별 알림 시간을 설정하고 수정할 수 있습니다.
  * **🔎 의약품 검색 및 직접 등록**
      * 식품의약품안전처 공공데이터를 활용하여 국내 유통되는 의약품 정보를 검색하고 등록할 수 있습니다.
  * **🏥 내 주변 약국 찾기**
      * 네이버 지도(Naver Map)를 연동하여 현재 위치 기준 반경 2km 이내의 약국을 검색합니다.
      * 영업 중/종료 상태를 실시간으로 확인하고 전화 걸기 기능을 지원합니다.
  * **📅 복약 캘린더**
      * 캘린더 뷰를 통해 날짜별 복용해야 할 약 목록을 한눈에 확인할 수 있습니다.
  * **💾 데이터 로컬 저장**
      * SQLite를 사용하여 사용자의 민감한 복약 정보를 기기 내부에 안전하게 저장합니다.

## 🛠 기술 스택 (Tech Stack)

| 구분 | 기술 | 비고 |
| --- | --- | --- |
| **Framework** | Flutter (Dart) | Cross-platform dev |
| **State Mgt** | `setState`, `StatefulWidget` | Native state management |
| **Local DB** | `sqflite` | SQLite DB Helper |
| **AI / OCR** | `google_mlkit_text_recognition` | Text Extraction |
| **LLM API** | Groq API (Llama-3) | Context Parsing |
| **Map** | `flutter_naver_map` | Naver Maps SDK |
| **Notification** | `flutter_local_notifications` | Local Push |
| **Ads** | `google_mobile_ads` | AdMob Integration |

## 📂 프로젝트 구조 (Project Structure)

```
lib/
├── models/          # 데이터 모델 (Medicine 등)
├── screens/         # UI 화면 (홈, 카메라, 지도, 캘린더 등)
├── services/        # 비즈니스 로직 (API, DB, OCR, 알림)
└── main.dart        # 앱 진입점
```

## 🚀 시작하기 (Getting Started)

이 프로젝트는 API 키와 같은 민감한 정보를 `.env` 파일로 관리합니다. 프로젝트를 실행하기 위해서는 환경 변수 설정이 필요합니다.

### 1\. 필수 API 키 준비

다음 서비스들의 API 키가 필요합니다:

  * **공공데이터포털**: [식품의약품안전처 의약품 정보 조회](https://www.data.go.kr/)
  * **Groq Cloud**: AI 파싱용 API Key
  * **Naver Cloud Platform**: 지도 SDK Client ID

### 2\. .env 파일 생성

프로젝트 최상위 경로( `pubspec.yaml` 이 있는 곳)에 `.env` 파일을 생성하고 아래 내용을 입력하세요.

```env
# .env 예시
PUBLIC_DATA_KEY=여기에_공공데이터_디코딩_키_입력
GROQ_API_KEY=gsk_여기에_Groq_API_키_입력
NAVER_CLIENT_ID=여기에_네이버_클라이언트_ID_입력
```

### 3\. 패키지 설치 및 실행

```bash
# 의존성 패키지 설치
flutter pub get

# 앱 실행
flutter run
```

## ⚠️ 주의사항

  * 이 앱은 보조 수단이며, 정확한 의학적 판단은 의사나 약사와 상담해야 합니다.
  * 하루 무료 스캔 횟수는 3회로 제한되어 있습니다.

## 📄 License

This project is licensed under the MIT License.