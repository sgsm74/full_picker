import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../../full_picker.dart';

class SelectSheet extends StatefulWidget {
  final BuildContext context;
  final ValueSetter<OutputFile> onSelected;
  final ValueSetter<int> onError;
  final bool image;
  final bool video;
  final bool file;
  final bool imageCamera;
  final bool videoCamera;
  final bool videoCompressor;
  final bool imageCropper;
  final bool multiFile;
  final String firstPartFileName;

  SelectSheet(
      {Key? key,
      required this.videoCompressor,
      required this.firstPartFileName,
      required this.multiFile,
      required this.imageCropper,
      required this.context,
      required this.onSelected,
      required this.onError,
      required this.imageCamera,
      required this.videoCamera,
      required this.image,
      required this.video,
      required this.file})
      : super(key: key);

  @override
  _SheetSelectState2 createState() => _SheetSelectState2();
}

class _SheetSelectState2 extends State<SelectSheet> {
  late List<ItemSheet> itemList = [];
  bool userClose = true;

  @override
  void initState() {
    super.initState();

    if (widget.image || widget.video) {
      itemList.add(ItemSheet(language.gallery, Icons.image, 1));
    }

    if (widget.imageCamera || widget.videoCamera) {
      if (!kIsWeb) itemList.add(ItemSheet(language.camera, Icons.camera, 2));
    }

    if (widget.file) {
      itemList.add(ItemSheet(language.file, Icons.insert_drive_file, 3));
    }
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
    return ResponsiveSizer(builder: (context, orientation, screenType) {
      return ClipRRect(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20.0), topRight: Radius.circular(20.0)),
          child: Container(
              color: Colors.white,
              child: Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                topSheet(language.select_file, context),
                Container(
                  child: GridView.builder(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                      ),
                      itemCount: itemList.length,
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: 2.w,
                          height: 2.h,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                                customBorder: new CircleBorder(),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(itemList[index].icon, size: 9.h),
                                    Padding(
                                      padding: EdgeInsets.only(top: 2.h),
                                      child: Text(itemList[index].name),
                                    )
                                  ],
                                ),
                                onTap: () {
                                  goPage(itemList[index]);
                                }),
                          ),
                        );
                      }),
                )
              ])));
    });
  }

  Future<void> goPage(ItemSheet mList) async {
    getFullPicker(
      id: mList.id,
      context: context,
      onIsUserCheng: (value) {
        userClose = value;
      },
      video: widget.video,
      file: widget.file,
      image: widget.image,
      imageCamera: widget.imageCamera,
      videoCamera: widget.videoCamera,
      videoCompressor: widget.videoCompressor,
      onError: widget.onError,
      onSelected: widget.onSelected,
      firstPartFileName: widget.firstPartFileName,
      imageCropper: widget.imageCropper,
      multiFile: widget.multiFile,
      inSheet: true,
    );
  }
}