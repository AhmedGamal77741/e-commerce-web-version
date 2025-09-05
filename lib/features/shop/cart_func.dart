import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> addProductAsNewEntryToCart({
  required String userId,
  required String productId,
  required int quantity,
  required String deliveryManagerId,
  required int price,
  required String productName,
}) async {
  final cartRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('cart');

  await cartRef.add({
    'cart_id': cartRef.doc().id, // optional if you want to use the doc ID
    'product_id': productId,
    'quantity': quantity,
    'price': price,
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
