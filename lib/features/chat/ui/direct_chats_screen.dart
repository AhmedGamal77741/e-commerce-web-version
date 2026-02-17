import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/loading_dialog.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/chat/services/friends_service.dart';
import 'package:ecommerece_app/features/chat/ui/chat_room_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/chat_room_model.dart';
import '../services/chat_service.dart';

class DirectChatsScreen extends StatefulWidget {
  @override
  State<DirectChatsScreen> createState() => _DirectChatsScreenState();
}

class _DirectChatsScreenState extends State<DirectChatsScreen> {
  final ChatService chatService = ChatService();
  String get currentUserId => FirebaseAuth.instance.currentUser!.uid;
  final FriendsService _friendsService = FriendsService();

  // ─── Hidden IDs stream ────────────────────────────────────────────────────
  Stream<Set<String>> _getHiddenIdsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value({});
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('hiddenFriends')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  // ─── Alias map stream ─────────────────────────────────────────────────────
  Stream<Map<String, String>> _getAliasesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value({});
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('aliases')
        .snapshots()
        .map((snap) {
          final map = <String, String>{};
          for (final doc in snap.docs) {
            final alias = doc.data()['alias'] as String?;
            if (alias != null && alias.isNotEmpty) {
              map[doc.id] = alias;
            }
          }
          return map;
        });
  }

  // ─── Resolve other participant ────────────────────────────────────────────
  Future<MyUser?> getOtherUser(ChatRoomModel chat) async {
    final otherId = chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    if (otherId.isEmpty) return null;

    if (chat.type == 'direct') {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(otherId)
              .get();
      if (!doc.exists) return null;
      return MyUser.fromDocument(doc.data()!);
    } else if (chat.type == 'seller') {
      final doc =
          await FirebaseFirestore.instance
              .collection('deliveryManagers')
              .doc(otherId)
              .get();
      if (!doc.exists) return null;
      return MyUser.fromSellerDocument(doc.data()!);
    } else if (chat.type == 'admin') {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(otherId)
              .get();
      if (!doc.exists) return null;
      return MyUser.fromSellerDocument(doc.data()!);
    }
    return null;
  }

  String _getOtherUserId(ChatRoomModel chat) {
    return chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  // ─── KakaoTalk-style long-press context menu ──────────────────────────────
  void _showChatMenu({
    required BuildContext tileContext,
    required ChatRoomModel chat,
    required String displayName,
    required String userId,
  }) {
    final RenderBox box = tileContext.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final Size tileSize = box.size;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    const double popupWidth = 200;
    // title (≈52) + divider + 2 options (≈48 each) + padding
    const double popupHeight = 160;

    // Default: right-aligned to the tile, vertically centred
    double left = offset.dx + tileSize.width - popupWidth - 8;
    double top = offset.dy + (tileSize.height / 2) - (popupHeight / 2);

    // Clamp to screen edges
    if (left < 8) left = 8;
    if (left + popupWidth > screenWidth - 8)
      left = screenWidth - popupWidth - 8;
    if (top < 8) top = 8;
    if (top + popupHeight > screenHeight - 20)
      top = screenHeight - popupHeight - 20;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder:
          (_) => Stack(
            children: [
              // Full-screen transparent barrier — tap outside to dismiss
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: popupWidth,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 16),
                        // ── Name title ──────────────────────────────────────
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            displayName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Divider(
                          color: Colors.grey[200],
                          thickness: 1,
                          height: 1,
                        ),

                        // ── 차단하기 (Block) ────────────────────────────────
                        _buildMenuOption(
                          label: '차단하기',
                          onTap: () async {
                            Navigator.pop(context);
                            if (userId.isEmpty) return;
                            showLoadingDialog(context);
                            final doc =
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .get();
                            if (doc.exists) {
                              final user = MyUser.fromDocument(doc.data()!);
                              await _friendsService.blockFriend(user.name);
                            }
                            if (mounted) Navigator.pop(context);
                          },
                        ),

                        Divider(
                          color: Colors.grey[100],
                          thickness: 1,
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),

                        // ── 나가기 (Leave) ──────────────────────────────────
                        _buildMenuOption(
                          label: '나가기',
                          isLast: true,
                          onTap: () async {
                            Navigator.pop(context);
                            showLoadingDialog(context);
                            await chatService.softDeleteChatForCurrentUser(
                              chat.id,
                            );
                            if (mounted) Navigator.pop(context);
                          },
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildMenuOption({
    required String label,
    required VoidCallback onTap,
    Color? labelColor,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          isLast
              ? BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              )
              : BorderRadius.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: labelColor ?? Colors.black87,
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: _getHiddenIdsStream(),
      builder: (context, hiddenSnapshot) {
        final hiddenIds = hiddenSnapshot.data ?? {};

        return StreamBuilder<Map<String, String>>(
          stream: _getAliasesStream(),
          builder: (context, aliasSnapshot) {
            final aliases = aliasSnapshot.data ?? {};

            return StreamBuilder<List<ChatRoomModel>>(
              stream: chatService.getChatRoomsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final directChats =
                    snapshot.data!
                        .where(
                          (chat) =>
                              (chat.type == 'direct' ||
                                  chat.type == 'seller' ||
                                  chat.type == 'admin' ||
                                  chat.type == '' ||
                                  chat.type == null) &&
                              !chat.deletedBy.contains(currentUserId) &&
                              chat.lastMessage != null &&
                              chat.lastMessage!.isNotEmpty,
                        )
                        .toList();

                if (directChats.isEmpty) {
                  return const Center(child: Text('No direct chats.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: directChats.length,
                  itemBuilder: (context, index) {
                    final chat = directChats[index];

                    final otherId = _getOtherUserId(chat);
                    if (otherId.isNotEmpty && hiddenIds.contains(otherId)) {
                      return const SizedBox.shrink();
                    }

                    return FutureBuilder<MyUser?>(
                      future: getOtherUser(chat),
                      builder: (context, userSnap) {
                        if (userSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(
                            leading: CircleAvatar(
                              radius: 25,
                              child: Icon(Icons.person),
                            ),
                            title: Text('Loading...'),
                          );
                        }

                        if (!userSnap.hasData) {
                          return _buildChatTile(
                            chat: chat,
                            displayName: '삭제된 사용자',
                            realName: null,
                            avatarUrl: null,
                            userId: '',
                            isDeleted: true,
                          );
                        }

                        final friend = userSnap.data!;
                        final String displayName =
                            aliases[friend.userId] ?? friend.name;
                        final bool hasAlias = displayName != friend.name;

                        return _buildChatTile(
                          chat: chat,
                          displayName: displayName,
                          realName: hasAlias ? friend.name : null,
                          avatarUrl: friend.url.isNotEmpty ? friend.url : null,
                          userId: friend.userId,
                        );
                      },
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

  // ─── Chat tile ────────────────────────────────────────────────────────────

  Widget _buildChatTile({
    required ChatRoomModel chat,
    required String displayName,
    required String? realName,
    required String? avatarUrl,
    required String userId,
    bool isDeleted = false,
  }) {
    final int unread =
        chat.unreadCount[FirebaseAuth.instance.currentUser!.uid] ?? 0;

    // Each tile needs its own GlobalKey to locate its position on screen
    final tileKey = GlobalKey();

    return Container(
      key: tileKey,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ChatScreen(
                    chatRoomId: chat.id,
                    chatRoomName: displayName,
                    isDeleted: isDeleted,
                  ),
            ),
          );
        },
        onLongPress: () {
          final tileCtx = tileKey.currentContext;
          if (tileCtx == null) return;
          _showChatMenu(
            tileContext: tileCtx,
            chat: chat,
            displayName: displayName,
            userId: userId,
          );
        },
        child: Row(
          children: [
            // ── Avatar ──
            CircleAvatar(
              radius: 25,
              backgroundImage:
                  avatarUrl != null
                      ? NetworkImage(avatarUrl) as ImageProvider
                      : isDeleted
                      ? const AssetImage('assets/avatar.png') as ImageProvider
                      : null,
              backgroundColor: Colors.grey[200],
              child:
                  avatarUrl == null && !isDeleted
                      ? Text(
                        displayName.isNotEmpty ? displayName[0] : '?',
                        style: const TextStyle(color: Colors.black),
                      )
                      : null,
            ),
            const SizedBox(width: 12),

            // ── Name + last message ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (realName != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '($realName)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (chat.lastMessage != null &&
                      chat.lastMessage!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      chat.lastMessage!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // ── Unread badge ──
            if (unread > 0)
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unread.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
