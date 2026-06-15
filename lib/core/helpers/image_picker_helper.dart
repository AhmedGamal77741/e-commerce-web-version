import 'package:image_picker/image_picker.dart';

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Picks a single image with unified, optimized compression options
  static Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 85,
    double maxWidth = 1080,
    double maxHeight = 1080,
  }) async {
    try {
      return await _picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
    } catch (e) {
      print('Error picking image in ImagePickerHelper: $e');
      return null;
    }
  }

  /// Picks multiple images with unified, optimized compression options
  static Future<List<XFile>> pickMultiImage({
    int imageQuality = 85,
    double maxWidth = 1080,
    double maxHeight = 1080,
  }) async {
    try {
      return await _picker.pickMultiImage(
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
    } catch (e) {
      print('Error picking multiple images in ImagePickerHelper: $e');
      return [];
    }
  }
}
