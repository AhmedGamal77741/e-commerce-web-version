import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/home/comments.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final notificationsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications');
    final unread =
        await notificationsRef.where('isRead', isEqualTo: false).get();
    for (final doc in unread.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return SafeArea(
      child:
          user == null
              ? Center(child: Text('로그인이 필요합니다'))
              : StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('notifications')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox.shrink();
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('알림이 없습니다.'));
                  }
                  final notifications = snapshot.data!.docs;
                  return ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => Divider(),
                    itemBuilder: (context, index) {
                      final data =
                          notifications[index].data() as Map<String, dynamic>;
                      return ListTile(
                        onTap: () {
                          final postId = (data['postId']) as String?;
                          final commentId = (data['commentId']) as String?;
                          if (postId != null && postId.isNotEmpty) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder:
                                  (context) => Container(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.95,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF2F2F2),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                      child: Comments(
                                        postId: postId,
                                        commentId: commentId,
                                      ),
                                    ),
                                  ),
                            );
                          }
                        },
                        title: Text(
                          data['title'] ?? '',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle:
                            data['body'] != null
                                ? Text(
                                  data['body'],
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontFamily: 'NotoSans',
                                  ),
                                )
                                : null,
                        trailing:
                            data['isRead'] == false
                                ? Icon(
                                  Icons.circle,
                                  color: Colors.red,
                                  size: 12,
                                )
                                : null,
                        dense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
