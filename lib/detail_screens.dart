import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'edit_screens.dart';
import 'models.dart';
import 'settings.dart';
import 'storage.dart';
import 'widgets.dart';

/// 타이머 종료 알림: 설정에 따라 알림음 + 진동 3회.
Future<void> timerAlert() async {
  final settings = AppSettings.instance;
  if (settings.sound) {
    SystemSound.play(SystemSoundType.alert);
  }
  if (!settings.vibration) return;
  for (var i = 0; i < 3; i++) {
    HapticFeedback.vibrate();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }
}

/// 무산소 운동 수행 화면: 세트 체크 + 세트별 휴식 타이머.
class AnaerobicDetailScreen extends StatefulWidget {
  const AnaerobicDetailScreen(
      {super.key, required this.date, required this.exercise});

  final DateTime date;
  final Exercise exercise;

  @override
  State<AnaerobicDetailScreen> createState() => _AnaerobicDetailScreenState();
}

class _AnaerobicDetailScreenState extends State<AnaerobicDetailScreen> {
  Timer? _timer;
  DateTime? _restEnd;
  int _restTotalMs = 0;

  bool get _resting => _restEnd != null;

  int get _remainingMs =>
      _restEnd == null ? 0 : max(0, _restEnd!.difference(DateTime.now()).inMilliseconds);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRest(int seconds) {
    _timer?.cancel();
    setState(() {
      _restTotalMs = seconds * 1000;
      _restEnd = DateTime.now().add(Duration(seconds: seconds));
    });
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_remainingMs <= 0) {
        _finishRest(notify: true);
      } else {
        setState(() {});
      }
    });
  }

  void _finishRest({required bool notify}) {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _restEnd = null;
      _restTotalMs = 0;
    });
    if (notify) timerAlert();
  }

  void _addRest(int seconds) {
    if (_restEnd == null) return;
    setState(() {
      _restEnd = _restEnd!.add(Duration(seconds: seconds));
      _restTotalMs += seconds * 1000;
    });
  }

  void _toggleSet(int index) {
    final ex = widget.exercise;
    final set = ex.sets[index];
    if (set.done) {
      set.done = false;
      if (_resting) _finishRest(notify: false);
    } else {
      set.done = true;
      HapticFeedback.lightImpact();
      if (ex.isCompleted) {
        if (_resting) _finishRest(notify: false);
      } else if (set.restSeconds > 0) {
        _startRest(set.restSeconds);
      }
    }
    WorkoutStore.instance.update();
    setState(() {});
  }

  Future<void> _edit() async {
    if (_resting) _finishRest(notify: false);
    await Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            AnaerobicEditScreen(date: widget.date, exercise: widget.exercise),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final done = ex.doneSetCount;
    final total = ex.sets.length;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(ex.name),
        previousPageTitle: '목록',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _edit,
          child: const Text('편집'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
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
                      const Text('세트 진행',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        '$done / $total 세트',
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
                    value: total == 0 ? 0 : done / total,
                    color: ex.isCompleted
                        ? CupertinoColors.systemGreen.resolveFrom(context)
                        : null,
                  ),
                ],
              ),
            ),
            if (_resting) ...[
              const SizedBox(height: 12),
              _restCard(context),
            ],
            if (ex.isCompleted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGreen
                      .resolveFrom(context)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      size: 20,
                      color: CupertinoColors.systemGreen.resolveFrom(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '모든 세트 완료! 수고했어요 💪',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color:
                            CupertinoColors.systemGreen.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SectionHeader('세트'),
            GroupCard(
              children: [
                for (var i = 0; i < ex.sets.length; i++) _setRow(context, i),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                '세트를 완료하면 설정한 휴식 타이머가 자동으로 시작됩니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restCard(BuildContext context) {
    final blue = CupertinoColors.activeBlue.resolveFrom(context);
    final remaining = (_remainingMs / 1000).ceil();
    final ratio = _restTotalMs == 0 ? 0.0 : _remainingMs / _restTotalMs;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.timer, size: 18, color: blue),
              const SizedBox(width: 6),
              Text(
                '휴식 중',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: blue),
              ),
              const Spacer(),
              Text(
                fmtClock(remaining),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: blue,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(value: ratio, color: blue),
          const SizedBox(height: 12),
          Row(
            children: [
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                onPressed: () => _addRest(30),
                child: Text('+30초',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: blue)),
              ),
              const Spacer(),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                onPressed: () => _finishRest(notify: false),
                child: const Text('건너뛰기', style: TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _setRow(BuildContext context, int i) {
    final set = widget.exercise.sets[i];
    final green = CupertinoColors.systemGreen.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: set.done
                  ? green
                  : CupertinoColors.systemFill.resolveFrom(context),
            ),
            child: set.done
                ? const Icon(CupertinoIcons.checkmark,
                    size: 16, color: CupertinoColors.white)
                : Text('${i + 1}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  set.weightKg > 0
                      ? '${set.reps}회 · ${fmtWeight(set.weightKg)}'
                      : '${set.reps}회',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  set.restSeconds > 0
                      ? '휴식 ${fmtSecondsKo(set.restSeconds)}'
                      : '휴식 없음',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          if (set.done)
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              onPressed: () => _toggleSet(i),
              child: Text(
                '취소',
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            )
          else
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: CupertinoColors.activeBlue.resolveFrom(context),
              borderRadius: BorderRadius.circular(20),
              onPressed: () => _toggleSet(i),
              child: const Text(
                '완료',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 유산소 운동 수행 화면: 지속 시간 카운트다운 타이머.
class CardioDetailScreen extends StatefulWidget {
  const CardioDetailScreen(
      {super.key, required this.date, required this.exercise});

  final DateTime date;
  final Exercise exercise;

  @override
  State<CardioDetailScreen> createState() => _CardioDetailScreenState();
}

class _CardioDetailScreenState extends State<CardioDetailScreen> {
  Timer? _timer;
  DateTime? _end; // 실행 중일 때만 설정
  late int _remainingMs = _totalMs;

  int get _totalMs => widget.exercise.durationMinutes * 60000;

  bool get _running => _end != null;

  int get _currentRemainingMs => _end != null
      ? max(0, _end!.difference(DateTime.now()).inMilliseconds)
      : _remainingMs;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _end = DateTime.now().add(Duration(milliseconds: _remainingMs)));
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_currentRemainingMs <= 0) {
        _timer?.cancel();
        _timer = null;
        setState(() {
          _end = null;
          _remainingMs = 0;
        });
        widget.exercise.cardioDone = true;
        WorkoutStore.instance.update();
        timerAlert();
      } else {
        setState(() {});
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _remainingMs = _currentRemainingMs;
      _end = null;
    });
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _end = null;
      _remainingMs = _totalMs;
    });
  }

  void _toggleDone() {
    widget.exercise.cardioDone = !widget.exercise.cardioDone;
    WorkoutStore.instance.update();
    setState(() {});
  }

  Future<void> _edit() async {
    _pause();
    await Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            CardioEditScreen(date: widget.date, exercise: widget.exercise),
      ),
    );
    if (mounted) _reset();
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final red = CupertinoColors.systemRed.resolveFrom(context);
    final green = CupertinoColors.systemGreen.resolveFrom(context);
    final remainingSec = (_currentRemainingMs / 1000).ceil();
    final ratio = _totalMs == 0 ? 0.0 : 1 - _currentRemainingMs / _totalMs;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(ex.name),
        previousPageTitle: '목록',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _edit,
          child: const Text('편집'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    fmtClock(remainingSec),
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _running
                          ? red
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '목표 ${fmtMinutesKo(ex.durationMinutes)}',
                    style: TextStyle(
                      fontSize: 15,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ProgressBar(value: ratio, color: red),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          color: CupertinoColors.systemFill
                              .resolveFrom(context),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: _reset,
                          child: Text(
                            '재설정',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color:
                                  CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          color: _running
                              ? CupertinoColors.systemOrange
                                  .resolveFrom(context)
                              : red,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: _currentRemainingMs <= 0
                              ? null
                              : _running
                                  ? _pause
                                  : _start,
                          child: Text(
                            _running ? '일시정지' : '시작',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              color: ex.cardioDone
                  ? CupertinoColors.systemFill.resolveFrom(context)
                  : green,
              borderRadius: BorderRadius.circular(12),
              onPressed: _toggleDone,
              child: Text(
                ex.cardioDone ? '완료 취소' : '완료로 표시',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ex.cardioDone
                      ? CupertinoColors.label.resolveFrom(context)
                      : CupertinoColors.white,
                ),
              ),
            ),
            if (ex.cardioDone)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.checkmark_seal_fill,
                        size: 20, color: green),
                    const SizedBox(width: 8),
                    Text(
                      '유산소 완료! 수고했어요 🏃',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: green,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
