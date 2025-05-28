import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/tab_app_bar.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/widgets/guest_preview.dart/guest_post_item.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MyUser? currentUser;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Don't call these methods here
    // Provider.of<PostsProvider>(context, listen: false).startListening();
    // _loadData();
  }

  Future<void> _loadData() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) throw Exception('Not signed in');

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .get();

      if (!doc.exists || doc.data() == null) {
        throw Exception('User profile not found');
      }
      final data = doc.data()!;
      setState(() {
        currentUser = MyUser(
          userId: data['userId'] as String? ?? firebaseUser.uid,
          email: data['email'] as String? ?? firebaseUser.email ?? '',
          name: data['name'] as String? ?? '',
          url: data['url'] as String? ?? '',
          isSub: data['isSub'] as bool? ?? false,
          defaultAddressId: data['defaultAddressId'] as String?,
          blocked:
              (data['blocked'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              <String>[],
        );
        _isLoading = false;
      });
    } catch (e) {
      print('Failed to load user data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: TabAppBar(firstTab: '추천'),
        body: TabBarView(
          children: [
            StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnapshot) {
                // Handle loading state
                if (authSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  );
                }

                final firebaseUser = authSnapshot.data;
                final postsProvider = Provider.of<PostsProvider>(
                  context,
                  listen: false,
                );

                // Safely manage posts provider based on auth state
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (firebaseUser == null) {
                    postsProvider.resetListening();
                  } else {
                    postsProvider.startListening();
                  }
                });

                // If no user, show the guest version of the UI
                if (firebaseUser == null) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Flexible(
                            child: InkWell(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("계속하려면 로그인해 주세요."),
                                  ),
                                );
                              },
                              child: Container(
                                width: 56,
                                height: 55,
                                decoration: ShapeDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/mypage_icon.png'),
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
                                    content: Text("계속하려면 로그인해 주세요."),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 10,
                                  children: [
                                    Text(
                                      '게스트 사용자',
                                      style: TextStyles.abeezee16px400wPblack,
                                    ),
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
                                            child: CircularProgressIndicator(),
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
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('posts')
                                  .orderBy('createdAt', descending: true)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            }

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }

                            final posts = snapshot.data!.docs;

                            if (posts.isEmpty) {
                              return Center(child: Text('게시물이 없습니다.'));
                            }

                            return ListView.builder(
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                final post =
                                    posts[index].data() as Map<String, dynamic>;

                                // Add document ID if postId is missing
                                if (post['postId'] == null) {
                                  post['postId'] = posts[index].id;
                                }

                                // Show guest-only posts for non-logged-in users
                                return GuestPostItem(post: post);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }

                // User is logged in, continue with authenticated UI flow
                return FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(firebaseUser.uid)
                          .get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>?;
                    if (userData == null) {
                      return Center(child: Text('User profile not found'));
                    }

                    final currentUser = MyUser(
                      userId: userData['userId'] as String? ?? firebaseUser.uid,
                      email:
                          userData['email'] as String? ??
                          firebaseUser.email ??
                          '',
                      name: userData['name'] as String? ?? '',
                      url: userData['url'] as String? ?? '',
                      isSub: userData['isSub'] as bool? ?? false,
                      defaultAddressId: userData['defaultAddressId'] as String?,
                      blocked:
                          (userData['blocked'] as List<dynamic>?)
                              ?.map((e) => e as String)
                              .toList() ??
                          <String>[],
                    );

                    // Now use your original UI code but with the currentUser from here
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Flexible(
                              child: InkWell(
                                onTap: () {
                                  context.pushNamed(Routes.notificationsScreen);
                                },
                                child: Stack(
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
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: ShapeDecoration(
                                          color: const Color(0xFFDA3A48),
                                          shape: OvalBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
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
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 10,
                                    children: [
                                      Text(
                                        currentUser.name.toString(),
                                        style: TextStyles.abeezee16px400wPblack,
                                      ),
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
                                                  CircularProgressIndicator(),
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
                        Expanded(
                          child: StreamBuilder<DocumentSnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUser.userId)
                                    .snapshots(),
                            builder: (context, userSnapshot) {
                              if (userSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (userSnapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Error loading user data: ${userSnapshot.error}',
                                  ),
                                );
                              }

                              if (!userSnapshot.hasData ||
                                  !userSnapshot.data!.exists) {
                                return Center(
                                  child: Text('User profile not found'),
                                );
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

                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return CircularProgressIndicator();
                                  }

                                  // Filter posts
                                  final List<DocumentSnapshot> filteredPosts =
                                      snapshot.data!.docs.where((doc) {
                                        Map<String, dynamic> data =
                                            doc.data() as Map<String, dynamic>;

                                        // Check if post is from a blocked user
                                        if (blockedUsers.contains(
                                          data['userId'],
                                        )) {
                                          return false;
                                        }

                                        // Check if user marked post as not interested
                                        List<dynamic> notInterestedBy =
                                            List<dynamic>.from(
                                              data['notInterestedBy'] ?? [],
                                            );
                                        if (notInterestedBy.contains(
                                          currentUser.userId,
                                        )) {
                                          return false;
                                        }

                                        return true;
                                      }).toList();

                                  return ListView.builder(
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
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
