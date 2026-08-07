import 'package:flutter/material.dart';
import 'package:movie_tool/pages/search_page.dart';
import 'package:movie_tool/pages/history_page.dart';
import 'package:movie_tool/pages/favorites_page.dart';
import 'package:movie_tool/pages/rules_page.dart';
import 'package:movie_tool/pages/settings_page.dart';
import 'package:movie_tool/services/storage_service.dart';
import 'package:movie_tool/services/xpath_service.dart';
import 'package:movie_tool/models/rule.dart';
import 'package:movie_tool/models/movie.dart';
import 'package:movie_tool/pages/detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final _storage = StorageService();
  final _xpathService = XPathService();
  List<MovieItem> _recommendations = [];
  bool _isLoadingRecs = false;

  // 热门关键词
  final List<String> _hotKeywords = [
    '动作', '喜剧', '爱情', '科幻', '动画',
    '悬疑', '恐怖', '战争', '纪录片', '剧情',
    '2024', '2025', '国产', '日韩', '欧美',
    '复仇者联盟', '流浪地球', '哪吒', '封神', '战狼',
    '周星驰', '成龙', '刘德华', '宫崎骏', '诺兰',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoadingRecs = true);
    try {
      final rules = _storage.getRules();
      if (rules.isNotEmpty) {
        final rule = rules.first;
        final results = await _xpathService.searchMovies(rule, '电影');
        if (mounted) {
          setState(() {
            _recommendations = results.take(12).toList();
            _isLoadingRecs = false;
          });
        }
      } else {
        setState(() => _isLoadingRecs = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRecs = false);
    }
  }

  void _searchByKeyword(String keyword) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(initialKeyword: keyword),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_currentIndex != 0) {
      return Scaffold(
        body: _buildPage(_currentIndex),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    return Scaffold(
      body: _buildHomePage(theme),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 1: return const HistoryPage();
      case 2: return const FavoritesPage();
      case 3: return const RulesPage();
      case 4: return const SettingsPage();
      default: return _buildHomePage(Theme.of(context));
    }
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() => _currentIndex = index);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
        NavigationDestination(icon: Icon(Icons.history), label: '历史'),
        NavigationDestination(icon: Icon(Icons.favorite_border), label: '收藏'),
        NavigationDestination(icon: Icon(Icons.rule), label: '规则'),
        NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
      ],
    );
  }

  Widget _buildHomePage(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.movie, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('MovieTool', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索电影',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecommendations,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchPage()),
                    );
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey[850]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey[500]),
                        const SizedBox(width: 12),
                        Text(
                          '搜索电影名称...',
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Hot keywords
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '热门搜索',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _hotKeywords.map((keyword) {
                    return ActionChip(
                      label: Text(keyword, style: const TextStyle(fontSize: 13)),
                      onPressed: () => _searchByKeyword(keyword),
                      backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // Recommendations
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '推荐电影',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _loadRecommendations,
                      child: const Text('刷新'),
                    ),
                  ],
                ),
              ),

              if (_isLoadingRecs)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_recommendations.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.movie_creation_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('暂无推荐', style: TextStyle(color: Colors.grey[500])),
                        const SizedBox(height: 4),
                        Text('请先在"规则"页面添加源', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _recommendations.length,
                    itemBuilder: (context, index) {
                      final item = _recommendations[index];
                      return _RecommendCard(
                        item: item,
                        onTap: () {
                          final rules = _storage.getRules();
                          if (rules.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailPage(
                                  rule: rules.first,
                                  movieItem: item,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),

              const SizedBox(height: 24),

              // Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'MovieTool v1.0 • 点击标签快速搜索',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
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

class _RecommendCard extends StatelessWidget {
  final MovieItem item;
  final VoidCallback onTap;

  const _RecommendCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.grey[200],
                child: item.cover.isNotEmpty
                    ? Image.network(
                        item.cover,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  if (item.year.isNotEmpty)
                    Text(
                      item.year,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(Icons.movie, size: 40, color: Colors.grey),
    );
  }
}