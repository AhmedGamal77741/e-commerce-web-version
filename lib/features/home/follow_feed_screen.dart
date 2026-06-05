import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/home/widgets/following_users_list.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FollowingTab extends StatefulWidget {
  final User? firebaseUser;
  final String? preselectedUser;
  const FollowingTab({Key? key, this.firebaseUser, this.preselectedUser})
    : super(key: key);

  @override
  State<FollowingTab> createState() => _FollowingTabState();
}

class _FollowingTabState extends State<FollowingTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<String?> _selectedUserId = ValueNotifier(null);
  final ValueNotifier<String?> _selectedCategoryId = ValueNotifier(null);
  late final Stream<User?> _authStream;
  late final Stream<DocumentSnapshot>? _userStream;
  late PageController _categoryPageController;
  List<String?> _categoryPages = [null]; // null represents "All" category
  bool get wantKeepAlive => true;

  final Map<String, GlobalKey> _userKeys = {};

  void _scrollToSelectedUser() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedId = _selectedUserId.value;
      if (selectedId != null && _userKeys.containsKey(selectedId)) {
        final context = _userKeys[selectedId]!.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.5,
          );
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _categoryPageController = PageController();
    _authStream = FirebaseAuth.instance.authStateChanges();
    _selectedUserId.value = widget.preselectedUser;
    if (widget.preselectedUser != null) {
      _scrollToSelectedUser();
    }
    if (widget.firebaseUser != null) {
      _userStream =
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.firebaseUser!.uid)
              .snapshots();
    }
  }

  @override
  void didUpdateWidget(FollowingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preselectedUser != oldWidget.preselectedUser &&
        widget.preselectedUser != null) {
      _selectedUserId.value = widget.preselectedUser;
      _selectedCategoryId.value = null;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _categoryPageController.dispose();
    _selectedUserId.dispose();
    _selectedCategoryId.dispose();
    super.dispose();
  }

  void _handleUserSelection(String userId) {
    _selectedUserId.value = (_selectedUserId.value == userId) ? null : userId;
    _selectedCategoryId.value = null;
    _categoryPages = [null]; // Reset category pages

    if (_categoryPageController.hasClients) {
      _categoryPageController.jumpToPage(0);
    }
  }

  void _handleCategorySelection(String categoryId) {
    final index = _categoryPages.indexOf(
      categoryId.isEmpty ? null : categoryId,
    );
    if (index != -1 && _categoryPageController.hasClients) {
      _categoryPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onCategoryPageChanged(int index) {
    final categoryId = _categoryPages[index];
    _selectedCategoryId.value = categoryId;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: StreamBuilder<User?>(
        stream: _authStream,
        builder: (context, authSnapshot) {
          final user = authSnapshot.data;

          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center();
          }

          if (user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '로그인이 필요합니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '내 페이지탭에서 회원가입 후 이용가능합니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            );
          }
          if (_userStream == null) {
            return const SizedBox.shrink();
          }
          return StreamBuilder<DocumentSnapshot>(
            stream: _userStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center();
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '오류가 발생했습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '잠시 후 다시 시도해주세요',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data?.data() == null) {
                return const Center(child: Text('사용자 정보를 불러올 수 없습니다'));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final isSub = data?['isSub'] == true;
              final currentUserId = user.uid;
              final blockedUsers = List<String>.from(
                (data?['blocked'] as List<dynamic>?) ?? [],
              );

              return Column(
                children: [
                  SizedBox(
                    height: 100,
                    child: StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUserId)
                              .collection('following')
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              '팔로우 목록을 불러올 수 없습니다',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red[300],
                              ),
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: SizedBox(width: 20, height: 20),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: Text('팔로우 데이터를 불러올 수 없습니다'),
                          );
                        }

                        final followingIds =
                            snapshot.data!.docs.map((doc) => doc.id).toList();

                        if (followingIds.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 32,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '팔로우한 사용자가 없습니다',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ValueListenableBuilder(
                          valueListenable: _selectedUserId,
                          builder: (context, selectedUserId, child) {
                            return FollowingUsersList(
                              followingIds: followingIds,
                              onUserTap: _handleUserSelection,
                              selectedUserId: selectedUserId,
                            );
                          },
                        );
                      },
                    ),
                  ),

                  ValueListenableBuilder<String?>(
                    valueListenable: _selectedUserId,
                    builder: (context, selectedUserId, _) {
                      if (selectedUserId == null) {
                        return const SizedBox.shrink();
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(selectedUserId)
                                .collection('categories')
                                .orderBy('order', descending: false)
                                .snapshots(),
                        builder: (context, categoriesSnapshot) {
                          if (categoriesSnapshot.hasData) {
                            _categoryPages = [
                              null,
                              ...categoriesSnapshot.data!.docs.map(
                                (doc) => doc.id,
                              ),
                            ];
                          }

                          return Column(
                            children: [
                              if (!blockedUsers.contains(selectedUserId))
                                ValueListenableBuilder<String?>(
                                  valueListenable: _selectedCategoryId,
                                  builder: (context, selectedCategoryId, _) {
                                    return UserCategoriesBar(
                                      userId: selectedUserId,
                                      selectedCategoryId: selectedCategoryId,
                                      onCategorySelected:
                                          _handleCategorySelection,
                                    );
                                  },
                                ),
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.65,
                                child: PageView.builder(
                                  controller: _categoryPageController,
                                  onPageChanged: _onCategoryPageChanged,
                                  itemCount: _categoryPages.length,
                                  itemBuilder: (context, index) {
                                    return FollowingPostsList(
                                      currentUserId: currentUserId,
                                      scrollController: _scrollController,
                                      selectedUserId: selectedUserId,
                                      selectedCategoryId: _categoryPages[index],
                                      useGuestPostItem: !isSub,
                                      blockedUsers: blockedUsers,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class UserCategoriesBar extends StatefulWidget {
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
  State<UserCategoriesBar> createState() => _UserCategoriesBarState();
}

class _UserCategoriesBarState extends State<UserCategoriesBar> {
  late Stream<QuerySnapshot> _categoriesStream;
  @override
  void initState() {
    super.initState();
    _categoriesStream = _buildStream(widget.userId);
  }

  @override
  void didUpdateWidget(UserCategoriesBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _categoriesStream = _buildStream(widget.userId);
    }
  }

  Stream<QuerySnapshot> _buildStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('categories')
        .orderBy('order', descending: false)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _categoriesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 50,
            child: Center(child: SizedBox(width: 20, height: 20)),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox(
            height: 50,
            child: Center(
              child: Text(
                '카테고리를 불러올 수 없습니다',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final categories = snapshot.data!.docs;

        if (categories.isEmpty) {
          return const SizedBox(
            height: 50,
            child: Center(
              child: Text(
                '카테고리가 없습니다',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          );
        }

        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 16),
                  _buildCategoryPill(
                    '전체',
                    widget.selectedCategoryId == null,
                    () => widget.onCategorySelected(''),
                  ),
                  ...categories.map((category) {
                    final categoryData =
                        category.data() as Map<String, dynamic>;
                    final categoryName = categoryData['name'] ?? '이름 없음';
                    final isSelected = widget.selectedCategoryId == category.id;

                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildCategoryPill(
                        categoryName,
                        isSelected,
                        () => widget.onCategorySelected(category.id),
                      ),
                    );
                  }).toList(),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryPill(
    String categoryName,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              isSelected
                  ? Border.all(color: Colors.grey)
                  : Border.all(color: Colors.transparent),
        ),
        child: Center(
          child: Text(
            categoryName,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class FollowingPostsList extends StatelessWidget {
  final String currentUserId;
  final ScrollController scrollController;
  final String? selectedUserId;
  final String? selectedCategoryId;
  final bool useGuestPostItem;
  final List<String> blockedUsers;

  const FollowingPostsList({
    Key? key,
    required this.currentUserId,
    required this.scrollController,
    this.selectedUserId,
    this.selectedCategoryId,
    this.useGuestPostItem = false,
    this.blockedUsers = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (selectedUserId != null && blockedUsers.contains(selectedUserId)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '차단된 사용자입니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .update({
                        'blocked': FieldValue.arrayRemove([selectedUserId]),
                      });
                  messenger.showSnackBar(
                    const SnackBar(content: Text('차단이 해제되었습니다.')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('오류 발생: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('차단 해제', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getFollowingPostsStream(selectedUserId, selectedCategoryId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  '오류가 발생했습니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '잠시 후 다시 시도해주세요',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center();
        }

        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  '데이터를 불러올 수 없습니다',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final rawPosts = snapshot.data!.docs;
        final posts =
            rawPosts.where((doc) {
              final postData = doc.data() as Map<String, dynamic>?;
              if (postData == null) return false;
              final authorId = postData['userId'] as String?;
              if (authorId != null && blockedUsers.contains(authorId)) {
                return false;
              }
              return true;
            }).toList();

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feed_outlined, size: 64, color: Colors.grey[300]),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            try {
              final postData = posts[index].data() as Map<String, dynamic>?;

              if (postData == null) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child:
                    useGuestPostItem
                        ? GuestPostItem(post: postData)
                        : PostItem(
                          postId: posts[index].id,
                          fromComments: false,
                        ),
              );
            } catch (e) {
              print('Error rendering post at index $index: $e');
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.red[400],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '이 게시물을 표시할 수 없습니다',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getFollowingPostsStream(
    String? userId,
    String? categoryId,
  ) {
    // ... (the rest of this method remains unchanged)
    // Keeping the full logic as it was (only ScreenUtil was removed above)
    try {
      if (userId != null) {
        Query query = FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: userId);

        if (categoryId != null && categoryId.isNotEmpty) {
          query = query.where('categoryId', isEqualTo: categoryId);
        }

        return query.orderBy('createdAt', descending: true).snapshots();
      }

      return FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .snapshots()
          .asyncMap((followingSnapshot) async {
            // ... (unchanged logic)
            try {
              final followingIds =
                  followingSnapshot.docs.map((doc) => doc.id).toList();

              if (followingIds.isEmpty) {
                return FirebaseFirestore.instance
                    .collection('posts')
                    .where(
                      'userId',
                      isEqualTo: 'nonexistent_user_id_for_empty_result',
                    )
                    .get();
              }

              if (followingIds.length <= 10) {
                return await FirebaseFirestore.instance
                    .collection('posts')
                    .where('userId', whereIn: followingIds)
                    .limit(50)
                    .get();
              } else {
                final batches = <Future<QuerySnapshot>>[];
                for (int i = 0; i < followingIds.length; i += 10) {
                  final batch = followingIds.skip(i).take(10).toList();
                  batches.add(
                    FirebaseFirestore.instance
                        .collection('posts')
                        .where('userId', whereIn: batch)
                        .get(),
                  );
                }

                final results = await Future.wait(batches);
                final allDocs = <QueryDocumentSnapshot>[];

                for (final result in results) {
                  allDocs.addAll(result.docs);
                }

                allDocs.sort((a, b) {
                  try {
                    final aData = a.data() as Map<String, dynamic>?;
                    final bData = b.data() as Map<String, dynamic>?;

                    if (aData == null || bData == null) return 0;

                    final aTimestamp = aData['createdAt'] as Timestamp?;
                    final bTimestamp = bData['createdAt'] as Timestamp?;

                    if (aTimestamp == null || bTimestamp == null) return 0;
                    return bTimestamp.compareTo(aTimestamp);
                  } catch (e) {
                    return 0;
                  }
                });

                return _MockQuerySnapshot(allDocs.take(50).toList());
              }
            } catch (e) {
              print('Error fetching following posts: $e');
              return FirebaseFirestore.instance
                  .collection('posts')
                  .where('userId', isEqualTo: 'error_fallback_empty_result')
                  .get();
            }
          });
    } catch (e) {
      print('Error creating posts stream: $e');
      return Stream.value(_MockQuerySnapshot([]));
    }
  }
}

// Mock QuerySnapshot (unchanged)
class _MockQuerySnapshot implements QuerySnapshot {
  final List<QueryDocumentSnapshot> _docs;

  _MockQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot> get docs => _docs;

  @override
  List<DocumentChange> get docChanges => [];

  @override
  SnapshotMetadata get metadata => _MockSnapshotMetadata();

  @override
  int get size => _docs.length;
}

class _MockSnapshotMetadata implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;

  @override
  bool get isFromCache => false;
}
