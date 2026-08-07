import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import 'package:movie_tool/models/movie.dart';
import 'package:movie_tool/models/rule.dart';
import 'package:movie_tool/services/http_service.dart';

/// XPath-based HTML parsing service for movie data extraction
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
    try {
      final doc = HtmlXPath.html(html);
      final elements = doc.query(rule.searchListXPath);
      for (final element in elements) {
        try {
          final title = element.queryXPath(rule.titleXPath).node?.text?.trim() ?? '';
          if (title.isEmpty) continue;
          String cover = '';
          if (rule.coverXPath.isNotEmpty) {
            cover = element.queryXPath(rule.coverXPath).attr ?? '';
            if (cover.isEmpty) {
              cover = element.queryXPath(rule.coverXPath).nodes.firstOrNull?.getAttribute('src') ?? '';
            }
          }
          String detailUrl = '';
          if (rule.detailLinkXPath.isNotEmpty) {
            final hrefNode = element.queryXPath(rule.detailLinkXPath).nodes.firstOrNull;
            if (hrefNode != null) {
              detailUrl = hrefNode.getAttribute('href') ?? '';
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
            year = element.queryXPath(rule.yearXPath).node?.text?.trim() ?? '';
          }
          items.add(MovieItem(
            title: title.trim(),
            cover: cover.trim(),
            detailUrl: detailUrl.trim(),
            year: year.trim(),
            ruleName: rule.name,
          ));
        } catch (_) {
          continue;
        }
      }
    } catch (_) {}
    return items;
  }

  Future<MovieDetail> getMovieDetail(MovieRule rule, String detailUrl) async {
    final html = await _http.get(detailUrl, referer: rule.referer);
    final doc = HtmlXPath.html(html);

    String title = '';
    try { title = doc.query(rule.titleXPath).node?.text?.trim() ?? ''; } catch (_) {}

    String cover = '';
    if (rule.coverXPath.isNotEmpty) {
      try { cover = doc.query(rule.coverXPath).nodes.firstOrNull?.getAttribute('src') ?? ''; } catch (_) {}
    }

    String description = '';
    if (rule.descriptionXPath.isNotEmpty) {
      try { description = doc.query(rule.descriptionXPath).node?.text?.trim() ?? ''; } catch (_) {}
    }

    String actors = '';
    if (rule.actorXPath.isNotEmpty) {
      try { actors = doc.query(rule.actorXPath).node?.text?.trim() ?? ''; } catch (_) {}
    }

    String year = '';
    if (rule.yearXPath.isNotEmpty) {
      try { year = doc.query(rule.yearXPath).node?.text?.trim() ?? ''; } catch (_) {}
    }

    final playSources = <PlaySource>[];
    if (rule.playSourceListXPath.isNotEmpty) {
      try {
        final sourceElements = doc.query(rule.playSourceListXPath);
        for (final sourceElement in sourceElements) {
          final linkNodes = sourceElement.queryXPath(rule.playUrlXPath);
          for (final linkNode in linkNodes) {
            final href = linkNode.getAttribute('href') ?? '';
            final text = linkNode.text?.trim() ?? '';
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