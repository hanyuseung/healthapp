import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage.dart';
import 'widgets.dart';

/// 앱 설정: 진동/알림음/한 주 시작 요일.
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  bool vibration = true;
  bool sound = true;
  int weekStartDay = DateTime.monday; // DateTime.monday(1) 또는 DateTime.sunday(7)

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    vibration = prefs.getBool('settings_vibration') ?? true;
    sound = prefs.getBool('settings_sound') ?? true;
    weekStartDay = prefs.getInt('settings_week_start') ?? DateTime.monday;
    if (weekStartDay != DateTime.monday && weekStartDay != DateTime.sunday) {
      weekStartDay = DateTime.monday;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_vibration', vibration);
    await prefs.setBool('settings_sound', sound);
    await prefs.setInt('settings_week_start', weekStartDay);
  }

  void setVibration(bool value) {
    vibration = value;
    _save();
    notifyListeners();
  }

  void setSound(bool value) {
    sound = value;
    _save();
    notifyListeners();
  }

  void setWeekStartDay(int value) {
    weekStartDay = value;
    _save();
    notifyListeners();
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _confirmClearAll() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('모든 데이터 삭제'),
        content: const Text('모든 날짜의 운동 계획과 기록이 삭제됩니다.\n되돌릴 수 없습니다.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      WorkoutStore.instance.clearAll();
      showHud(context, '모든 데이터를 삭제했어요');
    }
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('설정'),
        previousPageTitle: '홈',
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const SectionHeader('타이머 알림'),
            GroupCard(
              children: [
                _switchRow('진동', s.vibration,
                    (v) => setState(() => s.setVibration(v))),
                _switchRow('알림음', s.sound,
                    (v) => setState(() => s.setSound(v))),
              ],
            ),
            const SectionHeader('캘린더'),
            GroupCard(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Text('한 주의 시작', style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      CupertinoSlidingSegmentedControl<int>(
                        groupValue: s.weekStartDay,
                        onValueChanged: (v) {
                          if (v != null) {
                            setState(() => s.setWeekStartDay(v));
                          }
                        },
                        children: const {
                          DateTime.sunday: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('일요일', style: TextStyle(fontSize: 14)),
                          ),
                          DateTime.monday: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('월요일', style: TextStyle(fontSize: 14)),
                          ),
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SectionHeader('데이터'),
            GroupCard(
              children: [
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  onPressed: _confirmClearAll,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '모든 데이터 삭제',
                      style: TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.systemRed.resolveFrom(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '운동 플래너 1.0.0',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
