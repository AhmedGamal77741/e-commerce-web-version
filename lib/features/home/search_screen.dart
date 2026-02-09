import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/data/follow_service.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_item.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

class HomeSearch extends StatefulWidget {
  final bool useGuestPostItem;
  const HomeSearch({super.key, this.useGuestPostItem = false});

  @override
  State<HomeSearch> createState() => _HomeSearchState();
}

class _HomeSearchState extends State<HomeSearch> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 130,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios),
                  ),
                  SizedBox(
                    width: 270,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '검색...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        border: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.zero,
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.zero,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const ImageIcon(AssetImage('assets/Frame 4.png')),
                    onPressed: () {},
                  ),
                ],
              ),
              TabBar(
                labelStyle: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.none,
                  fontFamily: 'NotoSans',
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: ColorsManager.primaryblack,
                ),
                unselectedLabelColor: ColorsManager.primary600,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorColor: ColorsManager.primaryblack,
                tabs: const [Tab(text: '추천'), Tab(text: '구독')],
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _HomeFeedSearchTab(
              searchQuery: searchQuery,
              useGuestPostItem: widget.useGuestPostItem,
            ),
            FollowingSearchTab(searchQuery: searchQuery),
          ],
        ),
      ),
    );
  }
}

class _HomeFeedSearchTab extends StatefulWidget {
  final String searchQuery;
  final bool useGuestPostItem;

  const _HomeFeedSearchTab({
    required this.searchQuery,
    this.useGuestPostItem = false,
  });

  @override
  State<_HomeFeedSearchTab> createState() => _HomeFeedSearchTabState();
}

class _HomeFeedSearchTabState extends State<_HomeFeedSearchTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Helper: Stream author data in real-time with efficient multi-document listening
  Stream<Map<String, Map<String, dynamic>>> _streamAuthorDataRealtime(
    List<String> authorIds,
  ) {
    if (authorIds.isEmpty) {
      return Stream.value({});
    }

    // Chunk authorIds into groups of 10 (Firestore whereIn limit)
    final chunks = <List<String>>[];
    for (var i = 0; i < authorIds.length; i += 10) {
      chunks.add(
        authorIds.sublist(
          i,
          i + 10 > authorIds.length ? authorIds.length : i + 10,
        ),
      );
    }

    // Create streams for each chunk
    final streams =
        chunks.map((chunk) {
          return FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .snapshots()
              .map((snapshot) {
                final map = <String, Map<String, dynamic>>{};
                for (var doc in snapshot.docs) {
                  map[doc.id] = doc.data();
                }
                return map;
              });
        }).toList();

    // If only one chunk, return directly
    if (streams.length == 1) {
      return streams[0];
    }

    // For multiple chunks, merge them using StreamController
    return Stream.multi((controller) async {
      final dataMaps = List<Map<String, Map<String, dynamic>>>.filled(
        streams.length,
        {},
      );

      final subscriptions =
          <StreamSubscription<Map<String, Map<String, dynamic>>>>[];

      try {
        for (var i = 0; i < streams.length; i++) {
          subscriptions.add(
            streams[i].listen(
              (data) {
                dataMaps[i] = data;
                // Combine all maps from all chunks
                final combined = <String, Map<String, dynamic>>{};
                for (var map in dataMaps) {
                  combined.addAll(map);
                }
                // Add the combined map to controller
                controller.add(combined);
              },
              onError: (e) => controller.addError(e),
              onDone: () => controller.close(),
            ),
          );
        }
      } catch (e) {
        controller.addError(e);
        controller.close();
      }
    });
  }

  // Helper: Check if post should be visible based on privacy rules
  bool _shouldShowPost({
    required String postAuthorId,
    required String currentUserId,
    required Map<String, dynamic> authorData,
    required Set<String> followingSet,
  }) {
    // Always show user's own posts
    if (postAuthorId == currentUserId) {
      return true;
    }

    // Get author's privacy setting (default to false if not set)
    final bool isPrivate = authorData['isPrivate'] ?? false;

    // Show public posts to everyone
    if (!isPrivate) {
      return true;
    }

    // Show private posts only if user follows them
    return followingSet.contains(postAuthorId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.black),
          );
        }

        final firebaseUser = authSnapshot.data;
        final postsProvider = Provider.of<PostsProvider>(
          context,
          listen: false,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (firebaseUser == null) {
            postsProvider.resetListening();
          } else {
            postsProvider.startListening();
          }
        });

        final currentUser = FirebaseAuth.instance.currentUser;

        // FIX: Check if currentUser is null before proceeding
        if (currentUser == null) {
          return const Center(child: Text('Please sign in to continue'));
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    );
                  }

                  if (userSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading user data: ${userSnapshot.error}',
                      ),
                    );
                  }

                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const Center(child: Text('User profile not found'));
                  }

                  List<String> blockedUsers = List<String>.from(
                    userSnapshot.data!.get('blocked') ?? [],
                  );

                  // Determine user type
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  final isPremium =
                      userData != null && (userData['isSub'] == true);

                  // For non-premium users: show only public posts
                  if (!isPremium) {
                    return StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('posts')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                      builder: (context, postsSnapshot) {
                        if (postsSnapshot.hasError) {
                          return Text('Error: ${postsSnapshot.error}');
                        }
                        if (postsSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator(
                            color: Colors.black,
                          );
                        }

                        final posts = postsSnapshot.data?.docs ?? [];

                        // Extract author IDs for batch fetch
                        final authorIds = <String>{};
                        for (var post in posts) {
                          final data = post.data() as Map<String, dynamic>;
                          authorIds.add(data['userId'] as String);
                        }

                        // Stream author data for privacy checking
                        return StreamBuilder<Map<String, Map<String, dynamic>>>(
                          stream: _streamAuthorDataRealtime(authorIds.toList()),
                          builder: (context, authorsSnapshot) {
                            if (!authorsSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                ),
                              );
                            }

                            final authorsMap = authorsSnapshot.data ?? {};

                            // Filter posts with search query and privacy
                            final filteredPosts =
                                posts.where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final authorData =
                                      authorsMap[data['userId'] as String] ??
                                      {};

                                  // Check if post is from a blocked user
                                  if (blockedUsers.contains(data['userId'])) {
                                    return false;
                                  }

                                  // FIX: Safe string comparison for search query
                                  if (widget.searchQuery.isNotEmpty) {
                                    final postText =
                                        data['text']
                                            ?.toString()
                                            .toLowerCase() ??
                                        '';
                                    if (!postText.contains(
                                      widget.searchQuery,
                                    )) {
                                      return false;
                                    }
                                  }

                                  // Check if user marked post as not interested
                                  final notInterestedBy = List<dynamic>.from(
                                    data['notInterestedBy'] ?? [],
                                  );
                                  if (notInterestedBy.contains(
                                    currentUser.uid,
                                  )) {
                                    return false;
                                  }

                                  // Only show if author's profile is public
                                  return (authorData['isPrivate'] ?? false) ==
                                      false;
                                }).toList();

                            return ListView.builder(
                              controller: _scrollController,
                              itemCount: filteredPosts.length,
                              itemBuilder: (context, index) {
                                final post =
                                    filteredPosts[index].data()
                                        as Map<String, dynamic>;
                                return GuestPostItem(post: post);
                              },
                            );
                          },
                        );
                      },
                    );
                  }

                  // For premium users: full privacy filtering with following
                  return StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.uid)
                            .collection('following')
                            .snapshots(),
                    builder: (context, followingSnapshot) {
                      // Build the following set
                      final followingSet = <String>{};
                      if (followingSnapshot.hasData) {
                        for (var doc in followingSnapshot.data!.docs) {
                          final userId = doc.get('userId') as String?;
                          if (userId != null) {
                            followingSet.add(userId);
                          }
                        }
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('posts')
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                        builder: (context, postsSnapshot) {
                          if (postsSnapshot.hasError) {
                            return Text('Error: ${postsSnapshot.error}');
                          }

                          if (postsSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator(
                              color: Colors.black,
                            );
                          }

                          final posts = postsSnapshot.data?.docs ?? [];

                          // Extract author IDs for batch fetch
                          final authorIds = <String>{};
                          for (var post in posts) {
                            final data = post.data() as Map<String, dynamic>;
                            authorIds.add(data['userId'] as String);
                          }

                          // Stream author data for privacy and follower checking
                          return StreamBuilder<
                            Map<String, Map<String, dynamic>>
                          >(
                            stream: _streamAuthorDataRealtime(
                              authorIds.toList(),
                            ),
                            builder: (context, authorsSnapshot) {
                              if (!authorsSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                  ),
                                );
                              }

                              final authorsMap = authorsSnapshot.data ?? {};

                              // Filter posts with search query and privacy
                              final filteredPosts =
                                  posts.where((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final postAuthorId =
                                        data['userId'] as String;
                                    final authorData =
                                        authorsMap[postAuthorId] ?? {};

                                    // Check if post is from a blocked user
                                    if (blockedUsers.contains(postAuthorId)) {
                                      return false;
                                    }

                                    // FIX: Safe string comparison for search query
                                    if (widget.searchQuery.isNotEmpty) {
                                      final postText =
                                          data['text']
                                              ?.toString()
                                              .toLowerCase() ??
                                          '';
                                      if (!postText.contains(
                                        widget.searchQuery,
                                      )) {
                                        return false;
                                      }
                                    }

                                    // Check if user marked post as not interested
                                    final notInterestedBy = List<dynamic>.from(
                                      data['notInterestedBy'] ?? [],
                                    );
                                    if (notInterestedBy.contains(
                                      currentUser.uid,
                                    )) {
                                      return false;
                                    }

                                    // Check privacy rules
                                    return _shouldShowPost(
                                      postAuthorId: postAuthorId,
                                      currentUserId: currentUser.uid,
                                      authorData: authorData,
                                      followingSet: followingSet,
                                    );
                                  }).toList();

                              return ListView.builder(
                                controller: _scrollController,
                                itemCount: filteredPosts.length,
                                itemBuilder: (context, index) {
                                  final post =
                                      filteredPosts[index].data()
                                          as Map<String, dynamic>;
                                  return PostItem(
                                    postId: post['postId'],
                                    fromComments: false,
                                  );
                                },
                              );
                            },
                          );
                        },
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
  }
}

class FollowingSearchTab extends StatefulWidget {
  const FollowingSearchTab({super.key, this.searchQuery});
  final String? searchQuery; // FIX: Added proper type annotation

  @override
  State<FollowingSearchTab> createState() => _FollowingSearchTabState();
}

class _FollowingSearchTabState extends State<FollowingSearchTab> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index].data() as Map<String, dynamic>;
            final user = MyUser.fromDocument(doc);

            // FIX: Safe search query comparison
            final searchQuery = widget.searchQuery ?? '';
            if (user.userId == FirebaseAuth.instance.currentUser!.uid ||
                (searchQuery.isNotEmpty &&
                    !user.name.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ))) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: NetworkImage(user.url),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          if (user.bio != null && user.bio!.isNotEmpty) ...{
                            const SizedBox(height: 2),
                            Text(
                              user.bio.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          },
                        ],
                      ),
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser?.uid)
                              .collection('following')
                              .doc(user.userId)
                              .snapshots(),
                      builder: (context, followingSnapshot) {
                        final isFollowing =
                            followingSnapshot.hasData &&
                            followingSnapshot.data!.exists;

                        // Check if user is private
                        final isPrivate = user.isPrivate ?? false;

                        if (isFollowing) {
                          // Already following
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.black,
                              minimumSize: Size(47, 33),
                              textStyle: TextStyle(
                                fontSize: 12,
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.w500,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () async {
                              FollowService().toggleFollow(user.userId);
                            },
                            child: Text(
                              '구독 취소',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        // Not following - check if private
                        if (isPrivate) {
                          // Check for pending follow request
                          return StreamBuilder<DocumentSnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.userId)
                                    .collection('followRequests')
                                    .doc(FirebaseAuth.instance.currentUser?.uid)
                                    .snapshots(),
                            builder: (context, requestSnapshot) {
                              final hasRequest =
                                  requestSnapshot.hasData &&
                                  requestSnapshot.data!.exists;

                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      hasRequest
                                          ? Colors.grey[300]
                                          : ColorsManager.primary600,
                                  foregroundColor:
                                      hasRequest ? Colors.black : Colors.white,
                                  minimumSize: Size(47, 33),
                                  textStyle: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w500,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () async {
                                  if (hasRequest) {
                                    // Cancel request
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.userId)
                                        .collection('followRequests')
                                        .doc(
                                          FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.uid,
                                        )
                                        .delete();
                                  } else {
                                    // Send request
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.userId)
                                        .collection('followRequests')
                                        .doc(
                                          FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.uid,
                                        )
                                        .set({
                                          'userId':
                                              FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid,
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                  }
                                },
                                child: Text(
                                  hasRequest ? '요청 취소' : '요청',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        // Public profile - show follow button
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorsManager.primary600,
                            foregroundColor: Colors.white,
                            minimumSize: Size(47, 33),
                            textStyle: TextStyle(
                              fontSize: 12,
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () async {
                            FollowService().toggleFollow(user.userId);
                          },
                          child: Text(
                            '구독',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
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
