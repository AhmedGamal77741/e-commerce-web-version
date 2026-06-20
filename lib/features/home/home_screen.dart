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
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  User? _firebaseUser;
  Stream<DocumentSnapshot>? _userStream;
  int _selectedIndex = 0;
  bool isSub = false;
  late final StreamSubscription<User?> _authSubscription;
  late final ScrollController _feedTabController;
  late final ScrollController _followingTabController;
  late final ScrollController _myStoryTabController;

  /// Called by NavBar when the home icon is tapped while already on home.
  void resetToTop() {
    // Pop any navigator sub-pages back to root
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    // Scroll to top of the current tab
    final controller =
        _selectedIndex == 0
            ? _feedTabController
            : _selectedIndex == 1
            ? _followingTabController
            : _myStoryTabController;

    if (controller.hasClients) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _feedTabController = ScrollController();
    _followingTabController = ScrollController();
    _myStoryTabController = ScrollController();
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
          _firebaseUser = user;
          if (user != null) {
            _userStream =
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots();
          } else {
            _userStream = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _feedTabController.dispose();
    _followingTabController.dispose();
    _myStoryTabController.dispose();
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
                              clipBehavior: Clip.none,
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
                    MaterialPageRoute(
                      builder: (context) => HomeSearch(initialTabIndex: 1),
                    ),
                  );
                },
                child: ImageIcon(
                  AssetImage('assets/search_icon.png'),
                  color: Colors.black,
                  size: 30,
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

        body: Column(
          children: [
            _buildNormalPillRow(firebaseUser),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _HomeFeedTab(scrollController: _feedTabController),
                  FollowingTab(
                    firebaseUser: firebaseUser,
                    scrollController: _followingTabController,
                  ),
                  MyStory(scrollController: _myStoryTabController),
                ],
              ),
            ),
          ],
        ),
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

  // Data caches to prevent StreamBuilder flickering and waiting states
  DocumentSnapshot? _lastProfileDoc;
  QuerySnapshot? _lastFollowingDocs;
  QuerySnapshot? _lastPostsDocs;
  Map<String, Map<String, dynamic>>? _lastAuthorsData;

  final Stream<QuerySnapshot> _postsStream =
      FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots();

  Stream<DocumentSnapshot>? _userProfileStream;
  Stream<QuerySnapshot>? _followingStream;
  Stream<QuerySnapshot>? _hiddenFriendsStream;
  Stream<User?>? _authStream;
  String? _cachedUserId;

  List<String> _cachedAuthorIds = [];
  Stream<Map<String, Map<String, dynamic>>>? _cachedAuthorStream;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  // Helper to get or update stable streams based on current user
  void _updateStreamsIfNecessary(String uid) {
    if (_cachedUserId != uid) {
      _cachedUserId = uid;
      _userProfileStream =
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
      _followingStream =
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('following')
              .snapshots();
      _hiddenFriendsStream =
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('hiddenFriends')
              .snapshots();
    }
  }

  Stream<Map<String, Map<String, dynamic>>> _getStableAuthorStream(
    List<String> newAuthorIds,
  ) {
    bool isSame = _cachedAuthorIds.length == newAuthorIds.length;
    if (isSame) {
      final sortedCached = List<String>.from(_cachedAuthorIds)..sort();
      final sortedNew = List<String>.from(newAuthorIds)..sort();
      for (int i = 0; i < sortedNew.length; i++) {
        if (sortedCached[i] != sortedNew[i]) {
          isSame = false;
          break;
        }
      }
    }

    if (!isSame || _cachedAuthorStream == null) {
      _cachedAuthorIds = List.from(newAuthorIds);
      _cachedAuthorStream = _streamAuthorDataRealtime(_cachedAuthorIds);
    }

    return _cachedAuthorStream!;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Stream<Map<String, Map<String, dynamic>>> _streamAuthorDataRealtime(
    List<String> authorIds,
  ) {
    if (authorIds.isEmpty) {
      return Stream.value(<String, Map<String, dynamic>>{}).asBroadcastStream();
    }

    final chunks = <List<String>>[];
    for (var i = 0; i < authorIds.length; i += 10) {
      chunks.add(
        authorIds.sublist(
          i,
          i + 10 > authorIds.length ? authorIds.length : i + 10,
        ),
      );
    }

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

    if (streams.length == 1) {
      return streams[0];
    }

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
                final combined = <String, Map<String, dynamic>>{};
                for (var map in dataMaps) {
                  combined.addAll(map);
                }
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

  bool _shouldShowPost({
    required String postAuthorId,
    required String currentUserId,
    required Map<String, dynamic> authorData,
    required Set<String> followingSet,
  }) {
    if (postAuthorId == currentUserId) {
      return false;
    }

    final bool isPrivate = authorData['isPrivate'] ?? false;

    if (!isPrivate) {
      return true;
    }

    return followingSet.contains(postAuthorId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Center();
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

        if (firebaseUser == null) {
          _cachedUserId = null;
          _lastProfileDoc = null;
          _lastFollowingDocs = null;
          _lastAuthorsData = null;
          _cachedAuthorIds.clear();
          _cachedAuthorStream = null;
          return StreamBuilder<QuerySnapshot>(
            stream: _postsStream,
            initialData: _lastPostsDocs,
            builder: (context, postsSnapshot) {
              if (postsSnapshot.hasData) {
                _lastPostsDocs = postsSnapshot.data;
              }
              if (postsSnapshot.connectionState == ConnectionState.waiting &&
                  !postsSnapshot.hasData) {
                return Center();
              }
              if (postsSnapshot.hasError) {
                return Center(child: Text('Error: ${postsSnapshot.error}'));
              }

              final posts = postsSnapshot.data?.docs ?? [];

              final authorIds = <String>{};
              for (var post in posts) {
                final data = post.data() as Map<String, dynamic>;
                authorIds.add(data['userId'] as String);
              }

              return StreamBuilder<Map<String, Map<String, dynamic>>>(
                stream: _getStableAuthorStream(authorIds.toList()),
                initialData: _lastAuthorsData,
                builder: (context, authorsSnapshot) {
                  if (authorsSnapshot.hasData) {
                    _lastAuthorsData = authorsSnapshot.data;
                  }
                  if (!authorsSnapshot.hasData) {
                    return Center();
                  }

                  final authorsMap = authorsSnapshot.data ?? {};

                  final filteredPosts =
                      posts.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final authorData =
                            authorsMap[data['userId'] as String] ?? {};
                        return (authorData['isPrivate'] ?? false) == false;
                      }).toList();

                  return ListView.builder(
                    shrinkWrap: true,
                    controller: widget.scrollController,
                    itemCount: filteredPosts.length,
                    itemBuilder: (context, index) {
                      final post =
                          filteredPosts[index].data() as Map<String, dynamic>;
                      final postId = filteredPosts[index].id;
                      if (post['postId'] == null) {
                        post['postId'] = postId;
                      }
                      return Column(
                        key: ValueKey(postId),
                        children: [
                          GuestPostItem(post: post),
                          verticalSpace(10),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        }

        _updateStreamsIfNecessary(firebaseUser.uid);

        return StreamBuilder<DocumentSnapshot>(
          stream: _userProfileStream,
          initialData: _lastProfileDoc,
          builder: (context, userSnapshot) {
            if (userSnapshot.hasData) {
              _lastProfileDoc = userSnapshot.data;
            }
            if (!userSnapshot.hasData) {
              return Center();
            }
            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            if (userData == null) {
              return Center(child: Text('User profile not found'));
            }
            final currentUser = MyUser.fromDocument(userData);

            List<String> blockedUsers = List<String>.from(
              (userData['blocked'] as List<dynamic>?) ?? [],
            );

            return StreamBuilder<QuerySnapshot>(
              stream: _hiddenFriendsStream,
              builder: (context, hiddenFriendsSnapshot) {
                final hiddenFriendsSet = <String>{};
                if (hiddenFriendsSnapshot.hasData) {
                  for (var doc in hiddenFriendsSnapshot.data!.docs) {
                    hiddenFriendsSet.add(doc.id);
                  }
                }

                if (!currentUser.isSub) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: _postsStream,
                    initialData: _lastPostsDocs,
                    builder: (context, postsSnapshot) {
                      if (postsSnapshot.hasData) {
                        _lastPostsDocs = postsSnapshot.data;
                      }
                      if (postsSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !postsSnapshot.hasData) {
                        return Center();
                      }
                      if (postsSnapshot.hasError) {
                        return Center(
                          child: Text('Error: ${postsSnapshot.error}'),
                        );
                      }

                      final posts = postsSnapshot.data?.docs ?? [];

                      final authorIds = <String>{};
                      for (var post in posts) {
                        final data = post.data() as Map<String, dynamic>;
                        if ((data['userId'] as String) == currentUser.userId) {
                          continue;
                        }
                        authorIds.add(data['userId'] as String);
                      }

                      return StreamBuilder<Map<String, Map<String, dynamic>>>(
                        stream: _getStableAuthorStream(authorIds.toList()),
                        initialData: _lastAuthorsData,
                        builder: (context, authorsSnapshot) {
                          if (authorsSnapshot.hasData) {
                            _lastAuthorsData = authorsSnapshot.data;
                          }
                          if (!authorsSnapshot.hasData) {
                            return Center();
                          }

                          final authorsMap = authorsSnapshot.data ?? {};

                          final filteredPosts =
                              posts.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final postAuthorId = data['userId'] as String;

                                if (postAuthorId == currentUser.userId) {
                                  return false;
                                }
                                if (blockedUsers.contains(postAuthorId) ||
                                    hiddenFriendsSet.contains(postAuthorId)) {
                                  return false;
                                }

                                final authorData =
                                    authorsMap[postAuthorId] ?? {};
                                final authorBlockedUsers = List<dynamic>.from(
                                  authorData['blocked'] ?? [],
                                );
                                if (authorBlockedUsers.contains(
                                  currentUser.userId,
                                )) {
                                  return false;
                                }

                                final notInterestedBy = List<dynamic>.from(
                                  data['notInterestedBy'] ?? [],
                                );
                                if (notInterestedBy.contains(
                                  currentUser.userId,
                                )) {
                                  return false;
                                }

                                return (authorData['isPrivate'] ?? false) ==
                                    false;
                              }).toList();

                          return ListView.builder(
                            shrinkWrap: true,
                            controller: widget.scrollController,
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
                                key: ValueKey(post['postId']),
                                children: [
                                  PostItem(
                                    postId: post['postId'],
                                    fromComments: false,
                                  ),
                                  verticalSpace(10),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                }

                // (blockedUsers already extracted above)

                return StreamBuilder<QuerySnapshot>(
                  stream: _followingStream,
                  initialData: _lastFollowingDocs,
                  builder: (context, followingSnapshot) {
                    if (followingSnapshot.hasData) {
                      _lastFollowingDocs = followingSnapshot.data;
                    }
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
                      stream: _postsStream,
                      initialData: _lastPostsDocs,
                      builder: (context, postsSnapshot) {
                        if (postsSnapshot.hasData) {
                          _lastPostsDocs = postsSnapshot.data;
                        }
                        if (postsSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !postsSnapshot.hasData) {
                          return Center();
                        }
                        if (postsSnapshot.hasError) {
                          return Center(
                            child: Text('Error: ${postsSnapshot.error}'),
                          );
                        }

                        final posts = postsSnapshot.data?.docs ?? [];

                        final authorIds = <String>{};
                        for (var post in posts) {
                          final data = post.data() as Map<String, dynamic>;
                          if ((data['userId'] as String) ==
                              currentUser.userId) {
                            continue;
                          }
                          authorIds.add(data['userId'] as String);
                        }

                        return StreamBuilder<Map<String, Map<String, dynamic>>>(
                          stream: _getStableAuthorStream(authorIds.toList()),
                          initialData: _lastAuthorsData,
                          builder: (context, authorsSnapshot) {
                            if (authorsSnapshot.hasData) {
                              _lastAuthorsData = authorsSnapshot.data;
                            }
                            if (!authorsSnapshot.hasData) {
                              return Center();
                            }

                            final authorsMap = authorsSnapshot.data ?? {};

                            final List<DocumentSnapshot> filteredPosts =
                                posts.where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final postAuthorId = data['userId'] as String;
                                  final authorData =
                                      authorsMap[postAuthorId] ?? {};

                                  if (blockedUsers.contains(postAuthorId) ||
                                      hiddenFriendsSet.contains(postAuthorId)) {
                                    return false;
                                  }

                                  final authorBlockedUsers = List<dynamic>.from(
                                    authorData['blocked'] ?? [],
                                  );
                                  if (authorBlockedUsers.contains(
                                    currentUser.userId,
                                  )) {
                                    return false;
                                  }

                                  final notInterestedBy = List<dynamic>.from(
                                    data['notInterestedBy'] ?? [],
                                  );
                                  if (notInterestedBy.contains(
                                    currentUser.userId,
                                  )) {
                                    return false;
                                  }

                                  return _shouldShowPost(
                                    postAuthorId: postAuthorId,
                                    currentUserId: currentUser.userId,
                                    authorData: authorData,
                                    followingSet: followingSet,
                                  );
                                }).toList();

                            return ListView.builder(
                              shrinkWrap: true,
                              controller: widget.scrollController,
                              itemCount: filteredPosts.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [],
                                  );
                                } else {
                                  final post =
                                      filteredPosts[index - 1].data()
                                          as Map<String, dynamic>;
                                  return Column(
                                    key: ValueKey(post['postId']),
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
      },
    );
  }
}
