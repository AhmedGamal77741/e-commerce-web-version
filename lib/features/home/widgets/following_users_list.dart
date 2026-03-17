import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:flutter/material.dart';

class FollowingUsersList extends StatefulWidget {
  final List<String> followingIds;
  final void Function(String userId)? onUserTap;
  final String? selectedUserId;

  const FollowingUsersList({
    Key? key,
    required this.followingIds,
    this.onUserTap,
    this.selectedUserId,
  }) : super(key: key);

  @override
  State<FollowingUsersList> createState() => _FollowingUsersListState();
}

class _FollowingUsersListState extends State<FollowingUsersList> {
  late final PageController _pageController;
  final Map<String, Future<DocumentSnapshot>> _userFutures = {};
  Future<DocumentSnapshot> _getUserFuture(String userId) {
    print(userId);
    return _userFutures.putIfAbsent(
      // only fetches once per userId
      userId,
      () => FirebaseFirestore.instance.collection('users').doc(userId).get(),
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.15);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.followingIds.length,
      onPageChanged: (index) {
        if (widget.onUserTap != null) {
          // auto-select user when swiped to
          widget.onUserTap!(widget.followingIds[index]);
        }
      },
      itemBuilder: (context, index) {
        return FutureBuilder<DocumentSnapshot>(
          future: _getUserFuture(widget.followingIds[index]),
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
            final isSelected = widget.selectedUserId == user.userId;

            return GestureDetector(
              onTap: () => widget.onUserTap?.call(user.userId),
              child: AnimatedScale(
                scale: isSelected ? 1.0 : 0.8,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity:
                      widget.selectedUserId == null || isSelected ? 1 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration:
                              isSelected
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
                        SizedBox(height: 4),
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
              ),
            );
          },
        );
      },
    );
  }
}
