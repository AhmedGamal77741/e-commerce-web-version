// models/message_model.dart
import 'package:ecommerece_app/core/models/product_model.dart';

class MessageModel {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderName;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;
  final List<String> readBy;
  final String? replyToMessageId;
  final bool isEdited;
  final List<String> lovedBy;
  List<String> deletedBy;
  bool isStory = false;
  final String? storyId;
  final Map<String, dynamic>? postData;
  final Product? productData;
  MessageModel({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.imageUrl,
    required this.timestamp,
    this.readBy = const [],
    this.replyToMessageId,
    this.isEdited = false,
    this.lovedBy = const [],
    this.deletedBy = const [],
    this.isStory = false,
    this.storyId,
    this.postData,
    this.productData,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      chatRoomId: map['chatRoomId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'] ?? '', // <-- add this
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      readBy: List<String>.from(map['readBy'] ?? []),
      replyToMessageId: map['replyToMessageId'],
      isEdited: map['isEdited'] ?? false,
      lovedBy: List<String>.from(map['lovedBy'] ?? []),
      deletedBy: List<String>.from(map['deletedBy'] ?? []),
      isStory: map['isStory'] ?? false,
      storyId: map['storyId'] ?? '',
      postData:
          map['postData'] != null
              ? Map<String, dynamic>.from(map['postData'])
              : null,
      productData:
          map['productData'] != null
              ? Product.fromMap(Map<String, dynamic>.from(map['productData']))
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'imageUrl': imageUrl, // <-- add this
      'timestamp': timestamp.millisecondsSinceEpoch,
      'readBy': readBy,
      'replyToMessageId': replyToMessageId,
      'isEdited': isEdited,
      'lovedBy': lovedBy,
      'deletedBy': deletedBy,
      'isStory': isStory,
      'storyId': storyId,
      'postData': postData,
      'productData': productData?.toMap(),
    };
  }
}
