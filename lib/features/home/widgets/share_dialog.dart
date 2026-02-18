import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/core/services/share_service.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/chat/services/chat_service.dart';
import 'package:ecommerece_app/features/chat/services/friends_service.dart';
import 'package:ecommerece_app/features/chat/ui/chat_room_screen.dart';
import 'package:ecommerece_app/features/chat/ui/upload_story_screen.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

Future<void> _captureProductAndOpenStory(
  BuildContext context,
  String sellerName,
  String productImgUrl,
  Map<String, dynamic> productData,
) async {
  try {
    if (productImgUrl.isNotEmpty) {
      await precacheImage(NetworkImage(productImgUrl), context);
    }
    final product = Product.fromMap(productData);
    final Widget snapshotWidget = Material(
      child: Container(
        width: 300,
        height: 600,
        color: ColorsManager.primary,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 12),
            if (product.imgUrl!.isNotEmpty)
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image(
                    image: NetworkImage(product.imgUrl!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            SizedBox(height: 12),
            Text(
              product.productName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 6),
            Text(
              '${product.pricePoints[0].price} 원',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );

    final controller = ScreenshotController();
    final bytes = await controller.captureFromWidget(
      snapshotWidget,
      pixelRatio: MediaQuery.of(context).devicePixelRatio,
    );

    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미지 생성 실패: 다시 시도하세요.')));
      return;
    }

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UploadStoryScreen(initialImage: bytes),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('이미지 생성 실패: $e')));
  }
}

Future<void> _capturePostFromCommentsAndOpen(
  BuildContext context,
  String displayName,
  String profileUrl,
  Map<String, dynamic> postData,
) async {
  try {
    if (profileUrl.isNotEmpty) {
      await precacheImage(NetworkImage(profileUrl), context);
    }
    if ((postData['imgUrl'] ?? '').isNotEmpty) {
      await precacheImage(NetworkImage(postData['imgUrl']), context);
    }

    final Widget snapshotWidget = Material(
      child: Container(
        width: 300,
        height: 600,
        color: ColorsManager.primary,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: ShapeDecoration(
                    image: DecorationImage(
                      image:
                          profileUrl.isNotEmpty
                              ? NetworkImage(profileUrl)
                              : AssetImage('assets/avatar.png')
                                  as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                    shape: OvalBorder(),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            if ((postData['text'] ?? '').toString().isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    postData['text'] ?? '',
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ),
              ),
            if ((postData['imgUrl'] ?? '').toString().isNotEmpty)
              Flexible(
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image(
                      image: NetworkImage(postData['imgUrl']),
                      fit: BoxFit.fitWidth,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final controller = ScreenshotController();
    final bytes = await controller.captureFromWidget(
      snapshotWidget,
      pixelRatio: MediaQuery.of(context).devicePixelRatio,
    );

    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미지 생성 실패: 다시 시도하세요.')));
      return;
    }

    /*     final tempDir = await getTemporaryDirectory();
    final file =
        await File(
          '${tempDir.path}/post_story_${DateTime.now().millisecondsSinceEpoch}.png',
        ).create();
    await file.writeAsBytes(bytes); */

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UploadStoryScreen(initialImage: bytes),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('이미지 생성 실패: $e')));
  }
}

/* Future<void> _capturePostAndOpenStory(
  BuildContext context,
  ScreenshotController controller,
) async {
  try {
    print('Capturing post screenshot...');
    final bytes = await controller.capture(
      delay: const Duration(milliseconds: 300),
    );
    if (bytes == null) {
      // retry with longer delay
      final bytesRetry = await controller.capture(
        delay: const Duration(seconds: 1),
      );
      if (bytesRetry == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 생성 실패: 화면을 다시 시도하세요.')),
        );
        return;
      }
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final file =
        await File(
          '${tempDir.path}/post_story_${DateTime.now().millisecondsSinceEpoch}.png',
        ).create();
    await file.writeAsBytes(bytes);
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UploadStoryScreen(initialImage: file),
        ),
      );
    }
  } catch (e) {
    print(e);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('이미지 생성 실패: $e')));
  }
} */

Widget _buildSquareAction({
  required IconData icon,
  String? asset,
  required String label,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 110,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SizedBox(height: 8),
          if (asset != null)
            Opacity(
              opacity: 0.2,
              child: Image.asset(asset, width: 80, height: 80),
            )
          else
            Icon(icon, size: 80, color: Colors.grey[600]),
          SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}

Widget _buildFriendItem({
  required MyUser friend,
  required BuildContext context,
  required Map<String, dynamic> postData,
  required String type,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    child: InkWell(
      onTap: () async {
        try {
          final chatRoomId = await ChatService().createDirectChatRoom(
            friend.userId,
            friend.type != 'user',
          );
          if (chatRoomId != null) {
            if (type == 'post') {
              ChatService().sendMessage(
                chatRoomId: chatRoomId,
                content: postData['text'] ?? '',
                postData: postData,
              );
            } else if (type == 'product') {
              ChatService().sendMessage(
                chatRoomId: chatRoomId,
                content: '',
                productData: Product.fromMap(postData),
              );
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => ChatScreen(
                      chatRoomId: chatRoomId,
                      chatRoomName: friend.name,
                    ),
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      },
      child: Row(
        children: [
          CircleAvatar(radius: 25, backgroundImage: NetworkImage(friend.url)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                if (friend.bio != null && friend.bio!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    friend.bio ?? '',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
/* Widget buildFriendItem() {
  return ListTile(
    leading: const CircleAvatar(
      radius: 24,
      /*       backgroundImage: NetworkImage('https://via.placeholder.com/150'),
 */
    ),
    title: const Text('노찌', style: TextStyle(fontWeight: FontWeight.bold)),
    subtitle: const Text('상태 메시지', style: TextStyle(fontSize: 12)),
    onTap: () {},
  );
} */

void showShareDialog(
  BuildContext context,
  String type,
  String url,
  String id,
  String name,
  String imgUrl,
  Map<String, dynamic> mapData,
) {
  showDialog(
    context: context,
    builder: (context) {
      if (type == 'post') {
        mapData.addEntries({'authorName': name}.entries);
      }
      String searchQuery = '';
      final TextEditingController searchController = TextEditingController();
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 40,
            ),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '공유',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // 1. Horizontal Actions (Add to Story, Copy Link)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildSquareAction(
                          icon: Icons.add,
                          asset: 'assets/add_to_story.png',
                          label: '내 스토리에\n추가',
                          onTap: () {
                            if (type == 'post') {
                              _capturePostFromCommentsAndOpen(
                                context,
                                name,
                                imgUrl,
                                mapData,
                              );
                            } else if (type == 'product') {
                              _captureProductAndOpenStory(
                                context,
                                name,
                                imgUrl,
                                mapData,
                              );
                            }
                          } /* _capturePostAndOpenStory(
                                context,
                                screenshotController,
                              ) */ /* => _handleQuickShare(context) */,
                        ),
                        const SizedBox(width: 12),
                        _buildSquareAction(
                          icon: Icons.link,
                          label: '링크 복사',
                          onTap: () {
                            if (type == 'post') {
                              ShareService.sharePost(id);
                            } else if (type == 'product') {
                              ShareService.shareProduct(id, name);
                            }
                          } /* _copyToClipboard(postUrl) */,
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: '친구 검색',
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        searchQuery = value.trim().toLowerCase();
                        setState(() {});
                      },
                    ),
                  ),

                  // 3. Scrollable Friends List
                  Expanded(
                    child: FutureBuilder(
                      future: FriendsService().getFriendsList(),
                      builder: (context, asyncSnapshot) {
                        if (asyncSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (asyncSnapshot.hasError) {
                          return Center(child: Text('친구 목록을 불러오는 데 실패했습니다.'));
                        }
                        final friends = asyncSnapshot.data ?? [];

                        return ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            if (searchQuery.isNotEmpty &&
                                !friends[index].name.toLowerCase().contains(
                                  searchQuery,
                                )) {
                              return const SizedBox.shrink();
                            }
                            return _buildFriendItem(
                              friend: friends[index],
                              context: context,
                              postData: mapData,
                              type: type,
                            );
                          },
                        );
                      },
                    ),
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
