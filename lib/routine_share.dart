import 'dart:convert';

import 'models.dart';

/// 루틴 복사/붙여넣기 버퍼와 공유 코드 인코딩.
///
/// 공유 코드 형식: `FIT1.` + base64Url(utf8(json))
/// - 하루 루틴: {"t":"d","d":[운동...]}
/// - 1주일 루틴: {"t":"w","d":{"1":[운동...], ... "7":[...]}} (키 = ISO 요일)
class RoutineClipboard {
  static const _prefix = 'FIT1.';

  /// 앱 내 복사 버퍼 (마지막으로 복사한 페이로드).
  static Map<String, dynamic>? buffer;

  static bool get hasDay => buffer?['t'] == 'd';
  static bool get hasWeek => buffer?['t'] == 'w';

  static Map<String, dynamic> dayPayload(List<Exercise> exercises) => {
        't': 'd',
        'd': exercises.map((e) => e.toJson()).toList(),
      };

  /// [byWeekday]: ISO 요일(1=월 ~ 7=일) → 운동 목록.
  static Map<String, dynamic> weekPayload(
      Map<int, List<Exercise>> byWeekday) {
    final data = <String, dynamic>{};
    byWeekday.forEach((weekday, list) {
      if (list.isNotEmpty) {
        data['$weekday'] = list.map((e) => e.toJson()).toList();
      }
    });
    return {'t': 'w', 'd': data};
  }

  static String encode(Map<String, dynamic> payload) =>
      _prefix + base64UrlEncode(utf8.encode(jsonEncode(payload)));

  /// 잘못된 코드는 null.
  static Map<String, dynamic>? decode(String code) {
    try {
      final trimmed = code.trim();
      if (!trimmed.startsWith(_prefix)) return null;
      final raw = utf8.decode(
          base64Url.decode(base64Url.normalize(trimmed.substring(_prefix.length))));
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['t'] != 'd' && map['t'] != 'w') return null;
      if (map['d'] == null) return null;
      return map;
    } catch (_) {
      return null;
    }
  }

  /// 하루 페이로드에서 새 Exercise 목록 생성 (id 재발급, 완료 초기화).
  static List<Exercise> exercisesFromDay(Map<String, dynamic> payload) {
    final list = payload['d'] as List<dynamic>;
    return list
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>).copyFresh())
        .toList();
  }

  /// 주 페이로드에서 요일별 새 Exercise 목록 생성.
  static Map<int, List<Exercise>> exercisesFromWeek(
      Map<String, dynamic> payload) {
    final data = payload['d'] as Map<String, dynamic>;
    final result = <int, List<Exercise>>{};
    data.forEach((key, value) {
      final weekday = int.tryParse(key);
      if (weekday == null || weekday < 1 || weekday > 7) return;
      result[weekday] = (value as List<dynamic>)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>).copyFresh())
          .toList();
    });
    return result;
  }
}
