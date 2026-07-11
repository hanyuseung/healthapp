import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'detail_screens.dart';
import 'edit_screens.dart';
import 'models.dart';
import 'routine_share.dart';
import 'settings.dart';
import 'stats_screens.dart';
import 'storage.dart';
import 'widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WorkoutStore.instance.load();
  await AppSettings.instance.load();
  runApp(const HealthApp());
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: '운동 플래너',
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selected = dateOnly(DateTime.now());
  bool _monthExpanded = false;

  /// 설정된 시작 요일 기준의 주 시작 날짜.
  DateTime get _weekStart {
    final start = AppSettings.instance.weekStartDay;
    final offset = (_selected.weekday - start + 7) % 7;
    return dateOnly(_selected.subtract(Duration(days: offset)));
  }

  /// 접힘: 한 주 이동, 펼침: 한 달 이동.
  void _shift(int delta) {
    setState(() {
      if (_monthExpanded) {
        final target = DateTime(_selected.year, _selected.month + delta, 1);
        final lastDay = DateTime(target.year, target.month + 1, 0).day;
        _selected = DateTime(
            target.year, target.month, _selected.day.clamp(1, lastDay));
      } else {
        _selected = dateOnly(_selected.add(Duration(days: 7 * delta)));
      }
    });
  }

  void _goToday() => setState(() => _selected = dateOnly(DateTime.now()));

  Future<void> _showAddSheet() async {
    final type = await showCupertinoModalPopup<ExerciseType>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('운동 추가'),
        message: Text('${_selected.month}월 ${_selected.day}일 계획에 추가합니다.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ExerciseType.anaerobic),
            child: const Text('무산소 운동 (웨이트)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ExerciseType.cardio),
            child: const Text('유산소 운동'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소'),
        ),
      ),
    );
    if (type == null || !mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => type == ExerciseType.anaerobic
            ? AnaerobicEditScreen(date: _selected)
            : CardioEditScreen(date: _selected),
      ),
    );
  }

  Future<void> _showItemActions(Exercise e) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(e.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'edit'),
            child: const Text('편집'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('삭제'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소'),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') {
      WorkoutStore.instance.remove(_selected, e.id);
    } else if (action == 'edit') {
      await Navigator.of(context).push(
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (_) => e.type == ExerciseType.anaerobic
              ? AnaerobicEditScreen(date: _selected, exercise: e)
              : CardioEditScreen(date: _selected, exercise: e),
        ),
      );
    }
  }

  // ── 루틴 복사/붙여넣기/공유 ──────────────────────────────────

  /// 선택된 주의 요일별 운동 목록 (비어 있지 않은 날만).
  Map<int, List<Exercise>> _weekExercises() {
    final store = WorkoutStore.instance;
    final result = <int, List<Exercise>>{};
    for (var i = 0; i < 7; i++) {
      final day = dateOnly(_weekStart.add(Duration(days: i)));
      final list = store.exercisesFor(day);
      if (list.isNotEmpty) result[day.weekday] = list.toList();
    }
    return result;
  }

  Future<void> _showRoutineSheet() async {
    final buffer = RoutineClipboard.buffer;
    final pasteLabel = RoutineClipboard.hasDay
        ? '붙여넣기 (하루 루틴)'
        : RoutineClipboard.hasWeek
            ? '붙여넣기 (1주일 루틴)'
            : null;
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('루틴 복사 · 공유'),
        message: const Text('복사하면 공유 코드도 클립보드에 저장돼요.\n코드를 다른 사람에게 보내 공유할 수 있어요.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'copyDay'),
            child: const Text('이 날 루틴 복사'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'copyWeek'),
            child: const Text('이 주 루틴 복사'),
          ),
          if (buffer != null && pasteLabel != null)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'paste'),
              child: Text(pasteLabel),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'import'),
            child: const Text('공유 코드 가져오기'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소'),
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'copyDay':
        _copyDay();
      case 'copyWeek':
        _copyWeek();
      case 'paste':
        _paste();
      case 'import':
        await _importCode();
    }
  }

  void _copyDay() {
    final list = WorkoutStore.instance.exercisesFor(_selected);
    if (list.isEmpty) {
      showHud(context, '복사할 운동이 없어요');
      return;
    }
    final payload = RoutineClipboard.dayPayload(list.toList());
    RoutineClipboard.buffer = payload;
    Clipboard.setData(ClipboardData(text: RoutineClipboard.encode(payload)));
    showHud(context, '하루 루틴을 복사했어요\n공유 코드가 클립보드에 저장됐어요');
  }

  void _copyWeek() {
    final week = _weekExercises();
    if (week.isEmpty) {
      showHud(context, '이 주에 복사할 운동이 없어요');
      return;
    }
    final payload = RoutineClipboard.weekPayload(week);
    RoutineClipboard.buffer = payload;
    Clipboard.setData(ClipboardData(text: RoutineClipboard.encode(payload)));
    showHud(context, '1주일 루틴을 복사했어요\n공유 코드가 클립보드에 저장됐어요');
  }

  void _paste() {
    final buffer = RoutineClipboard.buffer;
    if (buffer == null) return;
    _applyPayload(buffer);
  }

  /// 페이로드를 선택된 날짜(하루) 또는 선택된 주(1주일)에 추가한다.
  void _applyPayload(Map<String, dynamic> payload) {
    final store = WorkoutStore.instance;
    if (payload['t'] == 'd') {
      final list = RoutineClipboard.exercisesFromDay(payload);
      store.addAll(_selected, list);
      showHud(context,
          '${_selected.month}월 ${_selected.day}일에 운동 ${list.length}개를 추가했어요');
    } else {
      final byWeekday = RoutineClipboard.exercisesFromWeek(payload);
      var count = 0;
      byWeekday.forEach((weekday, list) {
        for (var i = 0; i < 7; i++) {
          final day = dateOnly(_weekStart.add(Duration(days: i)));
          if (day.weekday == weekday) {
            store.addAll(day, list);
            count += list.length;
            break;
          }
        }
      });
      showHud(context, '이 주에 운동 $count개를 추가했어요');
    }
  }

  Future<void> _importCode() async {
    final controller = TextEditingController();
    final code = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('공유 코드 가져오기'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'FIT1. 으로 시작하는 코드 붙여넣기',
            maxLines: 3,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('가져오기'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty || !mounted) return;
    final payload = RoutineClipboard.decode(code);
    if (payload == null) {
      showHud(context, '올바르지 않은 공유 코드예요');
      return;
    }
    RoutineClipboard.buffer = payload;
    _applyPayload(payload);
  }

  void _openDetail(Exercise e) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => e.type == ExerciseType.anaerobic
            ? AnaerobicDetailScreen(date: _selected, exercise: e)
            : CardioDetailScreen(date: _selected, exercise: e),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge(
              [WorkoutStore.instance, AppSettings.instance]),
          builder: (context, _) {
            final items = WorkoutStore.instance.exercisesFor(_selected);
            return Column(
              children: [
                _buildHeader(context),
                _buildCalendar(context),
                Expanded(child: _buildBody(context, items)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isToday = sameDay(_selected, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '운동 플래너',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (!isToday)
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onPressed: _goToday,
                  child: const Text('오늘'),
                ),
              CupertinoButton(
                padding: const EdgeInsets.all(6),
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const StatsScreen()),
                ),
                child:
                    const Icon(CupertinoIcons.chart_bar_alt_fill, size: 24),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(6),
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const SettingsScreen()),
                ),
                child: const Icon(CupertinoIcons.gear_alt_fill, size: 24),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '${_selected.year}년 ${_selected.month}월',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _shift(-1),
                child: const Icon(CupertinoIcons.chevron_left, size: 22),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _shift(1),
                child: const Icon(CupertinoIcons.chevron_right, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    kWeekdaysKo[
                        (AppSettings.instance.weekStartDay - 1 + i) % 7],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _monthExpanded ? _monthGrid(context) : _weekRow(context),
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 2),
          onPressed: () => setState(() => _monthExpanded = !_monthExpanded),
          child: Icon(
            _monthExpanded
                ? CupertinoIcons.chevron_compact_up
                : CupertinoIcons.chevron_compact_down,
            size: 24,
            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
          ),
        ),
      ],
    );
  }

  Widget _weekRow(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
              child:
                  _dayCell(context, dateOnly(_weekStart.add(Duration(days: i))))),
      ],
    );
  }

  Widget _monthGrid(BuildContext context) {
    final first = DateTime(_selected.year, _selected.month, 1);
    final daysInMonth = DateTime(_selected.year, _selected.month + 1, 0).day;
    final leading =
        (first.weekday - AppSettings.instance.weekStartDay + 7) % 7;
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(_dayCell(context, DateTime(_selected.year, _selected.month, d)));
    }
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(Row(
        children: [
          for (var j = 0; j < 7; j++) Expanded(child: cells[i + j]),
        ],
      ));
      if (i + 7 < cells.length) rows.add(const SizedBox(height: 4));
    }
    return Column(children: rows);
  }

  Widget _dayCell(BuildContext context, DateTime day) {
    final store = WorkoutStore.instance;
    final selected = sameDay(day, _selected);
    final isToday = sameDay(day, dateOnly(DateTime.now()));
    final blue = CupertinoColors.activeBlue.resolveFrom(context);
    final green = CupertinoColors.systemGreen.resolveFrom(context);
    final allDone = store.allCompleted(day);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = day),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? (allDone ? green : blue) : null,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    selected || isToday ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? CupertinoColors.white
                    : allDone
                        ? green
                        : isToday
                            ? blue
                            : CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: allDone
                  ? green
                  : store.hasPlan(day)
                      ? blue
                      : const Color(0x00000000),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Exercise> items) {
    final anaerobic =
        items.where((e) => e.type == ExerciseType.anaerobic).toList();
    final cardio = items.where((e) => e.type == ExerciseType.cardio).toList();
    final doneCount = items.where((e) => e.isCompleted).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 4),
          child: Row(
            children: [
              Text(
                '${_selected.month}월 ${_selected.day}일 ${weekdayKo(_selected)}요일',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                onPressed: _showRoutineSheet,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.doc_on_doc, size: 17),
                    SizedBox(width: 4),
                    Text('루틴', style: TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          _buildEmpty(context)
        else ...[
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground
                  .resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('오늘의 진행',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(
                      '$doneCount / ${items.length} 완료',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ProgressBar(
                  value: doneCount / items.length,
                  color: doneCount == items.length
                      ? CupertinoColors.systemGreen.resolveFrom(context)
                      : null,
                ),
              ],
            ),
          ),
          if (anaerobic.isNotEmpty) ...[
            const SectionHeader('무산소'),
            GroupCard(
              children: [
                for (final e in anaerobic) _exerciseRow(context, e),
              ],
            ),
          ],
          if (cardio.isNotEmpty) ...[
            const SectionHeader('유산소'),
            GroupCard(
              children: [
                for (final e in cardio) _exerciseRow(context, e),
              ],
            ),
          ],
        ],
        const SizedBox(height: 24),
        CupertinoButton.filled(
          borderRadius: BorderRadius.circular(14),
          onPressed: _showAddSheet,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.add, size: 20),
              SizedBox(width: 6),
              Text('운동 추가', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.calendar_badge_plus,
            size: 56,
            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
          ),
          const SizedBox(height: 12),
          Text(
            '계획된 운동이 없어요',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '아래 버튼으로 운동을 추가해 보세요',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exerciseRow(BuildContext context, Exercise e) {
    final isCardio = e.type == ExerciseType.cardio;
    final tint = isCardio
        ? CupertinoColors.systemRed.resolveFrom(context)
        : CupertinoColors.activeBlue.resolveFrom(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(e),
      onLongPress: () => _showItemActions(e),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCardio ? CupertinoIcons.heart_fill : CupertinoIcons.bolt_fill,
                size: 20,
                color: tint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e.subtitle +
                        (!isCardio && e.doneSetCount > 0 && !e.isCompleted
                            ? ' · ${e.doneSetCount}세트 완료'
                            : ''),
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            if (e.isCompleted)
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                size: 22,
                color: CupertinoColors.systemGreen.resolveFrom(context),
              ),
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: () => _showItemActions(e),
              child: Icon(
                CupertinoIcons.ellipsis_circle,
                size: 22,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}
