import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String userId;
  final String text;
  final List<String> imgUrls; // Multiple images
  final int likes;
  final int comments;
  final Timestamp createdAt;
  final List<String> likedBy;
  final List<String> notInterestedBy;

  PostModel({
    required this.postId,
    required this.userId,
    required this.text,
    required this.imgUrls,
    required this.likes,
    required this.comments,
    required this.createdAt,
    required this.likedBy,
    required this.notInterestedBy,
  });

  /// Create PostModel from Firestore document
  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      postId: data['postId'] ?? doc.id,
      userId: data['userId'] ?? '',
      text: data['text'] ?? '',
      imgUrls: _parseImgUrls(data),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      likedBy: List<String>.from(data['likedBy'] ?? []),
      notInterestedBy: List<String>.from(data['notInterestedBy'] ?? []),
    );
  }

  /// Parse imgUrls from both old format (single imgUrl) and new format (imgUrls list)
  static List<String> _parseImgUrls(Map<String, dynamic> data) {
    // If imgUrls list exists, use it
    if (data['imgUrls'] != null && (data['imgUrls'] as List).isNotEmpty) {
      return List<String>.from(
        (data['imgUrls'] as List).map((url) => url.toString()),
      );
    }
    // Fallback to single imgUrl for backward compatibility
    if (data['imgUrl'] != null && (data['imgUrl'] as String).isNotEmpty) {
      return [data['imgUrl'] as String];
    }
    return [];
  }

  /// Convert to Firestore document format
  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'text': text,
      'imgUrls': imgUrls,
      'likes': likes,
      'comments': comments,
      'createdAt': createdAt,
      'likedBy': likedBy,
      'notInterestedBy': notInterestedBy,
    };
  }

  /// Create a copy with modified fields
  PostModel copyWith({
    String? postId,
    String? userId,
    String? text,
    List<String>? imgUrls,
    int? likes,
    int? comments,
    Timestamp? createdAt,
    List<String>? likedBy,
    List<String>? notInterestedBy,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      imgUrls: imgUrls ?? this.imgUrls,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      likedBy: likedBy ?? this.likedBy,
      notInterestedBy: notInterestedBy ?? this.notInterestedBy,
    );
  }
}
