import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'doomy_page.dart';
import 'history_page.dart';
import 'home_page.dart';
import 'memes.dart';
import 'settings_page.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MemeBank.load();
  runApp(const DoomPalApp());
}

class DoomPalApp extends StatelessWidget {
  const DoomPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoomPal',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _tabs = [
    (Icons.local_fire_department_outlined, Icons.local_fire_department, 'Today'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Doomy'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Receipts'),
    (Icons.gavel_outlined, Icons.gavel, 'Rules'),
  ];

  @override
  Widget build(BuildContext context) {
    final Widget page = switch (_index) {
      0 => const HomePage(),
      1 => const DoomyPage(),
      2 => const HistoryPage(),
      _ => const SettingsPage(),
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Palette.ink,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: SafeArea(bottom: false, child: page),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Palette.ink,
            border: Border(top: BorderSide(color: Palette.line)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == _index,
                        button: true,
                        label: _tabs[i].$3,
                        child: InkWell(
                          onTap: () => setState(() => _index = i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                i == _index ? _tabs[i].$2 : _tabs[i].$1,
                                color: i == _index ? Palette.white : Palette.muted,
                                size: 24,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _tabs[i].$3,
                                style: Txt.small.copyWith(
                                  fontSize: 11,
                                  color: i == _index ? Palette.white : Palette.muted,
                                  fontWeight: i == _index ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
