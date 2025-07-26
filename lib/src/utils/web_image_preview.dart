import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:full_picker/full_picker.dart';

class WebImagePreview extends StatefulWidget {
  const WebImagePreview({
    required this.dataUrl,
    super.key,
  });

  final Future<Uint8List> dataUrl;

  @override
  State<WebImagePreview> createState() => _WebImagePreviewState();
}

class _WebImagePreviewState extends State<WebImagePreview> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: <SystemUiOverlay>[SystemUiOverlay.bottom],
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
            onTap: () => Navigator.pop(context),
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
            alignment: Alignment.center,
            color: Colors.black,
            child: SafeArea(
              child: SingleChildScrollView(
                reverse: true,
                child: SizedBox(
                  width: double.infinity,
                  child: FutureBuilder<Uint8List>(
                    future: widget.dataUrl,
                    builder: (final BuildContext context, final AsyncSnapshot<Uint8List> snapshot) => Hero(
                      tag: widget.dataUrl,
                      child: snapshot.hasData
                          ? Image.memory(
                              snapshot.data!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            )
                          : const CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
