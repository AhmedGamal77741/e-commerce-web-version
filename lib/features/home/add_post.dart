import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ecommerece_app/core/helpers/image_picker_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/loading_dialog.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UploadableImage extends ChangeNotifier {
  final String id = UniqueKey().toString();
  final XFile localFile;
  String? _networkUrl;
  bool _isUploading;
  bool _hasError;
  double? _progress;

  UploadableImage({
    required this.localFile,
    String? networkUrl,
    bool isUploading = true,
    bool hasError = false,
    double? progress,
  }) : _networkUrl = networkUrl,
       _isUploading = isUploading,
       _hasError = hasError,
       _progress = progress;

  String? get networkUrl => _networkUrl;
  set networkUrl(String? value) {
    _networkUrl = value;
    notifyListeners();
  }

  bool get isUploading => _isUploading;
  set isUploading(bool value) {
    _isUploading = value;
    notifyListeners();
  }

  bool get hasError => _hasError;
  set hasError(bool value) {
    _hasError = value;
    notifyListeners();
  }

  double? get progress => _progress;
  set progress(double? value) {
    _progress = value;
    notifyListeners();
  }
}

class AddPost extends StatefulWidget {
  const AddPost({super.key});

  @override
  State<AddPost> createState() => _AddPostState();
}

class _AddPostState extends State<AddPost> {
  List<UploadableImage> images = [];
  final currentUser = FirebaseAuth.instance.currentUser;
  TextEditingController _textController = TextEditingController();
  String? selectedCategoryId;
  List<Map<String, dynamic>> categories = [];
  bool isArrangeMode = false;
  bool isDeleteMode = false;
  bool isEditMode = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (currentUser == null) return;
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .collection('categories')
              .orderBy('order', descending: false)
              .get();
      setState(() {
        categories =
            snapshot.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    'name': doc['name'],
                    'order': doc['order'],
                  },
                )
                .toList();
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _addCategory(String categoryName) async {
    if (currentUser == null || categoryName.isEmpty) return;
    try {
      final newOrder =
          categories.isEmpty ? 0 : (categories.last['order'] as int) + 1;
      final categoryRef =
          FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .collection('categories')
              .doc();
      await categoryRef.set({
        'name': categoryName,
        'order': newOrder,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _loadCategories();
    } catch (e) {
      print('Error adding category: $e');
    }
  }

  Future<void> _deleteCategory(String categoryId) async {
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('categories')
          .doc(categoryId)
          .delete();
      if (selectedCategoryId == categoryId) {
        setState(() => selectedCategoryId = null);
      }
      _loadCategories();
    } catch (e) {
      print('Error deleting category: $e');
    }
  }

  Future<void> _updateCategoryName(String categoryId, String newName) async {
    if (currentUser == null || newName.trim().isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('categories')
          .doc(categoryId)
          .update({'name': newName.trim()});
      _loadCategories();
    } catch (e) {
      print('Error updating category name: $e');
    }
  }

  Future<void> _updateCategoryOrder(List<Map<String, dynamic>> newOrder) async {
    if (currentUser == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (int i = 0; i < newOrder.length; i++) {
        final categoryRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('categories')
            .doc(newOrder[i]['id']);
        batch.update(categoryRef, {'order': i});
      }
      await batch.commit();
      _loadCategories();
    } catch (e) {
      print('Error updating category order: $e');
    }
  }

  void _showAddCategoryDialog() {
    final textEditingController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text('새 카테고리'),
            content: TextField(
              controller: textEditingController,
              decoration: InputDecoration(hintText: '카테고리 이름'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('취소', style: TextStyle(color: Colors.black)),
              ),
              TextButton(
                onPressed: () {
                  _addCategory(textEditingController.text);
                  Navigator.pop(context);
                },
                child: Text('추가', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
    );
  }

  void _showEditCategoryDialog(String categoryId, String currentName) {
    final textEditingController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text('카테고리 이름 변경'),
            content: TextField(
              controller: textEditingController,
              decoration: InputDecoration(hintText: '카테고리 이름'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('취소', style: TextStyle(color: Colors.black)),
              ),
              TextButton(
                onPressed: () {
                  _updateCategoryName(categoryId, textEditingController.text);
                  Navigator.pop(context);
                },
                child: Text('저장', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
    );
  }

  void _showCategoryMenu() {
    showMenu(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 50,
        120,
        16,
        0,
      ),
      items: [
        PopupMenuItem(
          value: 'add',
          child: Text('추가', style: TextStyle(fontSize: 13)),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Text('이름 변경', style: TextStyle(fontSize: 13)),
              if (isEditMode) ...[
                SizedBox(width: 8),
                Icon(Icons.check, size: 16, color: Colors.green),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: 'arrange',
          child: Row(
            children: [
              Text('정렬', style: TextStyle(fontSize: 13)),
              if (isArrangeMode) ...[
                SizedBox(width: 8),
                Icon(Icons.check, size: 16, color: Colors.green),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Text('삭제', style: TextStyle(fontSize: 13)),
              if (isDeleteMode) ...[
                SizedBox(width: 8),
                Icon(Icons.check, size: 16, color: Colors.green),
              ],
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'add') {
        _showAddCategoryDialog();
      } else if (value == 'edit') {
        setState(() {
          isEditMode = !isEditMode;
          if (isEditMode) {
            isArrangeMode = false;
            isDeleteMode = false;
          }
        });
      } else if (value == 'arrange') {
        setState(() {
          isArrangeMode = !isArrangeMode;
          if (isArrangeMode) {
            isDeleteMode = false;
            isEditMode = false;
          }
        });
      } else if (value == 'delete') {
        setState(() {
          isDeleteMode = !isDeleteMode;
          if (isDeleteMode) {
            isArrangeMode = false;
            isEditMode = false;
          }
        });
      }
    });
  }

  Widget _buildCategoryPill(
    String categoryName,
    bool isSelected,
    bool isInDeleteMode,
    bool isInEditMode,
    String categoryId,
  ) {
    return GestureDetector(
      onTap:
          isInDeleteMode
              ? null
              : isInEditMode
              ? () => _showEditCategoryDialog(categoryId, categoryName)
              : () {
                setState(() {
                  if (selectedCategoryId == categoryId) {
                    selectedCategoryId = null;
                  } else {
                    selectedCategoryId = categoryId;
                  }
                });
              },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[200],
          border: Border.all(
            color:
                isSelected
                    ? Colors.transparent
                    : Colors.grey[300] ?? Colors.grey,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isArrangeMode) ...[
              Icon(Icons.drag_handle, size: 14, color: Colors.grey[600]),
              SizedBox(width: 4),
            ],
            Text(
              categoryName,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.black : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (isInDeleteMode) ...[
              SizedBox(width: 6),
              GestureDetector(
                onTap: () => _deleteCategory(categoryId),
                child: Icon(Icons.close, size: 14, color: Colors.red),
              ),
            ],
            if (isInEditMode) ...[
              SizedBox(width: 6),
              Icon(Icons.edit, size: 14, color: Colors.orange),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final pickedFiles = await ImagePickerHelper.pickMultiImage();
                  if (pickedFiles.isEmpty) return;

                  final startIndex = images.length;
                  setState(() {
                    for (var file in pickedFiles) {
                      images.add(UploadableImage(localFile: file));
                    }
                  });

                  for (int i = 0; i < pickedFiles.length; i++) {
                    final file = pickedFiles[i];
                    final imageItem = images[startIndex + i];

                    // Fire and forget the async operation to allow concurrent uploads
                    () async {
                      try {
                        final url = await uploadSingleImageToFirebase(
                          file,
                          startIndex + i,
                          onProgress: (progress) {
                            imageItem.progress = progress;
                          },
                        );
                        if (mounted) {
                          imageItem.networkUrl = url;
                          imageItem.isUploading = false;
                          setState(
                            () {},
                          ); // Update parent once to enable the Post button
                        }
                      } catch (e) {
                        if (mounted) {
                          imageItem.isUploading = false;
                          imageItem.hasError = true;
                          setState(() {}); // Update parent once
                        }
                      }
                    }();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
                child: Text("사진 첨부", style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_textController.text.isEmpty && images.isEmpty) return;
                  if (images.any((img) => img.isUploading)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('사진이 아직 업로드 중입니다. 잠시만 기다려주세요.')),
                    );
                    return;
                  }

                  showLoadingDialog(context);
                  try {
                    final finalUrls =
                        images
                            .map((e) => e.networkUrl)
                            .where((url) => url != null)
                            .cast<String>()
                            .toList();
                    await uploadPost(
                      text: _textController.text,
                      imgUrls: finalUrls,
                      categoryId: selectedCategoryId,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('성공')));
                    Navigator.pop(context);
                  } catch (e) {
                    print(e.toString());
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('게시물 게시에 실패했습니다: ${e.toString()}'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (_textController.text.isEmpty && images.isEmpty) ||
                              images.any((img) => img.isUploading)
                          ? ColorsManager.primary200
                          : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
                child: Text("게시", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        appBar: AppBar(
          titleSpacing: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_ios),
              ),
              Text(
                "오늘의 이야기",
                style: TextStyle(
                  color: const Color(0xFF121212),
                  fontSize: 16,
                  fontFamily: 'NotoSans',
                  fontWeight: FontWeight.w400,
                  height: 1.40,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(4.0),
            child: Container(color: Colors.grey[400], height: 1.5),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                verticalSpace(5),

                // Mode indicator banner
                if (isArrangeMode || isDeleteMode)
                  Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isArrangeMode ? Colors.grey[100] : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isArrangeMode
                                ? Colors.grey[300]!
                                : Colors.red[200]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isArrangeMode
                                  ? Icons.swap_vert
                                  : Icons.delete_outline,
                              size: 18,
                              color:
                                  isArrangeMode
                                      ? Colors.black
                                      : Colors.red[700],
                            ),
                            SizedBox(width: 8),
                            Text(
                              isArrangeMode
                                  ? '카테고리를 드래그하여 정렬하세요'
                                  : '삭제할 카테고리의 X를 클릭하세요',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isArrangeMode
                                        ? Colors.black
                                        : Colors.red[900],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isArrangeMode = false;
                              isDeleteMode = false;
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor:
                                isArrangeMode ? Colors.black : Colors.red[700],
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            '완료',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Categories section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 35,
                        child:
                            categories.isEmpty
                                ? Center(
                                  child: Text(
                                    '카테고리를 추가해주세요',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: categories.length,
                                  itemBuilder: (context, index) {
                                    final category = categories[index];
                                    final isSelected =
                                        selectedCategoryId == category['id'];
                                    return Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child:
                                          isArrangeMode
                                              ? Draggable<int>(
                                                data: index,
                                                feedback: Material(
                                                  child: _buildCategoryPill(
                                                    category['name'],
                                                    isSelected,
                                                    isDeleteMode,
                                                    isEditMode,
                                                    category['id'],
                                                  ),
                                                ),
                                                childWhenDragging: Opacity(
                                                  opacity: 0.5,
                                                  child: _buildCategoryPill(
                                                    category['name'],
                                                    isSelected,
                                                    isDeleteMode,
                                                    isEditMode,
                                                    category['id'],
                                                  ),
                                                ),
                                                child: DragTarget<int>(
                                                  onAccept: (draggedIndex) {
                                                    final newCategories = List<
                                                      Map<String, dynamic>
                                                    >.from(categories);
                                                    final draggedCategory =
                                                        newCategories.removeAt(
                                                          draggedIndex,
                                                        );
                                                    newCategories.insert(
                                                      index,
                                                      draggedCategory,
                                                    );
                                                    _updateCategoryOrder(
                                                      newCategories,
                                                    );
                                                  },
                                                  builder: (
                                                    context,
                                                    candidateData,
                                                    rejectedData,
                                                  ) {
                                                    return _buildCategoryPill(
                                                      category['name'],
                                                      isSelected,
                                                      isDeleteMode,
                                                      isEditMode,
                                                      category['id'],
                                                    );
                                                  },
                                                ),
                                              )
                                              : _buildCategoryPill(
                                                category['name'],
                                                isSelected,
                                                isDeleteMode,
                                                isEditMode,
                                                category['id'],
                                              ),
                                    );
                                  },
                                ),
                      ),
                    ),
                    IconButton(
                      icon: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.transparent,
                        backgroundImage: AssetImage('assets/settings.png'),
                      ),
                      onPressed: _showCategoryMenu,
                    ),
                  ],
                ),

                SizedBox(height: 12),

                Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Visibility(
                      visible: _textController.text.isEmpty,
                      child: FutureBuilder(
                        future:
                            FirebaseFirestore.instance
                                .collection('widgets')
                                .doc('placeholders')
                                .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox.shrink();
                          }
                          if (snapshot.hasError) {
                            return const Center(child: Text('Error'));
                          }
                          return Text(
                            snapshot.data!.data()!['innerPlaceholderText'],
                            style: TextStyle(
                              color: const Color(0xFF5F5F5F),
                              fontSize: 13,
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w400,
                            ),
                          );
                        },
                      ),
                    ),
                    TextField(
                      controller: _textController,
                      onChanged: (value) => setState(() {}),
                      autofocus: true,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      style: TextStyle(
                        color: const Color(0xFF5F5F5F),
                        fontSize: 13,
                        fontFamily: 'NotoSans',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // ── UPDATED: Image preview with rounded corners ───────────
                StatefulBuilder(
                  builder: (BuildContext context, StateSetter setInnerState) {
                    if (images.isEmpty) return const SizedBox.shrink();

                    return Container(
                      height: 160,
                      margin: EdgeInsets.only(top: 8),
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final UploadableImage item = images.removeAt(
                              oldIndex,
                            );
                            images.insert(newIndex, item);
                          });
                          setInnerState(() {});
                        },
                        buildDefaultDragHandles: false,
                        itemBuilder: (context, index) {
                          final imageItem = images[index];

                          Widget content = ListenableBuilder(
                            key: ValueKey(imageItem.id),
                            listenable: imageItem,
                            builder: (context, child) {
                              Widget imgWidget;
                              if (imageItem.networkUrl != null) {
                                imgWidget = Image.network(
                                  imageItem.networkUrl!,
                                  height: 160,
                                  width: 120,
                                  fit: BoxFit.cover,
                                  cacheWidth: 300,
                                );
                              } else if (kIsWeb) {
                                imgWidget = Image.network(
                                  imageItem.localFile.path,
                                  height: 160,
                                  width: 120,
                                  fit: BoxFit.cover,
                                  cacheWidth: 300,
                                );
                              } else {
                                imgWidget = Image.file(
                                  File(imageItem.localFile.path),
                                  height: 160,
                                  width: 120,
                                  fit: BoxFit.cover,
                                  cacheWidth: 300,
                                );
                              }

                              return Container(
                                margin: EdgeInsets.only(right: 8),
                                width: 120,
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(25),
                                      child: imgWidget,
                                    ),
                                    if (imageItem.isUploading)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.5,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                          child: Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                value: imageItem.progress,
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (imageItem.hasError)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.5,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.error_outline,
                                              color: Colors.red,
                                              size: 30,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 8,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: ReorderableDragStartListener(
                                          index: index,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.6,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            padding: EdgeInsets.all(4),
                                            child: const Icon(
                                              Icons.drag_indicator,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setInnerState(() {
                                            images.remove(imageItem);
                                          });
                                          setState(
                                            () {},
                                          ); // Update parent so 'Post' button enables
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          padding: EdgeInsets.all(4),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );

                          return content;
                        },
                      ),
                    );
                  },
                ),

                SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
