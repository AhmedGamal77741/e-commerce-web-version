// screens/friends_screen.dart
import 'package:ecommerece_app/core/helpers/loading_dialog.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/chat/services/chat_service.dart';
import 'package:ecommerece_app/features/chat/services/contacts_service.dart';
import 'package:ecommerece_app/features/chat/ui/chat_room_screen.dart';
import 'package:ecommerece_app/features/chat/widgets/expandable_FAB.dart';
import 'package:ecommerece_app/features/chat/services/friends_service.dart';
import 'package:flutter/material.dart';

class FriendsScreen extends StatefulWidget {
  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with TickerProviderStateMixin {
  final FriendsService _friendsService = FriendsService();
  final ContactService _contactService = ContactService();
  final ChatService _chatService = ChatService();

  bool _isSyncing = false;
  bool editMode = false;
  bool searchMode = false;
  Set<String> selectedChatIds = {};
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  void toggleSearchMode() {
    setState(() {
      searchMode = !searchMode;
      if (!searchMode) {
        searchQuery = '';
        searchController.clear();
      }
    });
  }

  void toggleEditMode() {
    setState(() {
      editMode = !editMode;
      if (!editMode) selectedChatIds.clear();
    });
  }

  void onSelectChat(String chatId, bool selected) {}

  @override
  void initState() {
    super.initState();

    _syncContactsOnEnter();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _syncContactsOnEnter() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final addedCount = await _contactService.syncAndAddFriendsFromContacts();
      if (addedCount > 0) {
        // Show a subtle notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$addedCount명의 친구가 연락처에서 자동으로 추가되었습니다'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Contact sync error: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actionsPadding: EdgeInsets.only(right: 5),

        title:
            searchMode
                ? TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.trim().toLowerCase();
                    });
                  },
                )
                : null,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () async {
            if (editMode) {
              setState(() {
                editMode = false;
                selectedChatIds.clear();
              });
            } else if (searchMode) {
              setState(() {
                searchMode = false;
                searchQuery = '';
                searchController.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions:
            editMode
                ? [
                  InkWell(
                    onTap: () async {
                      showLoadingDialog(context);
                      // Block selected friends by name (FriendsService expects name)
                      final allFriends = _friendsService.getFriendsStream();
                      final friendsList = await allFriends.first;
                      for (String userId in selectedChatIds) {
                        final friend = friendsList.firstWhere(
                          (f) => f.userId == userId,
                          orElse:
                              () => MyUser(
                                userId: userId,
                                name: userId,
                                url: '',
                                type: 'user',
                                email: '',
                                lastSeen: DateTime.now(),
                              ),
                        );
                        await _friendsService.blockFriend(friend.name);
                      }
                      Navigator.pop(context);
                      toggleEditMode();
                    },
                    child: Image.asset(
                      'assets/block (1).png',
                      height: 30,
                      width: 30,
                      cacheWidth: 40,
                      cacheHeight: 40,
                    ),
                  ),
                  SizedBox(width: 5),
                  InkWell(
                    onTap: () async {
                      showLoadingDialog(context);
                      for (String chatId in selectedChatIds) {
                        await _friendsService.removeFriend(chatId);
                      }
                      Navigator.pop(context);
                      toggleEditMode();
                    },
                    child: Image.asset(
                      'assets/delete.png',
                      height: 30,
                      width: 30,
                      cacheWidth: 40,
                      cacheHeight: 40,
                    ),
                  ),
                ]
                : [
                  InkWell(
                    onTap: toggleEditMode,
                    child: Image.asset(
                      'assets/edit mode.png',
                      height: 30,
                      width: 30,
                      cacheWidth: 40,
                      cacheHeight: 40,
                    ),
                  ),
                  SizedBox(width: 5),
                  IconButton(
                    icon: Icon(Icons.search, color: Colors.black, size: 30),
                    onPressed: toggleSearchMode,
                  ),
                ],
      ),
      body: StreamBuilder<List<MyUser>>(
        stream: _friendsService.getFriendsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || _isSyncing) {
            return const Center(child: CircularProgressIndicator());
          }

          final allUsers = snapshot.data ?? [];
          final friends =
              allUsers.where((user) => user.type == 'user').toList();
          final brands =
              allUsers.where((user) => user.type == 'brand').toList();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFavoriteSection(friends),
                    _buildBrandSection(brands),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      /*       floatingActionButton: FloatingActionButton(
        heroTag: 'unique-fab-1', // Add this unique tag
        onPressed: () {
          /*           Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddFriendScreen()),
          ); */
        },
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ), */
    );
  }

  Widget _buildFavoriteSection(List<MyUser> friends) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            '친구 ${friends.length}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ...friends.map((friend) {
          // Filter by search query
          if (searchQuery.isNotEmpty &&
              !friend.name.toLowerCase().contains(searchQuery)) {
            return const SizedBox.shrink();
          }
          return _buildFriendItem(
            friend: friend,
            showSubtitle: true,
            showCheckbox: editMode,
          );
        }).toList(),
        /*         if (friends.length > 4) ...[
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE5E5E5)),
          const SizedBox(height: 16),
          ...friends
              .map(
                (friend) =>
                    _buildFriendItem(friend: friend, showSubtitle: true),
              )
              .toList(),
        ], */
      ],
    );
  }

  Widget _buildBrandSection(List<MyUser> friends) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            '브랜드 ${friends.length}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        StreamBuilder(
          stream: _friendsService.getBrandsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || _isSyncing) {
              return const Center(child: CircularProgressIndicator());
            }

            final allUsers = snapshot.data ?? [];

            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: allUsers.length,
              itemBuilder: (context, index) {
                return _buildFriendItem(
                  friend: allUsers[index],
                  showSubtitle: true,
                  showCheckbox: editMode,
                  isBrand: true,
                );
              },
            );
          },
        ),
        /*         if (friends.length > 4) ...[
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE5E5E5)),
          const SizedBox(height: 16),
          ...friends
              .map(
                (friend) =>
                    _buildFriendItem(friend: friend, showSubtitle: true),
              )
              .toList(),
        ], */
      ],
    );
  }

  Widget _buildFriendItem({
    required MyUser friend,
    bool showSubtitle = false,
    bool showCheckbox = false,
    bool isBrand = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          try {
            final chatRoomId = await _chatService.createDirectChatRoom(
              friend.userId,
              isBrand,
            );
            if (chatRoomId != null) {
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
            if (showCheckbox)
              StatefulBuilder(
                builder: (context, checkboxState) {
                  return Checkbox(
                    value: selectedChatIds.contains(friend.userId),
                    onChanged: (checked) {
                      checkboxState(() {
                        if (checked ?? false) {
                          selectedChatIds.add(friend.userId);
                        } else {
                          selectedChatIds.remove(friend.userId);
                        }
                      });

                      /*                                 onSelectChat(chat.id, );
                                 */
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandItem({
    required String name,
    String? subtitle,
    String? profileImage,
    Color backgroundColor = Colors.grey,
    Color textColor = Colors.white,
    bool hasGradient = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          // Handle brand tap
        },
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasGradient ? null : backgroundColor,
                gradient:
                    hasGradient
                        ? LinearGradient(
                          colors: [Colors.orange, Colors.pink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                        : null,
              ),
              child:
                  profileImage != null
                      ? ClipOval(
                        child: Image.asset(
                          profileImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.business,
                              color: textColor,
                              size: 24,
                            );
                          },
                        ),
                      )
                      : Icon(Icons.business, color: textColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
}
