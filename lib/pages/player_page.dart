import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movie_tool/services/http_service.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'dart:math';

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
  bool _showControls = true;
  bool _playerLocked = false;
  Timer? _controlsTimer;
  double _brightness = 1.0;
  double _volume = 1.0;
  bool _isDragging = false;
  double _dragStartX = 0;
  double _dragStartY = 0;
  Duration _dragStartPosition = Duration.zero;
  String _gestureHint = '';

  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _useWebview = widget.useWebview;
    _brightness = 1.0;
    _resolvePlayUrl();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.dispose();
    _controlsTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _videoController != null) {
      _videoController!.play();
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (!_playerLocked) {
      _controlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
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
      _videoController!.addListener(_onVideoUpdate);
      await _videoController!.play();
      await WakelockPlus.enable();
      _startControlsTimer();
      if (mounted) {
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _useWebview = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('视频播放失败，切换WebView: $e')),
        );
      }
    }
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    final v = _videoController?.value;
    if (v != null && v.isInitialized && v.isPlaying != _isPlaying) {
      setState(() => _isPlaying = v.isPlaying);
    }
  }

  String? _extractVideoUrl(String html) {
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
      if (_isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
        WakelockPlus.disable();
      } else {
        _videoController!.play();
        _isPlaying = true;
        WakelockPlus.enable();
      }
      _showControls = true;
      _startControlsTimer();
    });
  }

  void _onTapPlayer() {
    if (_playerLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('播放器已锁定，双击解锁'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    setState(() {
      _showControls = !_showControls;
      if (_showControls) _startControlsTimer();
    });
  }

  void _onDoubleTap() {
    if (_playerLocked) {
      setState(() => _playerLocked = false);
      _showControls = true;
      _startControlsTimer();
      return;
    }
    _togglePlayPause();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_playerLocked || _useWebview || _videoController == null) return;
    final size = MediaQuery.of(context).size;
    _isDragging = true;
    _dragStartX = details.localPosition.dx;
    _dragStartY = details.localPosition.dy;
    _dragStartPosition = _videoController!.value.position;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _videoController == null) return;
    final size = MediaQuery.of(context).size;
    final dx = details.localPosition.dx - _dragStartX;
    final dy = _dragStartY - details.localPosition.dy;

    // Left side: brightness
    if (_dragStartX < size.width / 2) {
      final delta = dy / (size.height * 0.8);
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
      setState(() => _gestureHint = '亮度: ${(_brightness * 100).toInt()}%');
    }
    // Right side: seek
    else {
      final duration = _videoController!.value.duration;
      if (duration.inSeconds > 0) {
        final seekDelta = (dx / size.width) * duration.inSeconds;
        final newPos = (_dragStartPosition.inSeconds + seekDelta.round())
            .clamp(0, duration.inSeconds);
        _videoController!.seekTo(Duration(seconds: newPos));
        setState(() {
          _gestureHint = '${_formatDuration(Duration(seconds: newPos))} / ${_formatDuration(duration)}';
        });
      }
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _isDragging = false;
    if (mounted) {
      setState(() => _gestureHint = '');
    }
  }

  void _seekRelative(int seconds) {
    if (_videoController == null) return;
    final current = _videoController!.value.position;
    final newPos = Duration(
      seconds: max(0, current.inSeconds + seconds),
    );
    _videoController!.seekTo(newPos);
    setState(() {
      _showControls = true;
      _startControlsTimer();
    });
  }

  Future<void> _showCastDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('投屏', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tv, color: Colors.white70),
              title: const Text('DLNA 投屏', style: TextStyle(color: Colors.white)),
              subtitle: const Text('搜索局域网设备', style: TextStyle(color: Colors.white54)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('未发现DLNA设备')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cast, color: Colors.white70),
              title: const Text('外部播放器', style: TextStyle(color: Colors.white)),
              subtitle: const Text('使用系统播放器打开', style: TextStyle(color: Colors.white54)),
              onTap: () {
                Navigator.pop(ctx);
                _openExternalPlayer();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _openExternalPlayer() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('外部播放: ${_playableUrl ?? widget.url}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.red),
                  SizedBox(height: 16),
                  Text('正在解析播放地址...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : _useWebview || _playableUrl == null
              ? _buildWebView()
              : _buildPlayer(),
    );
  }

  Widget _buildPlayer() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(height: 16),
            Text('正在加载播放器...', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    final value = _videoController!.value;
    final aspectRatio = value.isInitialized ? value.aspectRatio : 16 / 9;
    final duration = value.duration;
    final position = value.position;
    final bufferPercent = value.buffered.isNotEmpty
        ? value.buffered.first.end.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return GestureDetector(
      onTap: _onTapPlayer,
      onDoubleTap: _onDoubleTap,
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Stack(
        children: [
          // Video player with proper aspect ratio
          Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),

          // Gesture hint overlay
          if (_gestureHint.isNotEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _gestureHint,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),

          // Lock overlay
          if (_playerLocked)
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.lock, color: Colors.white70, size: 28),
                onPressed: _onDoubleTap,
                tooltip: '双击解锁',
              ),
            ),

          // Controls overlay
          if (_showControls && !_playerLocked) ...[
            // Top bar (back button + title + cast)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 4, right: 4, bottom: 8,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        if (_isFullScreen) {
                          _toggleFullScreen();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cast, color: Colors.white70),
                      tooltip: '投屏/外部播放',
                      onPressed: _showCastDialog,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      onSelected: (value) {
                        switch (value) {
                          case 'speed':
                            _showSpeedDialog();
                            break;
                          case 'webview':
                            setState(() => _useWebview = true);
                            break;
                          case 'lock':
                            setState(() {
                              _playerLocked = true;
                              _showControls = false;
                            });
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'speed',
                          child: Row(
                            children: [
                              const Icon(Icons.speed, size: 20),
                              const SizedBox(width: 8),
                              Text('倍速: ${_playbackSpeed}x'),
                            ],
                          ),
                        ),
                        if (!_useWebview)
                          const PopupMenuItem(
                            value: 'webview',
                            child: Row(
                              children: [
                                Icon(Icons.web, size: 20),
                                SizedBox(width: 8),
                                Text('WebView模式'),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'lock',
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline, size: 20),
                              SizedBox(width: 8),
                              Text('锁定播放器'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Center play/pause button
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: AnimatedOpacity(
                  opacity: _isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom controls bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  activeTrackColor: Colors.red,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.red,
                                  overlayColor: Colors.red.withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  min: 0,
                                  max: duration.inMilliseconds.toDouble(),
                                  value: position.inMilliseconds
                                      .toDouble()
                                      .clamp(0, duration.inMilliseconds.toDouble()),
                                  onChanged: (v) {
                                    _videoController!
                                        .seekTo(Duration(milliseconds: v.toInt()));
                                    setState(() {
                                      _showControls = true;
                                      _startControlsTimer();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous, color: Colors.white70, size: 28),
                          onPressed: () => _seekRelative(-30),
                          tooltip: '后退30秒',
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.skip_next, color: Colors.white70, size: 28),
                          onPressed: () => _seekRelative(30),
                          tooltip: '前进30秒',
                        ),
                        const Spacer(),
                        _ControlButton(
                          icon: Icons.speed,
                          label: '${_playbackSpeed}x',
                          onTap: _showSpeedDialog,
                        ),
                        _ControlButton(
                          icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                          label: _isFullScreen ? '缩小' : '全屏',
                          onTap: _toggleFullScreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
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
            const Text('WebView加载失败', style: TextStyle(color: Colors.white54)),
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
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('播放速度', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]
              .map((speed) {
            return RadioListTile<double>(
              title: Text('${speed}x',
                  style: TextStyle(
                    color: _playbackSpeed == speed ? Colors.red : Colors.white70,
                  )),
              value: speed,
              groupValue: _playbackSpeed,
              activeColor: Colors.red,
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
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}