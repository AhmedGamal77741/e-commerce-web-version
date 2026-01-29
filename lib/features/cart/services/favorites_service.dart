import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/models/product_model.dart';

Future<void> addProductToFavorites({
  required String userId,
  required String productId,
}) async {
  final firestore = FirebaseFirestore.instance;

  // 1. Reference to the user's favorites subcollection
  final favoritesRef = firestore
      .collection('users')
      .doc(userId)
      .collection('favorites');

  // 2. Reference to the product document
  final productRef = firestore.collection('products').doc(productId);

  // 3. Add product to user's favorites
  final newDocRef = favoritesRef.doc();
  await newDocRef.set({'favorite_id': newDocRef.id, 'product_id': productId});

  // 4. Add userId to favBy array in the product document
  await productRef.update({
    'favBy': FieldValue.arrayUnion([userId]),
  });
}

bool isFavoritedByUser({required Product p, required String userId}) {
  return p.favBy.contains(userId);
}

Future<void> removeProductFromFavorites({
  required String userId,
  required String productId,
}) async {
  final firestore = FirebaseFirestore.instance;

  // 1. Reference to the user's favorites subcollection
  final favoritesRef = firestore
      .collection('users')
      .doc(userId)
      .collection('favorites');

  // 2. Reference to the product document
  final productRef = firestore.collection('products').doc(productId);

  // 3. Query for the product that matches the productId
  final querySnapshot =
      await favoritesRef.where('product_id', isEqualTo: productId).get();

  if (querySnapshot.docs.isNotEmpty) {
    for (var doc in querySnapshot.docs) {
      // Delete the document from user's favorites
      await doc.reference.delete();
    }

    // 4. Remove userId from the favBy array in the product document
    await productRef.update({
      'favBy': FieldValue.arrayRemove([userId]),
    });
  } else {
    print("Product not found in favorites.");
  }
}
