import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:digital_signage/models/compaign_model.dart';
import 'package:digital_signage/view_models/mqtt_view_model.dart';



class MultiMediaView extends StatefulWidget {
  const MultiMediaView({super.key});

  @override
  State<MultiMediaView> createState() => _MultiMediaViewState();
}

class _MultiMediaViewState extends State<MultiMediaView> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mqttViewModel = Provider.of<MqttViewModel>(context, listen: false);
      mqttViewModel.startPlaylistTimerForCampaign();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mqttViewModel = Provider.of<MqttViewModel>(context);
    final campaignModel = mqttViewModel.campaignModel;

    if (campaignModel?.data.playerCampaigns.isEmpty ?? true) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "No campaign data available",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final campaign = campaignModel!.data.playerCampaigns[mqttViewModel.currentIndexOfCapmaign];
    final campaignSchedule = campaign.campaignSchedule;

    if (campaignSchedule.alwaysPlay) {
      return _buildZones(campaign);
    }

    DateTime now = DateTime.now();

    bool isCampaignDateInRange = _isCampaignDateInRange(
      DateTime.parse(campaignSchedule.period!.date.start),
      DateTime.parse(campaignSchedule.period!.date.end!),
    );

    bool isCampaignDayAllowed = _isCurrentDayAllowed(
      campaignSchedule.period!.days,
      now,
    );

    bool isCampaignTimeInRange = _isTimeInRange(
      campaignSchedule.period!.time.from,
      campaignSchedule.period!.time.to,
    );

    if (isCampaignDateInRange &&
        isCampaignDayAllowed &&
        isCampaignTimeInRange) {
      return _buildZones(campaign);
    }

    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          "Campaign is not scheduled to play at this time.",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildZones(PlayerCampaign campaign) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          // Capture the tap position and store it in the Provider
          final mqttViewModel = Provider.of<MqttViewModel>(context, listen: false);
          mqttViewModel.setTapPosition(details.localPosition.dx, details.localPosition.dy);
          print("Tapped at: x=${details.localPosition.dx}, y=${details.localPosition.dy}");
        },
        child: Stack(
          children: campaign.zones.map((zone) {
            return Positioned(
              left: zone.x.toDouble(),
              top: zone.y.toDouble(),
              width: zone.width.toDouble(),
              height: zone.height.toDouble(),
              child: VideoPlaylistWidget(
                zoneId: zone.id.toString(),
                mediaItems: zone.mediaItems,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _isCampaignDateInRange(DateTime startDate, DateTime endDate) {
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
    );

    DateTime toTime = DateTime.now().copyWith(
      hour: int.parse(timeTo.split(':')[0]),
      minute: int.parse(timeTo.split(':')[1]),
    );

    return currentTime.isAfter(fromTime) && currentTime.isBefore(toTime);
  }
}

class VideoPlaylistWidget extends StatefulWidget {
  final String zoneId;
  final List<MediaItem> mediaItems;

  const VideoPlaylistWidget({
    super.key,
    required this.zoneId,
    required this.mediaItems,
  });

  @override
  _VideoPlaylistWidgetState createState() => _VideoPlaylistWidgetState();
}

class _VideoPlaylistWidgetState extends State<VideoPlaylistWidget> {
  int _currentMediaIndex = 0;
  Timer? _timer;
  double _opacity = 1.0;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration.zero, () {});
    _initializeNextMedia();
  }

  @override
  void didUpdateWidget(covariant VideoPlaylistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItems != widget.mediaItems ||
        oldWidget.zoneId != widget.zoneId) {
      _resetState();
    }
  }

  void _resetState() {
    _currentMediaIndex = 0;
    _timer?.cancel();
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      _opacity = 1.0;
    });
    _initializeNextMedia();
  }

  void _initializeNextMedia() {
    if (widget.mediaItems.isEmpty) {
      print("Zone ${widget.zoneId}: No media items available.");
      return;
    }

    MediaItem currentMedia = widget.mediaItems[_currentMediaIndex];
    print(
        "Zone ${widget.zoneId}: Initializing media item ${currentMedia.id}...... ${currentMedia.mediaUrl}");
    if (currentMedia.schedule.alwaysPlay) {
      print("Always play is true for media: ${currentMedia.mediaUrl}");
      String duration = currentMedia.settings.duration.toString();
      print("Loading duration at index $_currentMediaIndex: $duration");
      _startMediaLoop(duration);
      _loadMedia(currentMedia);
      return;
    }
    DateTime now = DateTime.now();
    print("Current date: $now");

    DateTime startDate =
        DateTime.parse(currentMedia.schedule.period!.date.start);
    DateTime endDate = DateTime.parse(currentMedia.schedule.period!.date.end!);
    print("Media start date: $startDate");
    print("Media end date: $endDate");

    bool isDateInRange = now.isAfter(startDate) &&
        now.isBefore(endDate.add(const Duration(days: 1)));
    print("Is current date in range: $isDateInRange");

    bool isDayAllowed =
        _isCurrentDayAllowed(currentMedia.schedule.period!.days, now);
    print("Is current day allowed: $isDayAllowed");

    String? timeFrom = currentMedia.schedule.period!.time.from;
    String? timeTo = currentMedia.schedule.period!.time.to;

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
      String duration = currentMedia.settings.duration.toString();
      print("Loading duration at index $_currentMediaIndex: $duration");
      _startMediaLoop(duration);
      _loadMedia(currentMedia);
    } else {
      print("Skipping media not allowed by schedule.");
      print("Current date, day, or time is not allowed for this media.");
      _onMediaEnd();
    }
  }

  void _startMediaLoop(String duration) {
    print("Starting media loop for duration: $duration");
    int durationSeconds = int.tryParse(duration) ?? 10;

    if (_timer!.isActive) _timer!.cancel();
    _timer = Timer(Duration(seconds: durationSeconds), _onMediaEnd);
  }

  bool _isMediaAllowed(MediaItem media) {
    DateTime now = DateTime.now();
    DateTime startDate = DateTime.parse(media.schedule.period!.date.start);
    DateTime endDate = DateTime.parse(media.schedule.period!.date.end!);

    bool isDateInRange = now.isAfter(startDate) &&
        now.isBefore(endDate.add(const Duration(days: 1)));
    bool isDayAllowed = _isCurrentDayAllowed(media.schedule.period!.days, now);
    bool isTimeInRange = _isTimeInRange(
      media.schedule.period!.time.from,
      media.schedule.period!.time.to,
    );

    return isDateInRange && isDayAllowed && isTimeInRange;
  }

  void _loadMedia(MediaItem nextMedia) {
    print("[LOG] Loading media: ${nextMedia.mediaUrl}");
    if (isVideoFile(nextMedia.mediaUrl)) {
      _initializeNextVideo(nextMedia);
    } else if (isWebFile(nextMedia.mediaUrl)) {
      // Ensure you are not reinitializing the WebView if the file is the same
      if (_currentMediaIndex > 0 &&
          widget.mediaItems[_currentMediaIndex - 1].mediaUrl ==
              nextMedia.mediaUrl) {
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
      // if (widget.mediaItems.length == 1) {
      //   print("i am hererererer");
      //   Future.delayed(Duration(seconds: durationSeconds), _onMediaEnd);
      // }

      setState(() {});
      //       if (widget.mediaItems.length == 1) {
      //   _timer?.cancel();
      //   _timer = Timer(Duration(seconds: 1), () {
      //     print("[LOG] Only one media item, resetting to initial state");
      //     _initializeNextVideo(nextMedia); // Restart the video or handle accordingly
      //     setState(() {}); // Ensure UI updates
      //   });
      // }
    }
  }

  void _initializeNextVideo(MediaItem nextMedia) {
    print("[LOG] Initializing video: ${nextMedia.mediaUrl}");
    _videoController = VideoPlayerController.file(File(nextMedia.mediaUrl))
      ..initialize().then((_) {
        if (_videoController!.value.isInitialized) {
          int videoDuration = int.tryParse(nextMedia.settings.duration) ??
              _videoController!.value.duration.inSeconds;

          print("Video duration set to $videoDuration seconds");

          setState(() {
            _videoController!.play();
            _videoController!.setLooping(true);
          });

          // _timer = Timer(Duration(seconds: videoDuration), _onMediaEnd);
          _timer = Timer(Duration(seconds: videoDuration), () {
            _videoController!.pause();
            _onMediaEnd();
          });
          _videoController!.addListener(() {
            _checkVideoDuration(nextMedia);
          });
        }
      }).catchError((error) {
        print("[LOG] Error initializing video: $error");
        print("[LOG] Video URL: ${nextMedia.mediaUrl}");
        setState(() {});
      });
  }

  void _checkVideoDuration(MediaItem media) {
    if (_videoController != null &&
        _videoController!.value.isInitialized &&
        !_videoController!.value.isPlaying &&
        _videoController!.value.position >= _videoController!.value.duration) {
      print("Video has ended, transitioning...");
      _videoController!.pause();
      _onMediaEnd();
    }
  }

  void _showImage(MediaItem media) {
    int durationSeconds = int.tryParse(media.settings.duration.toString()) ?? 5;
    _timer?.cancel();
    _timer = Timer(Duration(seconds: durationSeconds), _onMediaEnd);
  }

  bool _isDisposed = false;

  void _onMediaEnd() {
    if (_timer!.isActive) _timer!.cancel();
    if (!_isDisposed) {
      setState(() {
        _opacity = 0.0;
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          if (_currentMediaIndex < widget.mediaItems.length - 1) {
            _currentMediaIndex++;
          } else {
            _currentMediaIndex = 0;
          }
          _opacity = 1.0;
          _initializeNextMedia();
        });
      });
    }
  }

  bool _isCurrentDayAllowed(dynamic days, DateTime now) {
    switch (now.weekday) {
      case DateTime.monday:
        return days.monday ?? false;
      case DateTime.tuesday:
        return days.tuesday ?? false;
      case DateTime.wednesday:
        return days.wednesday ?? false;
      case DateTime.thursday:
        return days.thursday ?? false;
      case DateTime.friday:
        return days.friday ?? false;
      case DateTime.saturday:
        return days.saturday ?? false;
      case DateTime.sunday:
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
    );
    DateTime toTime = DateTime.now().copyWith(
      hour: int.parse(timeTo.split(':')[0]),
      minute: int.parse(timeTo.split(':')[1]),
    );

    return currentTime.isAfter(fromTime) && currentTime.isBefore(toTime);
  }

  bool isWebFile(String path) {
    final webExtensions = ['.html'];
    return webExtensions.any((ext) => path.endsWith(ext));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _isDisposed = true;
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaItems.isEmpty) {
      return Center(child: Text("Zone ${widget.zoneId}: No media items."));
    }

    MediaItem currentMedia = widget.mediaItems[_currentMediaIndex];
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 500),
      child: AnimatedSwitcher(
        key: ValueKey(currentMedia.id),
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
                    begin: const Offset(-1, 0), // From left
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
                    begin: const Offset(0, 1), // From bottom
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
                        begin: const Offset(-1, 0), // From left
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeInOut)),
                    ),
                    child: child,
                  ),
                  SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: Offset.zero,
                        end: const Offset(1, 0), // Slide out to right
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
              return child; // No transition applied
          }
        },
        child: isVideoFile(currentMedia.mediaUrl)
            ? VideoPlayerWidget(
                key: ValueKey(currentMedia.id), // Unique key
                filePath: currentMedia.mediaUrl,
                onVideoEnd: _onMediaEnd,
                transitionType: currentMedia.settings.transition,
              )
            : isWebFile(currentMedia.mediaUrl)
                ? WBViewWidget(
                    key: ValueKey(currentMedia.id),
                    media: currentMedia.mediaUrl,
                    onMediaEnd: _onMediaEnd)
                : ImageWidget(
                    key: ValueKey(currentMedia.id), // Unique key
                    filePath: currentMedia.mediaUrl,
                    onImageEnd: _onMediaEnd,
                    transitionType: currentMedia.settings.transition,
                  ),
      ),
    );
  }

  bool isVideoFile(String path) {
    final videoExtensions = ['.mp4', '.avi', '.mov', '.mkv'];
    return videoExtensions.any((ext) => path.endsWith(ext));
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String filePath;
  final VoidCallback onVideoEnd;
  final String transitionType;

  const VideoPlayerWidget({
    super.key,
    required this.filePath,
    required this.onVideoEnd,
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

              _controller.setLooping(false);
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
        : SizedBox.expand(child: VideoPlayer(_controller));

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

  final String transitionType;

  const ImageWidget({
    super.key,
    required this.filePath,
    required this.onImageEnd,
    required this.transitionType,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = SizedBox.expand(
      child: Image.file(
        File(filePath),
        fit: BoxFit.cover,
        height: MediaQuery.sizeOf(context).height,
        width: MediaQuery.sizeOf(context).width,
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

  const WBViewWidget({
    Key? key,
    required this.media,
    required this.onMediaEnd,
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
