import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

class VideoPlayerPage extends StatefulWidget {
  final String videoPath;

  const VideoPlayerPage({Key? key, required this.videoPath}) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Video dosyasının var olup olmadığını kontrol et
      final videoFile = File(widget.videoPath);
      if (!await videoFile.exists()) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Video file not found: ${widget.videoPath}';
          _isLoading = false;
        });
        return;
      }

      // Video controller'ı başlat
      _controller = VideoPlayerController.file(videoFile);

      await _controller!.initialize();

      setState(() {
        _isLoading = false;
      });

      // Video başladığında otomatik oynat
      _controller!.play();

      // Video bittiğinde başa sar
      _controller!.addListener(() {
        if (_controller!.value.position == _controller!.value.duration) {
          _controller!.seekTo(Duration.zero);
          _controller!.pause();
        }
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error initializing video: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  void _seekTo(double value) {
    final duration = _controller!.value.duration;
    final position = Duration(
      milliseconds: (duration.inMilliseconds * value).round(),
    );
    _controller!.seekTo(position);
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Player'),
        backgroundColor: Colors.black87,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading video...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              )
            : _hasError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 64),
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _hasError = false;
                      });
                      _initializeVideo();
                    },
                    child: Text('Retry'),
                  ),
                ],
              )
            : GestureDetector(
                onTap: _toggleControls,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Video player
                    AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),

                    // Controls overlay
                    if (_showControls)
                      Container(
                        color: Colors.black38,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Play/Pause button in center
                            Expanded(
                              child: Center(
                                child: GestureDetector(
                                  onTap: _togglePlayPause,
                                  child: Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _controller!.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Bottom controls
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Column(
                                children: [
                                  // Progress bar
                                  ValueListenableBuilder(
                                    valueListenable: _controller!,
                                    builder:
                                        (
                                          context,
                                          VideoPlayerValue value,
                                          child,
                                        ) {
                                          final progress =
                                              value.position.inMilliseconds /
                                              value.duration.inMilliseconds;
                                          return SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                                  trackHeight: 3,
                                                  thumbShape:
                                                      RoundSliderThumbShape(
                                                        enabledThumbRadius: 8,
                                                      ),
                                                ),
                                            child: Slider(
                                              value: progress.isNaN
                                                  ? 0.0
                                                  : progress.clamp(0.0, 1.0),
                                              onChanged: _seekTo,
                                              activeColor: Colors.white,
                                              inactiveColor: Colors.white38,
                                            ),
                                          );
                                        },
                                  ),

                                  // Time display
                                  ValueListenableBuilder(
                                    valueListenable: _controller!,
                                    builder:
                                        (
                                          context,
                                          VideoPlayerValue value,
                                          child,
                                        ) {
                                          return Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  _formatDuration(
                                                    value.position,
                                                  ),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  _formatDuration(
                                                    value.duration,
                                                  ),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
