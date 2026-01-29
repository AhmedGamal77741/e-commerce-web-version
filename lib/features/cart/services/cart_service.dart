import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

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

Future<void> refreshCartPrices(String uid) async {
  final userSnapshot =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final isSubed = userSnapshot.data()!['isSub'];
  final cartSnapshot =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cart')
          .get();
  for (final cartDoc in cartSnapshot.docs) {
    final cartData = cartDoc.data();
    final productId = cartData['product_id'] as String?;
    final pricePointIndex =
        cartData['pricePointIndex'] is int
            ? cartData['pricePointIndex'] as int
            : int.tryParse('${cartData['pricePointIndex']}') ?? 0;
    if (productId == null) continue;
    final productRef = FirebaseFirestore.instance
        .collection('products')
        .doc(productId);
    final productSnap = await productRef.get();
    if (!productSnap.exists) continue;
    final prodData = productSnap.data()!;
    final prod = Product.fromMap(prodData);
    num computedPrice;
    try {
      final pp = prod.pricePoints[pricePointIndex];
      if (isSubed) {
        computedPrice = pp.price;
      } else {
        computedPrice = (pp.price / 0.8).round();
      }
    } catch (e) {
      final fallback = prodData['price'] ?? cartData['price'] ?? 0;
      computedPrice = fallback is num ? fallback : num.parse('$fallback');
    }
    final intPrice =
        computedPrice is double ? computedPrice.round() : computedPrice.toInt();
    await cartDoc.reference.update({'price': intPrice});
  }
}

// Function to calculate total cart price - now returns Stream to listen to price updates
Stream<int> calculateCartTotal(
  List<QueryDocumentSnapshot> cartDocs,
  bool isSub,
) {
  if (cartDocs.isEmpty) return Stream.value(0);

  List<String> productIds = [];

  // Collect unique product IDs
  for (final cartDoc in cartDocs) {
    final cartData = cartDoc.data() as Map<String, dynamic>;
    final productId = cartData['product_id'] as String?;
    if (productId != null) productIds.add(productId);
  }

  if (productIds.isEmpty) return Stream.value(0);

  // Create streams for each product and combine them
  final productStreams = <Stream<Map<String, dynamic>>>[];

  for (final productId in productIds) {
    productStreams.add(
      FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .snapshots()
          .map((doc) {
            if (!doc.exists) return {};
            return doc.data() ?? {};
          }),
    );
  }

  // Combine all streams and calculate total whenever any product changes
  return Rx.combineLatestList(productStreams).map((productDataList) {
    int total = 0;

    for (final cartDoc in cartDocs) {
      final cartData = cartDoc.data() as Map<String, dynamic>;
      final productId = cartData['product_id'] as String?;
      final pricePointIndex = (cartData['pricePointIndex'] as int?) ?? 0;

      if (productId != null) {
        final productIndex = productIds.indexOf(productId);
        if (productIndex >= 0 && productIndex < productDataList.length) {
          final prodData = productDataList[productIndex];
          if (prodData.isNotEmpty) {
            final prod = Product.fromMap(prodData);
            if (pricePointIndex < prod.pricePoints.length) {
              final pricePoint = prod.pricePoints[pricePointIndex];
              double price = pricePoint.price.toDouble();
              // Apply discount if user is not subscribed
              if (!isSub) {
                price = price / 0.8;
              }
              total += price.round();
            }
          }
        }
      }
    }

    return total;
  });
}

Stream<int> getProductQuantityStream(String? productId, int index) {
  if (productId == null) {
    return Stream.value(0);
  }

  return FirebaseFirestore.instance
      .collection('products')
      .doc(productId)
      .snapshots()
      .map((doc) {
        final data = doc.data();
        if (data == null) return 0;
        final prod = Product.fromMap(data);
        return prod.pricePoints[index].quantity;
      });
}

Stream<double> getProductPriceStream(String? productId, int index, bool isSub) {
  if (productId == null) {
    return Stream.value(0.0);
  }

  return FirebaseFirestore.instance
      .collection('products')
      .doc(productId)
      .snapshots()
      .map((doc) {
        final data = doc.data();
        if (data == null) return 0.0;
        final prod = Product.fromMap(data);
        double price = (prod.pricePoints[index].price as num).toDouble();
        // Apply discount if user is not subscribed
        if (!isSub) {
          price = price / 0.8;
        }
        return price;
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
