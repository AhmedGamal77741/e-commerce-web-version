import 'package:ecommerece_app/features/chat/services/chat_service.dart';
import 'package:ecommerece_app/features/chat/services/friends_service.dart';
import 'package:ecommerece_app/features/home/data/home_functions.dart';
import 'package:flutter/material.dart';

class ExpandableFAB extends StatefulWidget {
  const ExpandableFAB({Key? key}) : super(key: key);

  @override
  State<ExpandableFAB> createState() => _ExpandableFABState();
}

class _ExpandableFABState extends State<ExpandableFAB>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animation);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 40 - _animation.value * 70),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  alignment: Alignment.bottomRight,
                  child: Opacity(
                    opacity: _animation.value,
                    child: Container(
                      width: 200,
                      height: 200,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(40),
                          bottomLeft: Radius.circular(40),
                        ),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                        color: Colors.grey[200],
                        boxShadow: [],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildMenuItem(
                              icon: "assets/group_active_1.png",
                              label: '그룹 만들기',
                              onTap: () async {
                                await showCreateGroupDialog(context, (
                                  name,
                                  userIds,
                                  groupImage,
                                ) async {
                                  await ChatService().createGroupChatRoom(
                                    name: name,
                                    participantIds: userIds,
                                    groupImage: groupImage,
                                  );
                                });
                                _toggle();
                              },
                              showDivider: true,
                            ),
                          ),
                          Expanded(
                            child: _buildMenuItem(
                              icon: "assets/add friend.png",
                              label: '친구 추가',
                              onTap: () async {
                                await showAddFriendDialog(context, (
                                  userId,
                                ) async {
                                  await FriendsService().addFriend(userId);
                                });
                                _toggle();
                              },
                              showDivider: true,
                            ),
                          ),
                          Expanded(
                            child: _buildMenuItem(
                              icon: "assets/block user.png",
                              label: '차단 친구',
                              onTap: () async {
                                await showBlockUserDialog(context, (
                                  userId,
                                ) async {
                                  await FriendsService().blockFriend(userId);
                                });
                                _toggle();
                              },
                              showDivider: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Main FAB
          FloatingActionButton(
            onPressed: _toggle,
            backgroundColor: Colors.black,
            shape: const CircleBorder(),
            child: AnimatedRotation(
              turns: _isExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 300),
              child: ImageIcon(
                AssetImage("assets/imageedit_2_3487749186.png"),
                size: 60,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show dialog to block a user by user ID or name
  Future<void> showBlockUserDialog(
    BuildContext context,
    void Function(String userId) onBlock,
  ) async {
    final controller = TextEditingController();
    bool manageMode = false;
    List<Map<String, String>> blockedFriends = [];

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('차단 친구', style: TextStyle(color: Colors.black)),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.black,
                        ),
                        onPressed: () async {
                          if (!manageMode) {
                            blockedFriends =
                                await FriendsService().getBlockedFriends();
                          }
                          setState(() {
                            manageMode = !manageMode;
                          });
                        },
                        child: Text(
                          manageMode ? '차단' : '차단 친구 관리',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content:
                      manageMode
                          ? SizedBox(
                            width: 300,
                            child:
                                blockedFriends.isEmpty
                                    ? Text(
                                      '차단된 친구가 없습니다.',
                                      style: TextStyle(color: Colors.black54),
                                    )
                                    : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: blockedFriends.length,
                                      itemBuilder: (context, idx) {
                                        final user = blockedFriends[idx];
                                        return ListTile(
                                          title: Text(
                                            user['name'] ??
                                                user['userId'] ??
                                                '',
                                            style: TextStyle(
                                              color: Colors.black,
                                            ),
                                          ),
                                          subtitle:
                                              user['userId'] != null
                                                  ? Text(
                                                    user['userId']!,
                                                    style: TextStyle(
                                                      color: Colors.black54,
                                                      fontSize: 12,
                                                    ),
                                                  )
                                                  : null,
                                          trailing: TextButton(
                                            onPressed: () async {
                                              await FriendsService()
                                                  .unblockFriend(
                                                    user['userId']!,
                                                  );
                                              blockedFriends =
                                                  await FriendsService()
                                                      .getBlockedFriends();
                                              setState(() {});
                                            },
                                            child: Text(
                                              '해제',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                          )
                          : TextField(
                            controller: controller,
                            style: const TextStyle(color: Colors.black),
                            decoration: const InputDecoration(
                              labelText: '유저 ID 또는 이름',
                              labelStyle: TextStyle(color: Colors.black54),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black26),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black),
                              ),
                            ),
                          ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    if (!manageMode)
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.black,
                        ),
                        onPressed: () {
                          onBlock(controller.text.trim());
                          Navigator.pop(context);
                        },
                        child: const Text(
                          '차단',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ),
          ),
    );
  }

  // Show dialog to add a friend by user ID or name
  Future<void> showAddFriendDialog(
    BuildContext context,
    void Function(String userId) onAdd,
  ) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('친구 추가', style: TextStyle(color: Colors.black)),
            content: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: '유저 ID 또는 이름',
                labelStyle: TextStyle(color: Colors.black54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black26),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소', style: TextStyle(color: Colors.black)),
              ),
              TextButton(
                style: TextButton.styleFrom(backgroundColor: Colors.black),
                onPressed: () {
                  onAdd(controller.text.trim());
                  Navigator.pop(context);
                },
                child: const Text('추가', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Future<void> showCreateGroupDialog(
    BuildContext context,
    void Function(String name, List<String> userIds, String? groupImageUrl)
    onCreate,
  ) async {
    final nameController = TextEditingController();
    List<String> selectedUserIds = [];
    String? groupImagePath;
    final friends = await FriendsService().getFriendsStream().first;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: const Text(
                    '그룹 만들기',
                    style: TextStyle(color: Colors.black),
                  ),
                  content: SizedBox(
                    width: 350,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: () async {
                              groupImagePath =
                                  await uploadImageToFirebaseStorage();
                              setState(() {});
                            },
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.grey[300],
                              backgroundImage:
                                  groupImagePath != null
                                      ? NetworkImage(groupImagePath!)
                                      : null,
                              child:
                                  groupImagePath == null
                                      ? const Icon(
                                        Icons.camera_alt,
                                        size: 32,
                                        color: Colors.black54,
                                      )
                                      : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.black),
                          decoration: const InputDecoration(
                            labelText: '그룹 이름',
                            labelStyle: TextStyle(color: Colors.black54),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black26),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '친구 선택',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: friends.length,
                            itemBuilder: (context, idx) {
                              final user = friends[idx];
                              return CheckboxListTile(
                                value: selectedUserIds.contains(user.userId),
                                title: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage:
                                          user.url.isNotEmpty
                                              ? NetworkImage(user.url)
                                              : null,
                                      child:
                                          user.url.isEmpty
                                              ? Text(
                                                user.name.isNotEmpty
                                                    ? user.name[0]
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                ),
                                              )
                                              : null,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      selectedUserIds.add(user.userId);
                                    } else {
                                      selectedUserIds.remove(user.userId);
                                    }
                                  });
                                },
                                checkColor: Colors.white,
                                activeColor: Colors.black,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.black,
                      ),
                      onPressed: () {
                        onCreate(
                          nameController.text,
                          selectedUserIds,
                          groupImagePath,
                        );
                        Navigator.pop(context);
                      },
                      child: const Text(
                        '생성',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildMenuItem({
    required String icon,
    required String label,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Image.asset(
                    icon,
                    width: 30,
                    height: 30,
                    cacheWidth: 40, // Limits memory usage (2x display size)
                    cacheHeight: 40,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 16), // Extra padding on the right
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }
}
