// models/chat_room_model.dart
class ChatRoomModel {
  final String id;
  final String name;
  final String type; // 'direct' or 'group'
  final List<String> participants;
  List<String> deletedBy;
  final String? lastMessage;
  final DateTime lastMessageTime;
  final String? lastMessageSenderId;
  final String? groupImage;
  final String? createdBy;
  final DateTime createdAt;
  final Map<String, int> unreadCount; // userId -> unread count
  final String? lastMessageSenderName;
  ChatRoomModel({
    required this.id,
    required this.name,
    required this.type,
    required this.participants,
    this.lastMessage,
    required this.lastMessageTime,
    this.lastMessageSenderId,
    this.groupImage,
    this.createdBy,
    this.deletedBy = const [],
    required this.createdAt,
    this.unreadCount = const {},
    this.lastMessageSenderName,
  });

  factory ChatRoomModel.fromMap(Map<String, dynamic> map) {
    return ChatRoomModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'direct',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'],
      lastMessageTime: DateTime.fromMillisecondsSinceEpoch(
        map['lastMessageTime'] ?? 0,
      ),
      lastMessageSenderId: map['lastMessageSenderId'],
      groupImage: map['groupImage'],
      createdBy: map['createdBy'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      deletedBy: List<String>.from(map['deletedBy'] ?? []),
      lastMessageSenderName: map['lastMessageSenderName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'lastMessageSenderId': lastMessageSenderId,
      'groupImage': groupImage,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'unreadCount': unreadCount,
      'deletedBy': deletedBy,
      'lastMessageSenderName': lastMessageSenderName,
    };
  }
}
