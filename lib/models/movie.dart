class MovieItem {
  final String title;
  final String cover;
  final String detailUrl;
  final String year;
  final String description;
  final String actors;
  final String ruleName;
  final String rating;

  MovieItem({
    required this.title,
    this.cover = '',
    required this.detailUrl,
    this.year = '',
    this.description = '',
    this.actors = '',
    this.ruleName = '',
    this.rating = '',
  });
}

class PlaySource {
  final String name;
  final String url;
  final String referer;

  PlaySource({
    required this.name,
    required this.url,
    this.referer = '',
  });
}

class MovieDetail {
  final String title;
  final String cover;
  final String year;
  final String description;
  final String actors;
  final String rating;
  final List<PlaySource> playSources;

  MovieDetail({
    required this.title,
    this.cover = '',
    this.year = '',
    this.description = '',
    this.actors = '',
    this.rating = '',
    this.playSources = const [],
  });
}

class HistoryItem {
  final String title;
  final String cover;
  final String url;
  final String ruleName;
  final DateTime watchTime;
  final String progress;

  HistoryItem({
    required this.title,
    this.cover = '',
    required this.url,
    this.ruleName = '',
    DateTime? watchTime,
    this.progress = '',
  }) : watchTime = watchTime ?? DateTime.now();
}