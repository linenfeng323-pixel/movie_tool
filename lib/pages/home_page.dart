import 'package:flutter/material.dart';
import 'package:movie_tool/pages/search_page.dart';
import 'package:movie_tool/pages/history_page.dart';
import 'package:movie_tool/pages/favorites_page.dart';
import 'package:movie_tool/pages/rules_page.dart';
import 'package:movie_tool/pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const SearchPage(),
    const HistoryPage(),
    const FavoritesPage(),
    const RulesPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
          NavigationDestination(icon: Icon(Icons.history), label: '历史'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: '收藏'),
          NavigationDestination(icon: Icon(Icons.rule), label: '规则'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}