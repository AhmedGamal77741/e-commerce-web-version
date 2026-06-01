import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/widgets/safe_network_image.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_item.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileTab extends StatefulWidget {
  final String userId;

  const ProfileTab({super.key, required this.userId});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String? selectedCategoryId;
  late PageController _pageController;
  List<String?> _categoryPages = [null];
  User? _firebaseUser;
  late final StreamSubscription<User?> _authSubscription;
  Stream<DocumentSnapshot>? _userStream;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _firebaseUser = FirebaseAuth.instance.currentUser;

    _userStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _firebaseUser = user;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _pageController.dispose();
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
    }
  }

  void _onPageChanged(int index) {
    final categoryId = _categoryPages[index];
    setState(() {
      selectedCategoryId = categoryId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Center(child: Text('사용자 프로필을 찾을 수 없습니다'));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final profileUser = MyUser.fromDocument(userData);

        return StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(profileUser.userId)
                  .collection('categories')
                  .orderBy('order')
                  .snapshots(),
          builder: (context, categorySnapshot) {
            if (categorySnapshot.hasData) {
              _categoryPages = [
                null,
                ...categorySnapshot.data!.docs.map((doc) => doc.id),
              ];
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Back button row
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.arrow_back, size: 24),
                        ),
                        const Spacer(),
                      ],
                    ),
                    verticalSpace(10),
                    // Profile Image - no tap for other users
                    ClipOval(
                      child: SafeNetworkImage(
                        url: profileUser.url ?? '',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorWidget: Icon(Icons.person, size: 64),
                        placeholder: SizedBox(
                          width: 64,
                          height: 64,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                    ),
                    verticalSpace(4),
                    Text(
                      profileUser.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    verticalSpace(10),

                    UserCategoriesBar(
                      userId: profileUser.userId,
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
                          return _PostsPage(
                            userId: profileUser.userId,
                            categoryId: _categoryPages[index],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
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

  const _PostsPage({required this.userId, this.categoryId});

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
          return const Center(child: CircularProgressIndicator());
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

        final bool isGuest = FirebaseAuth.instance.currentUser == null;
        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final doc = posts[index];
            final post = doc.data() as Map<String, dynamic>;
            if (post['postId'] == null) {
              post['postId'] = doc.id;
            }
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  if (index != 0) Divider(color: ColorsManager.primary100),
                  isGuest
                      ? GuestPostItem(post: post)
                      : PostItem(postId: doc.id, fromComments: false),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class UserCategoriesBar extends StatelessWidget {
  final String userId;
  final String? selectedCategoryId;
  final Function(String) onCategorySelected;

  const UserCategoriesBar({
    super.key,
    required this.userId,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('categories')
              .orderBy('order')
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 50);
        }

        final categories = snapshot.data!.docs;

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
                  final name =
                      (cat.data() as Map<String, dynamic>)['name'] ?? '';
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
      },
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
