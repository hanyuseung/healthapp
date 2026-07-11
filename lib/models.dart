enum ExerciseType { anaerobic, cardio }

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

/// 무산소 운동의 한 세트: 반복 횟수, 무게(kg), 세트 후 휴식 시간(초).
class ExerciseSet {
  ExerciseSet({
    required this.reps,
    required this.restSeconds,
    this.weightKg = 0,
    this.done = false,
  });

  int reps;
  int restSeconds;
  double weightKg; // 0이면 맨몸/미설정
  bool done;

  factory ExerciseSet.fromJson(Map<String, dynamic> json) => ExerciseSet(
        reps: json['reps'] as int? ?? 10,
        restSeconds: json['restSeconds'] as int? ?? 90,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
        done: json['done'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'reps': reps,
        'restSeconds': restSeconds,
        'weightKg': weightKg,
        'done': done,
      };

  ExerciseSet copy() => ExerciseSet(
      reps: reps, restSeconds: restSeconds, weightKg: weightKg, done: done);
}

class Exercise {
  Exercise({
    required this.id,
    required this.type,
    required this.name,
    List<ExerciseSet>? sets,
    this.durationMinutes = 30,
    this.cardioDone = false,
  }) : sets = sets ?? [];

  final String id;
  final ExerciseType type;
  String name;
  List<ExerciseSet> sets; // 무산소용
  int durationMinutes; // 유산소용
  bool cardioDone; // 유산소용

  bool get isCompleted => type == ExerciseType.anaerobic
      ? sets.isNotEmpty && sets.every((s) => s.done)
      : cardioDone;

  int get doneSetCount => sets.where((s) => s.done).length;

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        type: json['type'] == 'cardio'
            ? ExerciseType.cardio
            : ExerciseType.anaerobic,
        name: json['name'] as String,
        sets: (json['sets'] as List<dynamic>? ?? [])
            .map((e) => ExerciseSet.fromJson(e as Map<String, dynamic>))
            .toList(),
        durationMinutes: json['durationMinutes'] as int? ?? 30,
        cardioDone: json['cardioDone'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == ExerciseType.cardio ? 'cardio' : 'anaerobic',
        'name': name,
        'sets': sets.map((s) => s.toJson()).toList(),
        'durationMinutes': durationMinutes,
        'cardioDone': cardioDone,
      };

  /// 완료 여부를 초기화한 새 사본 (붙여넣기/가져오기용).
  Exercise copyFresh() => Exercise(
        id: newId(),
        type: type,
        name: name,
        sets: sets
            .map((s) => ExerciseSet(
                reps: s.reps, restSeconds: s.restSeconds, weightKg: s.weightKg))
            .toList(),
        durationMinutes: durationMinutes,
      );

  double get maxWeight =>
      sets.fold(0, (m, s) => s.weightKg > m ? s.weightKg : m);

  /// 총 볼륨 (반복 × 무게 합계, kg 단위).
  double get totalVolume =>
      sets.fold(0, (sum, s) => sum + s.reps * s.weightKg);

  int get totalReps => sets.fold(0, (sum, s) => sum + s.reps);

  /// 목록에 표시할 한 줄 요약.
  String get subtitle {
    if (type == ExerciseType.cardio) {
      return fmtMinutesKo(durationMinutes);
    }
    if (sets.isEmpty) return '세트 없음';
    final reps = sets.map((s) => s.reps).toSet();
    final rests = sets.map((s) => s.restSeconds).toSet();
    final repsText =
        reps.length == 1 ? '${reps.first}회' : sets.map((s) => s.reps).join('·');
    final restText =
        rests.length == 1 ? '휴식 ${fmtSecondsKo(rests.first)}' : '휴식 개별 설정';
    final weightText = maxWeight > 0 ? ' · ${fmtWeight(maxWeight)}' : '';
    return '${sets.length}세트 × $repsText$weightText · $restText';
  }
}

// ── 날짜/시간 헬퍼 ──────────────────────────────────────────────

const kWeekdaysKo = ['월', '화', '수', '목', '금', '토', '일'];

String weekdayKo(DateTime d) => kWeekdaysKo[d.weekday - 1];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 90 → "1:30", 3665 → "1:01:05"
String fmtClock(int seconds) {
  if (seconds < 0) seconds = 0;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// 90 → "1분 30초", 60 → "1분", 45 → "45초"
String fmtSecondsKo(int seconds) {
  if (seconds < 60) return '$seconds초';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '$m분' : '$m분 $s초';
}

/// 60 → "60kg", 62.5 → "62.5kg"
String fmtWeight(double kg) {
  if (kg <= 0) return '';
  return kg % 1 == 0 ? '${kg.toInt()}kg' : '${kg.toStringAsFixed(1)}kg';
}

/// 90 → "1시간 30분", 45 → "45분"
String fmtMinutesKo(int minutes) {
  if (minutes < 60) return '$minutes분';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h시간' : '$h시간 $m분';
}
