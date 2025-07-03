import 'dart:async';
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
import 'package:ecommerece_app/core/models/product_model.dart';

class BuyNow extends StatefulWidget {
  final Product product;
  final int quantity;
  final int price;
  const BuyNow({
    Key? key,
    required this.product,
    required this.quantity,
    required this.price,
  }) : super(key: key);

  @override
  State<BuyNow> createState() => _BuyNowState();
}

class _BuyNowState extends State<BuyNow> {
  final deliveryAddressController = TextEditingController();
  final deliveryInstructionsController = TextEditingController();
  final cashReceiptController = TextEditingController();
  final phoneController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
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
    '문앞',
    '직접 받고 부재 시 문앞',
    '택배함',
    '경비실',
    '직접입력',
  ];
  String selectedRequest = '문앞';
  String? manualRequest;
  bool isProcessing = false;
  String? currentPaymentId;
  final Set<String> _finalizedPayments = {};
  int paymentMethod = 0;
  Map<String, dynamic>? userBank;
  Map<String, dynamic>? userCard;
  Timer? _paymentTimeoutTimer;
  String? _timeoutPaymentId;

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

  Future<void> _handlePlaceOrder(int totalPrice, String uid) async {
    if (!_formKey.currentState!.validate()) return;
    // Save name/phone/email to cache before placing order (for consistency with PlaceOrder)
    await _saveCachedUserValues();
    setState(() {
      isProcessing = true;
    });
    try {
      // Check stock for the single product
      final productRef = FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.product_id);
      final productSnapshot = await productRef.get();
      if (!productSnapshot.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('상품이 더 이상 존재하지 않습니다.')));
        setState(() {
          isProcessing = false;
        });
        return;
      }
      final currentStock = productSnapshot.data()?['stock'] ?? 0;
      if (widget.quantity <= 0 || currentStock < widget.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '재고가 부족합니다. (주문 수량: ${widget.quantity}, 남은 재고: $currentStock)',
            ),
          ),
        );
        setState(() {
          isProcessing = false;
        });
        return;
      }
      final docRef = FirebaseFirestore.instance.collection('orders').doc();
      final paymentId = docRef.id;
      currentPaymentId = paymentId;
      final pendingOrderRef =
          FirebaseFirestore.instance.collection('pending_orders').doc();
      final orderData = {
        'pendingOrderId': pendingOrderRef.id,
        'userId': uid,
        'paymentId': paymentId,
        'deliveryAddress': deliveryAddressController.text.trim(),
        'deliveryInstructions':
            selectedRequest == '직접입력'
                ? manualRequest?.trim() ?? ''
                : selectedRequest.trim(),
        'cashReceipt': cashReceiptController.text.trim(),
        'paymentMethod': paymentMethod == 0 ? 'bank' : 'card',
        'orderDate': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
        'totalPrice': totalPrice,
        'productIds': [widget.product.product_id],
        'quantities': [widget.quantity],
        'prices': [widget.price],
        'orderStatus': 'pending',
        'status': 'pending',
        'isRequested': false,
        'deliveryManagerIds': [''],
        'carrierId': '',
        'isSent': false,
        'phoneNo': phoneController.text.trim(),
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
      };
      await pendingOrderRef.set(orderData);
      final payerId =
          paymentMethod == 0
              ? (userBank != null ? userBank!['payerId'] as String? : null)
              : (userCard != null ? userCard!['payerId'] as String? : null);
      _startPaymentTimeout(paymentId, pendingOrderRef);
      if (paymentMethod == 0) {
        if (payerId != null && payerId.isNotEmpty) {
          _launchBankRpaymentPage(
            totalPrice.toString(),
            uid,
            phoneController.text.trim(),
            paymentId,
            payerId,
            nameController.text.trim(),
            emailController.text.trim(),
          );
        } else {
          _launchBankPaymentPage(
            totalPrice.toString(),
            uid,
            phoneController.text.trim(),
            paymentId,
            nameController.text.trim(),
            emailController.text.trim(),
          );
        }
      } else {
        if (payerId != null && payerId.isNotEmpty) {
          _launchCardRpaymentPage(
            totalPrice.toString(),
            uid,
            phoneController.text.trim(),
            paymentId,
            payerId,
            nameController.text.trim(),
            emailController.text.trim(),
          );
        } else {
          _launchCardPaymentPage(
            totalPrice.toString(),
            uid,
            phoneController.text.trim(),
            paymentId,
            nameController.text.trim(),
            emailController.text.trim(),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('주문 처리 중 오류가 발생했습니다. 다시 시도해주세요.')));
      setState(() {
        isProcessing = false;
      });
    }
  }

  Stream<QuerySnapshot>? get _pendingOrdersStream {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (currentPaymentId == null || uid == null) return null;
    return FirebaseFirestore.instance
        .collection('pending_orders')
        .where('userId', isEqualTo: uid)
        .where('paymentId', isEqualTo: currentPaymentId)
        .snapshots();
  }

  Widget _buildPaymentButton(int totalPrice, String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('pending_orders')
              .where('userId', isEqualTo: uid)
              .where('paymentId', isEqualTo: currentPaymentId)
              .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final pendingDoc = docs.isNotEmpty ? docs.first : null;
        final status =
            pendingDoc != null ? pendingDoc['status'] as String : null;
        if (pendingDoc == null) {
          return WideTextButton(
            txt: '주문',
            func: () => _handlePlaceOrder(totalPrice, uid),
            color: Colors.black,
            txtColor: Colors.white,
          );
        }
        if (status == 'failed') {
          _cancelPaymentTimeoutIfNeeded(
            pendingDoc['paymentId'] as String?,
            status,
          );
          return Column(
            children: [
              WideTextButton(
                txt: '주문',
                func: () async {
                  await pendingDoc.reference.update({'status': 'pending'});
                  final data = pendingDoc.data() as Map<String, dynamic>;
                  final payerId =
                      paymentMethod == 0
                          ? (userBank != null
                              ? userBank!['payerId'] as String?
                              : null)
                          : (userCard != null
                              ? userCard!['payerId'] as String?
                              : null);
                  final name = data['name'] ?? '';
                  final email = data['email'] ?? '';
                  if (paymentMethod == 0) {
                    if (payerId != null && payerId.isNotEmpty) {
                      _launchBankRpaymentPage(
                        (data['totalPrice'] ?? '').toString(),
                        data['userId'] ?? uid,
                        data['phoneNo'] ?? '',
                        data['paymentId'] ?? '',
                        payerId,
                        name,
                        email,
                      );
                    } else {
                      _launchBankPaymentPage(
                        (data['totalPrice'] ?? '').toString(),
                        data['userId'] ?? uid,
                        data['phoneNo'] ?? '',
                        data['paymentId'] ?? '',
                        name,
                        email,
                      );
                    }
                  } else {
                    if (payerId != null && payerId.isNotEmpty) {
                      _launchCardRpaymentPage(
                        (data['totalPrice'] ?? '').toString(),
                        data['userId'] ?? uid,
                        data['phoneNo'] ?? '',
                        data['paymentId'] ?? '',
                        payerId,
                        name,
                        email,
                      );
                    } else {
                      _launchCardPaymentPage(
                        (data['totalPrice'] ?? '').toString(),
                        data['userId'] ?? uid,
                        data['phoneNo'] ?? '',
                        data['paymentId'] ?? '',
                        name,
                        email,
                      );
                    }
                  }
                },
                color: Colors.black,
                txtColor: Colors.white,
              ),
              SizedBox(height: 8),
              Text('결제 실패. 다시 시도해주세요.', style: TextStyle(color: Colors.red)),
            ],
          );
        }
        if (status == 'success') {
          _cancelPaymentTimeoutIfNeeded(
            pendingDoc['paymentId'] as String?,
            status,
          );
          final paymentId = pendingDoc['paymentId'] as String?;
          if (paymentId != null && !_finalizedPayments.contains(paymentId)) {
            _finalizedPayments.add(paymentId);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _finalizeOrderAfterPayment([pendingDoc], uid);
            });
          }
          return Column(
            children: [
              SizedBox(height: 8),
              Text(
                isProcessing
                    ? '결제 성공! 주문을 완료 처리 중입니다...'
                    : '주문이 성공적으로 완료되었습니다!',
                style: TextStyle(color: Colors.green),
              ),
              if (isProcessing) ...[
                SizedBox(height: 8),
                CircularProgressIndicator(),
              ],
            ],
          );
        }
        if (status == 'pending') {
          return Column(
            children: [
              WideTextButton(
                txt: '결제 진행 중... 취소',
                func: () async {
                  // Cancel the pending order and reset state
                  await pendingDoc.reference.delete();
                  setState(() {
                    currentPaymentId = null;
                    isProcessing = false;
                  });
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                color: Colors.grey.shade400, // Keep original color
                txtColor: Colors.white,
              ),
              SizedBox(height: 8),
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text(
                '결제 대기 중입니다. 결제를 취소하려면 위 버튼을 누르세요.',
                style: TextStyle(color: Colors.black),
              ),
            ],
          );
        }
        return WideTextButton(
          txt: '주문',
          func: () => _handlePlaceOrder(totalPrice, uid),
          color: Colors.black,
          txtColor: Colors.white,
        );
      },
    );
  }

  Future<void> _finalizeOrderAfterPayment(
    List<QueryDocumentSnapshot> pendingDocs,
    String uid,
  ) async {
    if (!mounted) return;
    setState(() {
      isProcessing = true;
    });
    try {
      if (pendingDocs.isEmpty) return;
      final doc = pendingDocs.first;
      final data = doc.data() as Map<String, dynamic>;
      final productIds = List.from(data['productIds'] ?? []);
      final quantities = List.from(data['quantities'] ?? []);
      final prices = List.from(data['prices'] ?? []);
      final deliveryManagerIds = List.from(data['deliveryManagerIds'] ?? []);
      for (int i = 0; i < productIds.length; i++) {
        final productRef = FirebaseFirestore.instance
            .collection('products')
            .doc(productIds[i]);
        final productSnapshot = await productRef.get();
        final currentStock = productSnapshot.data()?['stock'] ?? 0;
        final orderQty = quantities[i];
        if (currentStock < orderQty || orderQty <= 0) {
          continue;
        }
        final orderRef = FirebaseFirestore.instance.collection('orders').doc();
        final orderData = {
          'orderId': orderRef.id,
          'userId': data['userId'],
          'paymentId': data['paymentId'],
          'deliveryAddress': data['deliveryAddress'],
          'deliveryInstructions': data['deliveryInstructions'],
          'cashReceipt': data['cashReceipt'],
          'paymentMethod': data['paymentMethod'],
          'orderDate': data['orderDate'],
          'totalPrice': prices[i],
          'productId': productIds[i],
          'quantity': orderQty,
          'courier': '',
          'trackingNumber': '',
          'trackingEvents': {},
          'orderStatus': 'orderComplete',
          'isRequested': data['isRequested'],
          'deliveryManagerId': deliveryManagerIds[i],
          'carrierId': '',
          'isSent': false,
          'phoneNo': data['phoneNo'],
        };
        await orderRef.set(orderData);
        await productRef.update({'stock': FieldValue.increment(-orderQty)});
      }
      await doc.reference.delete();
      final cartSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('cart')
              .get();
      for (var doc in cartSnapshot.docs) {
        await doc.reference.delete();
      }
      if (mounted) {
        setState(() {
          isProcessing = false;
          currentPaymentId = null;
        });
        context.go(Routes.orderCompleteScreen);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('주문 완료 처리 중 오류가 발생했습니다.')));
      setState(() {
        isProcessing = false;
      });
    }
  }

  void _startPaymentTimeout(
    String paymentId,
    DocumentReference pendingOrderRef,
  ) {
    _paymentTimeoutTimer?.cancel();
    _timeoutPaymentId = paymentId;
    _paymentTimeoutTimer = Timer(Duration(minutes: 2), () async {
      final doc = await pendingOrderRef.get();
      if (doc.exists &&
          (doc.data() as Map<String, dynamic>)['status'] == 'pending') {
        await pendingOrderRef.update({'status': 'failed'});
        if (mounted) setState(() {});
      }
    });
  }

  void _cancelPaymentTimeoutIfNeeded(String? paymentId, String? status) {
    if (_paymentTimeoutTimer != null &&
        _timeoutPaymentId == paymentId &&
        status != 'pending') {
      _paymentTimeoutTimer?.cancel();
      _paymentTimeoutTimer = null;
      _timeoutPaymentId = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserPaymentInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedUserValues();
    });
  }

  Future<void> _loadCachedUserValues() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('usercached_values')
            .doc(uid)
            .get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        nameController.text = data['name'] ?? '';
        emailController.text = data['email'] ?? '';
        phoneController.text = data['phone'] ?? '';
      }
    }
  }

  Future<void> _fetchUserPaymentInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = userDoc.data();
    setState(() {
      userBank = data?['bank'] as Map<String, dynamic>?;
      userCard = data?['card'] as Map<String, dynamic>?;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

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
                                                'Error loading user address: ${snapshot.error}',
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
                                                      userData['defaultAddressId'],
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
                        paymentMethod == 0 ? '간편 계좌 결제' : '간편 카드 결제',
                        style: TextStyle(
                          color: const Color(0xFF121212),
                          fontSize: 16,
                          fontFamily: 'NotoSans',
                          fontWeight: FontWeight.w400,
                          height: 1.40,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: ColorsManager.primary400,
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: TextFormField(
                                controller: cashReceiptController,
                                enabled: false,
                                decoration: InputDecoration(
                                  hintText:
                                      paymentMethod == 0
                                          ? (userBank != null &&
                                                  userBank!['bankName'] !=
                                                      null &&
                                                  userBank!['accountNumber'] !=
                                                      null
                                              ? '${userBank!['bankName']} / ${userBank!['accountNumber']}'
                                              : '등록된 계좌가 없습니다.')
                                          : (userCard != null &&
                                                  userCard!['cardName'] !=
                                                      null &&
                                                  userCard!['cardNumber'] !=
                                                      null
                                              ? '${userCard!['cardName']} / ${userCard!['cardNumber']}'
                                              : '등록된 카드가 없습니다.'),
                                  hintStyle: TextStyle(
                                    fontSize: 15,
                                    color: ColorsManager.primary400,
                                  ),
                                  border: InputBorder.none,
                                ),
                                obscureText: false,
                                keyboardType: TextInputType.text,
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  (isProcessing ||
                                          (currentPaymentId != null &&
                                              _pendingOrdersStream != null &&
                                              _finalizedPayments.contains(
                                                    currentPaymentId,
                                                  ) ==
                                                  false &&
                                              _getCurrentPendingStatus() ==
                                                  'pending'))
                                      ? () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '결제 진행 중에는 결제수단을 변경할 수 없습니다.',
                                            ),
                                          ),
                                        );
                                      }
                                      : () async {
                                        setState(() {
                                          paymentMethod =
                                              paymentMethod == 0 ? 1 : 0;
                                        });
                                      },
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
                        controller: nameController,
                        hintText: '이름',
                        obscureText: false,
                        keyboardType: TextInputType.text,
                        validator: (val) {
                          if (val!.isEmpty) {
                            return '이름을 입력하세요';
                          } else if (val.length > 30) {
                            return '이름이 너무 깁니다';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 10),
                      UnderlineTextField(
                        controller: emailController,
                        hintText: '이메일',
                        obscureText: false,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val!.isEmpty) {
                            return '이메일을 입력하세요';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 10),
                      UnderlineTextField(
                        controller: phoneController,
                        hintText: '전화번호',
                        obscureText: false,
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val!.isEmpty) {
                            return '전화번호를 입력하세요';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              verticalSpace(20),
              // --- Single product summary for Buy Now ---
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
                    Text(
                      '${widget.product.productName} / 수량 : ${widget.quantity}',
                      style: TextStyle(
                        color: const Color(0xFF747474),
                        fontSize: 14,
                        fontFamily: 'NotoSans',
                        fontWeight: FontWeight.w400,
                        height: 1.40,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${formatCurrency.format(widget.price)} 원',
                      style: TextStyle(
                        color: const Color(0xFF747474),
                        fontSize: 14,
                        fontFamily: 'NotoSans',
                        fontWeight: FontWeight.w600,
                        height: 1.40,
                      ),
                    ),
                  ],
                ),
              ),
              verticalSpace(20),
              // --- Total and payment button for Buy Now ---
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
                  Text(
                    '${formatCurrency.format(widget.price)} 원',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontFamily: 'NotoSans',
                      fontWeight: FontWeight.w400,
                      height: 1.40,
                    ),
                  ),
                ],
              ),
              _buildPaymentButton(widget.price, uid),
            ],
          ),
        ),
      ),
    );
  }

  Future<int> calculateCartTotalPay() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('No user logged in');
    }
    final querySnap =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('cart')
            .get();
    var total = 0;
    for (final doc in querySnap.docs) {
      final data = doc.data();
      final price = data['price'];
      if (price is num) {
        total += price.toInt();
      }
    }
    return total;
  }

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

  void _launchCardPaymentPage(
    String amount,
    String userId,
    String phoneNo,
    String paymentId,
    String userName,
    String email,
  ) async {
    final url = Uri.parse(
      'https://pay.pang2chocolate.com/p-payment.html?paymentId=$paymentId&amount=$amount&userId=$userId&phoneNo=$phoneNo&userName=$userName&email=$email',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _launchCardRpaymentPage(
    String amount,
    String userId,
    String phoneNo,
    String paymentId,
    String payerId,
    String userName,
    String email,
  ) async {
    final url = Uri.parse(
      'https://pay.pang2chocolate.com/r-p-payment.html?paymentId=$paymentId&amount=$amount&userId=$userId&phoneNo=$phoneNo&payerId=$payerId&userName=$userName&email=$email',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _launchBankPaymentPage(
    String amount,
    String userId,
    String phoneNo,
    String paymentId,
    String userName,
    String email,
  ) async {
    final url = Uri.parse(
      'https://pay.pang2chocolate.com/b-payment.html?paymentId=$paymentId&amount=$amount&userId=$userId&phoneNo=$phoneNo&userName=$userName&email=$email',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _launchBankRpaymentPage(
    String amount,
    String userId,
    String phoneNo,
    String paymentId,
    String payerId,
    String userName,
    String email,
  ) async {
    final url = Uri.parse(
      'https://pay.pang2chocolate.com/r-b-payment.html?paymentId=$paymentId&amount=$amount&userId=$userId&phoneNo=$phoneNo&payerId=$payerId&userName=$userName&email=$email',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _saveCachedUserValues() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('usercached_values')
        .doc(uid)
        .set({
          'userId': uid,
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
        }, SetOptions(merge: true));
  }

  Future<bool> isPaymentCompleted(String orderId, String uid) async {
    final querySnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('payments')
            .where('paymentId', isEqualTo: orderId)
            .limit(1)
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
      final card = data?['card'] as Map<String, dynamic>?;
      final payerId = card?['payerId'] as String?;
      return payerId;
    } catch (e) {
      print("Error fetching payerId: $e");
      return null;
    }
  }

  String? _getCurrentPendingStatus() {
    return null;
  }
}
