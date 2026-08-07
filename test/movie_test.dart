import 'package:flutter_test/flutter_test.dart';
import 'package:movie_tool/models/rule.dart';
import 'package:movie_tool/models/movie.dart';

void main() {
  group('MovieRule', () {
    test('fromJson and toJson roundtrip', () {
      final rule = MovieRule(
        name: '测试源',
        baseUrl: 'https://example.com/',
        searchUrl: 'https://example.com/search?wd=@keyword',
        searchListXPath: '//div[@class="list"]/li',
        titleXPath: '//h2/a',
        playSourceListXPath: '//div[@class="playlist"]/ul',
        playUrlXPath: '//li/a',
      );

      final json = rule.toJson();
      final restored = MovieRule.fromJson(json);

      expect(restored.name, rule.name);
      expect(restored.baseUrl, rule.baseUrl);
      expect(restored.searchUrl, rule.searchUrl);
    });

    test('fromKazumiJson supports Kazumi format', () {
      final kazumiJson = {
        'name': '测试源',
        'baseURL': 'https://example.com/',
        'searchURL': 'https://example.com/search?wd=@keyword',
        'searchList': '//div[@class="list"]/li',
        'searchName': '//h2/a',
        'searchResult': '//h2/a',
        'chapterRoads': '//div[@class="playlist"]/ul',
        'chapterResult': '//li/a',
      };

      final rule = MovieRule.fromJson(kazumiJson);
      expect(rule.name, '测试源');
      expect(rule.baseUrl, 'https://example.com/');
      expect(rule.searchListXPath, '//div[@class="list"]/li');
      expect(rule.titleXPath, '//h2/a');
    });

    test('base64 encode/decode', () {
      final rule = MovieRule(
        name: '测试源',
        baseUrl: 'https://example.com/',
        searchUrl: 'https://example.com/search?wd=@keyword',
        searchListXPath: '//div/li',
        titleXPath: '//a',
        playSourceListXPath: '//div/ul',
        playUrlXPath: '//li/a',
      );

      final b64 = rule.toBase64();
      final restored = MovieRule.fromBase64(b64);

      expect(restored.name, rule.name);
      expect(restored.baseUrl, rule.baseUrl);
    });
  });

  group('MovieItem', () {
    test('creates movie item correctly', () {
      final item = MovieItem(
        title: '测试电影',
        detailUrl: 'https://example.com/detail/1',
        year: '2024',
      );

      expect(item.title, '测试电影');
      expect(item.detailUrl, 'https://example.com/detail/1');
      expect(item.year, '2024');
    });
  });

  group('PlaySource', () {
    test('creates play source correctly', () {
      final source = PlaySource(
        name: '线路1',
        url: 'https://example.com/play.m3u8',
        referer: 'https://example.com/',
      );

      expect(source.name, '线路1');
      expect(source.url, 'https://example.com/play.m3u8');
    });
  });
}