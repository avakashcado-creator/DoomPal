import 'package:flutter/material.dart';

import 'history_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

void main() => runApp(const DoomPalApp());

class DoomPalApp extends StatelessWidget {
  const DoomPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoomPal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
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
    return Scaffold(
      body: SafeArea(child: page),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'History'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Limits'),
        ],
      ),
    );
  }
}
