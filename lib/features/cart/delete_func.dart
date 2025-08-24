import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> deleteCartItem(String cartId) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId != null && cartId.isNotEmpty) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .doc(cartId)
        .delete();
  }
}

Future<void> deleteFavItem(String favId) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId != null && favId.isNotEmpty) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(favId)
        .delete();
  }
}
