import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String storyId;
  final String authorId;
  final String authorName;
  final String authorImage;
  final String imageUrl;
  final DateTime createdAt;
  final int expiresAt;
  final List<String> viewers;

  StoryModel({
    required this.storyId,
    required this.authorId,
    required this.authorName,
    required this.authorImage,
    required this.imageUrl,
    required this.createdAt,
    required this.expiresAt,
    required this.viewers,
  });

  factory StoryModel.fromFirestore(Map<String, dynamic> json) {
    return StoryModel(
      storyId: json['storyId'] ?? '',
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? 'Unknown',
      authorImage: json['authorImage'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      expiresAt: json['expiresAt'] ?? 0,
      viewers: List<String>.from(json['viewers'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'storyId': storyId,
    'authorId': authorId,
    'authorName': authorName,
    'authorImage': authorImage,
    'imageUrl': imageUrl,
    'createdAt': FieldValue.serverTimestamp(),
    'expiresAt': expiresAt,
    'viewers': viewers,
  };
}

class UserStoryGroup {
  final String authorId;
  final String authorName;
  final String authorImage;
  final List<StoryModel> stories;

  UserStoryGroup({
    required this.authorId,
    required this.authorName,
    required this.authorImage,
    required this.stories,
  });
}
