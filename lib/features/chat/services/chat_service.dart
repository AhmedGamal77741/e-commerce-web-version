// services/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:ecommerece_app/features/chat/services/friends_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FriendsService _friendsService = FriendsService();

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Create or get direct chat room
  Future<String> createDirectChatRoom(String otherUserId, bool isBrand) async {
    const String supportUserId = 'JuxEfED9YSc2XyHRFgkPcNCFUSJ3';
    if (otherUserId != supportUserId) {
      final areFriends = await _friendsService.areFriends(otherUserId);
      if (!areFriends && !isBrand) {
        throw Exception('You can only chat with friends');
      }
    }

    final participants = [currentUserId, otherUserId]..sort();
    final chatRoomId = participants.join('_');

    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    final chatRoomDoc = await chatRoomRef.get();

    if (!chatRoomDoc.exists) {
      final otherUserDoc =
          await _firestore.collection('users').doc(otherUserId).get();
      if (!otherUserDoc.exists) {
        throw Exception('Other user not found');
      }

      final otherUser = MyUser.fromDocument(otherUserDoc.data()!);
      final now = DateTime.now();

      final chatRoom = ChatRoomModel(
        id: chatRoomId,
        name: otherUser.name,
        type: 'direct',
        participants: participants,
        lastMessageTime: now,
        createdAt: now,
        unreadCount: {currentUserId: 0, otherUserId: 0},
      );

      final batch = _firestore.batch();
      batch.set(chatRoomRef, chatRoom.toMap());
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'chatRooms': FieldValue.arrayUnion([chatRoomId]),
      });
      batch.update(_firestore.collection('users').doc(otherUserId), {
        'chatRooms': FieldValue.arrayUnion([chatRoomId]),
      });
      await batch.commit();
    }

    return chatRoomId;
  }

  Future<List<String>> createDirectChatRoomWithSeller(
    String otherUserId,
  ) async {
    final participants = [currentUserId, otherUserId]..sort();
    final chatRoomId = participants.join('_');

    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    final chatRoomDoc = await chatRoomRef.get();
    String otherUserName = "";

    if (!chatRoomDoc.exists) {
      final otherUserDoc =
          await _firestore
              .collection('deliveryManagers')
              .doc(otherUserId)
              .get();
      if (!otherUserDoc.exists) {
        throw Exception('Other user not found');
      }

      final otherUser = otherUserDoc.data()!;
      final now = DateTime.now();
      otherUserName = otherUser['name'];

      final chatRoom = ChatRoomModel(
        id: chatRoomId,
        name: otherUserName,
        type: 'seller',
        participants: participants,
        lastMessageTime: now,
        createdAt: now,
        unreadCount: {currentUserId: 0, otherUserId: 0},
      );

      final batch = _firestore.batch();
      batch.set(chatRoomRef, chatRoom.toMap());
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'chatRooms': FieldValue.arrayUnion([chatRoomId]),
      });
      batch.update(_firestore.collection('deliveryManagers').doc(otherUserId), {
        'chatRooms': FieldValue.arrayUnion([chatRoomId]),
      });
      await batch.commit();
    } else {
      otherUserName = chatRoomDoc.data()!['name'];
    }

    return [chatRoomId, otherUserName];
  }

  Future<String> createDirectChatRoomWithAdmin() async {
    final participants = [currentUserId, "Admin"]..sort();
    final chatRoomId = participants.join('_');

    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    final chatRoomDoc = await chatRoomRef.get();

    if (!chatRoomDoc.exists) {
      final now = DateTime.now();
      final chatRoom = ChatRoomModel(
        id: chatRoomId,
        name: "Admin",
        type: 'admin',
        participants: participants,
        lastMessageTime: now,
        createdAt: now,
        unreadCount: {currentUserId: 0, "Admin": 0},
      );

      final batch = _firestore.batch();
      batch.set(chatRoomRef, chatRoom.toMap());
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'chatRooms': FieldValue.arrayUnion([chatRoomId]),
      });
      batch.update(_firestore.collection('users').doc("Admin"), {
        'chatRooms': FieldValue.arrayUnion([chatRoomId]),
      });
      await batch.commit();
    }

    return chatRoomId;
  }

  Future<bool> toggleLoveReaction({
    required String messageId,
    required String chatRoomId,
  }) async {
    try {
      final messageRef = _firestore.collection('messages').doc(messageId);
      final messageDoc = await messageRef.get();

      if (!messageDoc.exists) return false;

      final message = MessageModel.fromMap(messageDoc.data()!);
      final isLoved = message.lovedBy.contains(currentUserId);

      if (isLoved) {
        await messageRef.update({
          'lovedBy': FieldValue.arrayRemove([currentUserId]),
        });
      } else {
        await messageRef.update({
          'lovedBy': FieldValue.arrayUnion([currentUserId]),
        });
      }

      return true;
    } catch (e) {
      print('Error toggling love reaction: $e');
      return false;
    }
  }

  // Create group chat room
  Future<String?> createGroupChatRoom({
    required String name,
    required List<String> participantIds,
    String? groupImage,
  }) async {
    for (String participantId in participantIds) {
      final areFriends = await _friendsService.areFriends(participantId);
      if (!areFriends) {
        throw Exception('You can only add friends to group chats');
      }
    }

    final chatRoomRef = _firestore.collection('chatRooms').doc();
    final chatRoomId = chatRoomRef.id;

    final participants = [currentUserId, ...participantIds];
    final unreadCount = <String, int>{};
    for (String userId in participants) {
      unreadCount[userId] = 0;
    }

    final chatRoom = ChatRoomModel(
      id: chatRoomId,
      name: name,
      type: 'group',
      participants: participants,
      lastMessageTime: DateTime.now(),
      createdAt: DateTime.now(),
      createdBy: currentUserId,
      groupImage: groupImage,
      unreadCount: unreadCount,
    );

    await chatRoomRef.set(chatRoom.toMap());

    for (String userId in participants) {
      await _updateUserChatRooms(userId, chatRoomId);
    }

    return chatRoomId;
  }

  // Get friends for chat creation
  Stream<List<MyUser>> getFriendsStream() {
    return _friendsService.getFriendsStream();
  }

  // ─── Send message ─────────────────────────────────────────────────────────
  Future<void> sendMessage({
    required String chatRoomId,
    required String content,
    String? imageUrl,
    String? replyToMessageId,
    bool isStory = false,
    String? storyId = '',
    Map<String, dynamic>? postData,
    Product? productData,
  }) async {
    // Verify chat room still exists (prevents blocked users from sending messages)
    final chatRoomDoc =
        await _firestore.collection('chatRooms').doc(chatRoomId).get();
    if (!chatRoomDoc.exists) {
      throw Exception('Chat room no longer exists or you are blocked.');
    }

    final chatRoom = ChatRoomModel.fromMap(chatRoomDoc.data()!);
    if (!chatRoom.participants.contains(currentUserId)) {
      throw Exception('You are no longer a participant in this chat.');
    }

    // Strict validation for direct chats
    if (chatRoom.type == 'direct') {
      final otherUserId = chatRoom.participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      if (otherUserId.isNotEmpty) {
        // Check if receiver blocked the sender
        final receiverDoc =
            await _firestore.collection('users').doc(otherUserId).get();
        if (receiverDoc.exists) {
          final receiverBlocked = List<String>.from(
            receiverDoc.data()?['blocked'] ?? [],
          );
          if (receiverBlocked.contains(currentUserId)) {
            throw Exception('You are blocked by this user.');
          }
        }

        // Check if they are still friends
        final areFriends = await _friendsService.areFriends(otherUserId);
        if (!areFriends) {
          throw Exception('You can only chat with friends.');
        }
      }
    }

    final messageRef = _firestore.collection('messages').doc();
    final messageId = messageRef.id;

    // Get current user data
    final userDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final user = MyUser.fromDocument(userDoc.data()!);

    final message = MessageModel(
      id: messageId,
      chatRoomId: chatRoomId,
      senderId: currentUserId,
      senderName: user.name,
      content: content,
      imageUrl: imageUrl,
      timestamp: DateTime.now(),
      readBy: [currentUserId],
      replyToMessageId: replyToMessageId,
      isStory: isStory,
      storyId: storyId,
      postData: postData,
      productData: productData,
    );

    // ✅ Save message to its subcollection too (for any future subcollection queries)
    final subRef = _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);

    final batch = _firestore.batch();
    batch.set(messageRef, message.toMap());
    batch.set(subRef, message.toMap());
    await batch.commit();

    // ✅ Determine lastMessage display text
    // If it's an image-only message, save '[사진]' so the group list shows photo icon
    final String lastMessageText =
        (content.isEmpty && imageUrl != null && imageUrl.isNotEmpty)
            ? '[사진]'
            : content;

    // ✅ Update chat room's last message — now includes senderName
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'lastMessage': lastMessageText,
      'lastMessageTime': message.timestamp.millisecondsSinceEpoch,
      'lastMessageSenderId': currentUserId,
      'lastMessageSenderName': user.name, // ✅ NEW — needed for group list
    });

    // Update unread count for other participants
    final updatedUnreadCount = Map<String, int>.from(chatRoom.unreadCount);
    for (String participantId in chatRoom.participants) {
      if (participantId != currentUserId) {
        updatedUnreadCount[participantId] =
            (updatedUnreadCount[participantId] ?? 0) + 1;
      }
    }

    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'unreadCount': updatedUnreadCount,
    });
  }

  Future<void> resetDeletedBy(String chatRoomId) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'deletedBy': [],
    });
  }

  Future<void> softDeleteChatForCurrentUser(String chatRoomId) async {
    final batch = _firestore.batch();

    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    batch.update(chatRoomRef, {
      'deletedBy': FieldValue.arrayUnion([currentUserId]),
    });

    final messagesQuery =
        await _firestore
            .collection('messages')
            .where('chatRoomId', isEqualTo: chatRoomId)
            .get();

    for (final doc in messagesQuery.docs) {
      batch.update(doc.reference, {
        'deletedBy': FieldValue.arrayUnion([currentUserId]),
      });
    }

    await batch.commit();
  }

  // Reset unread count for current user in the room doc
  Future<void> resetUnreadCount(String chatRoomId) async {
    final roomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    final roomDoc = await roomRef.get();
    if (roomDoc.exists) {
      final data = roomDoc.data();
      final unreadCount = Map<String, dynamic>.from(data?['unreadCount'] ?? {});
      final myUnread = unreadCount[currentUserId] ?? 0;
      if (myUnread > 0) {
        await roomRef.update({'unreadCount.$currentUserId': 0});
      }
    }
  }

  // Mark specific messages as read
  Future<void> markSpecificMessagesAsRead(
    String chatRoomId,
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return;

    final batch = _firestore.batch();
    for (final id in messageIds) {
      final msgRef = _firestore.collection('messages').doc(id);
      final subRef = _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(id);

      batch.set(msgRef, {
        'readBy': FieldValue.arrayUnion([currentUserId]),
      }, SetOptions(merge: true));
      batch.set(subRef, {
        'readBy': FieldValue.arrayUnion([currentUserId]),
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
    } catch (e) {
      print('Error committing read status batch: $e');
    }
    try {
      await resetUnreadCount(chatRoomId);
    } catch (e) {
      print('Error resetting unread count: $e');
    }
  }

  // Get chat rooms stream
  Stream<List<ChatRoomModel>> getChatRoomsStream() {
    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          final rooms =
              snapshot.docs
                  .map((doc) => ChatRoomModel.fromMap(doc.data()))
                  .toList();
          rooms.sort((a, b) {
            final aTime = a.lastMessageTime;
            final bTime = b.lastMessageTime;
            return bTime.compareTo(aTime);
          });
          return rooms;
        });
  }

  // Get messages stream
  Stream<List<MessageModel>> getMessagesStream(String chatRoomId) {
    return _firestore
        .collection('messages')
        .where('chatRoomId', isEqualTo: chatRoomId)
        .snapshots()
        .map((snapshot) {
          final messages =
              snapshot.docs
                  .map((doc) => MessageModel.fromMap(doc.data()))
                  .toList();
          messages.sort((a, b) {
            final aTime = a.timestamp;
            final bTime = b.timestamp;
            return bTime.compareTo(aTime);
          });
          return messages;
        });
  }

  // Get users for creating chats
  Stream<List<MyUser>> getUsersStream() {
    return _firestore
        .collection('users')
        .where('id', isNotEqualTo: currentUserId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => MyUser.fromDocument(doc.data()))
                  .toList(),
        );
  }

  // Helper method to update user's chat rooms
  Future<void> _updateUserChatRooms(String userId, String chatRoomId) async {
    await _firestore.collection('users').doc(userId).update({
      'chatRooms': FieldValue.arrayUnion([chatRoomId]),
    });
  }

  // Add participant to group
  Future<void> addParticipantToGroup(String chatRoomId, String userId) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'participants': FieldValue.arrayUnion([userId]),
      'unreadCount.$userId': 0,
    });

    await _updateUserChatRooms(userId, chatRoomId);
  }

  // Remove participant from group
  Future<void> removeParticipantFromGroup(
    String chatRoomId,
    String userId,
  ) async {
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'participants': FieldValue.arrayRemove([userId]),
      'unreadCount.$userId': FieldValue.delete(),
    });

    await _firestore.collection('users').doc(userId).update({
      'chatRooms': FieldValue.arrayRemove([chatRoomId]),
    });
  }
}
