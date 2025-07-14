import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:full_picker/full_picker.dart';
import 'package:full_picker/src/utils/pl.dart';
import 'package:limited_video_recorder/limited_video_recorder_config.dart';
import 'package:limited_video_recorder/limited_video_recorder_controller.dart';
import 'package:video_player/video_player.dart';

class VideoRecorderPage extends StatefulWidget {
  const VideoRecorderPage({required this.config, super.key});
  final RecordingConfig config;
  @override
  State<VideoRecorderPage> createState() => _VideoRecorderPageState();
}

class _VideoRecorderPageState extends State<VideoRecorderPage> {
  bool isRecording = false;
  String? videoPath;
  VideoPlayerController? _controller;
  late LimitedVideoRecorderController recorder;

  Duration? videoDuration;
  int? videoWidth;
  int? videoHeight;
  int? videoFileSize;

  Future<void> startRecording() async {
    try {
      recorder = LimitedVideoRecorderController();
      recorder.onRecordingComplete(_loadVideo);
      await recorder.start(config: widget.config);
      setState(() {
        isRecording = true;
      });
    } catch (_) {}
  }

  Future<void> stopRecording() async {
    try {
      final String? p = await recorder.stop();
      if (p != null) {
        await _loadVideo(p);
      }
      setState(() {
        isRecording = false;
      });
    } catch (_) {}
  }

  Future<void> _loadVideo(final String path) async {
    final File file = File(path);
    if (!file.existsSync()) {
      return;
    }

    final FileStat stat = file.statSync();

    final VideoPlayerController controller = VideoPlayerController.file(file);
    await controller.initialize();

    setState(() {
      videoPath = path;
      _controller = controller;
      videoDuration = controller.value.duration;
      videoWidth = controller.value.size.width.toInt();
      videoHeight = controller.value.size.height.toInt();
      videoFileSize = stat.size;
      isRecording = false;
    });
  }

  Future<void> _resetVideo() async {
    if (videoPath != null) {
      // If a recording already exists, delete it before starting a new one
      final File existingFile = File(videoPath!);
      if (existingFile.existsSync()) {
        await existingFile.delete();
      }
    }
    setState(() {
      isRecording = false;
      videoPath = null;
      videoDuration = null;
      videoWidth = null;
      videoHeight = null;
      videoFileSize = null;
      _controller?.dispose();
      _controller = null;
      recorder.dispose();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatBytes(final int bytes) {
    const List<String> suffixes = <String>['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  String _formatDuration(final Duration duration) {
    String twoDigits(final int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$minutes:$seconds";
  }

  Future<void> _done() async {
    if (_controller != null) {
      await _controller!.dispose();
    }
    final XFile file = XFile(videoPath!);
    if (mounted) {
      Navigator.pop(
        context,
        FullPickerOutput(
          bytes: <Uint8List?>[await file.readAsBytes()],
          fileType: FullPickerType.video,
          name: <String?>['${file.name}.mp4'],
          file: () {
            try {
              return <File?>[File(file.path)];
            } catch (_) {
              return <File?>[];
            }
          }(),
          xFile: <XFile?>[
            if (Pl.isWeb)
              file
            else
              getFillXFile(
                file: () {
                  try {
                    return File(file.path);
                  } catch (_) {
                    return null;
                  }
                }(),
                bytes: await file.readAsBytes(),
                mime: 'video/mp4',
                name: '${file.name}.mp4',
              ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(final BuildContext context) => Scaffold(
        body: Stack(
          children: <Widget>[
            if (videoPath != null && _controller != null)
              Stack(
                children: <Widget>[
                  VideoPlayer(_controller!),
                  Align(
                    alignment: Alignment.topLeft,
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Duration: ${videoDuration != null ? _formatDuration(videoDuration!) : '-'}",
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text("Resolution: ${videoWidth ?? '-'} x ${videoHeight ?? '-'}", style: const TextStyle(fontSize: 12)),
                          Text(
                            "File Size: ${videoFileSize != null ? _formatBytes(videoFileSize!) : '-'}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            if (videoPath == null) const Expanded(child: AndroidView(viewType: 'camera_preview', layoutDirection: TextDirection.ltr)),
            if (!isRecording && videoPath == null)
              Align(
                alignment: Alignment.bottomCenter,
                child: IconButton(
                  onPressed: startRecording,
                  icon: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: const Icon(
                      Icons.circle_rounded,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            if (isRecording && videoPath == null)
              Align(
                alignment: Alignment.bottomCenter,
                child: IconButton(
                  onPressed: stopRecording,
                  icon: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: const Icon(
                      Icons.stop_rounded,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            if (videoPath != null && _controller != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: IconButton(
                  onPressed: _done,
                  icon: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: const Icon(
                      Icons.done_rounded,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            if (videoPath != null && _controller != null)
              Align(
                alignment: Alignment.bottomLeft,
                child: IconButton(
                  onPressed: _resetVideo,
                  icon: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: const Icon(
                      Icons.delete_rounded,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            if (videoPath != null && _controller != null)
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      if (_controller!.value.isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                    });
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: Icon(
                      _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
