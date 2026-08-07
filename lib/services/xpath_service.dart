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
    // Support both {kw} (old format) and @keyword (Kazumi format)
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
    final elements = document.xpath(rule.searchListXPath);

    for (final element in elements) {
      try {
        final title = element.xpath(rule.titleXPath).stringValue;
        if (title.trim().isEmpty) continue;

        String cover = '';
        if (rule.coverXPath.isNotEmpty) {
          cover = element.xpath(rule.coverXPath).stringValue;
          if (cover.isEmpty) {
            final imgNode = element.xpath(rule.coverXPath).nodes.firstOrNull;
            if (imgNode != null) {
              cover = imgNode.toAttribute('src') ?? '';
            }
          }
        }

        String detailUrl = '';
        if (rule.detailLinkXPath.isNotEmpty) {
          final hrefNode = element.xpath(rule.detailLinkXPath).nodes.firstOrNull;
          if (hrefNode != null) {
            detailUrl = hrefNode.toAttribute('href') ?? '';
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
          year = element.xpath(rule.yearXPath).stringValue;
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
      title = document.xpath(rule.titleXPath).stringValue;
    } catch (_) {}

    String cover = '';
    if (rule.coverXPath.isNotEmpty) {
      try {
        final coverNode = document.xpath(rule.coverXPath).nodes.firstOrNull;
        if (coverNode != null) {
          cover = coverNode.toAttribute('src') ?? '';
        }
      } catch (_) {}
    }

    String description = '';
    if (rule.descriptionXPath.isNotEmpty) {
      try {
        description = document.xpath(rule.descriptionXPath).stringValue;
      } catch (_) {}
    }

    String actors = '';
    if (rule.actorXPath.isNotEmpty) {
      try {
        actors = document.xpath(rule.actorXPath).stringValue;
      } catch (_) {}
    }

    String year = '';
    if (rule.yearXPath.isNotEmpty) {
      try {
        year = document.xpath(rule.yearXPath).stringValue;
      } catch (_) {}
    }

    final playSources = <PlaySource>[];
    if (rule.playSourceListXPath.isNotEmpty) {
      try {
        final sourceElements = document.xpath(rule.playSourceListXPath);
        for (final sourceElement in sourceElements) {
          final linkNodes = sourceElement.xpath(rule.playUrlXPath);
          for (final linkNode in linkNodes) {
            final href = linkNode.toAttribute('href') ?? '';
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