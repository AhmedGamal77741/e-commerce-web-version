import 'package:flutter/rendering.dart';

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/underline_text_filed.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:ecommerece_app/features/cart/models/address.dart';
import 'package:ecommerece_app/features/cart/sub_screens/address_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ecommerece_app/core/models/product_model.dart';

final GlobalKey _orderSummaryKey = GlobalKey();

Future<void> _saveOrderSummaryAsImage(BuildContext context) async {
  try {
    RenderRepaintBoundary boundary =
        _orderSummaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
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
  bool isAddingNewBank = false; // True if 'Add New' selected
  final deliveryAddressController = TextEditingController();
  final deliveryInstructionsController = TextEditingController();
  final cashReceiptController = TextEditingController();
  final phoneController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
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
  Map<String, dynamic>? userBank;
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

  List<Map<String, dynamic>> bankAccounts = [];
  int selectedBankIndex = 0;

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

      // Show dialog for user to launch payment page and view order summary
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
      if (pendingDocs.isEmpty) return;
      final doc = pendingDocs.first;

      final productRef = FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.product_id);
      // final productSnapshot = await productRef.get();

      final orderQty = widget.quantity;

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
        'totalPrice': widget.price,
        'productId': widget.product.product_id,
        'quantity': widget.quantity,
        'courier': '',
        'trackingNumber': '',
        'trackingEvents': {},
        'orderStatus': 'orderComplete',
        'isRequested': false,
        'deliveryManagerId': widget.product.deliveryManagerId,
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
        'price': widget.price,
        'deliveryManagerId': widget.product.deliveryManagerId,
        'createdAt': FieldValue.serverTimestamp(),
      });

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

  @override
  void initState() {
    super.initState();
    _fetchBankAccounts();
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: ColorsManager.primary,
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
                                              height: 1.4,
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
                                            height: 1.4,
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
                                      : () async {
                                        await showDialog(
                                          context: context,
                                          builder: (context) {
                                            return StatefulBuilder(
                                              builder: (
                                                context,
                                                setStateDialog,
                                              ) {
                                                return Dialog(
                                                  backgroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  child: Padding(
                                                    padding: EdgeInsets.all(20),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          '계좌 선택',
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        SizedBox(height: 16),
                                                        if (bankAccounts
                                                            .isEmpty)
                                                          Text(
                                                            '등록된 계좌가 없습니다.',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                          ),
                                                        ...bankAccounts.asMap().entries.map((
                                                          entry,
                                                        ) {
                                                          int idx = entry.key;
                                                          var acc = entry.value;
                                                          return ListTile(
                                                            title: Text(
                                                              '${acc['bankName']} / ${acc['bankNumber']}',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors
                                                                        .black,
                                                              ),
                                                            ),
                                                            subtitle: Text(
                                                              'Payer ID: ${acc['payerId']}',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                            ),
                                                            tileColor:
                                                                idx ==
                                                                        selectedBankIndex
                                                                    ? Colors
                                                                        .black12
                                                                    : Colors
                                                                        .white,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                            onTap: () {
                                                              setState(() {
                                                                selectedBankIndex =
                                                                    idx;
                                                                isAddingNewBank =
                                                                    false;
                                                              });
                                                              setStateDialog(
                                                                () {},
                                                              );
                                                              Navigator.of(
                                                                context,
                                                              ).pop();
                                                            },
                                                          );
                                                        }).toList(),
                                                        Divider(
                                                          height: 32,
                                                          color: Colors.black,
                                                        ),
                                                        ListTile(
                                                          title: Text(
                                                            '새 계좌로 결제',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                          ),
                                                          tileColor:
                                                              selectedBankIndex ==
                                                                      -1
                                                                  ? Colors
                                                                      .black12
                                                                  : Colors
                                                                      .white,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          onTap: () {
                                                            setState(() {
                                                              selectedBankIndex =
                                                                  -1;
                                                              isAddingNewBank =
                                                                  true;
                                                            });
                                                            setStateDialog(
                                                              () {},
                                                            );
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
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
                                        setState(() {});
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
                          if (val!.isEmpty) {
                            return '이메일을 입력하세요';
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
                        hintText: '전화번호',
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
              verticalSpace(10),

              // --- Total and payment button for Buy Now ---
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 28),
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
              SizedBox(height: 8),
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
