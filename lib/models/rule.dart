import 'dart:convert';

class MovieRule {
  String name;
  String baseUrl;
  String searchUrl;
  String searchListXPath;
  String titleXPath;
  String coverXPath;
  String detailLinkXPath;
  String yearXPath;
  String descriptionXPath;
  String actorXPath;
  String playSourceListXPath;
  String playUrlXPath;
  Map<String, String> customHeaders;
  String danmakuUrl;
  String version;
  String referer;
  bool useWebview;
  bool useNativePlayer;

  MovieRule({
    required this.name,
    required this.baseUrl,
    required this.searchUrl,
    required this.searchListXPath,
    required this.titleXPath,
    this.coverXPath = '',
    this.detailLinkXPath = '',
    this.yearXPath = '',
    this.descriptionXPath = '',
    this.actorXPath = '',
    required this.playSourceListXPath,
    required this.playUrlXPath,
    this.customHeaders = const {},
    this.danmakuUrl = '',
    this.version = '1.0',
    this.referer = '',
    this.useWebview = false,
    this.useNativePlayer = true,
  });

  /// Support Kazumi format (baseURL, searchList, etc.) and our format
  factory MovieRule.fromKazumiJson(Map<String, dynamic> json) {
    return MovieRule(
      name: json['name'] as String? ?? '',
      baseUrl: json['baseURL'] as String? ?? json['baseUrl'] as String? ?? '',
      searchUrl: json['searchURL'] as String? ?? json['searchUrl'] as String? ?? '',
      searchListXPath: json['searchList'] as String? ?? json['searchListXPath'] as String? ?? '',
      titleXPath: json['searchName'] as String? ?? json['titleXPath'] as String? ?? '',
      coverXPath: json['coverXPath'] as String? ?? '',
      detailLinkXPath: json['searchResult'] as String? ?? json['detailLinkXPath'] as String? ?? '',
      yearXPath: json['yearXPath'] as String? ?? '',
      descriptionXPath: json['descriptionXPath'] as String? ?? '',
      actorXPath: json['actorXPath'] as String? ?? '',
      playSourceListXPath: json['chapterRoads'] as String? ?? json['playSourceListXPath'] as String? ?? '',
      playUrlXPath: json['chapterResult'] as String? ?? json['playUrlXPath'] as String? ?? '',
      customHeaders: json['customHeaders'] != null
          ? Map<String, String>.from(json['customHeaders'] as Map)
          : {},
      danmakuUrl: json['danmakuUrl'] as String? ?? '',
      version: json['version'] as String? ?? '1.0',
      referer: json['referer'] as String? ?? '',
      useWebview: json['useWebview'] as bool? ?? false,
      useNativePlayer: json['useNativePlayer'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'baseUrl': baseUrl,
      'searchUrl': searchUrl,
      'searchListXPath': searchListXPath,
      'titleXPath': titleXPath,
      'coverXPath': coverXPath,
      'detailLinkXPath': detailLinkXPath,
      'yearXPath': yearXPath,
      'descriptionXPath': descriptionXPath,
      'actorXPath': actorXPath,
      'playSourceListXPath': playSourceListXPath,
      'playUrlXPath': playUrlXPath,
      'customHeaders': customHeaders,
      'danmakuUrl': danmakuUrl,
      'version': version,
      'referer': referer,
      'useWebview': useWebview,
      'useNativePlayer': useNativePlayer,
    };
  }

  factory MovieRule.fromJson(Map<String, dynamic> json) {
    // Check if it's Kazumi format (has baseURL, searchList, etc.)
    if (json.containsKey('baseURL') || json.containsKey('searchList')) {
      return MovieRule.fromKazumiJson(json);
    }
    return MovieRule(
      name: json['name'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      searchUrl: json['searchUrl'] as String? ?? '',
      searchListXPath: json['searchListXPath'] as String? ?? '',
      titleXPath: json['titleXPath'] as String? ?? '',
      coverXPath: json['coverXPath'] as String? ?? '',
      detailLinkXPath: json['detailLinkXPath'] as String? ?? '',
      yearXPath: json['yearXPath'] as String? ?? '',
      descriptionXPath: json['descriptionXPath'] as String? ?? '',
      actorXPath: json['actorXPath'] as String? ?? '',
      playSourceListXPath: json['playSourceListXPath'] as String? ?? '',
      playUrlXPath: json['playUrlXPath'] as String? ?? '',
      customHeaders: json['customHeaders'] != null
          ? Map<String, String>.from(json['customHeaders'] as Map)
          : {},
      danmakuUrl: json['danmakuUrl'] as String? ?? '',
      version: json['version'] as String? ?? '1.0',
      referer: json['referer'] as String? ?? '',
      useWebview: json['useWebview'] as bool? ?? false,
      useNativePlayer: json['useNativePlayer'] as bool? ?? true,
    );
  }

  String toBase64() {
    final jsonStr = jsonEncode(toJson());
    return base64Encode(utf8.encode(jsonStr));
  }

  factory MovieRule.fromBase64(String base64Str) {
    final bytes = base64Decode(base64Str);
    final jsonStr = utf8.decode(bytes);
    return MovieRule.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
  }
}