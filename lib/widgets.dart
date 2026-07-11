import 'package:flutter/cupertino.dart';

/// iOS 설정 앱 스타일의 섹션 헤더.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

/// iOS 그룹 리스트 스타일의 둥근 카드. 자식 사이에 구분선을 넣는다.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Container(
      margin: const EdgeInsets.only(left: 16),
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) rows.add(divider);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: rows),
    );
  }
}

/// 진행률 표시용 얇은 막대.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color});

  final double value; // 0.0 ~ 1.0
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? CupertinoColors.activeBlue.resolveFrom(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 6,
        color: CupertinoColors.systemFill.resolveFrom(context),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: fill),
        ),
      ),
    );
  }
}

/// 잠시 표시되고 사라지는 iOS HUD 스타일 알림.
void showHud(BuildContext context, String message) {
  showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (ctx.mounted && Navigator.of(ctx).canPop()) {
          Navigator.of(ctx).pop();
        }
      });
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xE6323232),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: CupertinoColors.white,
              decoration: TextDecoration.none,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    },
  );
}

/// 스테퍼용 +/- 아이콘 버튼.
class StepButton extends StatelessWidget {
  const StepButton({super.key, required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      onPressed: onPressed,
      child: Icon(icon, size: 26),
    );
  }
}
