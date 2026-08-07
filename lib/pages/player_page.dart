import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movie_tool/services/http_service.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class PlayerPage extends StatefulWidget {
  final String title;
  final String url;
  final String referer;
  final Map<String, String> headers;
  final bool useWebview;

  const PlayerPage({
    super.key,
    required this.title,
    required this.url,
    this.referer = '',
    this.headers = const {},
    this.useWebview = false,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  final _httpService = HttpService();
  String? _playableUrl;
  bool _isLoading = true;
  double _playbackSpeed = 1.0;
  bool _isFullScreen = false;
  bool _useWebview = false;
  bool _isPlaying = false;

  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _useWebview = widget.useWebview;
    _resolvePlayUrl();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep playing in background
  }

  Future<void> _resolvePlayUrl() async {
    try {
      final url = widget.url;
      if (url.endsWith('.m3u8') ||
          url.endsWith('.mp4') ||
          url.endsWith('.webm') ||
          url.endsWith('.mkv') ||
          url.endsWith('.flv')) {
        if (mounted) {
          setState(() {
            _playableUrl = url;
            _isLoading = false;
          });
        }
        _initVideoPlayer();
        return;
      }

      final response = await _httpService.getResponse(
        url,
        referer: widget.referer.isNotEmpty ? widget.referer : null,
        headers: widget.headers.isNotEmpty ? widget.headers : null,
      );

      final html = response.data ?? '';

      // Look for iframe src
      final iframeRegex = RegExp(r'<iframe[^>]*src="([^"]+)"');
      final iframeMatch = iframeRegex.firstMatch(html);
      if (iframeMatch != null) {
        String iframeUrl = iframeMatch.group(1)!;
        if (!iframeUrl.startsWith('http')) {
          final uri = Uri.parse(url);
          iframeUrl = '${uri.scheme}://${uri.host}$iframeUrl';
        }
        final iframeResponse = await _httpService.getResponse(iframeUrl,
            referer: widget.referer.isNotEmpty ? widget.referer : url);
        final iframeHtml = iframeResponse.data ?? '';
        final videoUrl = _extractVideoUrl(iframeHtml);
        if (videoUrl != null) {
          if (mounted) {
            setState(() {
              _playableUrl = videoUrl;
              _isLoading = false;
            });
          }
          _initVideoPlayer();
          return;
        }
      }

      // Try direct video URL extraction
      final videoUrl = _extractVideoUrl(html);
      if (videoUrl != null) {
        if (mounted) {
          setState(() {
            _playableUrl = videoUrl;
            _isLoading = false;
          });
        }
        _initVideoPlayer();
        return;
      }

      // Fallback: use webview
      if (mounted) {
        setState(() {
          _playableUrl = url;
          _isLoading = false;
          _useWebview = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _useWebview = true;
          _playableUrl = widget.url;
        });
      }
    }
  }

  Future<void> _initVideoPlayer() async {
    if (_playableUrl == null) return;
    try {
      _videoController?.dispose();
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(_playableUrl!),
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          if (widget.referer.isNotEmpty) 'Referer': widget.referer,
          ...widget.headers,
        },
      );
      await _videoController!.initialize();
      await _videoController!.setPlaybackSpeed(_playbackSpeed);
      await _videoController!.play();
      await WakelockPlus.enable();
      if (mounted) {
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _useWebview = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('视频播放失败，切换到WebView模式: $e')),
        );
      }
    }
  }

  String? _extractVideoUrl(String html) {
    // Use String patterns instead of RegExp with embedded quotes
    final patterns = <Pattern>[
      RegExp(r'data-url="([^"]+)"'),
      RegExp(r'url:\s*["\x27]([^"\x27]+\.(?:m3u8|mp4|webm|flv)[^"\x27]*)["\x27]'),
      RegExp(r'"url"\s*:\s*"([^"]+\.(?:m3u8|mp4|webm|flv)[^"]*)"'),
      RegExp(r'src="([^"]+\.(?:m3u8|mp4|webm|flv)[^"]*)"'),
      RegExp(r'video_url\s*=\s*["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'"link"\s*:\s*"([^"]+)"'),
      RegExp(r'<video[^>]*src="([^"]+)"'),
      RegExp(r'"play_url"\s*:\s*"([^"]+)"'),
      RegExp(r'"videourl"\s*:\s*"([^"]+)"'),
    ];

    for (final pattern in patterns) {
      if (pattern is RegExp) {
        final match = pattern.firstMatch(html);
        if (match != null) {
          String url = match.group(1)!.replaceAll('\\', '');
          try {
            url = url.replaceAllMapped(
                RegExp(r'\\u([0-9a-fA-F]{4})'), (m) {
              return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
            });
          } catch (_) {}
          return url;
        }
      }
    }
    return null;
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
        WakelockPlus.disable();
      } else {
        _videoController!.play();
        _isPlaying = true;
        WakelockPlus.enable();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullScreen
          ? null
          : AppBar(
              title: Text(widget.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'speed') _showSpeedDialog();
                    if (value == 'webview') {
                      setState(() => _useWebview = true);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'speed',
                      child: Text('倍速: ${_playbackSpeed}x'),
                    ),
                    if (!_useWebview)
                      const PopupMenuItem(
                        value: 'webview',
                        child: Text('切换WebView模式'),
                      ),
                  ],
                ),
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _useWebview || _playableUrl == null
              ? _buildWebView()
              : _buildVideoPlayer(),
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载播放器...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _togglePlayPause,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_videoController!),
                if (!_isPlaying)
                  Container(
                    color: Colors.black26,
                    child: const Icon(
                      Icons.play_circle_outline,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: VideoProgressIndicator(
                    _videoController!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.red,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Controls bar
        Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: _togglePlayPause,
              ),
              Expanded(
                child: Text(
                  _formatDuration(_videoController!.value.position),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Text(
                _formatDuration(_videoController!.value.duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 8),
              _ControlButton(
                icon: Icons.speed,
                label: '${_playbackSpeed}x',
                onTap: _showSpeedDialog,
              ),
              _ControlButton(
                icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                label: _isFullScreen ? '退出' : '全屏',
                onTap: () {
                  setState(() => _isFullScreen = !_isFullScreen);
                  if (_isFullScreen) {
                    SystemChrome.setEnabledSystemUIMode(
                        SystemUiMode.immersiveSticky);
                  } else {
                    SystemChrome.setEnabledSystemUIMode(
                        SystemUiMode.edgeToEdge);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebView() {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(_playableUrl ?? widget.url));
      return WebViewWidget(controller: controller);
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('WebView加载失败'),
            const SizedBox(height: 8),
            Text('URL: ${_playableUrl ?? widget.url}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
          ],
        ),
      );
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择倍速'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]
              .map((speed) {
            return RadioListTile<double>(
              title: Text('${speed}x'),
              value: speed,
              groupValue: _playbackSpeed,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _playbackSpeed = value);
                  _videoController?.setPlaybackSpeed(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}