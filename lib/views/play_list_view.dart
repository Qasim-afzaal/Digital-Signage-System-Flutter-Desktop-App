import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:digital_signage/models/play_list_model.dart';
import 'package:digital_signage/view_models/mqtt_view_model.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late FocusNode _focusNode; // Declare FocusNode

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(); // Initialize FocusNode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start playlist timer after the frame is rendered
      final mqttViewModel = Provider.of<MqttViewModel>(context, listen: false);
      mqttViewModel.startPlaylistTimer();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose(); // Dispose FocusNode when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mqttViewModel = Provider.of<MqttViewModel>(context);

    final currentPlaylist =
        mqttViewModel.playListModel!.data.playlist[mqttViewModel.currentIndex];
    final playlistSchedule = currentPlaylist.playlistSchedule;

    if (playlistSchedule!.alwaysPlay) {
      return GestureDetector(
      onTapDown: (details) {
                    // Capture the tap position and store it in the Provider
          final mqttViewModel = Provider.of<MqttViewModel>(context, listen: false);
          mqttViewModel.setTapPosition(details.localPosition.dx, details.localPosition.dy);
          print("Tapped at: x=${details.localPosition.dx}, y=${details.localPosition.dy}");
        },
        child: Scaffold(
          body: mqttViewModel.mediaPath.isNotEmpty
              ? VideoPlaylistWidget(
                  mediaPaths: currentPlaylist.media!,
                  playlist: currentPlaylist,
                )
              : const Center(
                  child: Text("No media available"),
                ),
        ),
      );
    }

    DateTime now = DateTime.now();

    bool isPlaylistDateInRange = _isPlaylistDateInRange(
      playlistSchedule.period!.date.start,
      playlistSchedule.period!.date.end,
    );

    bool isPlaylistDayAllowed =
        _isCurrentDayAllowed(playlistSchedule.period!.days, now);
    bool isTimeInRange = _isTimeInRange(
      playlistSchedule.period!.time.from,
      playlistSchedule.period!.time.to,
    );

    return Scaffold(
      body: mqttViewModel.mediaPath.isNotEmpty &&
              isPlaylistDateInRange &&
              isPlaylistDayAllowed &&
              isTimeInRange
          ? VideoPlaylistWidget(
              mediaPaths: currentPlaylist.media!,
              playlist: currentPlaylist,
            )
          : const Center(
              child: Text("No media available"),
            ),
    );
  }

  bool _isPlaylistDateInRange(DateTime startDate, DateTime endDate) {
    DateTime now = DateTime.now();
    return now.isAfter(startDate) &&
        now.isBefore(endDate.add(const Duration(days: 1)));
  }

  bool _isCurrentDayAllowed(dynamic days, DateTime now) {
    switch (now.weekday) {
      case 1:
        return days.monday ?? false;
      case 2:
        return days.tuesday ?? false;
      case 3:
        return days.wednesday ?? false;
      case 4:
        return days.thursday ?? false;
      case 5:
        return days.friday ?? false;
      case 6:
        return days.saturday ?? false;
      case 7:
        return days.sunday ?? false;
      default:
        return false;
    }
  }

  bool _isTimeInRange(String timeFrom, String timeTo) {
    DateTime currentTime = DateTime.now();
    DateTime fromTime = DateTime.now().copyWith(
      hour: int.parse(timeFrom.split(':')[0]),
      minute: int.parse(timeFrom.split(':')[1]),
      second: int.parse(timeFrom.split(':')[2]),
    );

    DateTime toTime = DateTime.now().copyWith(
      hour: int.parse(timeTo.split(':')[0]),
      minute: int.parse(timeTo.split(':')[1]),
      second: int.parse(timeTo.split(':')[2]),
    );

    return currentTime.isAfter(fromTime) && currentTime.isBefore(toTime);
  }
}

class VideoPlaylistWidget extends StatefulWidget {
  final List<Media> mediaPaths;
  final Playlist playlist;

  const VideoPlaylistWidget({
    super.key,
    required this.mediaPaths,
    required this.playlist,
  });

  @override
  _VideoPlaylistWidgetState createState() => _VideoPlaylistWidgetState();
}

class _VideoPlaylistWidgetState extends State<VideoPlaylistWidget> {
  int _currentIndex = 0;
  bool _isDisposed = false;
  late Timer _timer;
  double _opacity = 1.0;
  VideoPlayerController? _nextController;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration.zero, () {});
    if (widget.playlist.playback!.order == "shuffle") {
      widget.mediaPaths.shuffle();
    }

    _initializeNextMedia();
  }

  void _onMediaEnd() {
    if (_timer.isActive) _timer.cancel();
    if (!_isDisposed) {
      setState(() {
        _opacity = 0.0;
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_isDisposed) {
          setState(() {
            if (widget.playlist.playback!.order == "shuffle") {
              print(".......i am in shuffle .....");
              _currentIndex = Random().nextInt(widget.mediaPaths.length);
            } else if (_currentIndex < widget.mediaPaths.length - 1) {
              _currentIndex++;
            } else {
              _currentIndex = 0;
            }
            _opacity = 1.0;
            _initializeNextMedia();
          });
        }
      });
    }
  }

  void _initializeNextMedia() {
    widget.mediaPaths.forEach((media) {
      print("This is listsssss ${media.mediaUrl}");
    });
    if (_currentIndex < widget.mediaPaths.length) {
      Media nextMedia = widget.mediaPaths[_currentIndex];
      print("Loading media at index $_currentIndex: ${nextMedia.mediaUrl}");
      if (nextMedia.schedule.alwaysPlay) {
        print("Always play is true for media: ${nextMedia.mediaUrl}");
        String duration = nextMedia.settings.duration.toString();
        print("Loading duration at index $_currentIndex: $duration");
        _startMediaLoop(duration);
        _loadMedia(nextMedia);
        return;
      }
      DateTime now = DateTime.now();
      print("Current date: $now");

      DateTime startDate = nextMedia.schedule.period!.date.start;
      DateTime endDate = nextMedia.schedule.period!.date.end;
      print("Media start date: $startDate");
      print("Media end date: $endDate");

      bool isDateInRange = now.isAfter(startDate) &&
          now.isBefore(endDate.add(const Duration(days: 1)));
      print("Is current date in range: $isDateInRange");

      bool isDayAllowed =
          _isCurrentDayAllowed(nextMedia.schedule.period!.days, now);
      print("Is current day allowed: $isDayAllowed");

      String? timeFrom = nextMedia.schedule.period!.time.from;
      String? timeTo = nextMedia.schedule.period!.time.to;

      DateTime currentTime = DateTime.now();
      DateTime fromTime = DateTime.now().copyWith(
        hour: int.parse(timeFrom.split(':')[0]),
        minute: int.parse(timeFrom.split(':')[1]),
        second: int.parse(timeFrom.split(':')[2]),
      );

      DateTime toTime = DateTime.now().copyWith(
        hour: int.parse(timeTo.split(':')[0]),
        minute: int.parse(timeTo.split(':')[1]),
        second: int.parse(timeTo.split(':')[2]),
      );

      bool isTimeInRange =
          currentTime.isAfter(fromTime) && currentTime.isBefore(toTime);
      print("Is current time in range: $isTimeInRange");

      if (isDateInRange && isDayAllowed && isTimeInRange) {
        String duration = nextMedia.settings.duration.toString();
        print("Loading duration at index $_currentIndex: $duration");
        _startMediaLoop(duration);
        _loadMedia(nextMedia);
      } else {
        print("Skipping media not allowed by schedule.");
        print("Current date, day, or time is not allowed for this media.");
        _onMediaEnd();
      }
    }
  }

  bool isWebFile(String path) {
    final webExtensions = ['.html'];
    return webExtensions.any((ext) => path.endsWith(ext));
  }

  void _loadMedia(Media nextMedia) {
    print("[LOG] Loading media: ${nextMedia.mediaUrl}");
    if (isVideoFile(nextMedia.mediaUrl)) {
      _initializeNextVideo(nextMedia);
    } else if (isWebFile(nextMedia.mediaUrl)) {
      // Ensure you are not reinitializing the WebView if the file is the same
      if (_currentIndex > 0 &&
          widget.mediaPaths[_currentIndex - 1].mediaUrl == nextMedia.mediaUrl) {
        print("[LOG] Skipping recreation of the same WebView");
        return;
      }
    } else {
      print("[LOG] Current media is an image: ${nextMedia.mediaUrl}");
      int durationSeconds =
          int.tryParse(nextMedia.settings.duration.toString()) ?? 5;

      // Set a timer for images with a duration
      _timer = Timer(Duration(seconds: durationSeconds), () {
        _onMediaEnd();
      });

      // If the playlist has only one media (image), force the transition after duration
      if (widget.mediaPaths.length == 1) {
        Future.delayed(Duration(seconds: durationSeconds), _onMediaEnd);
      }

      setState(() {});
    }
  }

  // Check if current day is allowed based on the schedule
  bool _isCurrentDayAllowed(dynamic days, DateTime now) {
    switch (now.weekday) {
      case 1:
        return days.monday ?? false;
      case 2:
        return days.tuesday ?? false;
      case 3:
        return days.wednesday ?? false;
      case 4:
        return days.thursday ?? false;
      case 5:
        return days.friday ?? false;
      case 6:
        return days.saturday ?? false;
      case 7:
        return days.sunday ?? false;
      default:
        return false;
    }
  }

  void _initializeNextVideo(Media nextMedia) {
    print("[LOG] Initializing video: ${nextMedia.mediaUrl}");
    _nextController = VideoPlayerController.file(File(nextMedia.mediaUrl))
      ..initialize().then((_) {
        if (_nextController!.value.isInitialized) {
          int videoDuration = int.tryParse(nextMedia.settings.duration) ??
              _nextController!.value.duration.inSeconds;

          print("Video duration set to $videoDuration seconds");

          setState(() {
            _nextController!.play();
            _nextController!.setLooping(true);
          });

          // _timer = Timer(Duration(seconds: videoDuration), _onMediaEnd);
          _timer = Timer(Duration(seconds: videoDuration), () {
            _nextController!.pause();
            _onMediaEnd();
          });
          _nextController!.addListener(() {
            _checkVideoDuration(nextMedia);
          });
        }
      }).catchError((error) {
        print("[LOG] Error initializing video: $error");
        setState(() {});
      });
  }

  void _startMediaLoop(String duration) {
    print("Starting media loop for duration: $duration");
    int durationSeconds = int.tryParse(duration) ?? 10;

    if (_timer.isActive) _timer.cancel();
    _timer = Timer(Duration(seconds: durationSeconds), _onMediaEnd);
  }

  void _checkVideoDuration(Media media) {
    if (_nextController != null &&
        _nextController!.value.isInitialized &&
        !_nextController!.value.isPlaying &&
        _nextController!.value.position >= _nextController!.value.duration) {
      print("Video has ended, transitioning...");
      _nextController!.pause();
      _onMediaEnd();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _isDisposed = true;
    _nextController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.mediaPaths.length || _currentIndex < 0) {
      _currentIndex = 0;
    }
    Media currentMedia = widget.mediaPaths[_currentIndex];

    print("Displaying indezzzz $_currentIndex");
    print("Displaying media: ${currentMedia.settings.duration}");
    print("Displaying media: ${currentMedia.settings.ratio}");
    print("Displaying media: ${currentMedia.mediaUrl}");
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 500),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) {
            print("this is transition${currentMedia.settings.transition}");

            switch (currentMedia.settings.transition) {
              case "fadeIn":
                return FadeTransition(opacity: animation, child: child);
              case "slideOverLeftToRight":
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(-1, 0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeInOut)),
                  ),
                  child: child,
                );
              case "slideOverRightToLeft":
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeInOut)),
                  ),
                  child: child,
                );
              case "slideOverTopToBottom":
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0, -1), // From top
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeInOut)),
                  ),
                  child: child,
                );
              case "slideOverBottomToTop":
                return SlideTransition(
                  position: animation.drive(
                    Tween(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeInOut)),
                  ),
                  child: child,
                );
              case "slideInOutLeftToRight":
                return Stack(
                  children: [
                    SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: const Offset(-1, 0),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeInOut)),
                      ),
                      child: child,
                    ),
                    SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: Offset.zero,
                          end: const Offset(1, 0),
                        ).chain(CurveTween(curve: Curves.easeInOut)),
                      ),
                      child: child,
                    ),
                  ],
                );
              case "slideInOutRightToLeft":
                return Stack(
                  children: [
                    SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: const Offset(1, 0), // From right
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeInOut)),
                      ),
                      child: child,
                    ),
                    SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: Offset.zero,
                          end: const Offset(-1, 0), // Slide out to left
                        ).chain(CurveTween(curve: Curves.easeInOut)),
                      ),
                      child: child,
                    ),
                  ],
                );
              case "slideInOutTopToBottom":
                return Stack(
                  children: [
                    SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: const Offset(0, -1), // From top
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeInOut)),
                      ),
                      child: child,
                    ),
                    SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: Offset.zero,
                          end: const Offset(0, 1), // Slide out to bottom
                        ).chain(CurveTween(curve: Curves.easeInOut)),
                      ),
                      child: child,
                    ),
                  ],
                );
              case "slideInOutBottomToTop":
                return Stack(
                  children: [
                    SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: const Offset(0, 1), // From bottom
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeInOut)),
                      ),
                      child: child,
                    ),
                    SlideTransition(
                      position: animation.drive(
                        Tween(
                          begin: Offset.zero,
                          end: const Offset(0, -1), // Slide out to top
                        ).chain(CurveTween(curve: Curves.easeInOut)),
                      ),
                      child: child,
                    ),
                  ],
                );
              default:
                return FadeTransition(opacity: animation, child: child);
            }
          },
          child: isVideoFile(currentMedia.mediaUrl)
              ? VideoPlayerWidget(
                  key: ValueKey(currentMedia.mediaUrl),
                  filePath: currentMedia.mediaUrl,
                  currentVolume:
                      double.parse(currentMedia.settings.volume.toString()),
                  onVideoEnd: _onMediaEnd,
                  aspectRatio: getAspectRatio(currentMedia.settings.ratio),
                  transitionType: currentMedia.settings.transition,
                )
              : isWebFile(currentMedia.mediaUrl)
                  ? SizedBox.expand(
                      key: ValueKey(currentMedia.mediaUrl),
                      child: WBViewWidget(
                          media: currentMedia.mediaUrl,
                          onMediaEnd: _onMediaEnd,
                          transitionType: currentMedia.settings.transition),
                    )
                  : SizedBox.expand(
                      key: ValueKey(currentMedia.mediaUrl),
                      child: ImageWidget(
                        filePath: currentMedia.mediaUrl,
                        onImageEnd: _onMediaEnd,
                        aspectRatio:
                            getAspectRatio(currentMedia.settings.ratio),
                        transitionType: currentMedia.settings.transition,
                      ),
                    ),
        ),
      ),
    );
  }

  double getAspectRatio(String? ratio) {
    switch (ratio) {
      case 'Stretch to Fill Region':
        return 16 / 9;
      default:
        return 16 / 9;
    }
  }

  bool isVideoFile(String path) {
    final videoExtensions = ['.mp4', '.avi', '.mov', '.mkv', '.mp3'];
    return videoExtensions.any((ext) => path.endsWith(ext));
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String filePath;
  final VoidCallback onVideoEnd;
  final double aspectRatio;
  final double currentVolume;
  final String transitionType;

  const VideoPlayerWidget({
    super.key,
    required this.filePath,
    required this.onVideoEnd,
    required this.currentVolume,
    required this.aspectRatio,
    required this.transitionType,
  });

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  bool _isVideoEnded = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() async {
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then(
        (_) {
          setState(
            () {
              _isLoading = false;
              _controller.setVolume(widget.currentVolume);
              _controller.setLooping(true);
              _controller.play();
            },
          );

          _controller.addListener(
            () {
              if (_controller.value.position >= _controller.value.duration &&
                  !_isVideoEnded) {
                _isVideoEnded = true;
                widget.onVideoEnd();
              }
            },
          );
        },
      ).catchError(
        (error) {
          print("Error initializing video: $error");
          setState(
            () {
              _isLoading = false;
            },
          );
        },
      );
  }

  void _checkVideoEnd() {
    if (_controller.value.isInitialized &&
        !_controller.value.isPlaying &&
        _controller.value.position >= _controller.value.duration &&
        !_isVideoEnded) {
      setState(() {
        _isVideoEnded = true;
      });
      widget.onVideoEnd();
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _controller.removeListener(_checkVideoEnd);
      _controller.dispose();
      _initializeVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget videoWidget = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SizedBox.expand(
            child: AspectRatio(
              aspectRatio: widget.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          );

    if (!_isLoading && !_controller.value.isInitialized) {
      videoWidget = const Center(child: CircularProgressIndicator());
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: videoWidget,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_checkVideoEnd);
    _controller.dispose();
    super.dispose();
  }
}

class ImageWidget extends StatelessWidget {
  final String filePath;
  final VoidCallback onImageEnd;
  final double aspectRatio;
  final String transitionType;

  const ImageWidget({
    super.key,
    required this.filePath,
    required this.onImageEnd,
    required this.aspectRatio,
    required this.transitionType,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = SizedBox.expand(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Image.file(File(filePath), fit: BoxFit.cover),
      ),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: imageWidget,
    );
  }
}

class WBViewWidget extends StatefulWidget {
  final String media; // Absolute file path
  final VoidCallback onMediaEnd;
  final String transitionType;

  const WBViewWidget({
    Key? key,
    required this.media,
    required this.onMediaEnd,
    required this.transitionType,
  }) : super(key: key);

  @override
  _WBViewWidgetState createState() => _WBViewWidgetState();
}

class _WBViewWidgetState extends State<WBViewWidget> {
  InAppWebViewController? _webViewController;
  double progress = 0;
  @override
  void dispose() {
    _webViewController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String fileUrl = 'file://${widget.media}';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Column(
        children: [
          if (progress < 1.0) LinearProgressIndicator(value: progress),
          Expanded(
            child: InAppWebView(
              initialUrlRequest:
                  URLRequest(url: WebUri.uri(Uri.parse(fileUrl))),
              onWebViewCreated: (InAppWebViewController controller) {
                _webViewController = controller;
              },
              onProgressChanged: (controller, newProgress) {
                setState(() {
                  progress = newProgress / 100.0;
                });
              },
              onLoadError: (controller, url, code, message) {
                print("Load error: $message");
              },
              onLoadHttpError: (controller, url, statusCode, description) {
                print("HTTP error: $description");
              },
            ),
          ),
        ],
      ),
    );
  }
}
