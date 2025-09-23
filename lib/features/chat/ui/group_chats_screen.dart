import 'package:ecommerece_app/features/chat/ui/chat_room_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_room_model.dart';
import '../services/chat_service.dart';

class GroupChatsScreen extends StatefulWidget {
  @override
  State<GroupChatsScreen> createState() => _GroupChatsScreenState();
}

class _GroupChatsScreenState extends State<GroupChatsScreen> {
  final ChatService chatService = ChatService();

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
                  TextButton(
                    onPressed:
                        selectedChatIds.isEmpty
                            ? null
                            : () {
                              for (var chatId in selectedChatIds) {
                                chatService.removeParticipantFromGroup(
                                  chatId,
                                  FirebaseAuth.instance.currentUser!.uid,
                                );
                              }
                              toggleEditMode();
                            },
                    child: Text(
                      '나가기',
                      style: TextStyle(
                        color:
                            selectedChatIds.isEmpty ? Colors.grey : Colors.red,
                        fontSize: 16,
                      ),
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
      body: StreamBuilder<List<ChatRoomModel>>(
        stream: chatService.getChatRoomsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final groupChats =
              snapshot.data!.where((chat) => chat.type == 'group').toList();
          if (groupChats.isEmpty)
            return const Center(child: Text('No group chats.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupChats.length,
            itemBuilder: (context, index) {
              final chat = groupChats[index];
              // Filter by search query
              if (searchQuery.isNotEmpty &&
                  !chat.name.toLowerCase().contains(searchQuery)) {
                return const SizedBox.shrink();
              }
              final showCheckbox = editMode;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ChatScreen(
                              chatRoomId: chat.id,
                              chatRoomName: chat.name,
                            ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundImage:
                            (chat.groupImage != null &&
                                    chat.groupImage!.isNotEmpty)
                                ? NetworkImage(chat.groupImage!)
                                : const AssetImage('assets/009.png'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chat.name,
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
                              value: selectedChatIds.contains(chat.id),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked ?? false) {
                                    selectedChatIds.add(chat.id);
                                  } else {
                                    selectedChatIds.remove(chat.id);
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
      ),
    );
  }
}
