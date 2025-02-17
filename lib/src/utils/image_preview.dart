import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:full_picker/full_picker.dart';

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
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: <SystemUiOverlay>[SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
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
              child: Text(
                globalFullPickerLanguage.cancel,
                style: const TextStyle(
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

  Future<dynamic> decodeImage() async {
    // ignore: prefer_typing_uninitialized_variables, always_specify_types
    final decodedImage = await decodeImageFromList(widget.file.readAsBytesSync());
    return decodedImage.width.toDouble();
  }
}
