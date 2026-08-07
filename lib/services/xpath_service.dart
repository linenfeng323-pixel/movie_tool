import 'package:html/parser.dart' as html_parser;
import 'package:xpath_selector/xpath_selector.dart';
import 'package:movie_tool/models/movie.dart';
import 'package:movie_tool/models/rule.dart';
import 'package:movie_tool/services/http_service.dart';

class XPathService {
  static final XPathService _instance = XPathService._internal();
  factory XPathService() => _instance;
  XPathService._internal();

  final HttpService _http = HttpService();

  Future<List<MovieItem>> searchMovies(MovieRule rule, String keyword) async {
    String url = rule.searchUrl;
    final encoded = Uri.encodeComponent(keyword);
    if (url.contains('@keyword')) {
      url = url.replaceAll('@keyword', encoded);
    } else {
      url = url.replaceAll('{kw}', encoded);
    }
    final html = await _http.get(url, referer: rule.referer);
    return _parseSearchResults(html, rule);
  }

  List<MovieItem> _parseSearchResults(String html, MovieRule rule) {
    final items = <MovieItem>[];
    final document = html_parser.parse(html);
    final xp = XPath(rule.searchListXPath);
    final elements = xp.select(document);

    for (final node in elements) {
      try {
        String title = '';
        if (rule.titleXPath.isNotEmpty) {
          final titleXp = XPath(rule.titleXPath);
          title = titleXp.select(node).stringValue;
        }
        if (title.trim().isEmpty) continue;

        String cover = '';
        if (rule.coverXPath.isNotEmpty) {
          final coverXp = XPath(rule.coverXPath);
          cover = coverXp.select(node).stringValue;
          if (cover.isEmpty) {
            final imgNodes = coverXp.select(node).nodes;
            if (imgNodes.isNotEmpty) {
              cover = imgNodes.first.getAttribute('src') ?? '';
            }
          }
        }

        String detailUrl = '';
        if (rule.detailLinkXPath.isNotEmpty) {
          final linkXp = XPath(rule.detailLinkXPath);
          final hrefNodes = linkXp.select(node).nodes;
          if (hrefNodes.isNotEmpty) {
            detailUrl = hrefNodes.first.getAttribute('href') ?? '';
            if (detailUrl.isNotEmpty && !detailUrl.startsWith('http')) {
              final base = rule.baseUrl.replaceAll(RegExp(r'/+$'), '');
              detailUrl = detailUrl.startsWith('/') ? '$base$detailUrl' : '$base/$detailUrl';
            }
          }
        } else {
          detailUrl = rule.baseUrl;
        }

        String year = '';
        if (rule.yearXPath.isNotEmpty) {
          final yearXp = XPath(rule.yearXPath);
          year = yearXp.select(node).stringValue;
        }

        items.add(MovieItem(
          title: title.trim(),
          cover: cover.trim(),
          detailUrl: detailUrl.trim(),
          year: year.trim(),
          ruleName: rule.name,
        ));
      } catch (e) {
        continue;
      }
    }
    return items;
  }

  Future<MovieDetail> getMovieDetail(MovieRule rule, String detailUrl) async {
    final html = await _http.get(detailUrl, referer: rule.referer);
    final document = html_parser.parse(html);

    String title = '';
    try {
      if (rule.titleXPath.isNotEmpty) {
        final xp = XPath(rule.titleXPath);
        title = xp.select(document).stringValue;
      }
    } catch (_) {}

    String cover = '';
    if (rule.coverXPath.isNotEmpty) {
      try {
        final xp = XPath(rule.coverXPath);
        final nodes = xp.select(document).nodes;
        if (nodes.isNotEmpty) {
          cover = nodes.first.getAttribute('src') ?? '';
        }
      } catch (_) {}
    }

    String description = '';
    if (rule.descriptionXPath.isNotEmpty) {
      try {
        final xp = XPath(rule.descriptionXPath);
        description = xp.select(document).stringValue;
      } catch (_) {}
    }

    String actors = '';
    if (rule.actorXPath.isNotEmpty) {
      try {
        final xp = XPath(rule.actorXPath);
        actors = xp.select(document).stringValue;
      } catch (_) {}
    }

    String year = '';
    if (rule.yearXPath.isNotEmpty) {
      try {
        final xp = XPath(rule.yearXPath);
        year = xp.select(document).stringValue;
      } catch (_) {}
    }

    final playSources = <PlaySource>[];
    if (rule.playSourceListXPath.isNotEmpty) {
      try {
        final srcXp = XPath(rule.playSourceListXPath);
        final sourceElements = srcXp.select(document);
        for (final sourceNode in sourceElements) {
          final linkXp = XPath(rule.playUrlXPath);
          final linkNodes = linkXp.select(sourceNode).nodes;
          for (final linkNode in linkNodes) {
            final href = linkNode.getAttribute('href') ?? '';
            final text = linkNode.stringValue.trim();
            if (href.isNotEmpty && text.isNotEmpty) {
              String fullUrl = href;
              if (!href.startsWith('http')) {
                final base = rule.baseUrl.replaceAll(RegExp(r'/+$'), '');
                fullUrl = href.startsWith('/') ? '$base$href' : '$base/$href';
              }
              playSources.add(PlaySource(
                name: text,
                url: fullUrl,
                referer: rule.referer.isNotEmpty ? rule.referer : rule.baseUrl,
              ));
            }
          }
        }
      } catch (_) {}
    }

    return MovieDetail(
      title: title.trim(),
      cover: cover,
      year: year.trim(),
      description: description.trim(),
      actors: actors.trim(),
      playSources: playSources,
    );
  }
}