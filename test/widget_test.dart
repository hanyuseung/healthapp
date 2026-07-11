import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthapp/main.dart';
import 'package:healthapp/models.dart';
import 'package:healthapp/routine_share.dart';
import 'package:healthapp/storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('홈 화면이 렌더링된다', (tester) async {
    await WorkoutStore.instance.load();
    await tester.pumpWidget(const HealthApp());
    expect(find.text('운동 플래너'), findsOneWidget);
    expect(find.text('계획된 운동이 없어요'), findsOneWidget);
    expect(find.text('운동 추가'), findsOneWidget);
  });

  testWidgets('운동 추가 시트가 열린다', (tester) async {
    await WorkoutStore.instance.load();
    await tester.pumpWidget(const HealthApp());
    await tester.tap(find.text('운동 추가'));
    await tester.pumpAndSettle();
    expect(find.text('무산소 운동 (웨이트)'), findsOneWidget);
    expect(find.text('유산소 운동'), findsOneWidget);
  });

  test('저장 후 다시 불러오면 데이터가 유지된다', () async {
    final store = WorkoutStore.instance;
    await store.load();
    final date = DateTime(2026, 7, 9);
    store.add(
      date,
      Exercise(
        id: newId(),
        type: ExerciseType.anaerobic,
        name: '벤치프레스',
        sets: [
          ExerciseSet(reps: 12, restSeconds: 90),
          ExerciseSet(reps: 10, restSeconds: 120),
        ],
      ),
    );
    store.add(
      date,
      Exercise(
        id: newId(),
        type: ExerciseType.cardio,
        name: '러닝',
        durationMinutes: 30,
      ),
    );
    // 저장이 비동기이므로 잠시 대기 후 다시 로드한다.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await store.load();
    final loaded = store.exercisesFor(date);
    expect(loaded.length, 2);
    expect(loaded[0].name, '벤치프레스');
    expect(loaded[0].sets.length, 2);
    expect(loaded[0].sets[1].restSeconds, 120);
    expect(loaded[1].type, ExerciseType.cardio);
    expect(loaded[1].durationMinutes, 30);
  });

  test('공유 코드 인코딩/디코딩 왕복', () {
    final exercises = [
      Exercise(
        id: newId(),
        type: ExerciseType.anaerobic,
        name: '데드리프트',
        sets: [
          ExerciseSet(reps: 5, restSeconds: 180, weightKg: 100, done: true),
          ExerciseSet(reps: 5, restSeconds: 180, weightKg: 102.5),
        ],
      ),
      Exercise(
        id: newId(),
        type: ExerciseType.cardio,
        name: '러닝',
        durationMinutes: 25,
        cardioDone: true,
      ),
    ];
    final code = RoutineClipboard.encode(RoutineClipboard.dayPayload(exercises));
    expect(code.startsWith('FIT1.'), isTrue);

    final decoded = RoutineClipboard.decode(code);
    expect(decoded, isNotNull);
    final imported = RoutineClipboard.exercisesFromDay(decoded!);
    expect(imported.length, 2);
    expect(imported[0].name, '데드리프트');
    expect(imported[0].sets[1].weightKg, 102.5);
    // 가져올 때 완료 상태와 id는 초기화된다.
    expect(imported[0].sets[0].done, isFalse);
    expect(imported[1].cardioDone, isFalse);
    expect(imported[0].id, isNot(exercises[0].id));

    expect(RoutineClipboard.decode('잘못된 코드'), isNull);
    expect(RoutineClipboard.decode('FIT1.!!!'), isNull);
  });

  test('주간 루틴 페이로드 왕복', () {
    final byWeekday = {
      DateTime.monday: [
        Exercise(id: newId(), type: ExerciseType.anaerobic, name: '스쿼트',
            sets: [ExerciseSet(reps: 10, restSeconds: 90)]),
      ],
      DateTime.sunday: [
        Exercise(id: newId(), type: ExerciseType.cardio, name: '걷기',
            durationMinutes: 40),
      ],
    };
    final code =
        RoutineClipboard.encode(RoutineClipboard.weekPayload(byWeekday));
    final decoded = RoutineClipboard.decode(code);
    final imported = RoutineClipboard.exercisesFromWeek(decoded!);
    expect(imported.keys.toSet(), {DateTime.monday, DateTime.sunday});
    expect(imported[DateTime.monday]!.first.name, '스쿼트');
    expect(imported[DateTime.sunday]!.first.durationMinutes, 40);
  });
}
