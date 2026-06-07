import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/loading_dialog.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/features/cart/services/cart_service.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/chat/services/contacts_service.dart';
import 'package:ecommerece_app/features/chat/widgets/chat_input_bar.dart';
import 'package:ecommerece_app/features/chat/widgets/chat_post_share.dart';
import 'package:ecommerece_app/features/home/data/post_provider.dart';
import 'package:ecommerece_app/features/home/models/comment_model.dart';
import 'package:ecommerece_app/features/home/follow_feed_screen.dart';
import 'package:ecommerece_app/features/home/widgets/post_item.dart';
import 'package:ecommerece_app/features/shop/item_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

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

class Comments extends StatefulWidget {
  const Comments({super.key, required this.postId, this.canInteract = true});
  final String postId;
  final bool canInteract;
  @override
  State<Comments> createState() => _CommentsState();
}

class _CommentsState extends State<Comments> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  final currentUser = FirebaseAuth.instance.currentUser;
  XFile? _pickedImage;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Map<String, dynamic>? _fetchedPostData;
  bool _fetchingPost = false;
  Future<MyUser>? _userFuture;
  String? _loadedUserId;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Provider.of<PostsProvider>(context, listen: false).startListening();
    _maybeFetchPost();
  }

  void _maybeFetchPost() async {
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    if (postsProvider.getPost(widget.postId) == null) {
      setState(() => _fetchingPost = true);
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('posts')
                .doc(widget.postId)
                .get();
        if (doc.exists && mounted) {
          setState(() {
            _fetchedPostData = doc.data();
          });
        }
      } catch (e) {
        print(e);
      } finally {
        if (mounted) setState(() => _fetchingPost = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _pickedImage = picked);
  }

  Future<void> _submitImageComment() async {
    if (_pickedImage == null) return;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.jpg';
    final ref = FirebaseStorage.instance.ref().child('chat_images/$fileName');
    UploadTask task;
    if (kIsWeb) {
      final bytes = await _pickedImage!.readAsBytes();
      task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      task = ref.putFile(File(_pickedImage!.path));
    }
    final url = await (await task).ref.getDownloadURL();
    final text = _commentController.text.trim();
    await Provider.of<PostsProvider>(
      context,
      listen: false,
    ).addComment(widget.postId, text, imageUrl: url);
    _commentController.clear();
    setState(() => _pickedImage = null);
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await Provider.of<PostsProvider>(
        context,
        listen: false,
      ).addComment(widget.postId, text);
      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('댓글 추가에 실패했습니다: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    if (postsProvider.getComments(widget.postId).isEmpty &&
        !postsProvider.isLoadingComments(widget.postId)) {
      postsProvider.listenToComments(widget.postId);
    }

    return Selector<PostsProvider, Map<String, dynamic>?>(
      selector: (_, provider) => provider.getPost(widget.postId),
      builder: (context, providerPostData, child) {
        final postData = providerPostData ?? _fetchedPostData;

        if (postData == null) {
          return const Scaffold(
            backgroundColor: _kBgColor,
            body: SizedBox.shrink(),
          );
        }

        final String postUserId = postData['userId'] ?? '';
        if (_userFuture == null || _loadedUserId != postUserId) {
          _loadedUserId = postUserId;
          _userFuture = postsProvider.loadUser(postUserId);
        }

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
                      child: Selector<PostsProvider, List<Comment>>(
                        selector:
                            (_, provider) =>
                                provider.getComments(widget.postId),
                        builder: (context, comments, child) {
                          final List<ChatMessageItem> chatItems = [];

                          // Add comments first (newest comments at lower indices)
                          for (final comment in comments) {
                            chatItems.add(
                              ChatMessageItem(
                                id: comment.id,
                                senderId: comment.userId,
                                senderName: comment.userName ?? '알 수 없음',
                                senderImage: comment.userImage ?? '',
                                content: comment.text,
                                timestamp:
                                    comment.createdAt is Timestamp
                                        ? (comment.createdAt as Timestamp)
                                            .toDate()
                                        : DateTime.now(),
                                imageUrls:
                                    comment.imageUrl != null &&
                                            comment.imageUrl!.isNotEmpty
                                        ? [comment.imageUrl!]
                                        : null,
                                postData: comment.postData,
                                productData: comment.productData,
                                isPost: false,
                              ),
                            );
                          }

                          // Add post itself at the end (will render at the top because of reverse: true)
                          final String postText = postData['text'] ?? '';
                          final List imgUrls =
                              postData['imgUrls'] as List? ?? [];
                          final List<String> castedUrls =
                              imgUrls.map((e) => e.toString()).toList();
                          final DateTime postTime =
                              postData['createdAt'] is Timestamp
                                  ? (postData['createdAt'] as Timestamp)
                                      .toDate()
                                  : DateTime.now();

                          chatItems.add(
                            ChatMessageItem(
                              id: widget.postId,
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
                              final isMe = item.senderId == currentUserId;
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
                    if (_pickedImage != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child:
                                  kIsWeb
                                      ? Image.network(
                                        _pickedImage!.path,
                                        fit: BoxFit.cover,
                                      )
                                      : Image.file(
                                        File(_pickedImage!.path),
                                        fit: BoxFit.cover,
                                      ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed:
                                    () => setState(() => _pickedImage = null),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.canInteract)
                      InputBar(
                        controller: _commentController,
                        pickedImage: _pickedImage,
                        onPickImage: _pickImage,
                        onSend: () async {
                          if (_pickedImage != null) {
                            showLoadingDialog(context);
                            final navigator = Navigator.of(context);
                            await _submitImageComment();
                            navigator.pop();
                          } else {
                            await _submitComment();
                          }
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
                            body: FollowingTab(
                              firebaseUser: FirebaseAuth.instance.currentUser,
                              preselectedUser: item.senderId,
                            ),
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
                                onTap: () {
                                  if (item.postData!['postId'] != item.id ||
                                      !item.isPost) {
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
                                              child: Comments(
                                                postId:
                                                    item.postData!['postId'],
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
