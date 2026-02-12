import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/follow_feed_screen.dart';
import 'package:ecommerece_app/features/home/search_screen.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_item.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  final ScrollController? scrollController;
  final TabController? tabController;
  const HomeScreen({super.key, this.scrollController, this.tabController});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final firebaseUser = authSnapshot.data;

        // If tabController is provided from parent, use it; otherwise create a new one
        if (widget.tabController != null) {
          return _buildScaffold(firebaseUser, widget.tabController!);
        } else {
          return DefaultTabController(
            length: 2,
            child: _buildScaffold(firebaseUser, null),
          );
        }
      },
    );
  }

  Widget _buildScaffold(User? firebaseUser, TabController? tabController) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 130,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              onTap: () {
                if (firebaseUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("검색은 회원가입 후 이용가능합니다")),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HomeSearch()),
                );
              },
              child: ImageIcon(
                AssetImage('assets/search.png'),
                color: Colors.black,
                size: 25,
              ),
            ),
            TabBar(
              controller: tabController,
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
              tabs: [Tab(text: '추천'), Tab(text: '구독')],
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          _HomeFeedTab(scrollController: widget.scrollController),
          FollowingTab(),
        ],
      ),
    );
  }
}

class _HomeFeedTab extends StatefulWidget {
  final ScrollController? scrollController;
  const _HomeFeedTab({this.scrollController});
  @override
  State<_HomeFeedTab> createState() => _HomeFeedTabState();
}

class _HomeFeedTabState extends State<_HomeFeedTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    // Only dispose if we created the controller
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
    final ScrollController? controller = widget.scrollController;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.black));
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

        // If no user, show the guest version of the UI
        if (firebaseUser == null) {
          // Guest user: show only public profile posts
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('posts')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, postsSnapshot) {
              if (postsSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: Colors.black),
                );
              }
              if (postsSnapshot.hasError) {
                return Center(child: Text('Error: ${postsSnapshot.error}'));
              }

              final posts = postsSnapshot.data?.docs ?? [];

              // Extract author IDs for batch fetch
              final authorIds = <String>{};
              for (var post in posts) {
                final data = post.data() as Map<String, dynamic>;
                authorIds.add(data['userId'] as String);
              }

              // Stream author data in real-time for privacy checking
              return StreamBuilder<Map<String, Map<String, dynamic>>>(
                stream: _streamAuthorDataRealtime(authorIds.toList()),
                builder: (context, authorsSnapshot) {
                  if (!authorsSnapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    );
                  }

                  final authorsMap = authorsSnapshot.data ?? {};

                  // Filter to show only public posts
                  final filteredPosts =
                      posts.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final authorData =
                            authorsMap[data['userId'] as String] ?? {};
                        // Only show if author's profile is public
                        return (authorData['isPrivate'] ?? false) == false;
                      }).toList();

                  return ListView.separated(
                    controller: controller,
                    itemCount: filteredPosts.length + 1, // +1 for user info row
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // User info row
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                horizontalSpace(3),
                                Flexible(
                                  child: InkWell(
                                    onTap: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "내 페이지 탭에서 회원가입 후 이용가능합니다",
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 65,
                                      height: 65,
                                      decoration: ShapeDecoration(
                                        image: DecorationImage(
                                          image: AssetImage(
                                            'assets/avatar.png',
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                        shape: OvalBorder(),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: InkWell(
                                    onTap: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "내 페이지 탭에서 회원가입 후 이용가능합니다",
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.only(right: 10),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          verticalSpace(8),
                                          Text(
                                            '게스트 사용자',
                                            style: TextStyles
                                                .abeezee16px400wPblack
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          verticalSpace(8),
                                          FutureBuilder(
                                            future:
                                                FirebaseFirestore.instance
                                                    .collection('widgets')
                                                    .doc('placeholders')
                                                    .get(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.black,
                                                      ),
                                                );
                                              }
                                              if (snapshot.hasError) {
                                                return const Center(
                                                  child: Text('Error'),
                                                );
                                              }
                                              return Text(
                                                snapshot.data!
                                                    .data()!['outerPlaceholderText'],
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xFF5F5F5F,
                                                  ),
                                                  fontSize: 13,
                                                  fontFamily: 'NotoSans',
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            verticalSpace(5),
                            Divider(),
                          ],
                        );
                      } else {
                        final post =
                            filteredPosts[index - 1].data()
                                as Map<String, dynamic>;
                        if (post['postId'] == null) {
                          post['postId'] = filteredPosts[index - 1].id;
                        }
                        return Column(
                          children: [
                            GuestPostItem(post: post),
                            verticalSpace(10),
                          ],
                        );
                      }
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      if (index < posts.length - 1 && index > 0) {
                        return Divider();
                      } else {
                        // For the very last item, return an empty widget
                        return SizedBox.shrink(); // A zero-sized box
                      }
                    },
                  );
                },
              );
            },
          );
        }

        // User is logged in, listen to user doc in real time
        return StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(firebaseUser.uid)
                  .snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(color: Colors.black),
              );
            }
            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            if (userData == null) {
              return Center(child: Text('User profile not found'));
            }
            final currentUser = MyUser.fromDocument(userData);

            // --- Non-premium user: can only view posts from public profiles ---
            if (!currentUser.isSub) {
              // Non-premium user: show only public profile posts
              return StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('posts')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                builder: (context, postsSnapshot) {
                  if (postsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    );
                  }
                  if (postsSnapshot.hasError) {
                    return Center(child: Text('Error: ${postsSnapshot.error}'));
                  }

                  final posts = postsSnapshot.data?.docs ?? [];

                  // Extract author IDs for batch fetch
                  final authorIds = <String>{};
                  for (var post in posts) {
                    final data = post.data() as Map<String, dynamic>;
                    authorIds.add(data['userId'] as String);
                  }

                  // Stream author data in real-time for privacy checking
                  return StreamBuilder<Map<String, Map<String, dynamic>>>(
                    stream: _streamAuthorDataRealtime(authorIds.toList()),
                    builder: (context, authorsSnapshot) {
                      if (!authorsSnapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(color: Colors.black),
                        );
                      }

                      final authorsMap = authorsSnapshot.data ?? {};

                      // Filter to show only public posts
                      final filteredPosts =
                          posts.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final authorData =
                                authorsMap[data['userId'] as String] ?? {};
                            // Only show if author's profile is public
                            return (authorData['isPrivate'] ?? false) == false;
                          }).toList();

                      return ListView.separated(
                        controller: controller,
                        itemCount:
                            filteredPosts.length + 1, // +1 for user info row

                        itemBuilder: (context, index) {
                          if (index == 0) {
                            // User info row for regular (non-premium) member
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    horizontalSpace(3),
                                    Flexible(
                                      child: InkWell(
                                        onTap: () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "프리미엄 가입 후 이용가능합니다",
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: 65,
                                          height: 65,
                                          decoration: ShapeDecoration(
                                            image: DecorationImage(
                                              image: NetworkImage(
                                                currentUser.url,
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                            shape: OvalBorder(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Padding(
                                        padding: EdgeInsets.only(right: 10),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            verticalSpace(8),
                                            Text(
                                              currentUser.name,
                                              style: TextStyles
                                                  .abeezee16px400wPblack
                                                  .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),

                                            verticalSpace(8),
                                            FutureBuilder(
                                              future:
                                                  FirebaseFirestore.instance
                                                      .collection('widgets')
                                                      .doc('placeholders')
                                                      .get(),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Colors.black,
                                                        ),
                                                  );
                                                }
                                                if (snapshot.hasError) {
                                                  return const Center(
                                                    child: Text('Error'),
                                                  );
                                                }
                                                return InkWell(
                                                  onTap: () {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          "프리미엄 회원 가입 후 게시글 작성, 좋아요, 댓글 사용할 수 있습니다!",
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: Text(
                                                    snapshot.data!
                                                        .data()!['outerPlaceholderText'],
                                                    style: TextStyle(
                                                      color: const Color(
                                                        0xFF5F5F5F,
                                                      ),
                                                      fontSize: 13,
                                                      fontFamily: 'NotoSans',
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                verticalSpace(5),
                                Divider(),
                                verticalSpace(5),
                              ],
                            );
                          } else {
                            final post =
                                filteredPosts[index - 1].data()
                                    as Map<String, dynamic>;
                            if (post['postId'] == null) {
                              post['postId'] = filteredPosts[index - 1].id;
                            }
                            return Column(
                              children: [
                                GuestPostItem(post: post),
                                verticalSpace(10),
                              ],
                            );
                          }
                        },
                        separatorBuilder: (BuildContext context, int index) {
                          if (index < posts.length - 1 && index > 0) {
                            return Divider();
                          } else {
                            // For the very last item, return an empty widget
                            return SizedBox.shrink(); // A zero-sized box
                          }
                        },
                      );
                    },
                  );
                },
              );
            }

            // --- Premium user: full interaction ---
            // Premium user: user info row and posts scroll together in a single ListView
            List<String> blockedUsers = List<String>.from(
              userSnapshot.data!.get('blocked') ?? [],
            );

            // Stream the following list for privacy filtering
            return StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.userId)
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

                // Now stream posts
                return StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('posts')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                  builder: (context, postsSnapshot) {
                    if (postsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      );
                    }
                    if (postsSnapshot.hasError) {
                      return Center(
                        child: Text('Error: ${postsSnapshot.error}'),
                      );
                    }

                    final posts = postsSnapshot.data?.docs ?? [];

                    // Extract author IDs for batch fetch
                    final authorIds = <String>{};
                    for (var post in posts) {
                      final data = post.data() as Map<String, dynamic>;
                      authorIds.add(data['userId'] as String);
                    }

                    // Stream author data in real-time for privacy and follower checking
                    return StreamBuilder<Map<String, Map<String, dynamic>>>(
                      stream: _streamAuthorDataRealtime(authorIds.toList()),
                      builder: (context, authorsSnapshot) {
                        if (!authorsSnapshot.hasData) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Colors.black,
                            ),
                          );
                        }

                        final authorsMap = authorsSnapshot.data ?? {};

                        // Filter posts with privacy rules
                        final List<DocumentSnapshot> filteredPosts =
                            posts.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final postAuthorId = data['userId'] as String;
                              final authorData = authorsMap[postAuthorId] ?? {};

                              // Check if post is from a blocked user
                              if (blockedUsers.contains(postAuthorId)) {
                                return false;
                              }

                              // Check if user marked post as not interested
                              final notInterestedBy = List<dynamic>.from(
                                data['notInterestedBy'] ?? [],
                              );
                              if (notInterestedBy.contains(
                                currentUser.userId,
                              )) {
                                return false;
                              }

                              // Check privacy rules
                              return _shouldShowPost(
                                postAuthorId: postAuthorId,
                                currentUserId: currentUser.userId,
                                authorData: authorData,
                                followingSet: followingSet,
                              );
                            }).toList();
                        return ListView.separated(
                          controller: controller,
                          itemCount:
                              filteredPosts.length + 1, // +1 for user info row
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              // User info row
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      horizontalSpace(3),

                                      Flexible(
                                        child: InkWell(
                                          onTap: () {
                                            context.pushNamed(
                                              Routes.alertsScreen,
                                            );
                                          },
                                          child: StreamBuilder<QuerySnapshot>(
                                            stream:
                                                FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(currentUser.userId)
                                                    .collection('notifications')
                                                    .where(
                                                      'isRead',
                                                      isEqualTo: false,
                                                    )
                                                    .limit(1)
                                                    .snapshots(),
                                            builder: (context, notifSnapshot) {
                                              final hasUnread =
                                                  notifSnapshot.hasData &&
                                                  notifSnapshot
                                                      .data!
                                                      .docs
                                                      .isNotEmpty;
                                              return Stack(
                                                clipBehavior:
                                                    Clip.none, // Allow overflow

                                                children: [
                                                  Container(
                                                    width: 65,
                                                    height: 65,
                                                    decoration: ShapeDecoration(
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                          currentUser.url
                                                              .toString(),
                                                        ),
                                                        fit: BoxFit.cover,
                                                      ),
                                                      shape: OvalBorder(),
                                                    ),
                                                  ),
                                                  if (hasUnread)
                                                    Positioned(
                                                      left: 0,
                                                      top: 0,
                                                      child: Image.asset(
                                                        'assets/notification.png',
                                                        width: 18,
                                                        height: 18,
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: InkWell(
                                          onTap: () {
                                            context.go(Routes.addPostScreen);
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.only(right: 10),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                verticalSpace(8),
                                                Text(
                                                  currentUser.name.toString(),
                                                  style: TextStyles
                                                      .abeezee16px400wPblack
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),

                                                verticalSpace(8),

                                                FutureBuilder(
                                                  future:
                                                      FirebaseFirestore.instance
                                                          .collection('widgets')
                                                          .doc('placeholders')
                                                          .get(),
                                                  builder: (context, snapshot) {
                                                    if (snapshot
                                                            .connectionState ==
                                                        ConnectionState
                                                            .waiting) {
                                                      return const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                      );
                                                    }
                                                    if (snapshot.hasError) {
                                                      return const Center(
                                                        child: Text('Error'),
                                                      );
                                                    }
                                                    return Text(
                                                      snapshot.data!
                                                          .data()!['outerPlaceholderText'],
                                                      style: TextStyle(
                                                        color: const Color(
                                                          0xFF5F5F5F,
                                                        ),
                                                        fontSize: 13,
                                                        fontFamily: 'NotoSans',
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  verticalSpace(5),
                                  Divider(),
                                ],
                              );
                            } else {
                              final post =
                                  filteredPosts[index - 1].data()
                                      as Map<String, dynamic>;
                              return Column(
                                children: [
                                  PostItem(
                                    postId: post['postId'],
                                    fromComments: false,
                                  ),
                                  verticalSpace(16),
                                ],
                              );
                            }
                          },
                          separatorBuilder: (BuildContext context, int index) {
                            if (index < posts.length - 1 && index > 0) {
                              return Divider();
                            } else {
                              // For the very last item, return an empty widget
                              return SizedBox.shrink(); // A zero-sized box
                            }
                          },
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
    );
  }
}
