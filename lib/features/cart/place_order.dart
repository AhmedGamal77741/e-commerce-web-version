import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/models/product_model.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/underline_text_filed.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:ecommerece_app/features/cart/models/address.dart';
import 'package:ecommerece_app/features/cart/services/cart_service.dart';
import 'package:ecommerece_app/features/cart/sub_screens/address_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/rendering.dart';
import 'package:web/web.dart' as web;

class PlaceOrder extends StatefulWidget {
  const PlaceOrder({super.key});

  @override
  State<PlaceOrder> createState() => _PlaceOrderState();
}

class _PlaceOrderState extends State<PlaceOrder> {
  final GlobalKey _orderSummaryKey = GlobalKey();
  bool isCheckoutValid = true;
  String? checkoutErrorMessage;
  void _showBankAccountDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '계좌 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 16),
                    if (bankAccounts.isEmpty)
                      Text(
                        '등록된 계좌가 없습니다.',
                        style: TextStyle(color: Colors.black),
                      ),
                    ...bankAccounts.asMap().entries.map((entry) {
                      int idx = entry.key;
                      var acc = entry.value;
                      return ListTile(
                        title: Text(
                          '${acc['bankName']} / ${acc['bankNumber']}',
                          style: TextStyle(color: Colors.black),
                        ),
                        subtitle: Text(
                          'Payer ID: ${acc['payerId']}',
                          style: TextStyle(color: Colors.grey),
                        ),
                        tileColor:
                            idx == selectedBankIndex
                                ? Colors.black12
                                : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onTap: () {
                          setState(() {
                            selectedBankIndex = idx;
                            isAddingNewBank = false;
                          });
                          setStateDialog(() {});
                          Navigator.of(context).pop();
                        },
                      );
                    }).toList(),
                    Divider(height: 32, color: Colors.black),
                    ListTile(
                      title: Text(
                        '새 계좌로 결제',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      tileColor:
                          selectedBankIndex == -1
                              ? Colors.black12
                              : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onTap: () {
                        setState(() {
                          selectedBankIndex = -1;
                          isAddingNewBank = true;
                        });
                        setStateDialog(() {});
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _validateCheckout() async {
    // Address check

    // Cart check
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        isCheckoutValid = false;
        checkoutErrorMessage = '로그인이 필요합니다.';
      });
      return;
    }
    final cartSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('cart')
            .get();
    final cartItems = cartSnapshot.docs.map((doc) => doc.data()).toList();
    if (cartItems.isEmpty) {
      setState(() {
        isCheckoutValid = false;
        checkoutErrorMessage = '장바구니가 비어 있습니다.';
      });
      return;
    }

    // Product existence and stock check
    for (var item in cartItems) {
      final productId = item['product_id'];
      /*       final quantityOrdered = item['quantity'];
 */
      int quantityOrdered = 0;
      final productStream =
          await FirebaseFirestore.instance
              .collection('products')
              .doc(productId)
              .get();
      final productData = productStream.data();
      if (productData != null) {
        final prod = Product.fromMap(productData);
        quantityOrdered = prod.pricePoints[item['pricePointIndex']].quantity;
      }

      final productRef = FirebaseFirestore.instance
          .collection('products')
          .doc(productId);
      final productSnapshot = await productRef.get();
      if (!productSnapshot.exists) {
        setState(() {
          isCheckoutValid = false;
          checkoutErrorMessage = '상품이 더 이상 존재하지 않습니다.';
        });
        return;
      }
      final currentStock = productSnapshot.data()?['stock'] ?? 0;
      if (quantityOrdered is! int || quantityOrdered <= 0) {
        setState(() {
          isCheckoutValid = false;
          checkoutErrorMessage = '주문 수량이 올바르지 않습니다.';
        });
        return;
      }
      if (currentStock < quantityOrdered) {
        setState(() {
          isCheckoutValid = false;
          checkoutErrorMessage =
              '재고가 부족한 상품이 있습니다. (주문 수량: $quantityOrdered, 남은 재고: $currentStock)';
        });
        return;
      }
    }

    // All checks passed
    setState(() {
      isCheckoutValid = true;
      checkoutErrorMessage = null;
    });
  }

  Future<void> _fetchBankAccounts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = userDoc.data();
    if (data != null && data['bankAccounts'] != null) {
      final accounts = List<Map<String, dynamic>>.from(data['bankAccounts']);
      setState(() {
        bankAccounts = accounts;
        selectedBankIndex = accounts.isNotEmpty ? 0 : -1;
      });
    } else {
      setState(() {
        bankAccounts = [];
        selectedBankIndex = -1;
      });
    }
  }

  List<Map<String, dynamic>> bankAccounts = [];
  int selectedBankIndex = -1;
  bool isAddingNewBank = false;
  final deliveryAddressController = TextEditingController();
  final deliveryInstructionsController = TextEditingController();
  final cashReceiptController = TextEditingController();
  final phoneController = TextEditingController();
  final nameController = TextEditingController();
  final emailController =
      TextEditingController(); // NEW: email field controller
  int selectedOption = 1;
  final _formKey = GlobalKey<FormState>();
  Address address = Address(
    id: '',
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
  // Removed timer logic

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
    await refreshCartPrices(uid);

    if (!_formKey.currentState!.validate()) return;
    // Save name/phone/email to cache before placing order

    setState(() {
      isProcessing = true;
    });
    try {
      final docRef = FirebaseFirestore.instance.collection('orders').doc();
      final paymentId = docRef.id;
      currentPaymentId = paymentId;

      String? payerId;
      if (bankAccounts.isNotEmpty &&
          selectedBankIndex >= 0 &&
          selectedBankIndex < bankAccounts.length) {
        payerId = bankAccounts[selectedBankIndex]['payerId'] as String?;
      } else {
        payerId = null;
      }
      // Removed payment timeout logic

      // Show dialog for user to launch payment page and view order summary
      if (payerId != null && payerId.isNotEmpty) {
        _launchBankRpaymentPage(
          totalPrice.toString(),
          uid,
          phoneController.text.trim(),
          paymentId,
          payerId,
          nameController.text.trim(), // pass name
          emailController.text.trim(), // pass email
        );
      } else {
        _launchBankPaymentPage(
          totalPrice.toString(),
          uid,
          phoneController.text.trim(),
          paymentId,
          nameController.text.trim(), // pass name
          emailController.text.trim(), // pass email
        );
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
          // Show failure message and delete pending order, then go back
          Future.microtask(() async {
            await pendingDoc.reference.delete();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('결제 실패. 다시 시도해주세요.'),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.pop(context);
            }
          });
          return SizedBox.shrink();
        }
        if (status == 'success') {
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
      final userData =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .get();
      final defaultAddressDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('addresses')
              .doc(userData['defaultAddressId'])
              .get();
      final defaultAddress = defaultAddressDoc.data() as Map<String, dynamic>;
      deliveryAddressController.text = defaultAddress['address'];
      address = Address(
        id: defaultAddress['id'],
        name: defaultAddress['name'],
        phone: defaultAddress['phone'],
        address: defaultAddress['address'],
        detailAddress: defaultAddress['detailAddress'],
        isDefault: defaultAddress['isDefault'],
        addressMap: defaultAddress['addressMap'],
      );
      final cartSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('cart')
              .get();
      final cartItems = cartSnapshot.docs.map((doc) => doc.data()).toList();
      final productIds = cartItems.map((item) => item['product_id']).toList();
      /*       final quantities = cartItems.map((item) => item['quantity']).toList();
 */
      final prices = cartItems.map((item) => item['price']).toList();
      final deliveryManagerIds =
          cartItems.map((item) => item['deliveryManagerId']).toList();
      if (pendingDocs.isEmpty) return;
      final doc = pendingDocs.first;

      for (int i = 0; i < productIds.length; i++) {
        final productRef = FirebaseFirestore.instance
            .collection('products')
            .doc(productIds[i]);
        final productSnapshot = await productRef.get();
        final prod = Product.fromMap(productSnapshot.data()!);
        final currentStock = productSnapshot.data()?['stock'] ?? 0;
        final orderQty =
            prod.pricePoints[cartItems[i]['pricePointIndex']].quantity;
        if (currentStock < orderQty || orderQty <= 0) {
          continue;
        }
        final orderRef = FirebaseFirestore.instance.collection('orders').doc();
        final orderData = {
          'orderId': orderRef.id,
          'userId': uid,
          'paymentId': currentPaymentId,
          'deliveryAddressId': address.id,
          'deliveryAddress': deliveryAddressController.text.trim(),
          'deliveryAddressDetail': address.detailAddress,

          'deliveryInstructions':
              selectedRequest == '직접입력'
                  ? manualRequest?.trim() ?? ''
                  : selectedRequest.trim(),
          'cashReceipt': cashReceiptController.text.trim(),
          'paymentMethod': 'bank',
          'orderDate': DateTime.now().toIso8601String(),
          'totalPrice': prices[i],
          'productId': productIds[i],
          'quantity': orderQty,
          'courier': '',
          'trackingNumber': '',
          'trackingEvents': {},
          'orderStatus': 'orderComplete',
          'isRequested': false,
          'deliveryManagerId': deliveryManagerIds[i],
          'carrierId': '',
          'isSent': false,
          'confirmed': false,
          'phoneNo': phoneController.text.trim(),
        };
        await orderRef.set(orderData);
        await productRef.update({'stock': FieldValue.increment(-orderQty)});

        // Add to order_settlement collection for settlement automation
        final settlementRef = FirebaseFirestore.instance
            .collection('order_settlement')
            .doc(orderRef.id);
        await settlementRef.set({
          'orderId': orderRef.id,
          'price': prices[i],
          'deliveryManagerId': deliveryManagerIds[i],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await doc.reference.delete();

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

  // Removed timer and timeout logic

  @override
  void initState() {
    super.initState();
    _fetchBankAccounts();
    _fetchUserPaymentInfo();
    _loadCachedUserValues();

    // NEW: load cached name/phone
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

  Future<void> _fetchUserPaymentInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = userDoc.data();
    print('Fetched user data:');
    print(data);
    setState(() {
      userBank = data?['bank'] as Map<String, dynamic>?;
      print('userBank:');
      print(userBank);
    });
  }

  Future<void> _saveOrderSummaryAsImage() async {
    try {
      RenderRepaintBoundary boundary =
          _orderSummaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        final pngBytes = byteData.buffer.asUint8List();
        final blob = html.Blob([pngBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor =
            html.AnchorElement()
              ..href = url
              ..download = 'order_summary.png'
              ..click();
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('이미지 저장에 실패했습니다. 다시 시도해주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return SafeArea(
      child: StreamBuilder(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                .snapshots(),
        builder: (context, userSnapshot) {
          final isSub = userSnapshot.data?.get('isSub') ?? false;
          return Scaffold(
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
              padding: EdgeInsets.only(left: 15, top: 10, right: 15),
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
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        height: 1.40,
                                                      ),
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      '배송지를 설정해주세요',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        color: Color(
                                                          0xFF9E9E9E,
                                                        ),
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
                                                  if (snapshot
                                                          .connectionState ==
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
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '베송지 | ${addressData!['name']}',
                                                        style: TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 15,
                                                          fontFamily:
                                                              'NotoSans',
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
                                                          color: Color(
                                                            0xFF9E9E9E,
                                                          ),
                                                          fontFamily:
                                                              'NotoSans',
                                                        ),
                                                      ),
                                                      Text(
                                                        addressData['address'],
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          color: Color(
                                                            0xFF9E9E9E,
                                                          ),
                                                          fontFamily:
                                                              'NotoSans',
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
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                  (text) =>
                                      setState(() => manualRequest = text),
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
                                          (bankAccounts.isNotEmpty &&
                                                  selectedBankIndex >= 0 &&
                                                  selectedBankIndex <
                                                      bankAccounts.length)
                                              ? '${bankAccounts[selectedBankIndex]['bankName']} / ${bankAccounts[selectedBankIndex]['bankNumber']}'
                                              : '등록된 계좌가 없습니다.',
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
                                      isProcessing
                                          ? null
                                          : _showBankAccountDialog,
                                  style: TextButton.styleFrom(
                                    fixedSize: Size(48, 30),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                              if (val == null || val.trim().isEmpty) {
                                return '이름을 입력해주세요';
                              }
                              return null;
                            },
                            onChanged: (val) {
                              _saveCachedUserValues();
                            },
                          ),
                          SizedBox(height: 10),
                          UnderlineTextField(
                            controller: emailController,
                            hintText: '이메일',
                            obscureText: false,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return '이메일을 입력해주세요';
                              }
                              // Simple email validation
                              if (!RegExp(
                                r'^.+@.+\..+$',
                              ).hasMatch(val.trim())) {
                                return '유효한 이메일을 입력해주세요';
                              }
                              return null;
                            },
                            onChanged: (val) {
                              _saveCachedUserValues();
                            },
                          ),
                          SizedBox(height: 10),
                          UnderlineTextField(
                            controller: phoneController,
                            hintText: '전화번호 ',
                            obscureText: false,
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return '전화번호를 입력해주세요';
                              }
                              final koreanReg = RegExp(
                                r'^01([0|1|6|7|8|9])-?([0-9]{3,4})-?([0-9]{4})$',
                              );
                              if (!koreanReg.hasMatch(val)) {
                                return '유효한 한국 전화번호를 입력하세요';
                              }
                              return null;
                            },
                            onChanged: (val) {
                              _saveCachedUserValues();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  verticalSpace(10),
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
                                  .doc(
                                    FirebaseAuth.instance.currentUser?.uid ??
                                        '',
                                  )
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
                                    final prod = Product.fromMap(productData);
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        StreamBuilder<int>(
                                          stream: getProductQuantityStream(
                                            cartData['product_id'],
                                            cartData['pricePointIndex'],
                                          ),
                                          builder: (context, snapshot) {
                                            final quan = snapshot.data ?? 0;
                                            return Text(
                                              '${productData['productName']} / 수량 : ${quan.toString()}',
                                              style: TextStyle(
                                                color: const Color(0xFF747474),
                                                fontSize: 14,
                                                fontFamily: 'NotoSans',
                                                fontWeight: FontWeight.w400,
                                                height: 1.40,
                                              ),
                                            );
                                          },
                                        ),
                                        /*                                     Text(
                                              '${productData['productName']} / 수량 : ${prod.pricePoints[cartData['pricePointIndex']].quantity.toString()}',
                                              style: TextStyle(
                                                color: const Color(0xFF747474),
                                                fontSize: 14,
                                                fontFamily: 'NotoSans',
                                                fontWeight: FontWeight.w400,
                                                height: 1.40,
                                              ),
                                            ), */
                                        SizedBox(height: 8),
                                        StreamBuilder<double>(
                                          stream: getProductPriceStream(
                                            cartData['product_id'],
                                            cartData['pricePointIndex'],
                                            isSub,
                                          ),
                                          builder: (context, snapshot) {
                                            final price = snapshot.data ?? 0.0;
                                            return Text(
                                              '${formatCurrency.format(price)} 원',
                                              style: TextStyle(
                                                color: const Color(0xFF747474),
                                                fontSize: 14,
                                                fontFamily: 'NotoSans',
                                                fontWeight: FontWeight.w600,
                                                height: 1.40,
                                              ),
                                            );
                                          },
                                        ),
                                        /*                                     Text(
                                              '${formatCurrency.format(cartData['price'] ?? 0)} 원',
                                              style: TextStyle(
                                                color: const Color(0xFF747474),
                                                fontSize: 14,
                                                fontFamily: 'NotoSans',
                                                fontWeight: FontWeight.w600,
                                                height: 1.40,
                                              ),
                                            ), */
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
                ],
              ),
            ),
            bottomNavigationBar: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                      .collection('cart')
                      .snapshots(),
              builder: (context3, cartSnapshot) {
                if (!cartSnapshot.hasData || cartSnapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }
                return StreamBuilder<int>(
                  stream: calculateCartTotal(cartSnapshot.data!.docs, isSub),
                  builder: (context2, totalSnapshot) {
                    final totalPrice = totalSnapshot.data ?? 0;
                    return Container(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        10,
                        16,
                        28,
                      ), // Extra bottom padding for iOS PWA
                      decoration: BoxDecoration(color: Colors.white),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                    '${formatCurrency.format(totalPrice)} 원',
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
                          SizedBox(height: 8),
                          _buildPaymentButton(totalPrice, uid),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  /*   Future<int> calculateCartTotalPay() async {
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
  } */

  /*   Future<int> calculateCartTotal(List<QueryDocumentSnapshot> cartDocs) async {
    int total = 0;
    for (final cartDoc in cartDocs) {
      final cartData = cartDoc.data() as Map<String, dynamic>;
      final price = cartData['price'];
      try {
        total += price as int;
      } catch (e) {}
    }
    return total;
  } */

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
      print(userId + " " + paymentId);
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
}
