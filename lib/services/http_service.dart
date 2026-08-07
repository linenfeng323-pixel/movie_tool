import 'package:dio/dio.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 15),
  ));

  Future<String> get(String url, {Map<String, String>? headers, String? referer}) async {
    final options = Options(headers: _buildHeaders(headers, referer));
    final response = await _dio.get<String>(url, options: options);
    return response.data ?? '';
  }

  Map<String, String> _buildHeaders(Map<String, String>? extraHeaders, String? referer) {
    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    };
    if (referer != null && referer.isNotEmpty) {
      headers['Referer'] = referer;
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<Response<String>> getResponse(String url, {Map<String, String>? headers, String? referer}) async {
    final options = Options(headers: _buildHeaders(headers, referer));
    return await _dio.get<String>(url, options: options);
  }
}