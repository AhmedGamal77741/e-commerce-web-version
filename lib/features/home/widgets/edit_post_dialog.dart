import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/image_picker_helper.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditPostDialogResult {
  final String text;
  final List<String> imgUrls; // Network URLs (unchanged images)
  final List<File> newImages; // Local files (new/replaced images)
  final String? categoryId; // Category ID selected

  EditPostDialogResult({
    required this.text,
    required this.imgUrls,
    required this.newImages,
    this.categoryId,
  });
}

class EditPostDialog extends StatefulWidget {
  final String currentText;
  final List<String> currentImgUrls;
  final String? currentCategoryId;

  const EditPostDialog({
    Key? key,
    required this.currentText,
    required this.currentImgUrls,
    this.currentCategoryId,
  }) : super(key: key);

  @override
  State<EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<EditPostDialog> {
  late TextEditingController _textController;
  late List<String> _networkImgUrls; // Existing network images
  late List<File> _localImages; // New local files to be uploaded
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.currentText);
    _networkImgUrls = List.from(widget.currentImgUrls);
    _localImages = [];
    _selectedCategoryId = widget.currentCategoryId;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('categories')
              .orderBy('order', descending: false)
              .get();
      if (mounted) {
        setState(() {
          _categories =
              snapshot.docs
                  .map((doc) => {'id': doc.id, 'name': doc['name']})
                  .toList();
        });
      }
    } catch (e) {
      print('Error loading categories in EditPostDialog: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(int? replaceIndex) async {
    try {
      final XFile? pickedFile = await ImagePickerHelper.pickImage();

      if (pickedFile != null) {
        setState(() {
          if (replaceIndex != null) {
            // Replace existing image
            if (replaceIndex < _networkImgUrls.length) {
              _networkImgUrls.removeAt(replaceIndex);
            } else if ((replaceIndex - _networkImgUrls.length) <
                _localImages.length) {
              _localImages.removeAt(replaceIndex - _networkImgUrls.length);
            }
          }
          _localImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('이미지 선택 실패: $e')));
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _networkImgUrls.length) {
        _networkImgUrls.removeAt(index);
      } else {
        _localImages.removeAt(index - _networkImgUrls.length);
      }
    });
  }

  void _moveImageUp(int index) {
    setState(() {
      if (index > 0) {
        if (index < _networkImgUrls.length) {
          // Current is a network image
          if (index - 1 >= 0) {
            // Previous is also a network image - swap
            final temp = _networkImgUrls[index];
            _networkImgUrls[index] = _networkImgUrls[index - 1];
            _networkImgUrls[index - 1] = temp;
          }
          // Can't move network image past boundary to local images
        } else {
          // Current is a local image
          final localIdx = index - _networkImgUrls.length;
          if (localIdx > 0) {
            // Previous is also a local image - swap
            final temp = _localImages[localIdx];
            _localImages[localIdx] = _localImages[localIdx - 1];
            _localImages[localIdx - 1] = temp;
          }
          // Can't move local image past boundary to network images
        }
      }
    });
  }

  void _moveImageDown(int index) {
    final totalImages = _networkImgUrls.length + _localImages.length;
    setState(() {
      if (index < totalImages - 1) {
        // Swap only within same category (network with network, local with local)
        if (index < _networkImgUrls.length) {
          // Current is a network image
          if (index + 1 < _networkImgUrls.length) {
            // Next is also a network image - swap
            final temp = _networkImgUrls[index];
            _networkImgUrls[index] = _networkImgUrls[index + 1];
            _networkImgUrls[index + 1] = temp;
          }
          // Can't move network image past boundary to local images
        } else {
          // Current is a local image
          final localIdx = index - _networkImgUrls.length;
          if (localIdx < _localImages.length - 1) {
            // Next is also a local image - swap
            final temp = _localImages[localIdx];
            _localImages[localIdx] = _localImages[localIdx + 1];
            _localImages[localIdx + 1] = temp;
          }
          // Can't move local image past boundary to network images
        }
      }
    });
  }

  bool _canMoveImageUp(int index) {
    if (index <= 0) return false;
    if (index < _networkImgUrls.length) {
      // Network image can move up within network images
      return index > 0;
    } else {
      // Local image can move up within local images
      final localIdx = index - _networkImgUrls.length;
      return localIdx > 0;
    }
  }

  bool _canMoveImageDown(int index) {
    final totalImages = _networkImgUrls.length + _localImages.length;
    if (index >= totalImages - 1) return false;

    if (index < _networkImgUrls.length) {
      // Network image can move down within network images
      return index + 1 < _networkImgUrls.length;
    } else {
      // Local image can move down within local images
      final localIdx = index - _networkImgUrls.length;
      return localIdx + 1 < _localImages.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalImages = _networkImgUrls.length + _localImages.length;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '게시글 수정',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16),
              // Text editor
              TextField(
                controller: _textController,
                maxLines: 8,
                style: TextStyle(color: Colors.black, fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  hintText: '게시글을 입력해주세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
              SizedBox(height: 20),
              // Category Selection
              if (_categories.isNotEmpty) ...[
                Text(
                  '카테고리 선택',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: 35,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategoryId == category['id'];
                      return Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_selectedCategoryId == category['id']) {
                                _selectedCategoryId = null;
                              } else {
                                _selectedCategoryId = category['id'];
                              }
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? Colors.black : Colors.grey[200],
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Colors.transparent
                                        : Colors.grey[300] ?? Colors.grey,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                category['name'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.grey[600],
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 20),
              ],
              // Image management section
              Text(
                '사진 관리 (${totalImages} 개)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 12),
              if (totalImages == 0)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.image_not_supported_outlined,
                        size: 32,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '사진을 추가해주세요',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(null),
                        icon: Icon(Icons.add_photo_alternate),
                        label: Text('사진 추가'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: totalImages + 1,
                    itemBuilder: (context, index) {
                      if (index == totalImages) {
                        // Add button
                        return Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _pickImage(null),
                            child: Container(
                              width: 100,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[50],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 28,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '추가',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      // Image tile
                      final isNetworkImage = index < _networkImgUrls.length;
                      final imageUrl =
                          isNetworkImage
                              ? _networkImgUrls[index]
                              : _localImages[index - _networkImgUrls.length]
                                  .path;

                      return Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            // Image
                            Container(
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[200],
                              ),
                              child:
                                  isNetworkImage
                                      ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) => const Center(
                                              child: SizedBox.shrink(),
                                            ),
                                        errorWidget:
                                            (context, url, error) =>
                                                Icon(Icons.error),
                                      )
                                      : Image.file(
                                        File(imageUrl),
                                        fit: BoxFit.cover,
                                      ),
                            ),
                            // Blue overlay for new images
                            if (!isNetworkImage)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.black.withOpacity(0.2),
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ColorsManager.primary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '신규',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Action buttons
                            Positioned(
                              top: 4,
                              right: 4,
                              child: SizedBox(
                                width: 60,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Delete button
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Material(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () => _removeImage(index),
                                          child: Icon(
                                            Icons.close,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    // Replace button
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Material(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () => _pickImage(index),
                                          child: Icon(
                                            Icons.edit,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Order buttons (left side)
                            Positioned(
                              left: 4,
                              top: 4,
                              bottom: 4,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Material(
                                      color:
                                          _canMoveImageUp(index)
                                              ? Colors.grey[700]
                                              : Colors.grey[400],
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap:
                                            _canMoveImageUp(index)
                                                ? () => _moveImageUp(index)
                                                : null,
                                        child: Icon(
                                          Icons.arrow_upward,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Material(
                                      color:
                                          _canMoveImageDown(index)
                                              ? Colors.grey[700]
                                              : Colors.grey[400],
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap:
                                            _canMoveImageDown(index)
                                                ? () => _moveImageDown(index)
                                                : null,
                                        child: Icon(
                                          Icons.arrow_downward,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              SizedBox(height: 20),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '취소',
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      // Validate text is not empty
                      if (_textController.text.trim().isEmpty &&
                          totalImages == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('텍스트 또는 사진 중 하나는 필수입니다')),
                        );
                        return;
                      }

                      Navigator.pop(
                        context,
                        EditPostDialogResult(
                          text: _textController.text,
                          imgUrls: _networkImgUrls,
                          newImages: _localImages,
                          categoryId: _selectedCategoryId,
                        ),
                      );
                    },
                    child: Text('수정'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
