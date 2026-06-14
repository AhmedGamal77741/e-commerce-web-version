import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/features/cart/services/cart_service.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/chat/services/contacts_service.dart';
import 'package:ecommerece_app/features/chat/widgets/chat_post_share.dart';
import 'package:ecommerece_app/features/home/follow_feed_screen.dart';
import 'package:ecommerece_app/features/home/profile_tab.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:ecommerece_app/features/shop/item_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _kBgColor = Color(0xFFF2F2F2);

class ChatMessageItem {
  final String id;
  final String senderId;
  final String senderName;
  final String senderImage;
  final String content;
  final DateTime timestamp;
  final List<String>? imageUrls;
  final Map<String, dynamic>? postData;
  final Product? productData;
  final bool isPost;

  ChatMessageItem({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderImage,
    required this.content,
    required this.timestamp,
    this.imageUrls,
    this.postData,
    this.productData,
    required this.isPost,
  });
}

class GuestComments extends StatefulWidget {
  final Map<String, dynamic> post;
  const GuestComments({Key? key, required this.post}) : super(key: key);

  @override
  State<GuestComments> createState() => _GuestCommentsState();
}

class _GuestCommentsState extends State<GuestComments> {
  Future<MyUser>? _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUser(widget.post['userId'] ?? '');
  }

  Future<MyUser> _loadUser(String userId) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};
    return MyUser.fromDocument(userData);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final String postUserId = post['userId'] ?? '';

    return FutureBuilder<MyUser>(
      future: _userFuture,
      builder: (context, userSnapshot) {
        final myuser = userSnapshot.data;
        final displayName =
            myuser?.name.isNotEmpty == true ? myuser!.name : '삭제된 사용자';
        final String profileUrl = myuser?.url ?? '';

        return Scaffold(
          backgroundColor: _kBgColor,

          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('posts')
                            .doc(post['postId'])
                            .collection('comments')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Text('댓글을 불러올 수 없습니다'));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      final List<ChatMessageItem> chatItems = [];

                      // Add comments first
                      for (final doc in docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        chatItems.add(
                          ChatMessageItem(
                            id: data['id'] ?? doc.id,
                            senderId: data['userId'] ?? '',
                            senderName: data['userName'] ?? '알 수 없음',
                            senderImage: data['userImage'] ?? '',
                            content: data['text'] ?? '',
                            timestamp:
                                data['createdAt'] is Timestamp
                                    ? (data['createdAt'] as Timestamp).toDate()
                                    : DateTime.now(),
                            imageUrls:
                                data['imageUrl'] != null &&
                                        data['imageUrl'].toString().isNotEmpty
                                    ? [data['imageUrl'].toString()]
                                    : null,
                            // postData & productData parsing if exist
                            postData: data['postData'],
                            productData:
                                data['productData'] != null
                                    ? Product.fromMap(data['productData'])
                                    : null,
                            isPost: false,
                          ),
                        );
                      }

                      // Add post itself
                      final String postText = post['text'] ?? '';
                      final List imgUrls = post['imgUrls'] as List? ?? [];
                      final List<String> castedUrls =
                          imgUrls.map((e) => e.toString()).toList();
                      final DateTime postTime =
                          post['createdAt'] is Timestamp
                              ? (post['createdAt'] as Timestamp).toDate()
                              : DateTime.now();

                      chatItems.add(
                        ChatMessageItem(
                          id: post['postId'] ?? '',
                          senderId: postUserId,
                          senderName: displayName,
                          senderImage: profileUrl,
                          content: postText,
                          timestamp: postTime,
                          imageUrls: castedUrls,
                          postData: null,
                          isPost: true,
                        ),
                      );

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        itemCount: chatItems.length,
                        itemBuilder: (context, index) {
                          final item = chatItems[index];
                          // Since guests are logged out, isMe is always false
                          const isMe = false;
                          final showDate =
                              index == chatItems.length - 1 ||
                              !_isSameDay(
                                item.timestamp,
                                chatItems[index + 1].timestamp,
                              );

                          return Column(
                            children: [
                              if (showDate)
                                _DateSeparator(date: item.timestamp),
                              _CommentBubble(item: item, isMe: isMe),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                // Disabled Input Bar for guests
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '로그인 후 댓글을 남길 수 있습니다.',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                              fontFamily: 'NotoSans',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommentBubble extends StatefulWidget {
  final ChatMessageItem item;
  final bool isMe;

  const _CommentBubble({Key? key, required this.item, required this.isMe})
    : super(key: key);

  @override
  State<_CommentBubble> createState() => _CommentBubbleState();
}

class _CommentBubbleState extends State<_CommentBubble> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isMe = widget.isMe;
    double maxW = MediaQuery.of(context).size.width - 120;
    if (maxW > 400.0) maxW = 400.0;
    return Padding(
      padding: EdgeInsets.only(
        bottom: 6,
        left: isMe ? 52 : 0,
        right: isMe ? 0 : 52,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => SafeArea(
                          child: Scaffold(
                            body: ProfileTab(userId: item.senderId),
                          ),
                        ),
                  ),
                );
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: ShapeDecoration(
                  image: DecorationImage(
                    image:
                        item.senderImage.isNotEmpty
                            ? NetworkImage(item.senderImage)
                            : const AssetImage('assets/avatar.png')
                                as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                  shape: const OvalBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: FutureBuilder<String?>(
                      future: ContactService().getContactNickname(
                        item.senderId,
                      ),
                      builder: (context, snapshot) {
                        final nickname = snapshot.data;
                        final display =
                            nickname != null && nickname.isNotEmpty
                                ? '${item.senderName} (@$nickname)'
                                : item.senderName;
                        return Text(
                          display,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFFEEEEEE),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.content.isNotEmpty)
                              Text(
                                item.content,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            if (item.postData != null) ...[
                              if (item.content.isNotEmpty)
                                const SizedBox(height: 6),
                              ChatPostShareWidget(
                                type: 'post',
                                imageUrl: item.postData!['imgUrl'] ?? '',
                                authorName: item.postData!['userId'] ?? '',
                                postTitle: item.postData!['text'] ?? '',
                                onTap: () async {
                                  final navigator = Navigator.of(context);
                                  final doc =
                                      await FirebaseFirestore.instance
                                          .collection('posts')
                                          .doc(item.postData!['postId'])
                                          .get();
                                  if (doc.exists) {
                                    final postMap =
                                        doc.data() as Map<String, dynamic>;
                                    postMap['postId'] = doc.id;
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder:
                                          (context) => Container(
                                            height:
                                                MediaQuery.of(
                                                  context,
                                                ).size.height *
                                                0.9,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFF2F2F2),
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                    top: Radius.circular(20),
                                                  ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(20),
                                                  ),
                                              child: GuestComments(
                                                post: postMap,
                                              ),
                                            ),
                                          ),
                                    );
                                  }
                                },
                              ),
                            ],
                            if (item.productData != null) ...[
                              if (item.content.isNotEmpty)
                                const SizedBox(height: 6),
                              ChatPostShareWidget(
                                type: 'product',
                                imageUrl: item.productData!.imgUrl ?? '',
                                postTitle:
                                    '${item.productData!.pricePoints[0].price} 원',
                                authorName: item.productData!.productName,
                                onTap: () async {
                                  final navigator = Navigator.of(context);
                                  bool isSub = await isUserSubscribed();
                                  navigator.push(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => ItemDetails(
                                            product: item.productData!,
                                            isSub: isSub,
                                            arrivalDay:
                                                item.productData!.arrivalDate ??
                                                '',
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ],
                            if (item.imageUrls != null &&
                                item.imageUrls!.isNotEmpty &&
                                item.postData == null) ...[
                              if (item.content.isNotEmpty)
                                const SizedBox(height: 6),
                              if (item.imageUrls!.length == 1)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    constraints: BoxConstraints(maxWidth: maxW),
                                    child: Image.network(
                                      item.imageUrls!.first,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    constraints: BoxConstraints(maxWidth: maxW),
                                    child: NaturalAspectPageView(
                                      imgUrls: item.imageUrls!,
                                      pageController: _pageController,
                                      explicitWidth: maxW,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: 3,
                    left: isMe ? 0 : 4,
                    right: isMe ? 4 : 0,
                  ),
                  child: Text(
                    _formatTime(item.timestamp),
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return '오늘';
    if (d == today.subtract(const Duration(days: 1))) return '어제';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _label(),
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}
