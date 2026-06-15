import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/image_picker_helper.dart';
import 'package:ecommerece_app/core/helpers/loading_service.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/widgets/safe_network_image.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MyStory extends StatefulWidget {
  final ScrollController? scrollController;
  const MyStory({super.key, this.scrollController});

  @override
  State<MyStory> createState() => _MyStoryState();
}

class _MyStoryState extends State<MyStory> {
  String? selectedCategoryId;
  late PageController _pageController;
  List<String?> _categoryPages = [null];
  User? _firebaseUser;
  late final StreamSubscription<User?> _authSubscription;
  final ValueNotifier<int> _currentPageIndex = ValueNotifier(0);
  Stream<MyUser?>? _userStream;
  String imgUrl = "";
  Stream<QuerySnapshot>? _categoriesStream;
  String? _cachedCategoriesUserId;

  Stream<QuerySnapshot> _getCategoriesStream(String userId) {
    if (_categoriesStream == null || _cachedCategoriesUserId != userId) {
      _cachedCategoriesUserId = userId;
      _categoriesStream =
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('categories')
              .orderBy('order')
              .snapshots();
    }
    return _categoriesStream!;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _firebaseUser = FirebaseAuth.instance.currentUser;

    if (_firebaseUser != null) {
      _userStream = FirebaseUserRepo().user;
    }

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _firebaseUser = user;
          _userStream = user != null ? FirebaseUserRepo().user : null;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _pageController.dispose();
    _currentPageIndex.dispose();
    super.dispose();
  }

  void _onCategorySelected(String categoryId) {
    final index = _categoryPages.indexOf(
      categoryId.isEmpty ? null : categoryId,
    );
    if (index != -1) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _currentPageIndex.value = index;
    }
  }

  void _onPageChanged(int index) {
    final categoryId = _categoryPages[index];
    setState(() {
      selectedCategoryId = categoryId;
    });
    _currentPageIndex.value = index;
  }

  /*   void _onCategorySelected(String categoryId) {
    setState(() {
      if (categoryId.isEmpty || selectedCategoryId == categoryId) {
        selectedCategoryId = null;
      } else {
        selectedCategoryId = categoryId;
      }
    });
  } */

  @override
  Widget build(BuildContext context) {
    if (_firebaseUser == null) {
      return const Center(child: Text('스토리를 보려면 로그인하세요'));
    }
    return StreamBuilder<MyUser?>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (!userSnapshot.hasData) {
          return const Center(child: Text('사용자 프로필을 찾을 수 없습니다'));
        }

        final currentUser = userSnapshot.data!;

        return StreamBuilder<QuerySnapshot>(
          stream: _getCategoriesStream(currentUser.userId),

          builder: (context, categorySnapshot) {
            if (categorySnapshot.hasData) {
              _categoryPages = [
                null,
                ...categorySnapshot.data!.docs.map((doc) => doc.id),
              ];
            }

            return Column(
              children: [
                verticalSpace(10),

                InkWell(
                  onTap: () async {
                    LoadingService().showLoading();
                    final newUrl = await uploadImageToFirebaseStorage(
                      await ImagePickerHelper.pickImage(),
                    );
                    LoadingService().hideLoading();
                    /* setState(() => imgUrl = newUrl); */
                  },
                  child: ClipOval(
                    child: SafeNetworkImage(
                      url: (imgUrl.isEmpty ? (currentUser.url) : imgUrl) ?? '',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorWidget: Icon(Icons.person, size: 64),
                      placeholder: SizedBox(
                        width: 64,
                        height: 64,
                        child: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  currentUser.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                verticalSpace(10),

                UserCategoriesBar(
                  categories:
                      categorySnapshot.hasData
                          ? categorySnapshot.data!.docs
                          : const [],
                  selectedCategoryId: selectedCategoryId,
                  onCategorySelected: _onCategorySelected,
                ),
                verticalSpace(10),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _categoryPages.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      return ValueListenableBuilder<int>(
                        valueListenable: _currentPageIndex,
                        builder: (context, activeIndex, _) {
                          return _PostsPage(
                            userId: currentUser.userId,
                            categoryId: _categoryPages[index],
                            scrollController:
                                (index == activeIndex)
                                    ? widget.scrollController
                                    : null,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Each page owns its own stable stream + stays alive when swiped away
class _PostsPage extends StatefulWidget {
  final String userId;
  final String? categoryId;
  final ScrollController? scrollController;
  const _PostsPage({
    required this.userId,
    this.categoryId,
    this.scrollController,
  });

  @override
  State<_PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<_PostsPage>
    with AutomaticKeepAliveClientMixin {
  late final Stream<QuerySnapshot> _stream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Query query = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true);

    if (widget.categoryId != null) {
      query = query.where('categoryId', isEqualTo: widget.categoryId);
    }

    _stream = query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          return const Center(child: Text('게시물을 불러오지 못했습니다'));
        }

        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                widget.categoryId == null
                    ? '아직 작성한 게시물이 없습니다.'
                    : '이 카테고리에 게시물이 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
          );
        }

        return ListView.builder(
          controller: widget.scrollController,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  if (index != 0) Divider(color: ColorsManager.primary100),
                  PostItem(postId: posts[index].id, fromComments: false),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/* /// 🔥 REAL-TIME QUERY WITH CATEGORY FILTER
Stream<QuerySnapshot> _userPostsStream(String userId) {
  Query query = FirebaseFirestore.instance
      .collection('posts')
      .where('userId', isEqualTo: userId);

  if (selectedCategoryId != null) {
    query = query.where('categoryId', isEqualTo: selectedCategoryId);
  }

  return query.orderBy('createdAt', descending: true).snapshots();
} */

class UserCategoriesBar extends StatelessWidget {
  final List<QueryDocumentSnapshot> categories;
  final String? selectedCategoryId;
  final Function(String) onCategorySelected;

  const UserCategoriesBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(width: 16),
            _pill(
              '전체',
              selectedCategoryId == null,
              () => onCategorySelected(''),
            ),
            ...categories.map((cat) {
              final name = (cat.data() as Map<String, dynamic>)['name'] ?? '';
              return Padding(
                padding: EdgeInsets.only(left: 8),
                child: _pill(
                  name,
                  selectedCategoryId == cat.id,
                  () => onCategorySelected(cat.id),
                ),
              );
            }),
            SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.grey : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : Colors.grey[600],
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
