import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_entity.dart';
import 'package:ecommerece_app/features/home/comments.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/widgets/post_actions.dart';
import 'package:ecommerece_app/features/home/widgets/show_post_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class PostItem extends StatelessWidget {
  final String postId;
  final bool fromComments;

  const PostItem({Key? key, required this.postId, required this.fromComments})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use Selector to only rebuild this widget when this specific post changes
    return Selector<PostsProvider, Map<String, dynamic>?>(
      selector: (_, provider) => provider.getPost(postId),
      builder: (context, postData, child) {
        if (postData == null) {
          return SizedBox.shrink(); // Post doesn't exist
        }

        return FutureBuilder<MyUserEntity>(
          future: getUser(postData['userId']),
          builder: (context, snapshot) {
            if (snapshot.hasError || !snapshot.hasData) {
              return _buildPostSkeleton();
            }

            final myuser = snapshot.data!;

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Avatar
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Container(
                          width: 56,
                          height: 55,
                          decoration: ShapeDecoration(
                            image: DecorationImage(
                              image: NetworkImage(myuser.url.toString()),
                              fit: BoxFit.cover,
                            ),
                            shape: OvalBorder(),
                          ),
                        ),
                      ),
                    ),

                    // Post Content
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: () {
                          if (!fromComments) {
                            context.push(
                              '/${Routes.commentsScreen}?postId=$postId',
                            );
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with menu
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    myuser.name,
                                    style: TextStyles.abeezee16px400wPblack,
                                  ),
                                  if (myuser.userId !=
                                      FirebaseAuth.instance.currentUser!.uid)
                                    IconButton(
                                      icon: Icon(Icons.more_horiz),
                                      onPressed:
                                          () => showPostMenu(
                                            context,
                                            postId,
                                            myuser.userId,
                                          ),
                                    ),
                                ],
                              ),

                              // Post Text
                              if (postData['text'].toString().isNotEmpty)
                                Text(
                                  postData['text'],
                                  style: TextStyle(
                                    color: const Color(0xFF343434),
                                    fontSize: 16,
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w400,
                                    height: 1.40,
                                    letterSpacing: -0.09,
                                  ),
                                ),
                              verticalSpace(5),
                              // Post Image
                              if (postData['imgUrl'].isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    postData['imgUrl'],
                                    width: 200,
                                    height: 272,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              verticalSpace(5),
                              // Like/Comment Buttons
                              PostActions(postId: postId, postData: postData),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

Widget _buildPostSkeleton() {
  return Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Container(
      height: 100,
      margin: EdgeInsets.all(8),
      color: Colors.white,
    ),
  );
}

Widget _buildErrorPost() {
  return Container(
    padding: EdgeInsets.all(16),
    child: Text('Failed to load user', style: TextStyle(color: Colors.red)),
  );
}
