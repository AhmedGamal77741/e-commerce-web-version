import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/underline_text_filed.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:ecommerece_app/features/cart/models/address.dart';
import 'package:ecommerece_app/features/cart/sub_screens/address_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class PlaceOrder extends StatefulWidget {
  const PlaceOrder({super.key});

  @override
  State<PlaceOrder> createState() => _PlaceOrderState();
}

class _PlaceOrderState extends State<PlaceOrder> {
  final deliveryAddressController = TextEditingController();
  final deliveryInstructionsController = TextEditingController();
  final cashReceiptController = TextEditingController();
  final phoneController = TextEditingController();
  int selectedOption = 1;
  final _formKey = GlobalKey<FormState>();
  Address address = Address(
    name: '',
    phone: '',
    address: '',
    detailAddress: '',
    isDefault: false,
    addressMap: {},
  );
  final List<String> deliveryRequests = [
    '문앞', // "At the door"
    '직접 받고 부재 시 문앞', // "Security office"
    '택배함', // "Parcel box"
    '경비실', // "Receive directly"
    '직접입력', // "Other"
  ];
  String selectedRequest = '문앞';
  String? manualRequest;
  Future<void> _selectAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddressListScreen()),
    );

    if (result != null) {
      deliveryAddressController.text = result.address;
      setState(() {
        address = result;
      });
    }
  }

  final formatCurrency = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    final docRef = FirebaseFirestore.instance.collection('orders').doc();
    final orderId = docRef.id;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios),
          ),
          title: Text("주문 결제", style: TextStyle(fontFamily: 'NotoSans')),
        ),
        body: Padding(
          padding: EdgeInsets.only(left: 15, top: 30, right: 15),
          child: ListView(
            children: [
              Container(
                padding: EdgeInsets.only(
                  left: 15,
                  top: 15,
                  bottom: 15,
                  right: 15,
                ),
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 0.27,
                      color: const Color(0xFF747474),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 5,
                    children: [
                      Container(
                        padding: EdgeInsets.only(bottom: 5),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: ColorsManager.primary400,
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child:
                                  address.name.isEmpty
                                      ? FutureBuilder(
                                        future:
                                            FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(
                                                  FirebaseAuth
                                                      .instance
                                                      .currentUser!
                                                      .uid,
                                                )
                                                .get(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }

                                          if (snapshot.hasError) {
                                            return Center(
                                              child: Text(
                                                'Error loading user address: ${snapshot.error}',
                                              ),
                                            );
                                          }

                                          if (!snapshot.hasData ||
                                              !snapshot.data!.exists) {
                                            return Center(
                                              child: Text(
                                                'User data not found',
                                              ),
                                            );
                                          }

                                          final userData =
                                              snapshot.data?.data();
                                          if (userData == null ||
                                              userData['defaultAddressId'] ==
                                                  null ||
                                              userData['defaultAddressId'] ==
                                                  '') {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '배송지 미설정',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 15,
                                                    fontFamily: 'NotoSans',
                                                    fontWeight: FontWeight.w400,
                                                    height: 1.40,
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  '배송지를 설정해주세요',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Color(0xFF9E9E9E),
                                                    fontFamily: 'NotoSans',
                                                  ),
                                                ),
                                              ],
                                            );
                                          }
                                          return FutureBuilder(
                                            future:
                                                FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(
                                                      FirebaseAuth
                                                          .instance
                                                          .currentUser!
                                                          .uid,
                                                    )
                                                    .collection('addresses')
                                                    .doc(
                                                      userData!['defaultAddressId'],
                                                    )
                                                    .get(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );
                                              }

                                              if (snapshot.hasError) {
                                                return Center(
                                                  child: Text(
                                                    'Error loading user address: ${snapshot.error}',
                                                  ),
                                                );
                                              }

                                              if (!snapshot.hasData ||
                                                  !snapshot.data!.exists) {
                                                return Center(
                                                  child: Text(
                                                    'User data not found',
                                                  ),
                                                );
                                              }

                                              final addressData =
                                                  snapshot.data?.data();
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '베송지 | ${addressData!['name']}',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 15,
                                                      fontFamily: 'NotoSans',
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      height: 1.40,
                                                    ),
                                                  ),
                                                  SizedBox(height: 8),

                                                  Text(
                                                    addressData['phone'],
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color: Color(0xFF9E9E9E),
                                                      fontFamily: 'NotoSans',
                                                    ),
                                                  ),
                                                  Text(
                                                    addressData['address'],
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color: Color(0xFF9E9E9E),
                                                      fontFamily: 'NotoSans',
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      )
                                      : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '베송지 | ${address.name}',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 15,
                                              fontFamily: 'NotoSans',
                                              fontWeight: FontWeight.w400,
                                              height: 1.40,
                                            ),
                                          ),
                                          SizedBox(height: 8),

                                          Text(
                                            address.phone,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF9E9E9E),
                                              fontFamily: 'NotoSans',
                                            ),
                                          ),
                                          Text(
                                            address.detailAddress,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF9E9E9E),
                                              fontFamily: 'NotoSans',
                                            ),
                                          ),
                                        ],
                                      ),
                            ),
                            TextButton(
                              onPressed: _selectAddress,

                              style: TextButton.styleFrom(
                                fixedSize: Size(48, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                              ),
                              child: Text(
                                '변경',
                                style: TextStyle(
                                  color: ColorsManager.primaryblack,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 15),
                      Text(
                        '배송 요청사항',
                        style: TextStyle(
                          color: const Color(0xFF121212),
                          fontSize: 16,
                          fontFamily: 'NotoSans',
                          fontWeight: FontWeight.w400,
                          height: 1.40,
                        ),
                      ),
                      StatefulBuilder(
                        builder: (context, setStateDropdown) {
                          return DropdownButtonFormField<String>(
                            value: selectedRequest,
                            dropdownColor: Colors.white,
                            items:
                                deliveryRequests
                                    .map(
                                      (request) => DropdownMenuItem(
                                        value: request,
                                        child: Text(
                                          request,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                            fontFamily: 'NotoSans',
                                            fontWeight: FontWeight.w400,
                                            height: 1.40,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            decoration: const InputDecoration(
                              border: UnderlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (value) {
                              setStateDropdown(() {
                                selectedRequest = value!;
                                // clear manual text when switching away
                                if (selectedRequest != '직접입력')
                                  manualRequest = null;
                              });
                              // also notify parent state if needed:
                              setState(() {});
                            },
                            icon: Icon(Icons.keyboard_arrow_down),
                          );
                        },
                      ),

                      // only show when “직접입력” is selected:
                      if (selectedRequest == '직접입력') ...[
                        SizedBox(height: 12),
                        TextFormField(
                          initialValue: manualRequest,
                          onChanged:
                              (text) => setState(() => manualRequest = text),
                          decoration: InputDecoration(
                            labelText: '직접 입력',
                            hintText: '배송 요청을 입력하세요',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 15),
                      Text(
                        '간편 계좌 결제',
                        style: TextStyle(
                          color: const Color(0xFF121212),
                          fontSize: 16,
                          fontFamily: 'NotoSans',
                          fontWeight: FontWeight.w400,
                          height: 1.40,
                        ),
                      ),
                      // Container(
                      //   decoration: BoxDecoration(
                      //     border: Border(
                      //       bottom: BorderSide(
                      //         color: ColorsManager.primary400,
                      //         width: 1.0,
                      //       ),
                      //     ),
                      //   ),
                      //   child: Row(
                      //     crossAxisAlignment: CrossAxisAlignment.start,
                      //     children: [
                      //       Flexible(
                      //         child: TextFormField(
                      //           controller: cashReceiptController,
                      //           enabled: false,
                      //           decoration: InputDecoration(
                      //             hintText: '국민은행 / 0000000000000',
                      //             hintStyle: TextStyle(
                      //               fontSize: 15.sp,
                      //               color: ColorsManager.primary400,
                      //             ),
                      //             border: InputBorder.none,
                      //           ),
                      //           obscureText: false,
                      //           keyboardType: TextInputType.text,
                      //           // validator: (val) {
                      //           //   if (val!.isEmpty) {
                      //           //     return '이름을 입력하세요';
                      //           //   } else if (val.length > 30) {
                      //           //     return '이름이 너무 깁니다';
                      //           //   }
                      //           //   return null;
                      //           // },
                      //         ),
                      //       ),
                      //       StreamBuilder<DocumentSnapshot>(
                      //         stream: userDoc.snapshots(),
                      //         builder: (context, snapshot) {
                      //           if (snapshot.connectionState ==
                      //               ConnectionState.waiting) {
                      //             return SizedBox(
                      //               width: 48.w,
                      //               height: 30.h,
                      //               child: Center(
                      //                 child: CircularProgressIndicator(
                      //                   strokeWidth: 2,
                      //                 ),
                      //               ),
                      //             );
                      //           }
                      //           // error
                      //           if (snapshot.hasError ||
                      //               !snapshot.hasData ||
                      //               !snapshot.data!.exists) {
                      //             return Text('Error loading status');
                      //           }

                      //           // extract payerId
                      //           final data =
                      //               snapshot.data!.data()
                      //                   as Map<String, dynamic>;
                      //           final payerId = data['payerId'] as String?;

                      //           // compute isFirst
                      //           final isFirst =
                      //               payerId == null || payerId.isEmpty;
                      //           return TextButton(
                      //             onPressed: () async {
                      //               if (!_formKey.currentState!.validate()) {
                      //                 return;
                      //               }
                      //               var total = await calculateCartTotalPay();
                      //               isFirst
                      //                   ? _launchPaymentPage(
                      //                     total.toString(),
                      //                     uid,
                      //                     phoneController.toString().trim(),
                      //                     orderId,
                      //                   )
                      //                   : _launchRpaymentPage(
                      //                     total.toString(),
                      //                     uid,
                      //                     phoneController.toString().trim(),
                      //                     orderId,
                      //                     payerId,
                      //                   );
                      //             },

                      //             style: TextButton.styleFrom(
                      //               fixedSize: Size(48.w, 30.h),
                      //               tapTargetSize:
                      //                   MaterialTapTargetSize.shrinkWrap,
                      //               side: BorderSide(
                      //                 color: Colors.grey.shade300,
                      //                 width: 1.0,
                      //               ),
                      //               shape: RoundedRectangleBorder(
                      //                 borderRadius: BorderRadius.circular(4.0),
                      //               ),
                      //             ),
                      //             child: Text(
                      //               '변경',
                      //               style: TextStyle(
                      //                 color: ColorsManager.primaryblack,
                      //                 fontWeight: FontWeight.bold,
                      //                 fontSize: 13.sp,
                      //               ),
                      //             ),
                      //           );
                      //         },
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      StatefulBuilder(
                        builder: (context, setStateRadio) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Radio(
                                    value: 1,
                                    groupValue: selectedOption,
                                    onChanged: (value) {
                                      setStateRadio(() {
                                        selectedOption = value!;
                                        print("Button value: $value");
                                      });
                                    },
                                  ),
                                  Text(
                                    '현금 영수증',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontFamily: 'NotoSans',
                                      fontWeight: FontWeight.w400,
                                      color: ColorsManager.primaryblack,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Radio(
                                    value: 2,
                                    groupValue: selectedOption,
                                    onChanged: (value) {
                                      setStateRadio(() {
                                        selectedOption = value!;
                                        print("Button value: $value");
                                      });
                                    },
                                  ),
                                  Text(
                                    '세금 계산서',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontFamily: 'NotoSans',
                                      fontWeight: FontWeight.w400,
                                      color: ColorsManager.primaryblack,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                      UnderlineTextField(
                        controller: phoneController,
                        hintText: '전화번호 ',
                        obscureText: false,
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val!.isEmpty) {
                            return '이름을 입력하세요';
                          } else if (val.length > 30) {
                            return '이름이 너무 깁니다';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              verticalSpace(20),
              Container(
                padding: EdgeInsets.only(left: 15, top: 15, bottom: 15),
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 0.27,
                      color: const Color(0xFF747474),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('구매목록', style: TextStyles.abeezee16px400wPblack),
                    verticalSpace(10),
                    StreamBuilder(
                      stream:
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                              .collection('cart')
                              .snapshots(),
                      builder: (context6, cartSnapshot) {
                        if (cartSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        final cartDocs = cartSnapshot.data!.docs;

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          separatorBuilder: (context5, index) {
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
                              builder: (context4, productSnapshot) {
                                if (!productSnapshot.hasData) {
                                  return ListTile(title: Text('로딩 중...'));
                                }
                                final productData =
                                    productSnapshot.data!.data()
                                        as Map<String, dynamic>;

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 12,
                                  children: [
                                    Text(
                                      '${productData['productName']} / 수량 : ${cartData['quantity'].toString()}',
                                      style: TextStyle(
                                        color: const Color(0xFF747474),
                                        fontSize: 14,
                                        fontFamily: 'NotoSans',
                                        fontWeight: FontWeight.w400,
                                        height: 1.40,
                                      ),
                                    ),

                                    Text(
                                      '${formatCurrency.format(cartData['price'] ?? 0)} 원',
                                      style: TextStyle(
                                        color: const Color(0xFF747474),
                                        fontSize: 14,
                                        fontFamily: 'NotoSans',
                                        fontWeight: FontWeight.w600,
                                        height: 1.40,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              verticalSpace(20),
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                        .collection('cart')
                        .snapshots(),
                builder: (context3, cartSnapshot) {
                  if (!cartSnapshot.hasData ||
                      cartSnapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return FutureBuilder<int>(
                    future: calculateCartTotal(cartSnapshot.data!.docs),
                    builder: (context2, totalSnapshot) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                        spacing: 12,
                        children: [
                          verticalSpace(20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '총 결제 금액 ',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontFamily: 'NotoSans',
                                  fontWeight: FontWeight.w400,
                                  height: 1.40,
                                ),
                              ),
                              totalSnapshot.hasData
                                  ? Text(
                                    '${formatCurrency.format(totalSnapshot.data ?? 0)} 원',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 18,
                                      fontFamily: 'NotoSans',
                                      fontWeight: FontWeight.w400,
                                      height: 1.40,
                                    ),
                                  )
                                  : CircularProgressIndicator(),
                            ],
                          ),
                          verticalSpace(5),
                          WideTextButton(
                            txt: '주문',
                            func: () async {
                              if (!_formKey.currentState!.validate()) return;
                              String? payerId = await fetchPayerId(uid);
                              final isFirst =
                                  payerId == null || payerId.isEmpty;
                              isFirst
                                  ? _launchPaymentPage(
                                    totalSnapshot.data.toString(),
                                    uid,
                                    phoneController.toString().trim(),
                                    orderId,
                                  )
                                  : _launchRpaymentPage(
                                    totalSnapshot.data.toString(),
                                    uid,
                                    phoneController.toString().trim(),
                                    orderId,
                                    payerId,
                                  );

                              if (!await isPaymentCompleted(orderId, uid)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('결제 시작'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) return;

                              final cartSnapshot =
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('cart')
                                      .get();

                              final cartItems =
                                  cartSnapshot.docs
                                      .map((doc) => doc.data())
                                      .toList();

                              try {
                                // Step 1: Validate stock for all items
                                for (var item in cartItems) {
                                  final productId = item['product_id'];
                                  final quantityOrdered = item['quantity'];

                                  final productRef = FirebaseFirestore.instance
                                      .collection('products')
                                      .doc(productId);
                                  final productSnapshot =
                                      await productRef.get();

                                  if (!productSnapshot.exists) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Product with ID $productId no longer exists.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final currentStock =
                                      productSnapshot.data()?['stock'] ?? 0;

                                  if (currentStock < quantityOrdered) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Not enough stock for product ID $productId.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                }

                                // Step 2: Create an order document **for each product**
                                for (var item in cartItems) {
                                  final productId = item['product_id'];
                                  final quantityOrdered = item['quantity'];
                                  final price = item['price'];

                                  final orderData = {
                                    'orderId': orderId,
                                    'userId': user.uid,
                                    'deliveryAddress':
                                        deliveryAddressController.text.trim(),
                                    'deliveryInstructions':
                                        selectedRequest == '직접입력'
                                            ? manualRequest!.trim()
                                            : selectedRequest.trim(),
                                    'cashReceipt':
                                        cashReceiptController.text.trim(),
                                    'paymentMethod': 'naver pay',
                                    'orderDate':
                                        DateTime.now().toIso8601String(),
                                    'totalPrice': price,
                                    'productId': productId,
                                    'quantity': quantityOrdered,
                                    "courier": '',
                                    "trackingNumber": '',
                                    "trackingEvents": {},
                                    "orderStatus": "orderComplete",
                                    'isRequested': false,
                                    'deliveryManagerId':
                                        item['deliveryManagerId'],
                                    'carrierId': '',
                                    'isSent': false,
                                    'phoneNo':
                                        phoneController.toString().trim(),
                                  };

                                  await docRef.set(orderData);

                                  // Step 3: Update stock
                                  final productRef = FirebaseFirestore.instance
                                      .collection('products')
                                      .doc(productId);
                                  await productRef.update({
                                    'stock': FieldValue.increment(
                                      -quantityOrdered,
                                    ),
                                  });
                                }

                                // Step 4: Clear cart
                                for (var doc in cartSnapshot.docs) {
                                  await doc.reference.delete();
                                }

                                if (mounted) {
                                  context.go(Routes.orderCompleteScreen);
                                }
                              } catch (e) {
                                print('Failed to place order: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to place order. Please try again.',
                                    ),
                                  ),
                                );
                              }
                            },
                            color: Colors.black,
                            txtColor: Colors.white,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fetches all docs in users/{uid}/cart once and returns the sum of their `price` fields.
// Future<int> calculateCartTotalPay() async {
//   // 1. Ensure we have a logged-in user
//   final uid = FirebaseAuth.instance.currentUser?.uid;
//   if (uid == null) {
//     throw StateError('No user logged in');
//   }

//   // 2. Fetch the cart subcollection
//   final querySnap =
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(uid)
//           .collection('cart')
//           .get();

//   // 3. Sum all price fields
//   var total = 0;
//   for (final doc in querySnap.docs) {
//     final data = doc.data();
//     final price = data['price'];
//     if (price is num) {
//       total += price.toInt();
//     }
//   }

//   return total;
// }

Future<int> calculateCartTotal(List<QueryDocumentSnapshot> cartDocs) async {
  int total = 0;

  for (final cartDoc in cartDocs) {
    final cartData = cartDoc.data() as Map<String, dynamic>;
    final price = cartData['price'];

    try {
      total += price as int;
    } catch (e) {}
  }

  return total;
}

void _launchPaymentPage(
  String amount,
  String userId,
  String phoneNo,
  String orderId,
) async {
  final url = Uri.parse(
    'https://e-commerce-app-34fb2.web.app/p-payment.html?orderId=$orderId&amount=$amount&userId=$userId&phoneNo=$phoneNo',
  );

  if (await canLaunchUrl(url)) {
    await launchUrl(
      url,
      // mode: LaunchMode.externalApplication, // Forces external browser
    );
  } else {
    throw 'Could not launch $url';
  }
}

void _launchRpaymentPage(
  String amount,
  String userId,
  String phoneNo,
  String orderId,
  String payerId,
) async {
  final url = Uri.parse(
    'https://e-commerce-app-34fb2.web.app/r-p-payment.html?orderId=$orderId&amount=$amount&userId=$userId&phoneNo=$phoneNo&payerId=$payerId',
  );

  if (await canLaunchUrl(url)) {
    await launchUrl(
      url,
      // mode: LaunchMode.externalApplication, // Forces external browser
    );
  } else {
    throw 'Could not launch $url';
  }
}

Future<bool> isPaymentCompleted(String orderId, String uid) async {
  final querySnapshot =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('payments')
          .where('orderId', isEqualTo: orderId)
          .limit(1) // We only need to know if at least one exists
          .get();

  return querySnapshot.docs.isNotEmpty;
}

Future<String?> fetchPayerId(String uid) async {
  try {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      print("User document doesn't exist.");
      return null;
    }

    final data = snapshot.data();
    final payerId = data?['payerId'] as String?;
    return payerId;
  } catch (e) {
    print("Error fetching payerId: $e");
    return null;
  }
}
