import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> addProductAsNewEntryToCart({
  required String userId,
  required String productId,
  required String deliveryManagerId,
  required int pricePointIndex,
  required String productName,
}) async {
  final cartRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('cart');

  await cartRef.add({
    'cart_id': cartRef.doc().id, // optional if you want to use the doc ID
    'product_id': productId,
    'pricePointIndex': pricePointIndex,
    'added_at': FieldValue.serverTimestamp(),
    'deliveryManagerId': deliveryManagerId,
    'productName': productName,
  });
}

Future<bool> isUserSubscribed() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) return false; // Not logged in

  final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

  final data = userDoc.data();

  if (data == null || data['issub'] == null) return false;

  return data['issub'] == true;
}

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
