import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/basetime.dart';
import 'package:ecommerece_app/core/helpers/extensions.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/black_text_button.dart';
import 'package:ecommerece_app/features/review/ui/exchange_or_refund.dart';
import 'package:ecommerece_app/features/review/ui/track_order.dart';
import 'package:ecommerece_app/features/review/ui/widgets/text_and_buttons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

class OrderHistory extends StatefulWidget {
  const OrderHistory({super.key});

  @override
  State<OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends State<OrderHistory> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text('주문을 보려면 로그인해야 합니다.'));
    }

    final orderStream =
        FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user.uid)
            .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: orderStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('주문이 없습니다'));
        }

        final orders = snapshot.data!.docs;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: ListView.separated(
            itemCount: orders.length,
            separatorBuilder:
                (context, index) => Divider(color: ColorsManager.primary300),
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;

              return FutureBuilder<Map<String, dynamic>>(
                future: fetchProductDetails(data['productId']),
                builder: (context, productSnapshot) {
                  if (productSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!productSnapshot.hasData ||
                      productSnapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No products found for this order.'),
                    );
                  }

                  // Get the product data
                  final product = productSnapshot.data!;
                  print(isDispatched(product, data['orderDate']));
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          product['imgUrl'],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      horizontalSpace(10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextAndButtons(
                              sellerName: product['sellerName'],
                              productName: product['productName'],
                              qunatity: data['quantity'].toString(),
                              orderPrice: data['totalPrice'].toString(),
                              baselineTime: product['baselineTime'],
                              meridiem: product['meridiem'],
                            ),
                            Row(
                              children: [
                                BlackTextButton(
                                  txt: '배송조회',
                                  style: TextStyles.abeezee14px400wW,
                                  func: () async {
                                    String arrivalDate = await getArrivalDay2(
                                      product['meridiem'],
                                      product['baselineTime'],
                                    );
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => TrackOrder(
                                              order: data,
                                              arrivalDate: arrivalDate,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                                horizontalSpace(5),
                                isDispatched(product, data['orderDate'])
                                    ? (data['isRequested']
                                        ? BlackTextButton(
                                          txt: '교환 · 반품 신청',
                                          style: TextStyles.abeezee14px400wW
                                              .copyWith(
                                                decoration:
                                                    TextDecoration.lineThrough,
                                                decorationColor: Colors.red,
                                                decorationThickness: 2,
                                              ),
                                          func: () {},
                                        )
                                        : BlackTextButton(
                                          txt: '교환 · 반품 신청',
                                          style: TextStyles.abeezee14px400wW,

                                          func: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) =>
                                                        ExchangeOrRefund(
                                                          userId: user.uid,
                                                          orderId:
                                                              data['orderId'],
                                                        ),
                                              ),
                                            );
                                          },
                                        ))
                                    : BlackTextButton(
                                      txt: '주문취소',
                                      style: TextStyles.abeezee14px400wW,
                                      func: () async {
                                        await deleteOrder(data);
                                      },
                                    ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // maybe show options for details
                        },
                        icon: Icon(
                          Icons.more_horiz,
                          color: ColorsManager.primary600,
                          size: 18,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
          ),
        );
      },
    );
  }
}

Future<Map<String, dynamic>> fetchProductDetails(String productId) async {
  DocumentSnapshot productSnapshot =
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

  if (productSnapshot.exists) {
    Map<String, dynamic> productData =
        productSnapshot.data() as Map<String, dynamic>;

    return productData;
  }

  return {}; // Return an empty map instead of null
}

bool isDispatched(Map<String, dynamic> product, String orderDate) {
  DateTime now = DateTime.now();
  DateTime orderTime = DateTime.parse(orderDate);

  DateTime adjustedTime;
  DateTime nextDay;

  int adjustedHour = product['baselineTime'];

  if (product['meridiem'].toLowerCase() == 'pm' &&
      product['baselineTime'] < 12) {
    adjustedHour += 12; // Convert PM to 24-hour format
  } else if (product['meridiem'].toLowerCase() == 'am' &&
      product['baselineTime'] == 12) {
    adjustedHour = 0; // Convert 12 AM to 0 hours (midnight)
  }
  adjustedTime = DateTime(
    orderTime.year,
    orderTime.month,
    orderTime.day,
    adjustedHour,
    orderTime.minute,
    orderTime.second,
    orderTime.millisecond,
    orderTime.microsecond,
  );
  nextDay = adjustedTime.add(Duration(days: 1));
  if (orderTime.isBefore(adjustedTime) && now.isAfter(adjustedTime)) {
    return true;
  } else if (orderTime.isAfter(adjustedTime) && now.isAfter(nextDay)) {
    return true;
  }

  return false;
}

Future<void> deleteOrder(Map<String, dynamic> order) async {
  try {
    final productId = order['productId'];
    final quantityOrdered = order['quantity'];

    final productRef = FirebaseFirestore.instance
        .collection('products')
        .doc(productId);

    await productRef.update({
      'stock': FieldValue.increment(quantityOrdered), // now it's positive
    });

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(order['orderId'])
        .delete();
  } catch (e) {
    print('Error deleting order: $e');
  }
}
