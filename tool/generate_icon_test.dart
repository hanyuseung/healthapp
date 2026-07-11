// 앱 아이콘 PNG 생성 스크립트.
// 실행: flutter test tool/generate_icon_test.dart
// 생성 후 `dart run flutter_launcher_icons` 로 각 플랫폼에 적용한다.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('앱 아이콘 PNG 생성', (tester) async {
    await tester.runAsync(() async {
      Directory('assets/icon').createSync(recursive: true);
      // 메인 아이콘: 파란 그라데이션 배경 + 흰 덤벨
      await _writeIcon('assets/icon/app_icon.png',
          withBackground: true, glyphScale: 0.95);
      // Android 적응형 아이콘 전경: 투명 배경 + 흰 덤벨(안전 영역에 맞게 축소)
      await _writeIcon('assets/icon/app_icon_foreground.png',
          withBackground: false, glyphScale: 0.62);
      expect(File('assets/icon/app_icon.png').existsSync(), isTrue);
      expect(File('assets/icon/app_icon_foreground.png').existsSync(), isTrue);
    });
  });
}

Future<void> _writeIcon(String path,
    {required bool withBackground, required double glyphScale}) async {
  const size = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas =
      Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

  if (withBackground) {
    final bg = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(size, size),
        const [Color(0xFF55A7FF), Color(0xFF2451D6)],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), bg);
    // 좌상단 은은한 하이라이트
    canvas.drawCircle(
      const Offset(size * 0.22, size * 0.16),
      size * 0.6,
      Paint()..color = const Color(0x14FFFFFF),
    );
  }

  canvas.translate(size / 2, size / 2);
  canvas.rotate(-pi / 4);
  canvas.scale(glyphScale);

  // 그림자 → 본체 순서로 덤벨을 그린다.
  canvas.save();
  canvas.translate(0, 14);
  _drawDumbbell(canvas, const Color(0x26000000));
  canvas.restore();
  _drawDumbbell(canvas, Colors.white);

  final image =
      await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void _drawDumbbell(Canvas canvas, Color color) {
  final paint = Paint()
    ..color = color
    ..isAntiAlias = true;
  void plate(double cx, double w, double h, double r) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, 0), width: w, height: h),
        Radius.circular(r),
      ),
      paint,
    );
  }

  plate(0, 560, 72, 36); // 바
  plate(-185, 92, 336, 42); // 안쪽 원판
  plate(185, 92, 336, 42);
  plate(-292, 76, 232, 38); // 바깥 원판
  plate(292, 76, 232, 38);
}
