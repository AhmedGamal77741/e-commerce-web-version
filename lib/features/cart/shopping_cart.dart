import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/basetime.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/cart/delete_func.dart';
import 'package:ecommerece_app/features/shop/cart_func.dart';
import 'package:ecommerece_app/features/shop/fav_fnc.dart';
import 'package:ecommerece_app/features/shop/item_details.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ShoppingCart extends StatefulWidget {
  const ShoppingCart({super.key});

  @override
  State<ShoppingCart> createState() => _ShoppingCartState();
}

class _ShoppingCartState extends State<ShoppingCart> {
  final formatCurrency = NumberFormat('#,###');
  // Function to calculate total cart price
  Future<int> calculateCartTotal(List<QueryDocumentSnapshot> cartDocs) async {
    int total = 0;

    for (final cartDoc in cartDocs) {
      final cartData = cartDoc.data() as Map<String, dynamic>;
      final price = cartData['price'];

      try {
        total += (price as int);
      } catch (e) {}
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) {
          return Center(child: Text('내 페이지 탭에서 회원가입 후 이용가능합니다.'));
        }
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: StreamBuilder(
                  stream:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('cart')
                          .snapshots(),
                  builder: (context, cartSnapshot) {
                    if (cartSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final cartDocs = cartSnapshot.data!.docs;

                    return ListView.separated(
                      separatorBuilder: (context, index) {
                        if (index == cartDocs.length - 1) {
                          return SizedBox.shrink();
                        }
                        return Divider();
                      },
                      itemCount: cartDocs.length,
                      itemBuilder: (ctx, index) {
                        final cartData = cartDocs[index].data();
                        final productId = cartData['product_id'];

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
                                bool isSub = await isUserSubscribed();
                                bool liked = isFavoritedByUser(
                                  p: p,
                                  userId:
                                      FirebaseAuth.instance.currentUser?.uid ??
                                      '',
                                );
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

                                // context.pushNamed(
                                //   Routes.itemDetailsScreen,
                                //   arguments: {
                                // 'imgUrl': data['imgUrl'],
                                // 'sellerName': data['sellerName	'],
                                // 'price': data['price	'],
                                // 'product_id': data['product_id'],
                                // 'freeShipping': data['freeShipping	'],
                                // 'meridiem': data['meridiem'],
                                // 'baselinehour': data['baselinehour	'],
                                // 'productName': data['productName	'],
                                //   },
                                // );
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      productData['imgUrl'],
                                      width: 106,
                                      height: 106,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(left: 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          productData['sellerName'],
                                          style: TextStyles.abeezee14px400wP600,
                                        ),

                                        Text(
                                          productData['productName'],
                                          style:
                                              TextStyles.abeezee16px400wPblack,
                                        ),

                                        Row(
                                          children: [
                                            Text(
                                              '수량 : ${cartData['quantity'].toString()}  ',
                                              style:
                                                  TextStyles
                                                      .abeezee14px400wP600,
                                            ),
                                            FutureBuilder<String>(
                                              future: getArrivalDay(
                                                productData['meridiem'],
                                                productData['baselineTime'],
                                              ),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return Text(
                                                    '로딩 중...',
                                                    style:
                                                        TextStyles
                                                            .abeezee14px400wP600,
                                                  );
                                                }
                                                if (snapshot.hasError) {
                                                  return Text(
                                                    '오류 발생',
                                                    style:
                                                        TextStyles
                                                            .abeezee14px400wP600,
                                                  );
                                                }

                                                return Text(
                                                  '${snapshot.data} 도착예정',
                                                  style:
                                                      TextStyles
                                                          .abeezee14px400wP600,
                                                );
                                              },
                                            ),
                                          ],
                                        ),

                                        Text(
                                          '${formatCurrency.format(cartData['price'] ?? 0)} 원',
                                          style:
                                              TextStyles.abeezee16px400wPblack,
                                        ),
                                      ],
                                    ),
                                  ),

                                  Spacer(),
                                  IconButton(
                                    onPressed: () async {
                                      await deleteCartItem(cartDocs[index].id);
                                    },
                                    icon: Icon(
                                      Icons.close,
                                      color: ColorsManager.primary600,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                      .collection('cart')
                      .snapshots(),
              builder: (context, cartSnapshot) {
                if (!cartSnapshot.hasData || cartSnapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }
                return FutureBuilder<int>(
                  future: calculateCartTotal(cartSnapshot.data!.docs),
                  builder: (context, totalSnapshot) {
                    return Container(
                      width: 428,
                      height: 50,
                      decoration: BoxDecoration(color: Colors.white),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 40, right: 70),
                            child: Text(
                              '총 금액: ',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.w400,
                                height: 1.40,
                              ),
                            ),
                          ),
                          Spacer(),
                          totalSnapshot.hasData
                              ? Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: Text(
                                  '${formatCurrency.format(totalSnapshot.data ?? 0)} 원',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontFamily: 'NotoSans',
                                    fontWeight: FontWeight.w400,
                                    height: 1.40,
                                  ),
                                ),
                              )
                              : CircularProgressIndicator(),
                          Padding(
                            padding: EdgeInsets.only(right: 20),
                            child: TextButton(
                              onPressed: () {
                                context.go(Routes.placeOrderScreen);
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF121212,
                                ), // Background color
                                foregroundColor: Colors.white, // Text color
                                minimumSize: Size(70, 40), // Exact dimensions
                                padding:
                                    EdgeInsets.zero, // Remove default padding
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    width: 1,
                                    color: const Color(0xFF121212),
                                  ), // Border
                                  borderRadius: BorderRadius.circular(
                                    11,
                                  ), // Corner radius
                                ),
                                elevation: 0, // Remove shadow
                              ),
                              child: Text(
                                '구매',
                                style: TextStyle(
                                  color: const Color(0xFFF5F5F5),
                                  fontSize: 16,
                                  fontFamily: 'NotoSans',
                                  fontWeight: FontWeight.w400,
                                  height: 1.40,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}
