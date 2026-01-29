import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/basetime.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/features/cart/services/cart_service.dart';
import 'package:ecommerece_app/features/cart/services/favorites_service.dart';
import 'package:ecommerece_app/features/shop/item_details.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class ShoppingCart extends StatefulWidget {
  const ShoppingCart({super.key});

  @override
  State<ShoppingCart> createState() => _ShoppingCartState();
}

class _ShoppingCartState extends State<ShoppingCart> {
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
        return StreamBuilder(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
          builder: (context, userSnapshot) {
            final isSub = userSnapshot.data?.get('isSub') ?? false;

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
                                if (productSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return ListTile(title: Text('로딩 중...'));
                                }
                                if (!productSnapshot.hasData ||
                                    !productSnapshot.data!.exists) {
                                  // delete the cart item if product is gone
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) async {
                                    await deleteCartItem(cartDocs[index].id);
                                  });
                                  return SizedBox.shrink(); // don't render anything
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
                                          FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.uid ??
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                productData['sellerName'],
                                                style:
                                                    TextStyles
                                                        .abeezee14px400wP600,
                                              ),

                                              Text(
                                                productData['productName'],
                                                style:
                                                    TextStyles
                                                        .abeezee16px400wPblack,
                                                maxLines: 2,
                                                overflow: TextOverflow.visible,
                                              ),

                                              StreamBuilder<int>(
                                                stream: getProductQuantityStream(
                                                  cartData['product_id'],
                                                  cartData['pricePointIndex'],
                                                ),
                                                builder: (context, snapshot) {
                                                  final quan =
                                                      snapshot.data ?? 0;
                                                  return Text(
                                                    '수량 : ${quan.toString()}  ',
                                                    style:
                                                        TextStyles
                                                            .abeezee16px400wPblack,
                                                  );
                                                },
                                              ),

                                              /*                                    Text(
                                                '수량 : ${cartData['quantity'].toString()}  ',
                                                style:
                                                    TextStyles.abeezee14px400wP600,
                                              ), */
                                              StreamBuilder<double>(
                                                stream: getProductPriceStream(
                                                  cartData['product_id'],
                                                  cartData['pricePointIndex'],
                                                  isSub,
                                                ),
                                                builder: (context, snapshot) {
                                                  final price =
                                                      snapshot.data ?? 0.0;
                                                  return Text(
                                                    '${formatCurrency.format(price)} 원',
                                                    style:
                                                        TextStyles
                                                            .abeezee16px400wPblack,
                                                  );
                                                },
                                              ),

                                              /*                                           Text(
                                                '${formatCurrency.format(cartData['price'] ?? 0)} 원',
                                                style:
                                                    TextStyles
                                                        .abeezee16px400wPblack,
                                              ), */
                                            ],
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          await deleteCartItem(
                                            cartDocs[index].id,
                                          );
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
                    if (!cartSnapshot.hasData ||
                        cartSnapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return StreamBuilder<int>(
                      stream: calculateCartTotal(
                        cartSnapshot.data!.docs,
                        isSub,
                      ),
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
                                  onPressed: () async {
                                    // Extra stock check before proceeding
                                    final cartDocs = cartSnapshot.data!.docs;
                                    bool hasInsufficientStock = false;
                                    String insufficientProductName = '';
                                    int remainingQuantity = 0;
                                    for (final cartDoc in cartDocs) {
                                      final cartData =
                                          cartDoc.data()
                                              as Map<String, dynamic>;
                                      final productId = cartData['product_id'];
                                      int quantity = 0;
                                      final productStream =
                                          await FirebaseFirestore.instance
                                              .collection('products')
                                              .doc(productId)
                                              .get();
                                      final productData = productStream.data();
                                      if (productData != null) {
                                        final prod = Product.fromMap(
                                          productData,
                                        );
                                        quantity =
                                            prod
                                                .pricePoints[cartData['pricePointIndex']]
                                                .quantity;
                                      }

                                      final productRef = FirebaseFirestore
                                          .instance
                                          .collection('products')
                                          .doc(productId);
                                      final productSnapshot =
                                          await productRef.get();
                                      final currentStock =
                                          productSnapshot.data()?['stock'] ?? 0;
                                      if (quantity > currentStock) {
                                        hasInsufficientStock = true;
                                        insufficientProductName =
                                            cartData['productName'] ?? '';
                                        remainingQuantity = currentStock;
                                        break;
                                      }
                                    }
                                    if (hasInsufficientStock) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '(${insufficientProductName})의 남은 수량은 (${remainingQuantity})개 입니다.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    context.go(Routes.placeOrderScreen);
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xFF121212,
                                    ), // Background color
                                    foregroundColor: Colors.white, // Text color
                                    minimumSize: Size(
                                      70,
                                      40,
                                    ), // Exact dimensions
                                    padding:
                                        EdgeInsets
                                            .zero, // Remove default padding
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
      },
    );
  }
}
