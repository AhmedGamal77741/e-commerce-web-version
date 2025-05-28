import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/auth/signup/data/signup_functions.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

class MyStory extends StatefulWidget {
  const MyStory({super.key});

  @override
  State<MyStory> createState() => _MyStoryState();
}

class _MyStoryState extends State<MyStory> {
  @override
  void initState() {
    super.initState();
    // Initial post loading is now handled in the build method
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Get posts provider
        final postsProvider = Provider.of<PostsProvider>(
          context,
          listen: false,
        );

        // Wait for auth state to be determined
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.black));
        }

        final firebaseUser = authSnapshot.data;

        // Not logged in
        if (firebaseUser == null) {
          // Reset provider on logout
          postsProvider.resetListening();
          return Center(child: Text('Please log in to view your story'));
        }

        // Force posts to refresh when user changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          postsProvider.resetListening();
          postsProvider.startListening();
        });

        // Fetch current user details
        return StreamBuilder<MyUser?>(
          stream: FirebaseUserRepo().user,
          builder: (context, userSnapshot) {
            // Loading user data
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: Colors.black),
              );
            }

            // Error loading user
            if (userSnapshot.hasError) {
              return Center(
                child: Text('Error loading profile: ${userSnapshot.error}'),
              );
            }

            // User not found
            final currentUser = userSnapshot.data;
            if (currentUser == null) {
              return Center(child: Text('User profile not found'));
            }

            // Now display the user's posts
            return Selector<PostsProvider, List<String>>(
              selector: (_, provider) => provider.postIds,
              builder: (context, postIds, child) {
                // No posts available yet
                if (postIds.isEmpty) {
                  return Center(child: CircularProgressIndicator());
                }

                // Filter posts belonging to current user
                final userPostIds =
                    postIds.where((postId) {
                      final postData = postsProvider.getPost(postId);
                      return postData != null &&
                          postData['userId'] == currentUser.userId;
                    }).toList();

                // No posts from this user
                if (userPostIds.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 20,
                      ),
                      child: Text(
                        '아직 작성한 게시물이 없습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                }

                // Display user's posts
                return ListView.builder(
                  itemCount: userPostIds.length,
                  itemBuilder: (context, index) {
                    final postId = userPostIds[index];
                    return Column(
                      children: [
                        if (index != 0)
                          Divider(color: ColorsManager.primary100),
                        PostItem(postId: postId, fromComments: false),
                      ],
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
