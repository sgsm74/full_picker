// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:full_picker/full_picker.dart';
import 'package:full_picker/src/utils/pl.dart';

/// Custom Camera for Image and Video
class Camera extends StatefulWidget {
  const Camera({
    required this.imageCamera,
    required this.videoCamera,
    required this.prefixName,
    super.key,
  });

  final bool videoCamera;
  final bool imageCamera;
  final String prefixName;

  @override
  State<Camera> createState() => _CameraState();
}

class _CameraState extends State<Camera> with WidgetsBindingObserver {
  Color colorCameraButton = Colors.white;
  List<CameraDescription> cameras = <CameraDescription>[];
  CameraController? controller;

  bool toggleCameraAndTextVisibility = true;
  bool stopVideoClick = false;
  bool recordVideoClick = false;
  bool firstCamera = true;

  IconData flashLightIcon = Icons.flash_auto;

  List<XFile> imageXFiles = <XFile>[];
  List<Uint8List> imageBytes = <Uint8List>[];
  List<String> imageNames = <String>[];
  List<File> imageFiles = <File>[];
  List<XFile> imageFilledXFiles = <XFile>[];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((final _) {
      _init();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  /// init Camera
  Future<void> _init() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        cameras = await availableCameras();
        setState(() {});
      } catch (_) {
        if (!context.mounted) {
          return;
        }
        showFullPickerToast(globalFullPickerLanguage.cameraNotFound, context);

        Navigator.of(context).pop();
      }
    } on CameraException {
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    controller?.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  Widget build(final BuildContext context) {
    if (cameras.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          _cameraPreviewWidget(),
          _close(),
          ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            shrinkWrap: true,
            itemCount: imageXFiles.length,
            itemBuilder: (final BuildContext context, final int index) => Row(
              children: <Widget>[
                Container(
                  alignment: Alignment.bottomLeft,
                  // ignore: unnecessary_null_comparison
                  child: imageXFiles[index] == null
                      ? const Text('No image captured')
                      : GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (final BuildContext context) => ImagePreviewView(File(imageXFiles[index].path)),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              Image.file(
                                File(
                                  imageXFiles[index].path,
                                ),
                                height: 90,
                                width: 60,
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      removeImage(index);
                                    });
                                  },
                                  child: Image.network(
                                    'https://logowik.com/content/uploads/images/close1437.jpg',
                                    height: 30,
                                    width: 30,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            scrollDirection: Axis.horizontal,
          ),
          Visibility(visible: imageXFiles.isNotEmpty, child: _done()),
          _buttons(context),
        ],
      ),
    );
  }

  double _maxZoom = 1;
  double _minZoom = 1;
  double _zoom = 1;
  double _scaleFactor = 1;

  bool hasBackFrontCamera = false;

  /// Main Widget for Camera
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller!.value.isInitialized) {
      // Check has Back or Front Camera
      for (final CameraDescription element in cameras) {
        if (element.lensDirection == CameraLensDirection.front) {
          hasBackFrontCamera = true;
        }
      }

      try {
        onNewCameraSelected(
          Pl.isWeb
              ? cameras.lastWhere(
                  (final CameraDescription description) => description.lensDirection == CameraLensDirection.back,
                )
              : cameras.firstWhere(
                  (final CameraDescription description) => description.lensDirection == CameraLensDirection.back,
                ),
        );
      } catch (_) {
        onNewCameraSelected(
          cameras.lastWhere(
            (final CameraDescription description) => description.lensDirection == CameraLensDirection.external,
          ),
        );
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: (final ScaleStartDetails details) {
        _zoom = _scaleFactor;
      },
      onScaleUpdate: (final ScaleUpdateDetails details) {
        final double temp = _zoom * details.scale;
        if (temp <= _maxZoom && temp >= _minZoom) {
          _scaleFactor = temp;
        }
        controller!.setZoomLevel(_scaleFactor);
      },
      child: () {
        try {
          return controller!.buildPreview();
        } catch (_) {
          return const Center(child: CircularProgressIndicator());
        }
      }(),
    );
  }

  /// initialize Camera Controller
  Future<void> onNewCameraSelected(
    final CameraDescription cameraDescription,
  ) async {
    if (controller != null) {
      await controller!.dispose();
    }

    controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller!.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }

    await _setMaxMinVideoSize();

    unawaited(_setFlashLightIcon(context));
  }

  /// Take Picture
  void onTakePictureButtonPressed() {
    takePicture().then((final String? filePath) async {
      if (filePath == '') {
        return;
      }
      setState(() {});
      final XFile file = XFile(filePath!);
      imageXFiles.add(file);
    });
  }

  void removeImage(int index) {
    setState(() {
      imageXFiles.removeAt(index);
    });
  }

  /// Stop Video Recording
  Future<void> onStopButtonPressed() async {
    stopVideoClick = true;
    await stopVideoRecording().then((final XFile? file) async {
      if (mounted) {
        Navigator.pop(
          context,
          FullPickerOutput(
            bytes: <Uint8List?>[await file!.readAsBytes()],
            fileType: FullPickerType.video,
            name: <String?>['${widget.prefixName}.mp4'],
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
                  name: '${widget.prefixName}.mp4',
                ),
            ],
          ),
        );
      }
    });
  }

  /// Start Video Recording
  Future<void> startVideoRecording() async {
    if (!controller!.value.isInitialized) {
      return;
    }

    if (controller!.value.isRecordingVideo) {
      /// A recording is already started, do nothing.
      return;
    }

    try {
      await controller!.startVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return;
    }
  }

  /// Stop Video Recording
  Future<XFile?> stopVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      return null;
    }

    await Future<void>.delayed(const Duration(seconds: 1));

    try {
      return controller!.stopVideoRecording();
    } catch (_) {}
    return null;
  }

  /// Take Picture
  Future<String?> takePicture() async {
    if (!controller!.value.isInitialized) {
      return '';
    }

    if (controller!.value.isTakingPicture) {
      return '';
    }

    try {
      final XFile file = await controller!.takePicture();
      return file.path;
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  /// show Camera Exception
  void _showCameraException(final CameraException e) {
    if (e.code == 'cameraPermission' || e.code == 'CameraAccessDenied') {
      if (mounted) {
        Navigator.pop(context);
      }

      showFullPickerToast(
        globalFullPickerLanguage.denyAccessPermission,
        context,
      );
    }
  }

  /// struct buttons in main page
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
            Visibility(
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              visible: (widget.imageCamera && widget.videoCamera) && toggleCameraAndTextVisibility,
              child: Text(
                globalFullPickerLanguage.tapForPhotoHoldForVideo,
                style: const TextStyle(color: Color(0xa3ffffff), fontSize: 20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 15),
              child: Row(
                children: <Widget>[
                  Visibility(
                    visible: hasBackFrontCamera,
                    replacement: Expanded(flex: 3, child: Container()),
                    child: Expanded(
                      flex: 3,
                      child: Visibility(
                        visible: toggleCameraAndTextVisibility,
                        child: IconButton(
                          icon: const Icon(
                            Icons.flip_camera_android,
                            color: Colors.white,
                            size: 33,
                          ),
                          onPressed: changeCamera,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Material(
                      borderRadius: BorderRadius.circular(100),
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(100),
                        onLongPress: widget.videoCamera && widget.imageCamera ? videoRecord : null,
                        onTap: () {
                          if (widget.imageCamera) {
                            if (controller!.value.isRecordingVideo) {
                              onStopButtonPressed();
                            } else {
                              onTakePictureButtonPressed();
                            }
                          } else {
                            videoRecord();
                          }
                        },
                        child: Icon(
                          Icons.camera,
                          color: colorCameraButton,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Visibility(
                      visible: toggleCameraAndTextVisibility,
                      child: IconButton(
                        icon: Icon(
                          flashLightIcon,
                          color: Colors.white,
                          size: 33,
                        ),
                        onPressed: () {
                          _toggleFlashLight(context);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  /// change Camera
  void changeCamera() {
    if (firstCamera) {
      firstCamera = false;
      onNewCameraSelected(
        cameras.lastWhere(
          (final CameraDescription description) => description.lensDirection == CameraLensDirection.front,
        ),
      );
    } else {
      onNewCameraSelected(
        Pl.isWeb
            ? cameras.lastWhere(
                (final CameraDescription description) => description.lensDirection == CameraLensDirection.back,
              )
            : cameras.firstWhere(
                (final CameraDescription description) => description.lensDirection == CameraLensDirection.back,
              ),
      );
      firstCamera = true;
    }
  }

  /// Video Recording
  void videoRecord() {
    if (stopVideoClick) {
      return;
    }
    setState(() {
      toggleCameraAndTextVisibility = false;
      colorCameraButton = Colors.red;
    });
    if (controller!.value.isRecordingVideo) {
      onStopButtonPressed();
    } else {
      if (recordVideoClick) {
        return;
      }
      recordVideoClick = true;

      startVideoRecording().then((final _) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<void> _setFlashLightIcon(final BuildContext context) async {
    if (controller!.value.flashMode == FlashMode.off) {
      flashLightIcon = Icons.flash_off;
    } else if (controller!.value.flashMode == FlashMode.auto) {
      flashLightIcon = Icons.flash_auto;
    } else {
      flashLightIcon = Icons.flash_on;
    }

    setState(() {});
  }

  Future<void> _toggleFlashLight(final BuildContext context) async {
    if (controller!.value.flashMode == FlashMode.off) {
      flashLightIcon = Icons.flash_auto;
      showFullPickerToast(globalFullPickerLanguage.auto, context);
      await controller!.setFlashMode(FlashMode.auto);
    } else if (controller!.value.flashMode == FlashMode.auto) {
      flashLightIcon = Icons.flash_on;
      showFullPickerToast(globalFullPickerLanguage.on, context);
      await controller!.setFlashMode(FlashMode.always);
    } else {
      flashLightIcon = Icons.flash_off;
      showFullPickerToast(globalFullPickerLanguage.off, context);
      await controller!.setFlashMode(FlashMode.off);
    }

    setState(() {});
  }

  Future<void> _setMaxMinVideoSize() async {
    _maxZoom = await controller!.getMaxZoomLevel();
    _minZoom = await controller!.getMinZoomLevel();
  }

  Widget _close() => PositionedDirectional(
        end: 0,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            end: 15,
            top: Pl.isWeb ? 10 : 26,
          ),
          child: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 33,
            ),
          ),
        ),
      );

  Widget _done() => PositionedDirectional(
        start: 0,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            end: 15,
            top: Pl.isWeb ? 10 : 26,
          ),
          child: InkWell(
            onTap: () async {
              if (mounted) {
                for (final XFile file in imageXFiles) {
                  imageBytes.add(await file.readAsBytes());
                  imageNames.add('${widget.prefixName}.jpg');
                  imageFiles.add(File(file.path));
                  imageFilledXFiles.add(
                    getFillXFile(
                      file: File(file.path),
                      bytes: await file.readAsBytes(),
                      mime: 'image/jpeg',
                      name: '${widget.prefixName}.jpg',
                    ),
                  );
                }
                Navigator.pop(
                  context,
                  FullPickerOutput(
                    bytes: imageBytes,
                    fileType: FullPickerType.image,
                    name: imageNames,
                    file: imageFiles,
                    xFile: imageFilledXFiles,
                  ),
                );
              }
            },
            child: Container(
              height: 70,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  'ذخیره',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      );
}

class ImagePreviewView extends StatefulWidget {
  const ImagePreviewView(this.file, {super.key});
  final File file;

  @override
  // ignore: library_private_types_in_public_api
  _ImagePreviewViewState createState() => _ImagePreviewViewState();
}

class _ImagePreviewViewState extends State<ImagePreviewView> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: <SystemUiOverlay>[
        SystemUiOverlay.bottom,
      ],
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.black,
          elevation: 1,
          leadingWidth: 100,
          leading: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Text(
                'بازگشت',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        body: InteractiveViewer(
          child: Container(
            height: double.infinity,
            width: double.infinity,
            alignment: Alignment.center,
            color: Colors.black,
            child: SafeArea(
              child: SingleChildScrollView(
                reverse: true,
                child: SizedBox(
                  width: double.infinity,
                  child: Hero(
                    tag: widget.file.path,
                    child: Image.file(
                      widget.file,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future decodeImage() async {
    // ignore: prefer_typing_uninitialized_variables
    final decodedImage = await decodeImageFromList(widget.file.readAsBytesSync());
    return decodedImage.width.toDouble();
  }
}
