import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:full_picker/full_picker.dart';
import 'package:full_picker/src/utils/pl.dart';
import 'package:limited_video_recorder/limited_video_recorder_config.dart';
import 'package:limited_video_recorder/limited_video_recorder_controller.dart';
import 'package:permission_handler/permission_handler.dart';
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
  Timer? _timer;
  Duration _recordedDuration = Duration.zero;
  bool _hasPermission = false;

  Future<void> startRecording() async {
    try {
      recorder = LimitedVideoRecorderController();
      recorder.onRecordingComplete(_loadVideo);
      await recorder.start(config: widget.config);
      _startTimer();
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
        _timer?.cancel();
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
      _timer?.cancel();
    });
  }

  void _startTimer() {
    _timer?.cancel(); // اطمینان از حذف تایمر قبلی
    _recordedDuration = Duration.zero;

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {
        _recordedDuration += const Duration(seconds: 1);
      });

      final Duration maxDuration = Duration(milliseconds: widget.config.maxDuration);
      if (widget.config.maxDuration > 0 && _recordedDuration >= maxDuration) {
        stopRecording();
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
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
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final bool cameraPermission = await Permission.camera.isGranted;
    final bool microphonePermission = await Permission.microphone.isGranted;

    if (cameraPermission && microphonePermission) {
      setState(() {
        _hasPermission = true;
      });
    } else {
      setState(_requestPermissions);
    }
  }

  Future<void> _requestPermissions() async {
    final Map<Permission, PermissionStatus> status = await <Permission>[Permission.camera, Permission.microphone].request();
    if (status[Permission.camera]!.isGranted && status[Permission.microphone]!.isGranted) {
      setState(() {
        _hasPermission = true;
      });
    }
  }

  @override
  Widget build(final BuildContext context) => Scaffold(
        body: SafeArea(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Stack(
              children: <Widget>[
                if (videoPath != null && _controller != null)
                  Stack(
                    children: <Widget>[
                      AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!)),
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          margin: const EdgeInsets.all(32),
                          padding: const EdgeInsets.all(8),
                          color: Colors.white.withValues(alpha: 0.5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                videoDuration != null ? _formatDuration(videoDuration!) : '-',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text("${videoWidth ?? '-'} x ${videoHeight ?? '-'}", style: const TextStyle(fontSize: 12)),
                              Text(
                                videoFileSize != null ? _formatBytes(videoFileSize!) : '-',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                if (videoPath == null && _hasPermission)
                  const SizedBox.expand(child: AndroidView(viewType: 'camera_preview', layoutDirection: TextDirection.ltr)),
                _buttons(context)
              ],
            ),
          ),
        ),
      );

  Container _buttons(final BuildContext context) => Container(
        // remove this height
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        alignment: Alignment.centerRight,
        child: Column(
          children: <Widget>[
            const Expanded(
              flex: 5,
              child: SizedBox(
                height: 15,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (videoPath != null && _controller != null)
                    Expanded(
                      flex: 3,
                      child: IconButton(
                        icon: Icon(
                          _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                            } else {
                              _controller!.play();
                            }
                          });
                        },
                      ),
                    ),
                  Visibility(
                    visible: videoPath != null && _controller != null,
                    replacement: Expanded(
                      flex: 3,
                      child: Material(
                        borderRadius: BorderRadius.circular(100),
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(100),
                          onTap: () {
                            if (isRecording) {
                              stopRecording();
                            } else {
                              startRecording();
                            }
                          },
                          child: Icon(
                            isRecording ? Icons.stop_rounded : Icons.circle_rounded,
                            color: isRecording ? Colors.black : Colors.red,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    child: Expanded(
                      flex: 3,
                      child: Material(
                        borderRadius: BorderRadius.circular(100),
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(100),
                          onTap: _done,
                          child: const Icon(
                            Icons.check,
                            color: Colors.black,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (videoPath != null && _controller != null)
                    Expanded(
                      flex: 3,
                      child: Visibility(
                        visible: videoPath != null && _controller != null,
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_rounded,
                            color: Colors.black,
                            size: 32,
                          ),
                          onPressed: _resetVideo,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}
