import 'package:flutter/material.dart';
import 'package:movie_tool/models/rule.dart';
import 'package:movie_tool/models/movie.dart';
import 'package:movie_tool/services/storage_service.dart';
import 'package:movie_tool/services/xpath_service.dart';
import 'package:movie_tool/pages/detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final _storage = StorageService();
  final _xpathService = XPathService();
  List<MovieItem> _results = [];
  bool _isLoading = false;
  MovieRule? _selectedRule;
  List<MovieRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  void _loadRules() {
    _rules = _storage.getRules();
    if (_rules.isNotEmpty && _selectedRule == null) {
      _selectedRule = _rules.first;
    }
    setState(() {});
  }

  Future<void> _search() async {
    if (_selectedRule == null || _searchController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final results = await _xpathService.searchMovies(
        _selectedRule!,
        _searchController.text.trim(),
      );
      setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MovieTool'),
        actions: [
          if (_rules.isNotEmpty)
            PopupMenuButton<MovieRule>(
              icon: const Icon(Icons.swap_vert),
              tooltip: '选择规则',
              onSelected: (rule) {
                setState(() => _selectedRule = rule);
              },
              itemBuilder: (context) => _rules.map((rule) {
                return PopupMenuMenuItem(
                  value: rule,
                  child: Text(
                    rule.name,
                    style: TextStyle(
                      fontWeight: _selectedRule == rule ? FontWeight.bold : FontWeight.normal,
                      color: _selectedRule == rule ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _selectedRule != null
                          ? '在 ${_selectedRule!.name} 中搜索...'
                          : '请先添加规则',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _results = []);
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _selectedRule != null ? _search : null,
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),
          if (_selectedRule != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Chip(
                avatar: const Icon(Icons.language, size: 18),
                label: Text('当前源: ${_selectedRule!.name}'),
              ),
            ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_results.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.movie_creation_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('搜索电影名称', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    Text(
                      _rules.isEmpty ? '请先在"规则"页面添加规则源' : '输入关键词开始搜索',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final item = _results[index];
                  return _MovieCard(
                    item: item,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailPage(
                            rule: _selectedRule!,
                            movieItem: item,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _MovieCard extends StatelessWidget {
  final MovieItem item;
  final VoidCallback onTap;

  const _MovieCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
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