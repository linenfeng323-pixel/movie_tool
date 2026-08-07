import 'package:flutter/material.dart';
import 'package:movie_tool/models/rule.dart';
import 'package:movie_tool/models/movie.dart';
import 'package:movie_tool/services/xpath_service.dart';
import 'package:movie_tool/services/storage_service.dart';
import 'package:movie_tool/pages/player_page.dart';

class DetailPage extends StatefulWidget {
  final MovieRule rule;
  final MovieItem movieItem;

  const DetailPage({
    super.key,
    required this.rule,
    required this.movieItem,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _xpathService = XPathService();
  final _storage = StorageService();
  MovieDetail? _detail;
  bool _isLoading = true;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = _storage.isFavorite(widget.movieItem.detailUrl);
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await _xpathService.getMovieDetail(
        widget.rule,
        widget.movieItem.detailUrl,
      );
      if (mounted) {
        setState(() {
          _detail = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载详情失败: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleFavorite() {
    _storage.toggleFavorite(HistoryItem(
      title: _detail?.title ?? widget.movieItem.title,
      cover: _detail?.cover ?? widget.movieItem.cover,
      url: widget.movieItem.detailUrl,
      ruleName: widget.rule.name,
    ));
    setState(() => _isFavorite = !_isFavorite);
  }

  void _play(PlaySource source) {
    _storage.addHistory(HistoryItem(
      title: _detail?.title ?? widget.movieItem.title,
      cover: _detail?.cover ?? widget.movieItem.cover,
      url: widget.movieItem.detailUrl,
      ruleName: widget.rule.name,
    ));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          title: _detail?.title ?? widget.movieItem.title,
          url: source.url,
          referer: source.referer.isNotEmpty ? source.referer : widget.rule.referer,
          headers: widget.rule.customHeaders,
          useWebview: widget.rule.useWebview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _detail?.title ?? widget.movieItem.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
            color: _isFavorite ? Colors.red : null,
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('暂无数据', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover and basic info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 140,
                              height: 200,
                              child: _detail!.cover.isNotEmpty
                                  ? Image.network(
                                      _detail!.cover,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.movie, size: 40),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.movie, size: 40),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _detail!.title,
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (_detail!.year.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('年份: ${_detail!.year}',
                                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                                ],
                                if (_detail!.rating.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('评分: ${_detail!.rating}',
                                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange)),
                                ],
                                const SizedBox(height: 8),
                                if (_detail!.actors.isNotEmpty)
                                  Text(
                                    '演员: ${_detail!.actors}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Description
                      if (_detail!.description.isNotEmpty) ...[
                        Text('剧情简介', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          _detail!.description,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Play Sources
                      Text('播放线路', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_detail!.playSources.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('暂无播放源', style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _detail!.playSources.map((source) {
                            return ActionChip(
                              label: Text(source.name),
                              onPressed: () => _play(source),
                              avatar: const Icon(Icons.play_arrow, size: 18),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
    );
  }
}