# 1. 사용하지 않는 언어(중국어, 데바나가리, 일본어)에 대한 경고 무시
# (라이브러리를 추가하지 않았으므로 클래스가 없는 것이 정상입니다)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**

# 2. 실제로 사용하는 한국어 및 공통 클래스는 유지 (난독화 방지)
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keep class com.google.mlkit.vision.text.latin.** { *; }
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.common.** { *; }