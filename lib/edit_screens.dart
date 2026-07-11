import 'package:flutter/cupertino.dart';

import 'models.dart';
import 'storage.dart';
import 'widgets.dart';

/// 무산소(웨이트) 운동 추가/편집 화면.
class AnaerobicEditScreen extends StatefulWidget {
  const AnaerobicEditScreen({super.key, required this.date, this.exercise});

  final DateTime date;
  final Exercise? exercise; // null이면 새로 추가

  @override
  State<AnaerobicEditScreen> createState() => _AnaerobicEditScreenState();
}

class _AnaerobicEditScreenState extends State<AnaerobicEditScreen> {
  late final TextEditingController _nameController;
  late List<ExerciseSet> _sets;

  @override
  void initState() {
    super.initState();
    final ex = widget.exercise;
    _nameController = TextEditingController(text: ex?.name ?? '');
    _nameController.addListener(() => setState(() {}));
    _sets = ex != null
        ? ex.sets.map((s) => s.copy()).toList()
        : List.generate(3, (_) => ExerciseSet(reps: 10, restSeconds: 90));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final ex = widget.exercise;
    if (ex == null) {
      WorkoutStore.instance.add(
        widget.date,
        Exercise(
          id: newId(),
          type: ExerciseType.anaerobic,
          name: name,
          sets: _sets,
        ),
      );
    } else {
      ex.name = name;
      ex.sets = _sets;
      WorkoutStore.instance.update();
    }
    Navigator.of(context).pop();
  }

  void _changeSetCount(int delta) {
    setState(() {
      if (delta > 0 && _sets.length < 20) {
        final last = _sets.isNotEmpty
            ? _sets.last
            : ExerciseSet(reps: 10, restSeconds: 90);
        _sets.add(ExerciseSet(reps: last.reps, restSeconds: last.restSeconds));
      } else if (delta < 0 && _sets.length > 1) {
        _sets.removeLast();
      }
    });
  }

  Future<void> _pickWeight(int index) async {
    const step = 2.5;
    const maxKg = 300.0;
    var selectedIndex =
        (_sets[index].weightKg / step).round().clamp(0, maxKg ~/ step);
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(ctx, 'all'),
                      child: const Text('모든 세트에 적용'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      onPressed: () => Navigator.pop(ctx, 'one'),
                      child: const Text('완료',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Text(
                '세트 ${index + 1} 무게',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(
                      initialItem: selectedIndex),
                  onSelectedItemChanged: (i) => selectedIndex = i,
                  children: [
                    for (var i = 0; i <= maxKg ~/ step; i++)
                      Center(
                        child: Text(i == 0 ? '없음 (맨몸)' : fmtWeight(i * step)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    final kg = selectedIndex * step;
    setState(() {
      if (result == 'all') {
        for (final s in _sets) {
          s.weightKg = kg;
        }
      } else {
        _sets[index].weightKg = kg;
      }
    });
  }

  Future<void> _pickRest(int index) async {
    var picked = Duration(seconds: _sets[index].restSeconds);
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(ctx, 'all'),
                      child: const Text('모든 세트에 적용'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      onPressed: () => Navigator.pop(ctx, 'one'),
                      child: const Text('완료',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Text(
                '세트 ${index + 1} 휴식 시간',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
                ),
              ),
              Expanded(
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.ms,
                  initialTimerDuration: picked,
                  onTimerDurationChanged: (d) => picked = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      if (result == 'all') {
        for (final s in _sets) {
          s.restSeconds = picked.inSeconds;
        }
      } else {
        _sets[index].restSeconds = picked.inSeconds;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.exercise == null ? '무산소 운동 추가' : '무산소 운동 편집'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _canSave ? _save : null,
          child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const SectionHeader('운동 이름'),
            CupertinoTextField(
              controller: _nameController,
              placeholder: '예: 벤치프레스, 스쿼트',
              padding: const EdgeInsets.all(14),
              clearButtonMode: OverlayVisibilityMode.editing,
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SectionHeader('세트 수'),
            GroupCard(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text('세트', style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      StepButton(
                        icon: CupertinoIcons.minus_circle,
                        onPressed:
                            _sets.length > 1 ? () => _changeSetCount(-1) : null,
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          '${_sets.length}세트',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      StepButton(
                        icon: CupertinoIcons.plus_circle,
                        onPressed:
                            _sets.length < 20 ? () => _changeSetCount(1) : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SectionHeader('세트별 반복 · 무게 · 휴식 타이머'),
            GroupCard(
              children: [
                for (var i = 0; i < _sets.length; i++) _setRow(context, i),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                '휴식 시간을 0초로 두면 해당 세트 후 휴식 타이머 없이 진행됩니다.',
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

  Widget _setRow(BuildContext context, int i) {
    final set = _sets[i];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
      child: Row(
        children: [
          Text('세트 ${i + 1}',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const Spacer(),
          StepButton(
            icon: CupertinoIcons.minus_circle,
            onPressed: set.reps > 1 ? () => setState(() => set.reps--) : null,
          ),
          SizedBox(
            width: 42,
            child: Text(
              '${set.reps}회',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          StepButton(
            icon: CupertinoIcons.plus_circle,
            onPressed: set.reps < 999 ? () => setState(() => set.reps++) : null,
          ),
          const SizedBox(width: 6),
          _pillButton(
            context,
            icon: CupertinoIcons.square_stack_3d_up,
            label: set.weightKg > 0 ? fmtWeight(set.weightKg) : '무게',
            dimmed: set.weightKg <= 0,
            onTap: () => _pickWeight(i),
          ),
          const SizedBox(width: 6),
          _pillButton(
            context,
            icon: CupertinoIcons.timer,
            label: fmtClock(set.restSeconds),
            onTap: () => _pickRest(i),
          ),
        ],
      ),
    );
  }

  Widget _pillButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool dimmed = false}) {
    final color = dimmed
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : CupertinoColors.activeBlue.resolveFrom(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.systemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 유산소 운동 추가/편집 화면.
class CardioEditScreen extends StatefulWidget {
  const CardioEditScreen({super.key, required this.date, this.exercise});

  final DateTime date;
  final Exercise? exercise;

  @override
  State<CardioEditScreen> createState() => _CardioEditScreenState();
}

class _CardioEditScreenState extends State<CardioEditScreen> {
  late final TextEditingController _nameController;
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    final ex = widget.exercise;
    _nameController = TextEditingController(text: ex?.name ?? '');
    _nameController.addListener(() => setState(() {}));
    _duration = Duration(minutes: ex?.durationMinutes ?? 30);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _duration.inMinutes >= 1;

  void _save() {
    final name = _nameController.text.trim();
    if (!_canSave) return;
    final ex = widget.exercise;
    if (ex == null) {
      WorkoutStore.instance.add(
        widget.date,
        Exercise(
          id: newId(),
          type: ExerciseType.cardio,
          name: name,
          durationMinutes: _duration.inMinutes,
        ),
      );
    } else {
      ex.name = name;
      ex.durationMinutes = _duration.inMinutes;
      WorkoutStore.instance.update();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.exercise == null ? '유산소 운동 추가' : '유산소 운동 편집'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _canSave ? _save : null,
          child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const SectionHeader('운동 이름'),
            CupertinoTextField(
              controller: _nameController,
              placeholder: '예: 러닝, 사이클, 걷기',
              padding: const EdgeInsets.all(14),
              clearButtonMode: OverlayVisibilityMode.editing,
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SectionHeader('지속 시간'),
            GroupCard(
              children: [
                SizedBox(
                  height: 200,
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: _duration,
                    onTimerDurationChanged: (d) =>
                        setState(() => _duration = d),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                _duration.inMinutes >= 1
                    ? '목표: ${fmtMinutesKo(_duration.inMinutes)}'
                    : '1분 이상으로 설정해 주세요.',
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
}
