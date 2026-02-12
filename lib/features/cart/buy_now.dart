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

class BuyNow extends StatefulWidget {
  final String? paymentId;
  const BuyNow({Key? key, this.paymentId}) : super(key: key);

  @override
  State<BuyNow> createState() => _BuyNowState();
}

class _BuyNowState extends State<BuyNow> {
  String invoiceeType = '사업자'; // 사업자 / 개인 / 외국인
  final invoiceeCorpNumController = TextEditingController(); // 사업자번호
  final invoiceeCorpNameController = TextEditingController(); // 상호명 or 개인 이름
  final invoiceeCEONameController = TextEditingController(); //
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

  // Store pending_buynow data
  Map<String, dynamic>? pendingBuynowData;
  int pendingPrice = 0;
  int pendingQuantity = 0;
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
      // persist selected address into usercached_values so backend and cart flow can reuse
      await _saveCachedUserValues();
    }
  }

  final formatCurrency = NumberFormat('#,###');

  Future<void> _handlePlaceOrder(int totalPrice, String uid) async {
    if (!_formKey.currentState!.validate()) return;

    // Save user values to cache before placing order
    await _saveCachedUserValues();

    setState(() {
      isProcessing = true;
    });
    try {
      final paymentId = widget.paymentId;
      if (paymentId == null || paymentId.isEmpty) {
        throw Exception('Invalid payment ID');
      }
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
          selectedOption.toString(),
          pendingBuynowData?['deliveryManagerId']?.toString() ?? '',
        );
      } else {
        _launchBankPaymentPage(
          totalPrice.toString(),
          uid,
          phoneController.text.trim(),
          paymentId,
          selectedOption.toString(),
          pendingBuynowData?['deliveryManagerId']?.toString() ?? '',
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
      // Backend has already handled:
      // - Order creation
      // - Stock updates
      // - Settlement records
      // - Receipt/Invoice issuance
      // - pending_buynow cleanup

      // Just clean up pending order and navigate
      if (pendingDocs.isNotEmpty) {
        await pendingDocs.first.reference.delete();
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
    _init();
  }

  Future<void> _init() async {
    await _fetchBankAccounts();
    await _fetchUserPaymentInfo();
    await _loadCachedUserValues();
    await _loadPendingBuynowData();
    await _ensureCachedAddressAndInstructions();
  }

  // Ensure usercached_values contains delivery address/instructions.
  // If missing, populate from user's defaultAddressId so backend has values.
  Future<void> _ensureCachedAddressAndInstructions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final cacheRef = FirebaseFirestore.instance
        .collection('usercached_values')
        .doc(uid);
    final cacheSnap = await cacheRef.get();
    final cacheData =
        cacheSnap.exists ? cacheSnap.data() as Map<String, dynamic> : {};

    final hasAddress =
        (cacheData['deliveryAddressId'] ?? '') != '' ||
        (cacheData['deliveryAddress'] ?? '') != '';
    final hasDeliveryInstr = (cacheData['deliveryInstructions'] ?? '') != '';

    if (hasAddress && hasDeliveryInstr) return;

    // Try to fetch user's default address
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final userData =
        userSnap.exists ? userSnap.data() as Map<String, dynamic> : {};
    final defaultAddressId = userData['defaultAddressId'] as String?;

    if (!hasAddress &&
        defaultAddressId != null &&
        defaultAddressId.isNotEmpty) {
      final addrSnap =
          await userRef.collection('addresses').doc(defaultAddressId).get();
      if (addrSnap.exists) {
        final addr = addrSnap.data() as Map<String, dynamic>;
        // update local `address` used by UI
        setState(() {
          address = Address(
            id: addr['id'] ?? defaultAddressId,
            name: addr['name'] ?? '',
            phone: addr['phone'] ?? '',
            address: addr['address'] ?? '',
            detailAddress: addr['detailAddress'] ?? '',
            isDefault: addr['isDefault'] ?? false,
            addressMap: addr['addressMap'] ?? {},
          );
        });

        await cacheRef.set({
          'deliveryAddressId': address.id,
          'deliveryAddress': address.address,
          'deliveryAddressDetail': address.detailAddress,
          'recipientName': address.name,
          'recipientPhone': address.phone,
        }, SetOptions(merge: true));
      }
    }

    if (!hasDeliveryInstr) {
      // If there's a pending buynow doc with instructions prefer that
      if (pendingBuynowData != null &&
          (pendingBuynowData?['deliveryInstructions'] ?? '') != '') {
        await cacheRef.set({
          'deliveryInstructions':
              pendingBuynowData?['deliveryInstructions'] ?? '',
        }, SetOptions(merge: true));
      } else {
        // write empty string to ensure field exists
        await cacheRef.set({
          'deliveryInstructions': '',
        }, SetOptions(merge: true));
      }
    }
  }

  Future<void> _loadPendingBuynowData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.paymentId == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('pending_buynow')
              .doc(widget.paymentId)
              .get();
      if (doc.exists) {
        setState(() {
          pendingBuynowData = doc.data();
          pendingPrice = pendingBuynowData?['price'] ?? 0;
          pendingQuantity = pendingBuynowData?['quantity'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading pending_buynow: $e');
    }
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
      if (data != null && mounted) {
        setState(() {
          nameController.text = data['name'] ?? '';
          emailController.text = data['email'] ?? '';
          phoneController.text = data['phone'] ?? '';
          invoiceeType = data['invoiceeType'] ?? '사업자';
          invoiceeCorpNumController.text = data['invoiceeCorpNum'] ?? '';
          invoiceeCorpNameController.text = data['invoiceeCorpName'] ?? '';
          invoiceeCEONameController.text = data['invoiceeCEOName'] ?? '';
        });
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
                              // persist delivery request to user cache
                              _saveCachedUserValues();
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
                          onChanged: (text) {
                            setState(() => manualRequest = text);
                            // persist manual delivery instruction
                            _saveCachedUserValues();
                          },
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
                          height: 1.4,
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
                                      });
                                      // Also trigger parent rebuild:
                                      setState(() {});
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
                                      });
                                      // Also trigger parent rebuild:
                                      setState(() {});
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
                      // --- conditional: cash receipt (selectedOption == 1) OR tax invoice (selectedOption == 2) ---
                      if (selectedOption == 1) ...[
                        // Cash receipt — keep your existing fields (unchanged)
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
                            if (val == null || val.trim().isEmpty) {
                              return '이메일을 입력해주세요';
                            }
                            if (!RegExp(r'^.+@.+\..+$').hasMatch(val.trim())) {
                              return '유효한 이메일을 입력해주세요';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            _saveCachedUserValues();
                            return null;
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
                            return null;
                          },
                        ),
                      ] else ...[
                        // Tax invoice UI
                        DropdownButtonFormField<String>(
                          dropdownColor: Colors.white,
                          value: invoiceeType,
                          items:
                              ['사업자', '개인', '외국인']
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            setState(() => invoiceeType = val ?? '사업자');
                            _saveCachedUserValues();
                          },

                          decoration: const InputDecoration(
                            border: UnderlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 8,
                            ),
                          ),
                          icon: Icon(Icons.keyboard_arrow_down),
                        ),
                        SizedBox(height: 10),

                        // 사업자번호 only when 사업자
                        UnderlineTextField(
                          obscureText: false,
                          controller: invoiceeCorpNumController,
                          hintText: '공급받는자 사업자번호',
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (invoiceeType == '사업자') {
                              if (val == null || val.trim().isEmpty) {
                                return '사업자번호를 입력해주세요';
                              }
                              if (!RegExp(
                                r'^[0-9]{10}$',
                              ).hasMatch(val.trim())) {
                                return '사업자번호는 숫자 10자리여야 합니다';
                              }
                              // optional: add basic format check (remove non-digits)
                            }
                            return null;
                          },
                          onChanged: (val) {
                            _saveCachedUserValues();
                            return null;
                          },
                        ),
                        SizedBox(height: 10),

                        UnderlineTextField(
                          obscureText: false,
                          controller: invoiceeCorpNameController,
                          hintText: '공급받는자 상호',
                          keyboardType: TextInputType.text,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return '이름을 입력해주세요';
                            }
                            if (val.trim().length > 200) {
                              return '입력은 최대 200자까지 가능합니다';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            _saveCachedUserValues();
                            return null;
                          },
                        ),
                        SizedBox(height: 10),

                        UnderlineTextField(
                          obscureText: false,
                          controller: invoiceeCEONameController,
                          hintText: '공급받는자 대표자 성명',
                          keyboardType: TextInputType.text,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return '대표자 성명을 입력해주세요';
                            }
                            if (val.trim().length > 200) {
                              return '입력은 최대 200자까지 가능합니다';
                            }

                            return null;
                          },
                          onChanged: (val) {
                            _saveCachedUserValues();
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
                            if (val == null || val.trim().isEmpty) {
                              return '이메일을 입력해주세요';
                            }
                            if (!RegExp(r'^.+@.+\..+$').hasMatch(val.trim())) {
                              return '유효한 이메일을 입력해주세요';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            _saveCachedUserValues();
                            return null;
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
                            return null;
                          },
                        ),
                        SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
              verticalSpace(20),
              // --- Single product summary for Buy Now ---
              if (pendingBuynowData != null)
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
                        '${pendingBuynowData!['product_name']} / 수량 : $pendingQuantity',
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
                        '${formatCurrency.format(pendingPrice)} 원',
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
                    '${formatCurrency.format(pendingPrice)} 원',
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
              _buildPaymentButton(pendingPrice, uid),
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

  void _launchBankPaymentPage(
    String amount,
    String userId,
    String phoneNo,
    String paymentId,
    String option,
    String dm,
  ) async {
    final url = Uri.parse(
      'https://pay.pang2chocolate.com/b-payment.html?paymentId=$paymentId&amount=$amount&userId=$userId&phoneNo=$phoneNo&option=$option&dm=$dm',
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
    String option,
    String dm,
  ) async {
    final url = Uri.parse(
      'https://pay.pang2chocolate.com/r-b-payment.html?paymentId=$paymentId&amount=$amount&userId=$userId&phoneNo=$phoneNo&payerId=$payerId&option=$option&dm=$dm',
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
    await FirebaseFirestore.instance.collection('usercached_values').doc(uid).set({
      'userId': uid,
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'phone': phoneController.text.trim(),
      'invoiceeType': invoiceeType,
      'invoiceeCorpNum': invoiceeCorpNumController.text.trim(),
      'invoiceeCorpName': invoiceeCorpNameController.text.trim(),
      'invoiceeCEOName': invoiceeCEONameController.text.trim(),
      // Address + delivery instructions cached so both BuyNow and Cart flows can reuse
      'deliveryAddressId': address.id,
      'deliveryAddress': address.address,
      'deliveryAddressDetail': address.detailAddress,
      'deliveryInstructions':
          selectedRequest == '직접입력'
              ? (manualRequest?.trim() ?? '')
              : selectedRequest,
      'recipientName': address.name,
      'recipientPhone': address.phone,
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
}
