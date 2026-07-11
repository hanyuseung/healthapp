import 'dart:math';

import 'package:flutter/cupertino.dart';

import 'models.dart';
import 'storage.dart';
import 'widgets.dart';

/// 운동별 기록 목록: 이름을 선택하면 성장 그래프로 이동.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('성장 그래프'),
        previousPageTitle: '홈',
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: WorkoutStore.instance,
          builder: (context, _) {
            // 운동 이름별로 (날짜, 운동) 기록을 모은다.
            final anaerobic = <String, List<(DateTime, Exercise)>>{};
            final cardio = <String, List<(DateTime, Exercise)>>{};
            WorkoutStore.instance.allByDate().forEach((date, list) {
              for (final e in list) {
                final map =
                    e.type == ExerciseType.anaerobic ? anaerobic : cardio;
                map.putIfAbsent(e.name, () => []).add((date, e));
              }
            });
            if (anaerobic.isEmpty && cardio.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.chart_bar_square,
                      size: 56,
                      color:
                          CupertinoColors.tertiaryLabel.resolveFrom(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '기록된 운동이 없어요',
                      style: TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (anaerobic.isNotEmpty) ...[
                  const SectionHeader('무산소'),
                  GroupCard(
                    children: [
                      for (final name in anaerobic.keys.toList()..sort())
                        _row(context, name, ExerciseType.anaerobic,
                            anaerobic[name]!),
                    ],
                  ),
                ],
                if (cardio.isNotEmpty) ...[
                  const SectionHeader('유산소'),
                  GroupCard(
                    children: [
                      for (final name in cardio.keys.toList()..sort())
                        _row(context, name, ExerciseType.cardio,
                            cardio[name]!),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String name, ExerciseType type,
      List<(DateTime, Exercise)> entries) {
    final days = entries.map((e) => e.$1).toSet().length;
    final isCardio = type == ExerciseType.cardio;
    final tint = isCardio
        ? CupertinoColors.systemRed.resolveFrom(context)
        : CupertinoColors.activeBlue.resolveFrom(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) =>
              ExerciseChartScreen(name: name, type: type, entries: entries),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                isCardio
                    ? CupertinoIcons.heart_fill
                    : CupertinoIcons.bolt_fill,
                size: 20,
                color: tint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '기록 $days일',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
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

enum _Metric { maxWeight, volume, reps, duration }

class ExerciseChartScreen extends StatefulWidget {
  const ExerciseChartScreen(
      {super.key, required this.name, required this.type, required this.entries});

  final String name;
  final ExerciseType type;
  final List<(DateTime, Exercise)> entries;

  @override
  State<ExerciseChartScreen> createState() => _ExerciseChartScreenState();
}

class _ExerciseChartScreenState extends State<ExerciseChartScreen> {
  late _Metric _metric =
      widget.type == ExerciseType.cardio ? _Metric.duration : _Metric.maxWeight;

  /// 날짜별 지표 값 (같은 날 같은 운동이 여러 개면 합산/최대).
  List<(DateTime, double)> get _points {
    final byDate = <DateTime, double>{};
    for (final (date, e) in widget.entries) {
      final v = switch (_metric) {
        _Metric.maxWeight => e.maxWeight,
        _Metric.volume => e.totalVolume,
        _Metric.reps => e.totalReps.toDouble(),
        _Metric.duration => e.durationMinutes.toDouble(),
      };
      if (_metric == _Metric.maxWeight) {
        byDate[date] = max(byDate[date] ?? 0, v);
      } else {
        byDate[date] = (byDate[date] ?? 0) + v;
      }
    }
    final list = byDate.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    return list;
  }

  String get _unit => switch (_metric) {
        _Metric.maxWeight => 'kg',
        _Metric.volume => 'kg',
        _Metric.reps => '회',
        _Metric.duration => '분',
      };

  String _fmtValue(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final isCardio = widget.type == ExerciseType.cardio;
    final tint = isCardio
        ? CupertinoColors.systemRed.resolveFrom(context)
        : CupertinoColors.activeBlue.resolveFrom(context);
    final points = _points;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.name),
        previousPageTitle: '그래프',
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (!isCardio)
              CupertinoSlidingSegmentedControl<_Metric>(
                groupValue: _metric,
                onValueChanged: (v) {
                  if (v != null) setState(() => _metric = v);
                },
                children: const {
                  _Metric.maxWeight: Text('최대 무게'),
                  _Metric.volume: Text('총 볼륨'),
                  _Metric.reps: Text('총 횟수'),
                },
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: points.isEmpty || points.every((p) => p.$2 == 0)
                  ? SizedBox(
                      height: 160,
                      child: Center(
                        child: Text(
                          _metric == _Metric.maxWeight ||
                                  _metric == _Metric.volume
                              ? '무게 기록이 없어요.\n운동 편집에서 세트별 무게를 설정해 보세요.'
                              : '기록이 없어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 220,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _LineChartPainter(
                          points: points,
                          color: tint,
                          labelColor: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                          gridColor:
                              CupertinoColors.separator.resolveFrom(context),
                          unit: _unit,
                        ),
                      ),
                    ),
            ),
            if (points.length == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(
                  '기록이 2일 이상 쌓이면 변화 추이를 볼 수 있어요.',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            const SectionHeader('기록'),
            GroupCard(
              children: [
                for (var i = points.length - 1; i >= 0; i--)
                  _recordRow(context, points, i),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordRow(
      BuildContext context, List<(DateTime, double)> points, int i) {
    final (date, value) = points[i];
    final prev = i > 0 ? points[i - 1].$2 : null;
    final diff = prev == null ? null : value - prev;
    final green = CupertinoColors.systemGreen.resolveFrom(context);
    final red = CupertinoColors.systemRed.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            '${date.year}. ${date.month}. ${date.day}. (${weekdayKo(date)})',
            style: const TextStyle(fontSize: 15),
          ),
          const Spacer(),
          if (diff != null && diff != 0) ...[
            Icon(
              diff > 0 ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
              size: 13,
              color: diff > 0 ? green : red,
            ),
            Text(
              _fmtValue(diff.abs()),
              style: TextStyle(
                fontSize: 13,
                color: diff > 0 ? green : red,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '${_fmtValue(value)}$_unit',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.color,
    required this.labelColor,
    required this.gridColor,
    required this.unit,
  });

  final List<(DateTime, double)> points;
  final Color color;
  final Color labelColor;
  final Color gridColor;
  final String unit;

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 40.0;
    const rightPad = 12.0;
    const topPad = 18.0;
    const bottomPad = 26.0;
    final plotW = size.width - leftPad - rightPad;
    final plotH = size.height - topPad - bottomPad;

    final values = points.map((p) => p.$2).toList();
    var minV = values.reduce(min);
    var maxV = values.reduce(max);
    if (minV == maxV) {
      minV -= 1;
      maxV += 1;
    } else {
      final pad = (maxV - minV) * 0.15;
      minV = max(0, minV - pad);
      maxV += pad;
    }

    Offset pos(int i) {
      final x = points.length == 1
          ? leftPad + plotW / 2
          : leftPad + plotW * i / (points.length - 1);
      final y = topPad + plotH * (1 - (points[i].$2 - minV) / (maxV - minV));
      return Offset(x, y);
    }

    // 가로 그리드 3줄 + y축 라벨
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (var g = 0; g <= 2; g++) {
      final y = topPad + plotH * g / 2;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y),
          gridPaint);
      final labelValue = maxV - (maxV - minV) * g / 2;
      _drawText(canvas, _fmt(labelValue), Offset(0, y - 6),
          maxWidth: leftPad - 6, align: TextAlign.right, size: 10);
    }

    // 선 아래 그라데이션
    if (points.length > 1) {
      final fillPath = Path()..moveTo(pos(0).dx, topPad + plotH);
      for (var i = 0; i < points.length; i++) {
        fillPath.lineTo(pos(i).dx, pos(i).dy);
      }
      fillPath.lineTo(pos(points.length - 1).dx, topPad + plotH);
      fillPath.close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
        ).createShader(
            Rect.fromLTWH(leftPad, topPad, plotW, plotH));
      canvas.drawPath(fillPath, fillPaint);

      final linePath = Path()..moveTo(pos(0).dx, pos(0).dy);
      for (var i = 1; i < points.length; i++) {
        linePath.lineTo(pos(i).dx, pos(i).dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 점 + 값 라벨 (점이 적을 때만 값 표시)
    final dotPaint = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      final p = pos(i);
      canvas.drawCircle(p, 4, dotPaint);
      if (points.length <= 8) {
        _drawText(canvas, _fmt(points[i].$2), Offset(p.dx - 20, p.dy - 18),
            maxWidth: 40, align: TextAlign.center, size: 10, bold: true);
      }
    }

    // x축 날짜 라벨 (최대 4개)
    final labelCount = min(4, points.length);
    for (var l = 0; l < labelCount; l++) {
      final i = labelCount == 1
          ? 0
          : ((points.length - 1) * l / (labelCount - 1)).round();
      final p = pos(i);
      final d = points[i].$1;
      _drawText(canvas, '${d.month}/${d.day}',
          Offset(p.dx - 20, topPad + plotH + 8),
          maxWidth: 40, align: TextAlign.center, size: 10);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset,
      {required double maxWidth,
      TextAlign align = TextAlign.left,
      double size = 10,
      bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: labelColor,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(minWidth: maxWidth, maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.unit != unit;
}
