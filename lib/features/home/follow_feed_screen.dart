import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/home/widgets/following_users_list.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FollowingTab extends StatefulWidget {
  final User? firebaseUser;
  const FollowingTab({Key? key, this.firebaseUser}) : super(key: key);

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
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
    if (widget.firebaseUser != null) {
      _userStream =
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.firebaseUser!.uid)
              .snapshots();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _selectedUserId.dispose();
    _selectedCategoryId.dispose();
    super.dispose();
  }

  void _handleUserSelection(String userId) {
    _selectedUserId.value = (_selectedUserId.value == userId) ? null : userId;
    _selectedCategoryId.value = null;
  }

  void _handleCategorySelection(String categoryId) {
    if (categoryId.isEmpty) {
      _selectedCategoryId.value = null;
    } else {
      _selectedCategoryId.value =
          (_selectedCategoryId.value == categoryId) ? null : categoryId;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: EdgeInsets.only(top: 10),
      child: StreamBuilder<User?>(
        stream: _authStream,
        builder: (context, authSnapshot) {
          final user = authSnapshot.data;

          // Loading auth state
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // User not authenticated
          if (user == null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    SizedBox(height: 16),
                    Text(
                      '로그인이 필요합니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
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
            return SizedBox.shrink();
          }
          return StreamBuilder<DocumentSnapshot>(
            stream: _userStream,
            builder: (context, snapshot) {
              // Loading user data
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Error loading user data
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
                      SizedBox(height: 16),
                      Text(
                        '오류가 발생했습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '잠시 후 다시 시도해주세요',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              // No user data
              if (!snapshot.hasData || snapshot.data?.data() == null) {
                return const Center(child: Text('사용자 정보를 불러올 수 없습니다'));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final isSub = data?['isSub'] == true;
              final currentUserId = user.uid;

              return Column(
                children: [
                  // Following users horizontal list
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
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
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
                                SizedBox(height: 8),
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

                  // Categories row (only shown when a user is selected)
                  ValueListenableBuilder<String?>(
                    valueListenable: _selectedUserId,
                    builder: (context, selectedUserId, _) {
                      if (selectedUserId == null)
                        return const SizedBox.shrink();
                      return ValueListenableBuilder<String?>(
                        valueListenable: _selectedCategoryId,
                        builder: (context, selectedCategoryId, _) {
                          return UserCategoriesBar(
                            userId: selectedUserId,
                            selectedCategoryId: selectedCategoryId,
                            onCategorySelected: _handleCategorySelection,
                          );
                        },
                      );
                    },
                  ),
                  // Posts from following users
                  ValueListenableBuilder<String?>(
                    valueListenable: _selectedUserId,
                    builder: (context, selectedUserId, _) {
                      return ValueListenableBuilder<String?>(
                        valueListenable: _selectedCategoryId,
                        builder: (context, selectedCategoryId, _) {
                          return FollowingPostsList(
                            currentUserId: currentUserId,
                            scrollController: _scrollController,
                            selectedUserId: selectedUserId,
                            selectedCategoryId: selectedCategoryId,
                            useGuestPostItem: !isSub,
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

// New widget to display user's categories
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
    // Only recreate stream if userId actually changed
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
          return SizedBox(
            height: 50,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: 50,
            child: Center(
              child: Text(
                '카테고리를 불러올 수 없습니다',
                style: TextStyle(fontSize: 12, color: Colors.red[300]),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final categories = snapshot.data!.docs;

        // If no categories, show a simple message
        if (categories.isEmpty) {
          return SizedBox(
            height: 50,
            child: Center(
              child: Text(
                '카테고리가 없습니다',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
          );
        }

        return Container(
          height: 50,

          padding: EdgeInsets.symmetric(vertical: 8),

          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Add left padding for centering
                  SizedBox(width: 16),

                  // "All" category option
                  _buildCategoryPill(
                    '전체',
                    widget.selectedCategoryId == null,
                    () => widget.onCategorySelected(''),
                  ),

                  // User's categories
                  ...categories.map((category) {
                    final categoryData =
                        category.data() as Map<String, dynamic>;
                    final categoryName = categoryData['name'] ?? '이름 없음';
                    final isSelected = widget.selectedCategoryId == category.id;

                    return Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: _buildCategoryPill(
                        categoryName,
                        isSelected,
                        () => widget.onCategorySelected(category.id),
                      ),
                    );
                  }).toList(),

                  // Add right padding for centering
                  SizedBox(width: 16),
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

  const FollowingPostsList({
    Key? key,
    required this.currentUserId,
    required this.scrollController,
    this.selectedUserId,
    this.selectedCategoryId,
    this.useGuestPostItem = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFollowingPostsStream(selectedUserId, selectedCategoryId),
      builder: (context, snapshot) {
        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                SizedBox(height: 16),
                Text(
                  '오류가 발생했습니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '잠시 후 다시 시도해주세요',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // No data state
        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 64, color: Colors.grey[300]),
                SizedBox(height: 16),
                Text(
                  '데이터를 불러올 수 없습니다',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data!.docs;

        // Empty posts state - different messages based on context
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feed_outlined, size: 64, color: Colors.grey[300]),
                SizedBox(height: 16),
                Text(
                  _getEmptyStateMessage(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _getEmptyStateSubMessage(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        // Success state with posts
        return ListView.builder(
          shrinkWrap: true,
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            try {
              final postData = posts[index].data() as Map<String, dynamic>?;

              // Handle null or invalid post data
              if (postData == null) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child:
                    useGuestPostItem
                        ? GuestPostItem(post: postData)
                        : PostItem(
                          postId: posts[index].id,
                          fromComments: false,
                        ),
              );
            } catch (e) {
              // Handle individual post rendering errors
              print('Error rendering post at index $index: $e');
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: EdgeInsets.all(16),
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
                      SizedBox(width: 8),
                      Text(
                        '이 게시물을 표시할 수 없습니다',
                        style: TextStyle(fontSize: 12, color: Colors.red[700]),
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

  String _getEmptyStateMessage() {
    // User selected + Category selected
    if (selectedUserId != null && selectedCategoryId != null) {
      return '이 카테고리에 게시물이 없습니다';
    }

    // User selected + No category (showing all user's posts)
    if (selectedUserId != null) {
      return '아직 게시물이 없습니다';
    }

    // No user selected (showing all following users' posts)
    return '팔로우한 사용자의 게시물이 없습니다';
  }

  String _getEmptyStateSubMessage() {
    // User selected + Category selected
    if (selectedUserId != null && selectedCategoryId != null) {
      return '다른 카테고리를 선택해보세요';
    }

    // User selected + No category
    if (selectedUserId != null) {
      return '첫 게시물을 기다리고 있어요';
    }

    // No user selected
    return '더 많은 사용자를 팔로우해보세요';
  }

  Stream<QuerySnapshot> _getFollowingPostsStream(
    String? userId,
    String? categoryId,
  ) {
    try {
      if (userId != null) {
        // Show posts from the selected user
        Query query = FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: userId);

        // Add category filter if a category is selected
        if (categoryId != null && categoryId.isNotEmpty) {
          query = query.where('categoryId', isEqualTo: categoryId);
        }

        return query.orderBy('createdAt', descending: true).snapshots();
      }

      // Show all posts from following users (no specific user selected)
      return FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .snapshots()
          .asyncMap((followingSnapshot) async {
            try {
              final followingIds =
                  followingSnapshot.docs.map((doc) => doc.id).toList();

              if (followingIds.isEmpty) {
                // Return empty query result
                return FirebaseFirestore.instance
                    .collection('posts')
                    .where(
                      'userId',
                      isEqualTo: 'nonexistent_user_id_for_empty_result',
                    )
                    .get();
              }

              // Firestore 'in' query limit is 10, so we need to batch if more
              if (followingIds.length <= 10) {
                return await FirebaseFirestore.instance
                    .collection('posts')
                    .where('userId', whereIn: followingIds)
                    .limit(50)
                    .get();
              } else {
                // Handle more than 10 following users
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

                // Sort all posts by creation date
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
                    print('Error sorting posts: $e');
                    return 0;
                  }
                });

                // Return a custom QuerySnapshot wrapper
                return _MockQuerySnapshot(allDocs.take(50).toList());
              }
            } catch (e) {
              print('Error fetching following posts: $e');
              // Return empty result on error
              return FirebaseFirestore.instance
                  .collection('posts')
                  .where('userId', isEqualTo: 'error_fallback_empty_result')
                  .get();
            }
          });
    } catch (e) {
      print('Error creating posts stream: $e');
      // Return a stream that emits an empty result
      return Stream.value(_MockQuerySnapshot([]));
    }
  }
}

// Mock QuerySnapshot to handle batched queries
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
