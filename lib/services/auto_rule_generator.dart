import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:movie_tool/models/rule.dart';

/// 自动从电影网站生成规则的智能分析器
class AutoRuleGenerator {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// 从URL自动分析并生成规则
  Future<MovieRule?> generateFromUrl(String url) async {
    try {
      if (!url.startsWith('http')) url = 'https://$url';
      final baseUrl = url.replaceAll(RegExp(r'/+$'), '');

      final response = await _dio.get<String>(url, options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ));
      final html = response.data ?? '';
      if (html.isEmpty) return null;

      final document = html_parser.parse(html);
      final text = document.body?.text ?? '';

      // 提取网站标题作为规则名称
      String name = _extractTitle(document) ?? '未知源';

      // 检测搜索URL模式
      final searchUrl = _detectSearchUrl(html, baseUrl);
      if (searchUrl == null) return null;

      // 检测搜索结果列表
      final searchListXPath = _detectSearchList(html);
      // 检测标题
      final titleXPath = _detectTitle(html);
      // 检测封面
      final coverXPath = _detectCover(html);
      // 检测详情链接
      final detailLinkXPath = _detectDetailLink(html);
      // 检测播放线路
      final playSourceXPath = _detectPlaySource(html);
      // 检测播放地址
      final playUrlXPath = _detectPlayUrl(html);

      return MovieRule(
        name: name,
        baseUrl: baseUrl,
        searchUrl: searchUrl,
        searchListXPath: searchListXPath,
        titleXPath: titleXPath,
        coverXPath: coverXPath,
        detailLinkXPath: detailLinkXPath,
        playSourceListXPath: playSourceXPath,
        playUrlXPath: playUrlXPath,
        referer: baseUrl,
        version: '1.0',
      );
    } catch (e) {
      return null;
    }
  }

  String? _extractTitle(dynamic document) {
    try {
      final title = document.title;
      if (title != null) {
        // 清理标题
        return title
            .replaceAll(RegExp(r'[-_|].*$'), '')
            .trim();
      }
    } catch (_) {}
    return null;
  }

  String? _detectSearchUrl(String html, String baseUrl) {
    // 检测搜索表单 action
    final formPatterns = [
      RegExp(r'<form[^>]*action="([^"]*search[^"]*)"', caseSensitive: false),
      RegExp(r'<form[^>]*action="([^"]*so[^"]*)"', caseSensitive: false),
      RegExp(r'<form[^>]*action="([^"]*)"[^>]*>\s*<input[^>]*name="[^"]*(?:wd|key|search|keyword|q)[^"]*"', caseSensitive: false),
      RegExp(r'<input[^>]*name="(?:wd|key|search|keyword|q)"[^>]*>', caseSensitive: false),
    ];

    // 检测常见搜索URL模式
    if (html.contains('/search') || html.contains('/vodsearch')) {
      if (html.contains('?wd=')) return '$baseUrl/search?wd={kw}';
      if (html.contains('/vodsearch/')) return '$baseUrl/vodsearch/{kw}.html';
      return '$baseUrl/search?wd={kw}';
    }

    // 检测苹果CMS搜索URL
    if (html.contains('/vodsearch/') || html.contains('vodsearch')) {
      // 苹果CMS格式
      return '$baseUrl/vodsearch/-------------.html?wd={kw}';
    }

    // 通用搜索URL
    return '$baseUrl/search?wd={kw}';
  }

  String _detectSearchList(String html) {
    // 检测常见的列表容器
    final patterns = [
      // 苹果CMS列表
      RegExp(r'<div[^>]*class="[^"]*module-items[^"]*"[^>]*>', caseSensitive: false),
      RegExp(r'<div[^>]*class="[^"]*vod-list[^"]*"[^>]*>', caseSensitive: false),
      RegExp(r'<ul[^>]*class="[^"]*vod-list[^"]*"[^>]*>', caseSensitive: false),
      RegExp(r'<ul[^>]*class="[^"]*list[^"]*"[^>]*>', caseSensitive: false),
      RegExp(r'<div[^>]*class="[^"]*search-list[^"]*"[^>]*>', caseSensitive: false),
      RegExp(r'<div[^>]*class="[^"]*result[^"]*"[^>]*>', caseSensitive: false),
    ];

    // 尝试匹配已知电影网站模式
    // 苹果CMS: //div[contains(@class,'module-items')]/div
    // 通用: //ul/li

    // 计数常见的li数量
    final liCount = RegExp(r'<li').allMatches(html).length;
    if (liCount > 5) {
      // 检查是否有ul包裹
      if (html.contains('<ul class="vod-list') || html.contains('<ul class="list')) {
        return '//ul/li';
      }
      // 检查是否有search结果的div
      if (html.contains('class="search-list') || html.contains('class="result')) {
        return '//div[contains(@class,"search-list")]//div[contains(@class,"item")]';
      }
      return '//div[contains(@class,"module-items")]/div';
    }

    return '//div[contains(@class,"module-items")]/div';
  }

  String _detectTitle(String html) {
    // 检测标题元素
    if (html.contains('<h2') || html.contains('<h3')) {
      return '//h2/a';
    }
    if (html.contains('class="title"')) {
      return '//div[contains(@class,"title")]/a';
    }
    if (html.contains('class="name"')) {
      return '//div[contains(@class,"name")]/a';
    }
    return '//a[contains(@class,"title")]';
  }

  String _detectCover(String html) {
    if (html.contains('class="lazyload"') || html.contains('data-original')) {
      return '//img/@data-original';
    }
    if (html.contains('class="cover"') || html.contains('class="thumb"') || html.contains('class="pic"')) {
      return '//img/@src';
    }
    if (html.contains('class="module-item-pic"')) {
      return '//div[contains(@class,"module-item-pic")]/img/@data-src';
    }
    return '//a/img/@src';
  }

  String _detectDetailLink(String html) {
    return '//h2/a';
  }

  String _detectPlaySource(String html) {
    if (html.contains('class="module-tab-items"') || html.contains('class="playlist"')) {
      return '//div[contains(@class,"playlist")]/ul';
    }
    if (html.contains('class="play_source"') || html.contains('id="playlist"')) {
      return '//div[contains(@class,"play_source")]//ul';
    }
    if (html.contains('class="vod-play-list"')) {
      return '//div[contains(@class,"vod-play-list")]//ul';
    }
    return '//div[contains(@class,"playlist")]/ul';
  }

  String _detectPlayUrl(String html) {
    return '//li/a';
  }

  /// 验证规则是否能正常工作
  Future<bool> validateRule(MovieRule rule) async {
    try {
      final testUrl = rule.searchUrl.replaceAll('{kw}', 'test');
      final response = await _dio.get<String>(testUrl, options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': rule.baseUrl,
        },
      ));
      return response.statusCode == 200 && (response.data?.isNotEmpty ?? false);
    } catch (e) {
      return false;
    }
  }
}