import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/chat/models/chat_room_model.dart';
import 'package:ecommerece_app/features/chat/ui/chats_navbar.dart';
import 'package:ecommerece_app/features/chat/ui/friends_screen.dart';
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
  const HomeScreen({super.key, this.scrollController});
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 130,
          backgroundColor: ColorsManager.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, authSnapshot) {
                  final user = authSnapshot.data;
                  if (user == null) {
                    // Not authenticated: show disabled chat icon with tooltip
                    return Tooltip(
                      message: '로그인 후 채팅을 이용할 수 있습니다',
                      child: Opacity(
                        opacity: 0.4,
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('로그인 후 채팅을 이용할 수 있습니다'),
                              ),
                            );
                          },
                          child: ImageIcon(
                            AssetImage('assets/005 3.png'),
                            size: 21,
                          ),
                        ),
                      ),
                    );
                  }
                  // Authenticated: show chat icon with unread badge
                  return StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('chatRooms')
                        .where('participants', arrayContains: user.uid)
                        .orderBy('lastMessageTime', descending: true)
                        .snapshots()
                        .map(
                          (snapshot) =>
                              snapshot.docs
                                  .map(
                                    (doc) => ChatRoomModel.fromMap(doc.data()),
                                  )
                                  .toList(),
                        ),
                    builder: (context, snapshot) {
                      final currentUserId = user.uid;
                      bool hasUnread = false;
                      if (snapshot.hasData) {
                        final chatRooms = snapshot.data!;
                        hasUnread = chatRooms.any(
                          (room) => (room.unreadCount[currentUserId] ?? 0) > 0,
                        );
                      }
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatsNavbar(),
                            ),
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ImageIcon(AssetImage('assets/005 3.png'), size: 24),
                            if (hasUnread)
                              Positioned(
                                left: -10,
                                top: -5,
                                child: Image.asset(
                                  'assets/notification.png',
                                  width: 18,
                                  height: 18,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
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
                tabs: [Tab(text: '추천'), Tab(text: '구독')],
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _HomeFeedTab(scrollController: widget.scrollController),
            FollowingTab(),
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

  @override
  void dispose() {
    // Only dispose if we created the controller
    super.dispose();
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
          // Guest user: user info row and posts scroll together in a single ListView
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('posts')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: Colors.black),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final posts = snapshot.data?.docs ?? [];
              return ListView.builder(
                controller: controller,
                itemCount: posts.length + 1, // +1 for user info row
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
                            SizedBox(width: 10),
                            Flexible(
                              child: InkWell(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("내 페이지 탭에서 회원가입 후 이용가능합니다"),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 56,
                                  height: 55,
                                  decoration: ShapeDecoration(
                                    image: DecorationImage(
                                      image: AssetImage('assets/avatar.png'),
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("내 페이지 탭에서 회원가입 후 이용가능합니다"),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: EdgeInsets.only(right: 10),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '게스트 사용자',
                                        style: TextStyles.abeezee16px400wPblack,
                                      ),
                                      SizedBox(height: 10),

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
                                              child: CircularProgressIndicator(
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
                                              color: const Color(0xFF5F5F5F),
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
                        posts[index - 1].data() as Map<String, dynamic>;
                    if (post['postId'] == null) {
                      post['postId'] = posts[index - 1].id;
                    }
                    return Column(
                      children: [
                        GuestPostItem(post: post),
                        SizedBox(height: 16),
                      ],
                    );
                  }
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

            // --- Non-premium user: can only view posts, but sees their own info ---
            if (!currentUser.isSub) {
              // Non-premium user: user info row and posts scroll together in a single ListView
              return StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('posts')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final posts = snapshot.data?.docs ?? [];
                  return ListView.builder(
                    controller: controller,
                    itemCount: posts.length + 1, // +1 for user info row
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // User info row for regular (non-premium) member, now with search feature
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                SizedBox(width: 10),
                                Flexible(
                                  child: InkWell(
                                    onTap: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("프리미엄 가입 후 이용가능합니다"),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 56,
                                      height: 55,
                                      decoration: ShapeDecoration(
                                        image: DecorationImage(
                                          image: NetworkImage(currentUser.url),
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
                                        Row(
                                          children: [
                                            Text(
                                              currentUser.name,
                                              style:
                                                  TextStyles
                                                      .abeezee16px400wPblack,
                                            ),
                                            Spacer(),
                                            InkWell(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (context) =>
                                                            HomeSearch(),
                                                  ),
                                                );
                                              },
                                              child: ImageIcon(
                                                AssetImage('assets/search.png'),
                                                color: Colors.black,
                                                size: 25,
                                              ),
                                            ),
                                            SizedBox(width: 5),
                                          ],
                                        ),
                                        SizedBox(height: 10),
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
                                                color: const Color(0xFF5F5F5F),
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
                              ],
                            ),
                            verticalSpace(5),
                            Divider(),
                          ],
                        );
                      } else {
                        final post =
                            posts[index - 1].data() as Map<String, dynamic>;
                        if (post['postId'] == null) {
                          post['postId'] = posts[index - 1].id;
                        }
                        return Column(
                          children: [
                            GuestPostItem(post: post),
                            SizedBox(height: 16),
                          ],
                        );
                      }
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
            return StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('posts')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                // Filter posts
                final List<DocumentSnapshot> filteredPosts =
                    (snapshot.data?.docs ?? []).where((doc) {
                      Map<String, dynamic> data =
                          doc.data() as Map<String, dynamic>;
                      // Check if post is from a blocked user
                      if (blockedUsers.contains(data['userId'])) {
                        return false;
                      }
                      // Check if user marked post as not interested
                      List<dynamic> notInterestedBy = List<dynamic>.from(
                        data['notInterestedBy'] ?? [],
                      );
                      if (notInterestedBy.contains(currentUser.userId)) {
                        return false;
                      }
                      return true;
                    }).toList();
                return ListView.builder(
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
                              SizedBox(width: 10),

                              Flexible(
                                child: InkWell(
                                  onTap: () {
                                    context.pushNamed(
                                      Routes.notificationsScreen,
                                    );
                                  },
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream:
                                        FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(currentUser.userId)
                                            .collection('notifications')
                                            .where('isRead', isEqualTo: false)
                                            .limit(1)
                                            .snapshots(),
                                    builder: (context, notifSnapshot) {
                                      final hasUnread =
                                          notifSnapshot.hasData &&
                                          notifSnapshot.data!.docs.isNotEmpty;
                                      return Stack(
                                        clipBehavior:
                                            Clip.none, // Allow overflow

                                        children: [
                                          Container(
                                            width: 56,
                                            height: 55,
                                            decoration: ShapeDecoration(
                                              image: DecorationImage(
                                                image: NetworkImage(
                                                  currentUser.url.toString(),
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
                                        Row(
                                          children: [
                                            Text(
                                              currentUser.name.toString(),
                                              style:
                                                  TextStyles
                                                      .abeezee16px400wPblack,
                                            ),
                                            Spacer(),
                                            InkWell(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (context) =>
                                                            HomeSearch(),
                                                  ),
                                                );
                                              },
                                              child: ImageIcon(
                                                AssetImage('assets/search.png'),
                                                color: Colors.black,
                                                size: 25,
                                              ),
                                            ),
                                            SizedBox(width: 5),
                                          ],
                                        ),
                                        SizedBox(height: 10),

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
                                                color: const Color(0xFF5F5F5F),
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
                      return Column(
                        children: [
                          PostItem(postId: post['postId'], fromComments: false),
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
  }
}
