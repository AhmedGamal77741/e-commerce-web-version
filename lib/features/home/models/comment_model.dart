import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/models/product_model.dart';

class Comment {
  final String id;
  final String userId;
  final String text;
  final dynamic createdAt;
  final String? imageUrl;
  final int likes;
  final String? userImage;
  final String? userName;
  final List<String> likedBy;
  final Map<String, dynamic>? postData;
  final Product? productData;
  Comment({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.imageUrl,
    this.likes = 0,
    this.userImage,
    this.userName,
    this.likedBy = const [],
    this.postData,
    this.productData,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      userId: data['userId'] ?? '',
      text: data['text'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      likes: data['likes'] ?? 0,
      userImage: data['userImage'],
      imageUrl: data['imageUrl'] ?? '',
      userName: data['userName'],
      likedBy: List<String>.from(data['likedBy'] ?? []),
      postData:
          data['postData'] != null
              ? Map<String, dynamic>.from(data['postData'])
              : null,
      productData:
          data['productData'] != null
              ? Product.fromMap(Map<String, dynamic>.from(data['productData']))
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'text': text,
      'createdAt': createdAt,
      'imageUrl': imageUrl,
      'likes': likes,
      'userImage': userImage,
      'userName': userName,
      'likedBy': likedBy,
      'postData': postData,
      'productData': productData?.toMap(),
    };
  }
}
