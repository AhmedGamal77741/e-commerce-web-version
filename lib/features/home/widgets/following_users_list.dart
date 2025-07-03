import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:flutter/material.dart';

class FollowingUsersList extends StatelessWidget {
  final List<String> followingIds;
  final void Function(String userId)? onUserTap;
  final String? selectedUserId; // Add this
  const FollowingUsersList({
    Key? key,
    required this.followingIds,
    this.onUserTap,
    this.selectedUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      itemCount: followingIds.length,
      itemBuilder: (context, index) {
        return FutureBuilder<DocumentSnapshot>(
          future:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(followingIds[index])
                  .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                width: 70,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            if (userData == null) return const SizedBox.shrink();
            final user = MyUser.fromDocument(userData);
            return GestureDetector(
              onTap: () {
                if (onUserTap != null) {
                  onUserTap!(user.userId);
                }
              },
              child: Opacity(
                opacity:
                    selectedUserId == user.userId
                        ? 1
                        : selectedUserId == null
                        ? 1
                        : .5,
                child: Container(
                  margin: const EdgeInsets.only(right: 16),

                  child: Column(
                    children: [
                      Container(
                        decoration:
                            selectedUserId == user.userId
                                ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    width: 2,
                                    color: Colors.black,
                                  ),
                                )
                                : null,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: NetworkImage(user.url),
                        ),
                      ),
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
