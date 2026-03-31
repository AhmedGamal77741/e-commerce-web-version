import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/follow_feed_screen.dart';
import 'package:ecommerece_app/features/home/search_screen.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_item.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:ecommerece_app/features/mypage/ui/my_story.dart';
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

  User? _firebaseUser;
  late Stream<DocumentSnapshot>? _userStream;
  int _selectedIndex = 0;
  bool isSub = false;
  late final _authSubscription;
  @override
  void initState() {
    super.initState();
    _firebaseUser = FirebaseAuth.instance.currentUser;
    if (_firebaseUser != null) {
      _userStream =
          FirebaseFirestore.instance
              .collection('users')
              .doc(_firebaseUser!.uid)
              .snapshots();
    }
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          if (_firebaseUser != null) {
            _userStream =
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(_firebaseUser!.uid)
                    .snapshots();
          }
          _firebaseUser = user;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  final List<Map<String, dynamic>> _userTabs = [
    {'label': '추천'},
    {'label': '구독'},
    {'label': 'MY'},
  ];

  final List<Map<String, dynamic>> _nonUserTabs = [
    {'label': '추천'},
  ];

  Widget _buildPill(int index) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _userTabs[index]['label'],
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildNormalPillRow(User? firebaseUser) {
    return Padding(
      padding: EdgeInsets.fromLTRB(5, 0, 5, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        key: const ValueKey('pills'),
        children: [
          firebaseUser == null
              ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < _nonUserTabs.length; i++) ...[
                      _buildPill(i),
                      if (i < _nonUserTabs.length - 1) SizedBox(width: 8),
                    ],
                  ],
                ),
              )
              : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < _userTabs.length; i++) ...[
                      _buildPill(i),
                      if (i < _userTabs.length - 1) SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () {
                  if (firebaseUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("검색은 회원가입 후 이용가능합니다")),
                    );
                    return;
                  }
                  context.pushNamed(Routes.alertsScreen);
                },
                child:
                    firebaseUser == null
                        ? Image.asset(
                          'assets/notification_bell_transparent.png',
                          height: 35,
                          width: 35,
                        )
                        : StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(firebaseUser.uid)
                                  .collection('notifications')
                                  .where('isRead', isEqualTo: false)
                                  .limit(1)
                                  .snapshots(),
                          builder: (context, notifSnapshot) {
                            final hasUnread =
                                notifSnapshot.hasData &&
                                notifSnapshot.data!.docs.isNotEmpty;
                            return Stack(
                              clipBehavior: Clip.none, // Allow overflow

                              children: [
                                Image.asset(
                                  'assets/notification_bell_transparent.png',
                                  height: 35,
                                  width: 35,
                                ),
                                if (hasUnread)
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    child: Image.asset(
                                      'assets/notification_dot.png',
                                      width: 18,
                                      height: 18,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
              ),
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
                  size: 35,
                ),
              ),
              horizontalSpace(5),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return _buildScaffold(_firebaseUser, widget.tabController, _selectedIndex);
  }

  Widget _buildScaffold(
    User? firebaseUser,
    TabController? tabController,
    int floating,
  ) {
    return SafeArea(
      child: Scaffold(
        floatingActionButton:
            (floating == 0 || floating == 2) && firebaseUser != null
                ? StreamBuilder(
                  stream: _userStream,
                  builder: (context, asyncSnapshot) {
                    if (!asyncSnapshot.hasData) {
                      return SizedBox.shrink();
                    }
                    final userData =
                        asyncSnapshot.data!.data() as Map<String, dynamic>?;
                    if (userData == null) {
                      return SizedBox.shrink();
                    }
                    final currentUser = MyUser.fromDocument(userData);
                    if (!currentUser.isSub) {
                      return SizedBox.shrink();
                    }
                    return FloatingActionButton(
                      heroTag: floating == 0 ? "home_feed_fab" : "MY_feed_fab",
                      shape: CircleBorder(),
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      highlightElevation: 0,
                      onPressed: () {
                        context.go(Routes.addPostScreen);
                      },
                      child: ClipOval(
                        child: Image.asset(
                          "assets/add_post_transparent.png",
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                )
                : null,

        body: ListView(
          children: [
            _buildNormalPillRow(firebaseUser),
            IndexedStack(
              index: _selectedIndex,
              children: [
                _HomeFeedTab(),
                FollowingTab(firebaseUser: firebaseUser),
                MyStory(),
              ],
            ),
          ],
        ),
        /* TabBarView(
          controller: tabController,
          children: [
            _HomeFeedTab(scrollController: widget.scrollController),
            FollowingTab(),
          ],
        ), */
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
      return false;
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

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),

                    controller: controller,
                    itemCount: filteredPosts.length,
                    itemBuilder: (context, index) {
                      final post =
                          filteredPosts[index].data() as Map<String, dynamic>;
                      final postId = filteredPosts[index].id;
                      if (post['postId'] == null) {
                        post['postId'] = postId;
                      }
                      return Column(
                        children: [
                          GuestPostItem(post: post),
                          verticalSpace(10),
                        ],
                      );
                    },
                    /*                     separatorBuilder: (BuildContext context, int index) {
                      if (index < posts.length - 1 && index > 0) {
                        return Divider();
                      } else {
                        // For the very last item, return an empty widget
                        return SizedBox.shrink(); // A zero-sized box
                      }
                    }, */
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
                    if ((data['userId'] as String) == currentUser.userId) {
                      continue;
                    }
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
                            return (authorData['isPrivate'] ?? false) ==
                                    false ||
                                data['userId'] != currentUser.userId;
                          }).toList();

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),

                        controller: controller,
                        itemCount: filteredPosts.length,

                        itemBuilder: (context, index) {
                          final post =
                              filteredPosts[index].data()
                                  as Map<String, dynamic>;
                          final postId = filteredPosts[index].id;
                          if (post['postId'] == null) {
                            post['postId'] = postId;
                          }
                          return Column(
                            children: [
                              GuestPostItem(post: post),
                              verticalSpace(10),
                            ],
                          );
                        },
                        /*                         separatorBuilder: (BuildContext context, int index) {
                          if (index < posts.length - 1 && index > 0) {
                            return Divider();
                          } else {
                            // For the very last item, return an empty widget
                            return SizedBox.shrink(); // A zero-sized box
                          }
                        }, */
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
                      if ((data['userId'] as String) == currentUser.userId) {
                        continue;
                      }
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
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),

                          controller: controller,
                          itemCount:
                              filteredPosts.length + 1, // +1 for user info row
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              // User info row
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  /* Row(
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
                                            padding: EdgeInsets.only(
                                              right: 10,
                                            ),
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
                                  Divider(), */
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
                                  SizedBox(height: 16),
                                ],
                              );
                            }
                          },
                          /*                           separatorBuilder: (BuildContext context, int index) {
                            if (index < posts.length - 1 && index > 0) {
                              return Divider();
                            } else {
                              // For the very last item, return an empty widget
                              return SizedBox.shrink(); // A zero-sized box
                            }
                          }, */
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
