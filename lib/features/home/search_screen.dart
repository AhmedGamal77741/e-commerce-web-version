import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/basetime.dart';
import 'package:ecommerece_app/core/helpers/extensions.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/home/data/follow_service.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/widgets/following_users_list.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_item.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:ecommerece_app/features/shop/cart_func.dart';
import 'package:ecommerece_app/features/shop/fav_fnc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HomeSearch extends StatefulWidget {
  final bool useGuestPostItem;
  const HomeSearch({super.key, this.useGuestPostItem = false});

  @override
  State<HomeSearch> createState() => _HomeSearchState();
}

class _HomeSearchState extends State<HomeSearch> {
  TextEditingController _searchController = TextEditingController();
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
          backgroundColor: ColorsManager.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios),
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
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.zero,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.zero,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: ImageIcon(AssetImage('assets/Frame 4.png')),
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
                tabs: [Tab(text: '추천'), Tab(text: '구독')],
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
    super.key,
    required this.searchQuery,
    this.useGuestPostItem = false,
  });

  @override
  State<_HomeFeedSearchTab> createState() => _HomeFeedSearchTabState();
}

class _HomeFeedSearchTabState extends State<_HomeFeedSearchTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  _HomeFeedSearchTabState();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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

        final currentUser = FirebaseAuth.instance.currentUser;
        // --- Premium user: full interaction ---
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser!.uid)
                        .snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(
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
                    return Center(child: Text('User profile not found'));
                  }

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
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator(color: Colors.black);
                      }

                      // Filter posts
                      final List<DocumentSnapshot> filteredPosts =
                          snapshot.data!.docs.where((doc) {
                            Map<String, dynamic> data =
                                doc.data() as Map<String, dynamic>;

                            // Check if post is from a blocked user
                            if (blockedUsers.contains(data['userId'])) {
                              return false;
                            }
                            if (widget.searchQuery.isNotEmpty &&
                                !data['text'].contains(widget.searchQuery)) {
                              return false;
                            }
                            // Check if user marked post as not interested
                            List<dynamic> notInterestedBy = List<dynamic>.from(
                              data['notInterestedBy'] ?? [],
                            );
                            if (notInterestedBy.contains(currentUser.uid)) {
                              return false;
                            }

                            return true;
                          }).toList();

                      // Determine user type
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>?;
                      final isPremium =
                          userData != null && (userData['isSub'] == true);
                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: filteredPosts.length,
                        itemBuilder: (context, index) {
                          final post =
                              filteredPosts[index].data()
                                  as Map<String, dynamic>;
                          if (isPremium) {
                            return PostItem(
                              postId: post['postId'],
                              fromComments: false,
                            );
                          } else {
                            return GuestPostItem(post: post);
                          }
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
  final searchQuery;
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
            if (user.userId == FirebaseAuth.instance.currentUser!.uid ||
                (widget.searchQuery.isNotEmpty &&
                    !user.name.contains(widget.searchQuery))) {
              return SizedBox.shrink();
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      builder: (context, snapshot) {
                        final isFollowing =
                            snapshot.hasData && snapshot.data!.exists;
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isFollowing
                                    ? Colors.grey[300]
                                    : ColorsManager.primary600,
                            foregroundColor:
                                isFollowing ? Colors.black : Colors.white,
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
                            isFollowing ? '구독 취소' : '구독',
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
