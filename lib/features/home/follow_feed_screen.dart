import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/home/widgets/following_users_list.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FollowingTab extends StatefulWidget {
  const FollowingTab({Key? key}) : super(key: key);

  @override
  State<FollowingTab> createState() => _FollowingTabState();
}

class _FollowingTabState extends State<FollowingTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  String? selectedUserId; // Add this

  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (user == null) {
          return const Center(child: Text('내 페이지탭에서 회원가입 후 이용가능합니다'));
        }
        return StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('오류가 발생했습니다'));
            }
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final isSub = data?['isSub'] == true;
            final currentUserId = user.uid;
            return Column(
              children: [
                // Following users horizontal list
                SizedBox(
                  height: 90,
                  child: StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUserId)
                            .collection('following')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text('오류가 발생했습니다'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final followingIds =
                          snapshot.data!.docs.map((doc) => doc.id).toList();
                      if (followingIds.isEmpty) {
                        return const Center(child: Text('팔로우한 사용자가 없습니다'));
                      }
                      return FollowingUsersList(
                        followingIds: followingIds,
                        onUserTap: (userId) {
                          setState(() {
                            if (selectedUserId == userId) {
                              selectedUserId = null; // Deselect if tapped again
                            } else {
                              selectedUserId = userId;
                            }
                          });
                        },
                        selectedUserId: selectedUserId,
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                // Posts from following users
                Expanded(
                  child: FollowingPostsList(
                    currentUserId: currentUserId,
                    scrollController: _scrollController,
                    selectedUserId: selectedUserId, // Pass here
                    useGuestPostItem: !isSub,
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

class FollowingPostsList extends StatelessWidget {
  final String currentUserId;
  final ScrollController scrollController;
  final String? selectedUserId;
  final bool useGuestPostItem;

  FollowingPostsList({
    Key? key,
    required this.currentUserId,
    required this.scrollController,
    this.selectedUserId,
    this.useGuestPostItem = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFollowingPostsStream(selectedUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('오류가 발생했습니다'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feed, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  '팔로우한 사용자의 게시물이 없습니다',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final postData = posts[index].data() as Map<String, dynamic>;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child:
                  useGuestPostItem
                      ? GuestPostItem(post: postData)
                      : PostItem(postId: posts[index].id, fromComments: false),
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getFollowingPostsStream(String? userId) {
    if (userId != null) {
      // Show only posts from the selected user
      return FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .snapshots()
        .asyncMap((followingSnapshot) async {
          final followingIds =
              followingSnapshot.docs.map((doc) => doc.id).toList();
          if (followingIds.isEmpty) {
            return FirebaseFirestore.instance
                .collection('posts')
                .where('userId', isEqualTo: 'nonexistent')
                .get();
          }

          // Firestore 'in' query limit is 10, so we need to batch if more
          if (followingIds.length <= 10) {
            return FirebaseFirestore.instance
                .collection('posts')
                .where('userId', whereIn: followingIds)
                .orderBy('createdAt', descending: true)
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
                    .orderBy('createdAt', descending: true)
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
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTimestamp = aData['createdAt'] as Timestamp?;
              final bTimestamp = bData['createdAt'] as Timestamp?;

              if (aTimestamp == null || bTimestamp == null) return 0;
              return bTimestamp.compareTo(aTimestamp);
            });

            // Create a mock QuerySnapshot (you might need to create a custom class)
            return _createMockQuerySnapshot(allDocs.take(50).toList());
          }
        });
  }

  QuerySnapshot _createMockQuerySnapshot(List<QueryDocumentSnapshot> docs) {
    // This is a simplified approach - you might want to use a different method
    // or create a custom stream that handles this better
    throw UnimplementedError('Implement based on your needs');
  }
}
