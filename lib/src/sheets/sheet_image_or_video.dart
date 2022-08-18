import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:full_picker/full_picker.dart';
import 'package:video_compress/video_compress.dart';

import '../utils/progress_dialog.dart';

class SheetImageOrVideo extends StatefulWidget {
  int pictureOrVideo;
  bool showAlone;
  bool? videoCompressor;
  BuildContext context;
  ValueSetter<OutputFile> onSelected;
  ValueSetter<int> onError;
  bool image;
  bool audio;
  bool video;
  bool file;

  SheetImageOrVideo(
      {Key? key,
      required this.context,
      required this.onSelected,
      required this.onError,
      required this.pictureOrVideo,
      required this.videoCompressor,
      required this.image,
      required this.audio,
      required this.video,
      required this.file,
      required this.showAlone})
      : super(key: key);

  @override
  _SheetImageOrVideoState createState() => _SheetImageOrVideoState();
}

class _SheetImageOrVideoState extends State<SheetImageOrVideo> {
  late String _desFile;
  late BuildContext contextHolder;
  bool userClose = true;

  @override
  void initState() {
    if (widget.videoCompressor == null) {
      widget.videoCompressor = true;
    }
    super.initState();
  }

  @override
  void dispose() {
    if (userClose) {
      widget.onError.call(1);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.0), topRight: Radius.circular(20.0)),
        child: Container(
            color: Colors.white,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  topSheet(
                      widget.image,
                      widget.audio,
                      widget.video,
                      widget.file,
                      language.select_file_method,
                      widget.showAlone,
                      widget.context,
                      false,
                      widget.onSelected,
                      widget.onError,
                      widget.videoCompressor!),
                  Container(
                    child: Wrap(
                      children: <Widget>[
                        newItem(language.camera, Icons.camera, () {
                          if (widget.pictureOrVideo == 1) {
                            contextHolder = context;
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) {
                                return Camera(
                                  isTakeImage: true,
                                  onSelected: (value) {
                                    Cropper(
                                      context,
                                      onSelected: (value) {
                                        userClose = false;
                                        Navigator.of(contextHolder).pop();
                                        widget.onSelected.call(value);
                                      },
                                      onError: (value) {
                                        userClose = false;
                                        Navigator.of(contextHolder).pop();
                                        widget.onError.call(value);
                                      },
                                      imageName: value.file.path,
                                    );
                                  },
                                  onError: (value) {
                                    userClose = false;
                                    Navigator.of(contextHolder).pop();
                                    widget.onError.call(1);
                                  },
                                );
                              },
                            ));
                          } else {
                            contextHolder = context;
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) {
                                return Camera(
                                  isTakeImage: false,
                                  onSelected: (value) {
                                    userClose = false;
                                    Navigator.of(contextHolder).pop();
                                    widget.onSelected.call(value);
                                  },
                                  onError: (value) {
                                    userClose = false;
                                    Navigator.of(contextHolder).pop();
                                    widget.onError.call(1);
                                  },
                                );
                              },
                            ));
                          }
                        }),
                        newItem(language.gallery, Icons.collections, () async {
                          if (widget.pictureOrVideo == 1) {
                            getFile(context, FileType.image, "IG")
                                .then((value) => {
                                      if (value!.path == '')
                                        {
                                          userClose = false,
                                          widget.onError.call(1),
                                        }
                                      else
                                        {
                                          contextHolder = context,
                                          Cropper(
                                            context,
                                            onSelected: (value) {
                                              userClose = false;
                                              Navigator.of(contextHolder).pop();
                                              widget.onSelected.call(value);
                                            },
                                            onError: (value) {
                                              userClose = false;
                                              if (value == 44) {
                                                Navigator.of(contextHolder)
                                                    .pop();
                                              }
                                              widget.onError.call(1);
                                              Navigator.of(context).pop();
                                            },
                                            imageName: value.path,
                                          )
                                        }
                                    });
                          } else {
                            await getFile(context, FileType.video, "VG")
                                .then((value) => {
                                      if (value!.path != '')
                                        {
                                          if (widget.videoCompressor!)
                                            {
                                              videoCompress(value.path),
                                            }
                                          else
                                            {
                                              _desFile = value.path,
                                              userClose = false,
                                              Navigator.of(context).pop(),
                                              widget.onSelected.call(OutputFile(
                                                  File(_desFile),
                                                  PickerFileType.VIDEO)),
                                            }
                                        }
                                      else
                                        {
                                          userClose = false,
                                          widget.onError.call(1),
                                        }
                                    });
                          }
                        }),
                      ],
                    ),
                  )
                ])));
  }

  videoCompress(String path) async {
    ValueNotifier<double> onProgress = ValueNotifier<double>(0);
    onProgress.value = 0;

    int _size;
    try {
      _size = int.parse(File(path).lengthSync().toString());

    } catch (e) {
      throw ArgumentError("Can not parse the size parameter: $e");
    }
    if(_size<10000000){
      userClose = false;
      Navigator.of(context).pop();
      widget.onSelected
          .call(OutputFile(File(path), PickerFileType.VIDEO));
      return;
    }
    Subscription _subscription;

    _subscription = VideoCompress.compressProgress$.subscribe((progress) {
      onProgress.value = progress / 100;
    });

    ProgressDialog ppp = ProgressDialog(context, (dynamic) {
      if (onProgress.value.toString() != "1.0") {
        VideoCompress.cancelCompression();
      }

      _subscription.unsubscribe();
    }, onProgress, language.on_compressing);

    ppp.show();

    _desFile = await destinationFile;

    await VideoCompress.setLogLevel(3);
    try {
      final MediaInfo? info = await VideoCompress.compressVideo(path,
          deleteOrigin: false,
          includeAudio: true,
          quality: VideoQuality.MediumQuality,
          frameRate: 24);

      ppp.dismiss();
      _subscription.unsubscribe();

      if (info != null) {
        _desFile = info.file!.path;
        userClose = false;
        Navigator.of(context).pop();
        widget.onSelected
            .call(OutputFile(File(_desFile), PickerFileType.VIDEO));
      } else {
        widget.onError.call(1);
        userClose = false;
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("ajabaaaaaaaaaaa");
      userClose = false;
      Navigator.of(context).pop();
      widget.onSelected.call(OutputFile(File(path), PickerFileType.VIDEO));
    }
  }
}