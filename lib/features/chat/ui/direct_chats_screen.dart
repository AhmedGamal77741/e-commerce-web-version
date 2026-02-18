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

  // ── Active overlay (only one menu open at a time) ────────────────────────
  OverlayEntry? _activeMenuOverlay;

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

  @override
  void dispose() {
    _dismissActiveMenu();
    super.dispose();
  }

  void _dismissActiveMenu() {
    _activeMenuOverlay?.remove();
    _activeMenuOverlay = null;
  }

  // ─── KakaoTalk-style long-press context menu ──────────────────────────────
  void _showChatMenu({
    required LayerLink layerLink,
    required Size tileSize,
    required ChatRoomModel chat,
    required String displayName,
    required String userId,
  }) {
    _dismissActiveMenu();

    const double popupWidth = 200;
    const double popupHeight = 160;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Right-aligned to tile, vertically centred — matches original math
    final double followerDx = tileSize.width - popupWidth - 8;
    final double followerDy = (tileSize.height / 2) - (popupHeight / 2) + 40;

    _activeMenuOverlay = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            // ── Transparent dismiss barrier ──────────────────────────────
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissActiveMenu,
                child: const SizedBox.expand(),
              ),
            ),

            // ── Popup anchored to the tile ────────────────────────────────
            CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              offset: Offset(followerDx, followerDy),
              child: Align(
                alignment: Alignment.topLeft,
                child: _ClampedMenu(
                  popupWidth: popupWidth,
                  popupHeight: popupHeight,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: popupWidth,
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
                          const SizedBox(height: 16),
                          // ── Name title ──────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              displayName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(
                            color: Colors.grey[200],
                            thickness: 1,
                            height: 1,
                          ),

                          // ── 차단하기 (Block) ────────────────────────────
                          _buildMenuOption(
                            label: '차단하기',
                            onTap: () async {
                              _dismissActiveMenu();
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

                          // ── 나가기 (Leave) ──────────────────────────────
                          _buildMenuOption(
                            label: '나가기',
                            isLast: true,
                            onTap: () async {
                              _dismissActiveMenu();
                              showLoadingDialog(context);
                              await chatService.softDeleteChatForCurrentUser(
                                chat.id,
                              );
                              if (mounted) Navigator.pop(context);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_activeMenuOverlay!);
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
              ? const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              )
              : BorderRadius.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
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

    // LayerLink per tile — replaces the old GlobalKey approach
    final LayerLink layerLink = LayerLink();

    // LayoutBuilder gives us the tile's actual width at build time (reliable on web).
    // Height is fixed at 72 for the vertical-centre calc — visually accurate.
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSize = Size(constraints.maxWidth, 72);

        return CompositedTransformTarget(
          link: layerLink,
          child: Container(
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
                _showChatMenu(
                  layerLink: layerLink,
                  tileSize: tileSize,
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
                            ? const AssetImage('assets/avatar.png')
                                as ImageProvider
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
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── _ClampedMenu ─────────────────────────────────────────────────────────────
//
// Post-frame clamp: measures the popup's actual screen position after layout
// and applies a Transform.translate to keep it fully within screen bounds.
// Replicates the original left/top if-clamp chain, but done correctly on web.

class _ClampedMenu extends StatefulWidget {
  const _ClampedMenu({
    required this.child,
    required this.popupWidth,
    required this.popupHeight,
    required this.screenWidth,
    required this.screenHeight,
  });

  final Widget child;
  final double popupWidth;
  final double popupHeight;
  final double screenWidth;
  final double screenHeight;

  @override
  State<_ClampedMenu> createState() => _ClampedMenuState();
}

class _ClampedMenuState extends State<_ClampedMenu> {
  double _dx = 0;
  double _dy = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final pos = box.localToGlobal(Offset.zero);

      double dx = 0;
      double dy = 0;

      // Right edge
      if (pos.dx + widget.popupWidth > widget.screenWidth - 8) {
        dx = (widget.screenWidth - 8) - (pos.dx + widget.popupWidth);
      }
      // Left edge
      if (pos.dx + dx < 8) dx = 8 - pos.dx;

      // Bottom edge
      if (pos.dy + widget.popupHeight > widget.screenHeight - 20) {
        dy = (widget.screenHeight - 20) - (pos.dy + widget.popupHeight);
      }
      // Top edge
      if (pos.dy + dy < 8) dy = 8 - pos.dy;

      if (dx != 0 || dy != 0) {
        setState(() {
          _dx = dx;
          _dy = dy;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(offset: Offset(_dx, _dy), child: widget.child);
  }
}
