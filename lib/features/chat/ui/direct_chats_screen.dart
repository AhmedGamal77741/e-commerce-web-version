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

  bool editMode = false;
  bool searchMode = false;
  Set<String> selectedChatIds = {};
  Set<String> selectedFriendIds = {};
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  Future<MyUser?> getOtherUser(ChatRoomModel chat) async {
    final otherId = chat.participants.firstWhere((id) => id != currentUserId);
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(otherId).get();
    if (!doc.exists) return null;
    return MyUser.fromDocument(doc.data()!);
  }

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
      if (!editMode) {
        selectedChatIds.clear();
        selectedFriendIds.clear();
      }
    });
  }

  void onSelectChat(String chatId, bool selected) {}

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
                selectedFriendIds.clear();
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
                      for (String chatId in selectedFriendIds) {
                        await _friendsService.blockFriend(chatId);
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
                        await chatService.softDeleteChatForCurrentUser(chatId);
                      }
                      Navigator.pop(context);
                    },
                    child: Image.asset(
                      'assets/delete.png',
                      height: 30,
                      width: 30,
                      cacheWidth: 40,
                      cacheHeight: 40,
                    ),
                  ),
                  /*  TextButton(
                    onPressed:
                        selectedChatIds.isEmpty
                            ? null
                            : () {
                              // Handle delete or other action for selectedChatIds
                              // Example: chatService.deleteChats(selectedChatIds);
                              toggleEditMode();
                            },
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color:
                            selectedChatIds.isEmpty ? Colors.grey : Colors.red,
                        fontSize: 16.sp,
                      ),
                    ),
                  ), */
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
      body: StreamBuilder<List<ChatRoomModel>>(
        stream: chatService.getChatRoomsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          // Show chats with type 'direct', missing type, or empty type
          final directChats =
              snapshot.data!
                  .where(
                    (chat) =>
                        chat.type == 'direct' ||
                        chat.type == '' ||
                        chat.type == null,
                  )
                  .toList();
          if (directChats.isEmpty)
            return const Center(child: Text('No direct chats.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: directChats.length,
            itemBuilder: (context, index) {
              final chat = directChats[index];
              if (chat.deletedBy.contains(currentUserId))
                return const SizedBox.shrink();
              return FutureBuilder<MyUser?>(
                future: getOtherUser(chat),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(
                        radius: 25,
                        child: Icon(Icons.person),
                      ),
                      title: Text('Loading...'),
                    );
                  }
                  final friend = userSnap.data!;
                  // Filter by search query
                  if (searchQuery.isNotEmpty &&
                      !friend.name.toLowerCase().contains(searchQuery)) {
                    return const SizedBox.shrink();
                  }
                  // Only show checkboxes for non-brands (assuming brands have isBrand == true)
                  final showCheckbox = editMode;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap:
                          editMode
                              ? () {
                                onSelectChat(
                                  chat.id,
                                  !selectedChatIds.contains(friend.userId),
                                );
                              }
                              : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ChatScreen(
                                          chatRoomId: chat.id,
                                          chatRoomName: friend.name,
                                        ),
                                  ),
                                );
                              },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundImage:
                                friend.url.isNotEmpty
                                    ? NetworkImage(friend.url)
                                    : null,
                            child:
                                friend.url.isEmpty
                                    ? Text(
                                      friend.name.isNotEmpty
                                          ? friend.name[0]
                                          : '?',
                                    )
                                    : null,
                          ),
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
                              ],
                            ),
                          ),
                          if (chat.unreadCount[FirebaseAuth
                                      .instance
                                      .currentUser!
                                      .uid] !=
                                  null &&
                              chat.unreadCount[FirebaseAuth
                                      .instance
                                      .currentUser!
                                      .uid]! >
                                  0)
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                chat
                                    .unreadCount[FirebaseAuth
                                        .instance
                                        .currentUser!
                                        .uid]!
                                    .toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (showCheckbox)
                            StatefulBuilder(
                              builder: (context, checkboxState) {
                                return Checkbox(
                                  value: selectedFriendIds.contains(
                                    friend.userId,
                                  ),
                                  onChanged: (checked) {
                                    checkboxState(() {
                                      if (checked ?? false) {
                                        selectedChatIds.add(chat.id);
                                        selectedFriendIds.add(friend.userId);
                                      } else {
                                        selectedChatIds.remove(chat.id);
                                        selectedFriendIds.remove(friend.userId);
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
                },
              );
            },
          );
        },
      ),
    );
  }
}
