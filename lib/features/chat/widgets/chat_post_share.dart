import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatPostShareWidget extends StatelessWidget {
  final String imageUrl;
  final String postTitle;
  final String authorName;
  final VoidCallback onTap;
  final String type;

  const ChatPostShareWidget({
    super.key,
    required this.imageUrl,
    required this.postTitle,
    required this.authorName,
    required this.onTap,
    required this.type,
  });

  Future<String> fetchUserName(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return data['name'] ?? 'Unknown User';
      }
      return 'User not found';
    } catch (e) {
      print("Error fetching user name: $e");
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Post Preview Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 1, // Keeps it square like Instagram shares
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        color: Colors.grey[400],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                        ),
                      ),
                ),
              ),
            ),

            // 2. Post Content Info
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  type == 'post'
                      ? FutureBuilder<String>(
                        future: fetchUserName(authorName),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text("Loading...");
                          }

                          final name = snapshot.data ?? 'Unknown';

                          return Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          );
                        },
                      )
                      : Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                  const SizedBox(height: 4),
                  Text(
                    postTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
