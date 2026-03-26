import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MediaViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const MediaViewerScreen(
      {Key? key, required this.url, this.title = 'Media Viewer'})
      : super(key: key);

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _videoPlayerController;
  late final WebViewController _webViewController;
  bool _isVideo = false;
  bool _isInit = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _checkMediaType();
  }

  void _checkMediaType() {
    final lowerUrl = widget.url.toLowerCase();

    // Check if directly a video link
    if (lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mkv') ||
        lowerUrl.contains('cloudinary.com/video')) {
      _isVideo = true;
      _initVideoPlayer();
    } else {
      _isVideo = false;
      _initWebView();
    }
  }

  void _initVideoPlayer() {
    _videoPlayerController =
        VideoPlayerController.networkUrl(Uri.parse(widget.url))
          ..initialize().then((_) {
            setState(() {
              _isInit = true;
            });
            _videoPlayerController!.play();
          }).catchError((e) {
            setState(() {
              _hasError = true;
            });
          });
  }

  void _initWebView() {
    String finalUrl = widget.url;

    // Convert regular YouTube links to embed links to hide UI
    if (finalUrl.contains('youtube.com/watch?v=')) {
      finalUrl = finalUrl.replaceFirst('watch?v=', 'embed/');
      if (finalUrl.contains('&')) {
        finalUrl = finalUrl.split('&').first;
      }
    } else if (finalUrl.contains('youtu.be/')) {
      finalUrl = finalUrl.replaceFirst('youtu.be/', 'youtube.com/embed/');
      if (finalUrl.contains('?')) {
        finalUrl = finalUrl.split('?').first;
      }
    }

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(finalUrl));
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF4F46E5),
      ),
      body: _hasError
          ? const Center(
              child: Text("Error loading media. Are you sure it's valid?"))
          : _isVideo
              ? _buildVideoPlayer()
              : WebViewWidget(controller: _webViewController),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isInit) {
      return const Center(child: CircularProgressPadding());
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_videoPlayerController!),
            _ControlsOverlay(controller: _videoPlayerController!),
            VideoProgressIndicator(_videoPlayerController!,
                allowScrubbing: true),
          ],
        ),
      ),
    );
  }
}

class CircularProgressPadding extends StatelessWidget {
  const CircularProgressPadding({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => const CircularProgressIndicator();
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({Key? key, required this.controller})
      : super(key: key);

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child: controller.value.isPlaying
              ? const SizedBox.shrink()
              : Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 100.0,
                      semanticLabel: 'Play',
                    ),
                  ),
                ),
        ),
        GestureDetector(
          onTap: () {
            controller.value.isPlaying ? controller.pause() : controller.play();
          },
        ),
      ],
    );
  }
}
