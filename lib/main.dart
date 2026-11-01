import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'history_page.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'theme.dart';

void main() => runApp(const DoomPalApp());

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

  static const _tabs = ['Today', 'History', 'Limits'];

  @override
  Widget build(BuildContext context) {
    final Widget page;
    if (_index == 0) {
      page = const HomePage();
    } else if (_index == 1) {
      page = const HistoryPage();
    } else {
      page = const SettingsPage();
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Palette.moss,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: SafeArea(bottom: false, child: page),
        bottomNavigationBar: _NavBar(
          tabs: _tabs,
          index: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

/// Three words and a small pollen dot over the one you're on.
class _NavBar extends StatelessWidget {
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onTap;
  const _NavBar({required this.tabs, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Palette.moss,
        border: Border(top: BorderSide(color: Palette.vein)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    child: InkWell(
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: i == index ? 5 : 0,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Palette.pollen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tabs[i],
                            style: Txt.label.copyWith(
                              color: i == index ? Palette.lichen : Palette.sage,
                              fontWeight: i == index
                                  ? FontWeight.w600
                                  : FontWeight.w500,
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
    );
  }
}
