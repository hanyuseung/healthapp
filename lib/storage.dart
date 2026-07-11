import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// 날짜별 운동 계획을 보관하고 shared_preferences 에 저장하는 스토어.
class WorkoutStore extends ChangeNotifier {
  WorkoutStore._();

  static final WorkoutStore instance = WorkoutStore._();
  static const _prefsKey = 'workout_plans_v1';

  final Map<String, List<Exercise>> _plans = {};

  static String keyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _plans.clear();
    try {
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.forEach((key, value) {
        _plans[key] = (value as List<dynamic>)
            .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      // 손상된 데이터는 무시하고 빈 상태로 시작한다.
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      for (final e in _plans.entries)
        if (e.value.isNotEmpty) e.key: e.value.map((x) => x.toJson()).toList(),
    };
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  List<Exercise> exercisesFor(DateTime date) =>
      List.unmodifiable(_plans[keyFor(date)] ?? const <Exercise>[]);

  bool hasPlan(DateTime date) => (_plans[keyFor(date)]?.isNotEmpty) ?? false;

  /// 해당 날짜의 운동이 1개 이상 있고 전부 완료됐는지.
  bool allCompleted(DateTime date) {
    final list = _plans[keyFor(date)];
    if (list == null || list.isEmpty) return false;
    return list.every((e) => e.isCompleted);
  }

  /// 저장된 모든 계획을 날짜별로 반환 (통계용).
  Map<DateTime, List<Exercise>> allByDate() {
    final result = <DateTime, List<Exercise>>{};
    _plans.forEach((key, value) {
      if (value.isEmpty) return;
      final parts = key.split('-');
      if (parts.length != 3) return;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) return;
      result[DateTime(y, m, d)] = List.unmodifiable(value);
    });
    return result;
  }

  void add(DateTime date, Exercise exercise) {
    _plans.putIfAbsent(keyFor(date), () => []).add(exercise);
    _save();
    notifyListeners();
  }

  void addAll(DateTime date, List<Exercise> exercises) {
    if (exercises.isEmpty) return;
    _plans.putIfAbsent(keyFor(date), () => []).addAll(exercises);
    _save();
    notifyListeners();
  }

  void clearAll() {
    _plans.clear();
    _save();
    notifyListeners();
  }

  void remove(DateTime date, String id) {
    _plans[keyFor(date)]?.removeWhere((e) => e.id == id);
    _save();
    notifyListeners();
  }

  /// Exercise 객체를 직접 수정한 뒤 호출하면 저장 및 갱신된다.
  void update() {
    _save();
    notifyListeners();
  }
}
