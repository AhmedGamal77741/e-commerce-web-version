import 'dart:io';
import 'package:ecommerece_app/features/chat/models/text_overlay_model.dart';
import 'package:ecommerece_app/features/chat/services/story_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

class UploadStoryScreen extends StatefulWidget {
  final File initialImage;
  const UploadStoryScreen({super.key, required this.initialImage});

  @override
  State<UploadStoryScreen> createState() => _UploadStoryScreenState();
}

class _UploadStoryScreenState extends State<UploadStoryScreen> {
  late File _currentImage;
  List<TextOverlay> _textOverlays = [];
  final ImagePicker _picker = ImagePicker();
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.initialImage;
  }

  Future<void> _changeImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _currentImage = File(pickedFile.path);
      });
    }
  }

  void _addText() {
    setState(() {
      _textOverlays.add(
        TextOverlay(text: "Tap to edit", position: Offset(100.w, 100.h)),
      );
    });
  }

  void _editText(int index) {
    final TextEditingController controller = TextEditingController(
      text: _textOverlays[index].text,
    );

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Edit Text"),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "Enter your text",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _textOverlays[index].text = controller.text;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text("Save"),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _textOverlays.removeAt(index);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Screenshot(
                  controller: _screenshotController,

                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(_currentImage, fit: BoxFit.cover),
                      ),
                      ..._textOverlays.asMap().entries.map((entry) {
                        int index = entry.key;
                        TextOverlay overlay = entry.value;
                        return Positioned(
                          left: overlay.position.dx,
                          top: overlay.position.dy,
                          child: GestureDetector(
                            onTap: () => _editText(index),
                            child: Draggable(
                              feedback: Material(
                                color: Colors.transparent,
                                child: Text(
                                  overlay.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              childWhenDragging: Container(),
                              onDragEnd: (details) {
                                setState(() {
                                  overlay.position = details.offset;
                                });
                              },
                              child: Text(
                                overlay.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  shadows: [
                                    Shadow(blurRadius: 10, color: Colors.black),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                Positioned(
                  top: 20.h,
                  left: 0,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.black,
                      size: 50.sp,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                    },
                  ),
                ),
                // Top Buttons
                Positioned(
                  bottom: 5.h,
                  right: 5.w,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _addText,
                        child: _buildOverlayButton(Icons.text_fields_rounded),
                      ),
                      SizedBox(width: 15.w),
                      GestureDetector(
                        onTap: _changeImage, // Function for the image button
                        child: _buildOverlayButton(Icons.image_outlined),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    void _showErrorDialog(String message) {
      print(message);
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text("Upload Failed"),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK"),
                ),
              ],
            ),
      );
    }

    Future<void> _captureAndUpload() async {
      if (_isLoading) return;

      setState(() => _isLoading = true);
      try {
        final imageBytes = await _screenshotController.capture();

        if (imageBytes != null) {
          final tempDir = await getTemporaryDirectory();
          final file =
              await File(
                '${tempDir.path}/story_${DateTime.now().millisecondsSinceEpoch}.png',
              ).create();
          await file.writeAsBytes(imageBytes);

          final currentUser = FirebaseAuth.instance.currentUser!;
          await StoryService().uploadStory(
            file,
            currentUser.displayName.toString(),
            currentUser.photoURL.toString(),
          );

          if (mounted) Navigator.pop(context);
        }
      } on FirebaseException catch (e) {
        // Handle Firebase specific errors (permissions, storage full, etc.)
        _showErrorDialog("Firebase Error: ${e.message}");
      } on SocketException {
        // Handle Internet connection issues
        _showErrorDialog("No internet connection. Please check your network.");
      } catch (e) {
        // Handle any other unexpected errors
        _showErrorDialog("An unexpected error occurred: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '나를 구독한 사람만 내 스토리를 볼 수 있어요',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _captureAndUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text(
                      '공유',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}
