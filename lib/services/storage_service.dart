import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:movie_tool/models/rule.dart';
import 'package:movie_tool/models/movie.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _rulesBox = 'rules';
  static const String _historyBox = 'history';
  static const String _favoritesBox = 'favorites';
  static const String _settingsBox = 'settings';

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    await Hive.openBox(_rulesBox);
    await Hive.openBox(_historyBox);
    await Hive.openBox(_favoritesBox);
    await Hive.openBox(_settingsBox);
  }

  Future<void> loadBuiltInRules() async {
    final box = Hive.box(_rulesBox);
    if (box.isNotEmpty) return;

    try {
      final jsonStr = await rootBundle.loadString('assets/rules/built_in.json');
      final List<dynamic> rulesList = json.decode(jsonStr) as List<dynamic>;
      for (final item in rulesList) {
        box.add(item as Map<String, dynamic>);
      }
    } catch (e) {
      // Silently fail - no built-in rules
    }
  }

  Box get _rules => Hive.box(_rulesBox);
  Box get _history => Hive.box(_historyBox);
  Box get _favorites => Hive.box(_favoritesBox);
  Box get _settings => Hive.box(_settingsBox);

  // Rules
  List<MovieRule> getRules() {
    final list = <MovieRule>[];
    for (final e in _rules.values) {
      if (e is Map) {
        final map = Map<String, dynamic>.from(e);
        list.add(MovieRule.fromJson(map));
      }
    }
    return list;
  }

  void addRule(MovieRule rule) => _rules.add(rule.toJson());

  void deleteRule(int index) => _rules.deleteAt(index);

  void updateRule(int index, MovieRule rule) => _rules.putAt(index, rule.toJson());

  int getRuleCount() => _rules.length;

  // Settings
  bool getSetting(String key, {bool defaultValue = false}) {
    final val = _settings.get(key, defaultValue: defaultValue);
    if (val is bool) return val;
    return defaultValue;
  }

  void setSetting(String key, bool value) => _settings.put(key, value);

  // History
  List<HistoryItem> getHistory() {
    final list = <HistoryItem>[];
    final data = _history.toMap();
    for (final value in data.values) {
      if (value is Map) {
        final m = Map<String, dynamic>.from(value);
        list.add(HistoryItem(
          title: m['title'] ?? '',
          cover: m['cover'] ?? '',
          url: m['url'] ?? '',
          ruleName: m['ruleName'] ?? '',
          watchTime: m['watchTime'] != null
              ? DateTime.fromMillisecondsSinceEpoch((m['watchTime'] as num).toInt())
              : DateTime.now(),
          progress: m['progress'] ?? '',
        ));
      }
    }
    list.sort((a, b) => b.watchTime.compareTo(a.watchTime));
    return list;
  }

  void addHistory(HistoryItem item) {
    _history.put(item.url, {
      'title': item.title,
      'cover': item.cover,
      'url': item.url,
      'ruleName': item.ruleName,
      'watchTime': item.watchTime.millisecondsSinceEpoch,
      'progress': item.progress,
    });
  }

  void clearHistory() => _history.clear();

  // Favorites
  List<HistoryItem> getFavorites() {
    final list = <HistoryItem>[];
    final data = _favorites.toMap();
    for (final value in data.values) {
      if (value is Map) {
        final m = Map<String, dynamic>.from(value);
        list.add(HistoryItem(
          title: m['title'] ?? '',
          cover: m['cover'] ?? '',
          url: m['url'] ?? '',
          ruleName: m['ruleName'] ?? '',
          progress: m['progress'] ?? '',
        ));
      }
    }
    return list;
  }

  bool isFavorite(String url) => _favorites.containsKey(url);

  void toggleFavorite(HistoryItem item) {
    if (_favorites.containsKey(item.url)) {
      _favorites.delete(item.url);
    } else {
      _favorites.put(item.url, {
        'title': item.title,
        'cover': item.cover,
        'url': item.url,
        'ruleName': item.ruleName,
      });
    }
  }
}