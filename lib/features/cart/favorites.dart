import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/basetime.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/shop/cart_func.dart';
import 'package:ecommerece_app/features/shop/fav_fnc.dart';
import 'package:ecommerece_app/features/shop/item_details.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:intl/intl.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final formatCurrency = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) {
          return Center(child: Text('내 페이지 탭에서 회원가입 후 이용가능합니다.'));
        }
        return StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return Center(child: Text('User profile not found'));
            }
            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            final isSub = userData != null && (userData['isSub'] ?? false);
            return Padding(
              padding: EdgeInsets.only(left: 10, top: 12, bottom: 12),
              child: StreamBuilder(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('favorites')
                        .snapshots(),
                builder: (context, favoritesSnapshot) {
                  if (favoritesSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final favoritesDocs = favoritesSnapshot.data!.docs;

                  return ListView.separated(
                    separatorBuilder: (context, index) {
                      if (index == favoritesDocs.length - 1) {
                        return SizedBox.shrink();
                      }
                      return Divider();
                    },
                    itemCount: favoritesDocs.length,
                    itemBuilder: (ctx, index) {
                      final favoriteData = favoritesDocs[index].data();
                      final productId = favoriteData['product_id'];

                      return FutureBuilder<DocumentSnapshot>(
                        future:
                            FirebaseFirestore.instance
                                .collection('products')
                                .doc(productId)
                                .get(),
                        builder: (context, productSnapshot) {
                          if (!productSnapshot.hasData) {
                            return ListTile(title: Text('로딩 중...'));
                          }
                          final productData =
                              productSnapshot.data!.data()
                                  as Map<String, dynamic>;
                          Product p = Product.fromMap(productData);
                          return InkWell(
                            onTap: () async {
                              String arrivalTime = await getArrivalDay(
                                p.meridiem,
                                p.baselineTime,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ItemDetails(
                                        product: p,
                                        arrivalDay: arrivalTime,
                                        isSub: isSub,
                                      ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 1),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      p.imgUrl ?? '',
                                      width: 106,
                                      height: 110,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.sellerName,
                                          style: TextStyles.abeezee14px400wP600,
                                        ),

                                        Text(
                                          p.productName,
                                          style:
                                              TextStyles.abeezee16px400wPblack,
                                          maxLines: 2,
                                          overflow: TextOverflow.visible,
                                        ),
                                        Text(
                                          isSub
                                              ? '${formatCurrency.format(p.price)} 원'
                                              : '${formatCurrency.format(p.price / 0.9)} 원',
                                          style:
                                              TextStyles.abeezee16px400wPblack,
                                        ),

                                        Text(
                                          '${p.arrivalDate ?? ''} ',
                                          style: TextStyles.abeezee14px400wP600,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      await removeProductFromFavorites(
                                        userId:
                                            FirebaseAuth
                                                .instance
                                                .currentUser!
                                                .uid,
                                        productId: p.product_id,
                                      );
                                    },
                                    icon: Icon(Icons.close, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
// Function to remove a product from favorites
//   Future<void> removeProductFromFavorites({
//     required String userId,
//     required String productId,
//   }) async {
//     final favoritesRef = FirebaseFirestore.instance
//         .collection('users')
//         .doc(userId)
//         .collection('favorites');

//     // Query for the product that matches the productId
//     final querySnapshot =
//         await favoritesRef.where('product_id', isEqualTo: productId).get();

//     // Check if the product exists in favorites
//     if (querySnapshot.docs.isNotEmpty) {
//       // Loop through all documents found (should be only one)
//       for (var doc in querySnapshot.docs) {
//         // Delete the document
//         await doc.reference.delete();
//       }
//     } else {
//       print("Product not found in favorites.");
//     }
//   }
// }
