import 'dart:async';
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

class PlaceOrder extends StatefulWidget {
  const PlaceOrder({super.key});

  @override
  State<PlaceOrder> createState() => _PlaceOrderState();
}

class _PlaceOrderState extends State<PlaceOrder> {
  // ── Tax invoice fields ────────────────────────────────────────────────────
  String invoiceeType = '사업자';
  final invoiceeCorpNumController = TextEditingController();
  final invoiceeCorpNameController = TextEditingController();
  final invoiceeCEONameController = TextEditingController();

  // ── Controllers ───────────────────────────────────────────────────────────
  List<Map<String, dynamic>> bankAccounts = [];
  int selectedBankIndex = -1;
  bool isAddingNewBank = false;
  final deliveryAddressController = TextEditingController();
  final phoneController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();

  // Only one FormKey — lives inside the receipt/invoice bottom sheet
  final _bottomSheetFormKey = GlobalKey<FormState>();

  // ── Address ───────────────────────────────────────────────────────────────
  Address address = Address(
    id: '',
    name: '',
    phone: '',
    address: '',
    detailAddress: '',
    isDefault: false,
    addressMap: {},
  );

  // ── Delivery request ──────────────────────────────────────────────────────
  final List<String> deliveryRequests = [
    '문앞',
    '직접 받고 부재 시 문앞',
    '택배함',
    '경비실',
    '직접입력',
  ];
  String selectedRequest = '문앞';
  String? manualRequest;

  // ── Payment state ─────────────────────────────────────────────────────────
  int selectedOption = 1;
  bool isProcessing = false;
  String? currentPaymentId;
  final Set<String> _finalizedPayments = {};
  Map<String, dynamic>? userBank;

  // ── Background subscription ───────────────────────────────────────────────
  // Safety net: runs independently of the StreamBuilder so payment success
  // is caught even when the app is backgrounded or the widget is off-screen.
  StreamSubscription<QuerySnapshot>? _pendingOrderSub;

  final formatCurrency = NumberFormat('#,###');

  // ───────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ───────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pendingOrderSub?.cancel();
    invoiceeCorpNumController.dispose();
    invoiceeCorpNameController.dispose();
    invoiceeCEONameController.dispose();
    deliveryAddressController.dispose();
    phoneController.dispose();
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // refreshCartPrices runs here at page load — NOT in _handlePlaceOrder.
    // This keeps _handlePlaceOrder fully synchronous (zero awaits before
    // launchUrl), satisfying the browser user-gesture requirement.
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) await refreshCartPrices(uid);
    await _fetchBankAccounts();
    await _fetchUserPaymentInfo();
    await _loadCachedUserValues();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DATA FETCHING
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _fetchBankAccounts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = userDoc.data();
    if (data != null && data['bankAccounts'] != null) {
      final accounts = List<Map<String, dynamic>>.from(data['bankAccounts']);
      if (mounted) {
        setState(() {
          bankAccounts = accounts;
          selectedBankIndex = accounts.isNotEmpty ? 0 : -1;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          bankAccounts = [];
          selectedBankIndex = -1;
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
    if (mounted) {
      setState(() {
        userBank = data?['bank'] as Map<String, dynamic>?;
      });
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
    if (!doc.exists || !mounted) return;
    final data = doc.data();
    if (data == null) return;
    setState(() {
      nameController.text = data['name'] ?? '';
      emailController.text = data['email'] ?? '';
      phoneController.text = data['phone'] ?? '';
      invoiceeType = data['invoiceeType'] ?? '사업자';
      invoiceeCorpNumController.text = data['invoiceeCorpNum'] ?? '';
      invoiceeCorpNameController.text = data['invoiceeCorpName'] ?? '';
      invoiceeCEONameController.text = data['invoiceeCEOName'] ?? '';
      selectedOption = data['selectedOption'] ?? 1;

      // Restore delivery request
      final cachedRequest = data['deliveryInstructions'] as String?;
      if (cachedRequest != null && deliveryRequests.contains(cachedRequest)) {
        selectedRequest = cachedRequest;
      }

      // Restore address
      final cachedAddressId = (data['deliveryAddressId'] ?? '') as String;
      if (cachedAddressId.isNotEmpty) {
        address = Address(
          id: cachedAddressId,
          name: data['recipientName'] ?? '',
          phone: data['recipientPhone'] ?? '',
          address: data['deliveryAddress'] ?? '',
          detailAddress: data['deliveryAddressDetail'] ?? '',
          isDefault: false,
          addressMap: {},
        );
        deliveryAddressController.text = data['deliveryAddress'] ?? '';
      }
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CACHE SAVE
  //
  // showFeedback: false (default) → silent, for auto-saves
  // showFeedback: true            → shows snackbar, for explicit 저장 button
  // ───────────────────────────────────────────────────────────────────────────

  Future<bool> _saveCachedUserValues({bool showFeedback = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      await FirebaseFirestore.instance
          .collection('usercached_values')
          .doc(uid)
          .set({
            'userId': uid,
            'name': nameController.text.trim(),
            'email': emailController.text.trim(),
            'phone': phoneController.text.trim(),
            'invoiceeType': invoiceeType,
            'invoiceeCorpNum': invoiceeCorpNumController.text.trim(),
            'invoiceeCorpName': invoiceeCorpNameController.text.trim(),
            'invoiceeCEOName': invoiceeCEONameController.text.trim(),
            'selectedOption': selectedOption,
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

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('정보가 저장되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (e) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ADDRESS SELECTION
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _selectAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddressListScreen()),
    );
    if (result != null) {
      deliveryAddressController.text = result.address;
      setState(() => address = result);
      _saveCachedUserValues(); // silent
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // RECEIPT FIELD VALIDATION
  // ───────────────────────────────────────────────────────────────────────────

  bool _validateReceiptTypeFields() {
    if (selectedOption == 1) {
      if (nameController.text.trim().isEmpty ||
          emailController.text.trim().isEmpty ||
          phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현금 영수증: 이름, 이메일, 전화번호를 모두 입력해주세요')),
        );
        return false;
      }
    } else if (selectedOption == 2) {
      if (nameController.text.trim().isEmpty ||
          emailController.text.trim().isEmpty ||
          phoneController.text.trim().isEmpty ||
          invoiceeType.isEmpty ||
          invoiceeCorpNumController.text.trim().isEmpty ||
          invoiceeCorpNameController.text.trim().isEmpty ||
          invoiceeCEONameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('세금 계산서: 모든 필수 필드를 입력해주세요')),
        );
        return false;
      }
    }
    return true;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BACKGROUND SUBSCRIPTION
  //
  // Runs in parallel with the StreamBuilder.
  // Guarantees finalization even when:
  //   • User backgrounds the app during payment
  //   • StreamBuilder widget is temporarily off-screen / paused
  //   • App is resumed after the cloud function already wrote success
  //
  // _finalizedPayments set prevents double-execution between the subscription
  // and the StreamBuilder both firing on the same paymentId.
  // ───────────────────────────────────────────────────────────────────────────

  void _subscribePendingOrder(String paymentId, String uid) {
    _pendingOrderSub?.cancel();
    _pendingOrderSub = FirebaseFirestore.instance
        .collection('pending_orders')
        .where('userId', isEqualTo: uid)
        .where('paymentId', isEqualTo: paymentId)
        .snapshots()
        .listen((snapshot) async {
          if (!mounted) return;

          // Doc missing: cloud function may have already cleaned up and
          // navigated via StreamBuilder. Check orders collection as fallback.
          if (snapshot.docs.isEmpty) {
            try {
              final orderQuery =
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .where('paymentId', isEqualTo: paymentId)
                      .where('userId', isEqualTo: uid)
                      .limit(1)
                      .get();
              if (orderQuery.docs.isNotEmpty &&
                  !_finalizedPayments.contains(paymentId) &&
                  mounted) {
                _finalizedPayments.add(paymentId);
                await _finalizeOrderAfterPayment([], uid);
              }
            } catch (_) {}
            return;
          }

          final doc = snapshot.docs.first;
          final status = doc['status'] as String?;

          if (status == 'success') {
            final pid = doc['paymentId'] as String?;
            if (pid != null && !_finalizedPayments.contains(pid) && mounted) {
              _finalizedPayments.add(pid);
              if (!isProcessing) setState(() => isProcessing = true);
              await _finalizeOrderAfterPayment([doc], uid);
            }
          } else if (status == 'failed') {
            try {
              await doc.reference.delete();
            } catch (_) {}
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('결제 실패. 다시 시도해주세요.'),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() {
                currentPaymentId = null;
                isProcessing = false;
              });
            }
          }
        });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ORDER PLACEMENT  — fully synchronous, zero awaits before launchUrl
  // ───────────────────────────────────────────────────────────────────────────

  void _handlePlaceOrder(int totalPrice, String uid) {
    if (selectedOption != 1 && selectedOption != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현금 영수증 또는 세금 계산서를 선택해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_validateReceiptTypeFields()) return;

    setState(() => isProcessing = true);

    final docRef = FirebaseFirestore.instance.collection('orders').doc();
    final paymentId = docRef.id;
    currentPaymentId = paymentId;

    // Start background subscription before launching URL.
    // No await — purely synchronous stream setup.
    _subscribePendingOrder(paymentId, uid);

    String? payerId;
    if (bankAccounts.isNotEmpty &&
        selectedBankIndex >= 0 &&
        selectedBankIndex < bankAccounts.length) {
      payerId = bankAccounts[selectedBankIndex]['payerId'] as String?;
    }

    // launchUrl fires immediately — nothing async above this point
    if (payerId != null && payerId.isNotEmpty) {
      _launchBankRpaymentPage(
        totalPrice.toString(),
        uid,
        phoneController.text.trim(),
        paymentId,
        payerId,
        selectedOption.toString(),
      );
    } else {
      _launchBankPaymentPage(
        totalPrice.toString(),
        uid,
        phoneController.text.trim(),
        paymentId,
        selectedOption.toString(),
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PAYMENT BUTTON  — StreamBuilder handles the normal (foreground) case
  // ───────────────────────────────────────────────────────────────────────────

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
            try {
              await pendingDoc.reference.delete();
            } catch (_) {}
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('결제 실패. 다시 시도해주세요.'),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() {
                currentPaymentId = null;
                isProcessing = false;
              });
            }
          });
          return const SizedBox.shrink();
        }

        if (status == 'success') {
          final paymentId = pendingDoc['paymentId'] as String?;
          if (paymentId != null && !_finalizedPayments.contains(paymentId)) {
            _finalizedPayments.add(paymentId);
            if (!isProcessing) setState(() => isProcessing = true);
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
                style: const TextStyle(color: Colors.green),
              ),
              if (isProcessing) ...[
                SizedBox(height: 8),
                const CircularProgressIndicator(),
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
                  _pendingOrderSub?.cancel();
                  _pendingOrderSub = null;
                  try {
                    await pendingDoc.reference.delete();
                  } catch (_) {}
                  setState(() {
                    currentPaymentId = null;
                    isProcessing = false;
                  });
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
                color: Colors.grey.shade400,
                txtColor: Colors.white,
              ),
              SizedBox(height: 8),
              const CircularProgressIndicator(),
              SizedBox(height: 8),
              const Text(
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

  // ───────────────────────────────────────────────────────────────────────────
  // FINALIZE
  //
  // Backend already handled everything (order creation, stock, settlements,
  // receipts, cart cleanup). We just delete the pending_orders doc and go.
  // Called by both the StreamBuilder and the background subscription —
  // _finalizedPayments ensures only one of them actually executes.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _finalizeOrderAfterPayment(
    List<QueryDocumentSnapshot> pendingDocs,
    String uid,
  ) async {
    if (!mounted) return;
    setState(() => isProcessing = true);
    try {
      _pendingOrderSub?.cancel();
      _pendingOrderSub = null;

      if (pendingDocs.isNotEmpty) {
        try {
          await pendingDocs.first.reference.delete();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          isProcessing = false;
          currentPaymentId = null;
        });
        context.go(Routes.orderCompleteScreen);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('주문 완료 처리 중 오류가 발생했습니다.')));
        setState(() => isProcessing = false);
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BANK ACCOUNT BOTTOM SHEET
  // ───────────────────────────────────────────────────────────────────────────

  void _showBankAccountDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Padding(
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
                  verticalSpace(16),
                  if (bankAccounts.isEmpty)
                    const Text(
                      '등록된 계좌가 없습니다.',
                      style: TextStyle(color: Colors.black),
                    ),
                  ...bankAccounts.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final acc = entry.value;
                    return Column(
                      children: [
                        ListTile(
                          title: Text(
                            '${acc['bankName']} / ${acc['bankNumber']}',
                            style: const TextStyle(color: Colors.black),
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
                        ),
                        verticalSpace(5),
                      ],
                    );
                  }),
                  WideTextButton(
                    txt: '새 계좌 등록하기',
                    func: () {
                      setState(() {
                        selectedBankIndex = -1;
                        isAddingNewBank = true;
                      });
                      setStateDialog(() {});
                      Navigator.of(context).pop();
                    },
                    color: Colors.black,
                    txtColor: Colors.white,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BUILD
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return SafeArea(
      child: StreamBuilder(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          final isSub = userSnapshot.data?.get('isSub') ?? false;

          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios),
              ),
              title: Text(
                "주문 / 결제",
                style: TextStyle(
                  fontFamily: 'NotoSans',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            body: Padding(
              padding: EdgeInsets.only(left: 15, top: 10, right: 15),
              child: ListView(
                children: [
                  // ── Cart items card ───────────────────────────────────────
                  Container(
                    padding: EdgeInsets.only(
                      left: 15,
                      top: 15,
                      bottom: 15,
                      right: 15,
                    ),
                    decoration: ShapeDecoration(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(width: 1.5, color: Colors.black),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '구매목록',
                          style: TextStyles.abeezee16px400wPblack.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        verticalSpace(10),
                        StreamBuilder(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection('cart')
                                  .snapshots(),
                          builder: (context, cartSnapshot) {
                            if (cartSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final cartDocs = cartSnapshot.data!.docs;
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              separatorBuilder:
                                  (_, index) =>
                                      index == cartDocs.length - 1
                                          ? const SizedBox.shrink()
                                          : verticalSpace(10),
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
                                      return const ListTile(
                                        title: Text('로딩 중...'),
                                      );
                                    }
                                    final productData =
                                        productSnapshot.data!.data()
                                            as Map<String, dynamic>;
                                    return Row(
                                      children: [
                                        Image.network(
                                          productData['imgUrl'] ?? '',
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, __, ___) => SizedBox(
                                                width: 80,
                                                height: 80,
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                ),
                                              ),
                                        ),
                                        horizontalSpace(10),
                                        Flexible(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${productData['productName']}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 16,
                                                  fontFamily: 'NotoSans',
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.40,
                                                ),
                                              ),
                                              verticalSpace(8),
                                              StreamBuilder<int>(
                                                stream: getProductQuantityStream(
                                                  cartData['product_id'],
                                                  cartData['pricePointIndex'],
                                                ),
                                                builder: (context, snapshot) {
                                                  final quan =
                                                      snapshot.data ?? 0;
                                                  return Text(
                                                    '$quan 개',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 16,
                                                      fontFamily: 'NotoSans',
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      height: 1.40,
                                                    ),
                                                  );
                                                },
                                              ),
                                              SizedBox(height: 8),
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
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 16,
                                                      fontFamily: 'NotoSans',
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      height: 1.40,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
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
                  verticalSpace(10),

                  // ── Address card ──────────────────────────────────────────
                  Container(
                    padding: EdgeInsets.only(left: 15, top: 15, bottom: 15),
                    decoration: ShapeDecoration(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(width: 1.5, color: Colors.black),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child:
                              address.name.isEmpty
                                  ? FutureBuilder(
                                    future:
                                        FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(uid)
                                            .get(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      if (snapshot.hasError ||
                                          !snapshot.hasData ||
                                          !snapshot.data!.exists) {
                                        return const Center(
                                          child: Text('User data not found'),
                                        );
                                      }
                                      final userData = snapshot.data!.data()!;
                                      if ((userData['defaultAddressId'] ?? '')
                                          .isEmpty) {
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
                                                color: const Color(0xFF9E9E9E),
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
                                                .doc(uid)
                                                .collection('addresses')
                                                .doc(
                                                  userData['defaultAddressId'],
                                                )
                                                .get(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                          if (!snapshot.hasData ||
                                              !snapshot.data!.exists) {
                                            return const Center(
                                              child: Text(
                                                'User data not found',
                                              ),
                                            );
                                          }
                                          final d = snapshot.data!.data()!;
                                          return _buildAddressText(
                                            label: '배송지 정보 (기본 배송지)',
                                            name: d['name'] ?? '',
                                            phone: d['phone'] ?? '',
                                            address: d['address'] ?? '',
                                          );
                                        },
                                      );
                                    },
                                  )
                                  : _buildAddressText(
                                    label: '배송지 정보 (기본 배송지)',
                                    name: address.name,
                                    phone: address.phone,
                                    address: address.detailAddress,
                                  ),
                        ),
                        IconButton(
                          onPressed: _selectAddress,
                          icon: Icon(
                            Icons.arrow_forward_ios_sharp,
                            size: 30,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  verticalSpace(10),

                  // ── Settings cards ────────────────────────────────────────
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Delivery request card ─────────────────────────────
                      Container(
                        padding: EdgeInsets.fromLTRB(15, 15, 0, 15),
                        decoration: ShapeDecoration(
                          color: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(
                              width: 1.5,
                              color: Colors.black,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: StatefulBuilder(
                          builder: (context, setStateLocal) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '배송 요청사항',
                                        style: TextStyles.abeezee16px400wPblack
                                            .copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      verticalSpace(5),
                                      Text(
                                        selectedRequest,
                                        style: TextStyle(
                                          color: Colors.grey[800],
                                          fontSize: 16,
                                          fontFamily: 'NotoSans',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      if (selectedRequest == '직접입력') ...[
                                        SizedBox(height: 12),
                                        TextFormField(
                                          initialValue: manualRequest,
                                          onChanged: (text) {
                                            setState(
                                              () => manualRequest = text,
                                            );
                                            _saveCachedUserValues();
                                          },
                                          decoration: InputDecoration(
                                            labelText: '직접 입력',
                                            hintText: '배송 요청을 입력하세요',
                                            border: const OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 14,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 30,
                                    color: Colors.black,
                                  ),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      backgroundColor: Colors.white,
                                      context: context,
                                      builder: (context) {
                                        return Padding(
                                          padding: EdgeInsets.all(15),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children:
                                                deliveryRequests
                                                    .map(
                                                      (req) => ListTile(
                                                        title: Text(
                                                          req,
                                                          style: TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 16,
                                                            fontFamily:
                                                                'NotoSans',
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                        ),
                                                        onTap: () {
                                                          setStateLocal(() {
                                                            selectedRequest =
                                                                req;
                                                            if (req != '직접입력') {
                                                              manualRequest =
                                                                  null;
                                                            }
                                                          });
                                                          setState(() {});
                                                          _saveCachedUserValues();
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                        },
                                                      ),
                                                    )
                                                    .toList(),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      verticalSpace(10),

                      // ── Bank account card (only if accounts exist) ────────
                      if (bankAccounts.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.fromLTRB(15, 15, 0, 15),
                          decoration: ShapeDecoration(
                            color: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                width: 1.5,
                                color: Colors.black,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '간편 계좌 결제',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontFamily: 'NotoSans',
                                        fontWeight: FontWeight.w800,
                                        height: 1.40,
                                      ),
                                    ),
                                    verticalSpace(5),
                                    Text(
                                      (selectedBankIndex >= 0 &&
                                              selectedBankIndex <
                                                  bankAccounts.length)
                                          ? '${bankAccounts[selectedBankIndex]['bankName']} / ${bankAccounts[selectedBankIndex]['bankNumber']}'
                                          : '주문과 동시에 새 계좌 등록이 진행됩니다.',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed:
                                    isProcessing
                                        ? null
                                        : _showBankAccountDialog,
                                icon: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 30,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        verticalSpace(10),
                      ],

                      // ── Receipt / invoice card ────────────────────────────
                      Container(
                        padding: EdgeInsets.fromLTRB(15, 15, 0, 15),
                        decoration: ShapeDecoration(
                          color: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(
                              width: 1.5,
                              color: Colors.black,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '현금영수증 · 세금계산서',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                      fontFamily: 'NotoSans',
                                      fontWeight: FontWeight.w800,
                                      height: 1.40,
                                    ),
                                  ),
                                  verticalSpace(5),
                                  Text(
                                    selectedOption == 1
                                        ? '현금 영수증'
                                        : selectedOption == 2
                                        ? '세금 계산서'
                                        : '필요 없음',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.white,
                                  isScrollControlled: true,
                                  builder: (context) {
                                    return StatefulBuilder(
                                      builder: (context, setStateSheet) {
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            top: 20,
                                            left: 20,
                                            right: 20,
                                            bottom:
                                                MediaQuery.of(
                                                  context,
                                                ).viewInsets.bottom +
                                                20,
                                          ),
                                          child: SingleChildScrollView(
                                            child: Form(
                                              key: _bottomSheetFormKey,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      _buildRadioOption(
                                                        value: 1,
                                                        label: '현금 영수증',
                                                        setStateSheet:
                                                            setStateSheet,
                                                      ),
                                                      _buildRadioOption(
                                                        value: 2,
                                                        label: '세금 계산서',
                                                        setStateSheet:
                                                            setStateSheet,
                                                      ),
                                                    ],
                                                  ),
                                                  if (selectedOption == 1)
                                                    ..._buildCashReceiptFields()
                                                  else
                                                    ..._buildTaxInvoiceFields(
                                                      setStateSheet,
                                                    ),
                                                  verticalSpace(10),
                                                  WideTextButton(
                                                    txt: '저장',
                                                    func: () async {
                                                      if (!_bottomSheetFormKey
                                                          .currentState!
                                                          .validate()) {
                                                        return;
                                                      }
                                                      final success =
                                                          await _saveCachedUserValues(
                                                            showFeedback: true,
                                                          );
                                                      if (success && mounted) {
                                                        Navigator.pop(context);
                                                      }
                                                    },
                                                    color: Colors.black,
                                                    txtColor: Colors.white,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                              icon: Icon(
                                Icons.arrow_forward_ios,
                                size: 30,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      verticalSpace(10),
                    ],
                  ),

                  verticalSpace(15),
                ],
              ),
            ),

            // ── Bottom bar ───────────────────────────────────────────────────
            bottomNavigationBar: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('cart')
                      .snapshots(),
              builder: (context, cartSnapshot) {
                if (!cartSnapshot.hasData || cartSnapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }
                return StreamBuilder<int>(
                  stream: calculateCartTotal(cartSnapshot.data!.docs, isSub),
                  builder: (context, totalSnapshot) {
                    final totalPrice = totalSnapshot.data ?? 0;
                    return Container(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 28),
                      decoration: const BoxDecoration(color: Colors.white),
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
                                  : const CircularProgressIndicator(),
                            ],
                          ),
                          verticalSpace(8),
                          _buildPaymentButton(totalPrice, uid),
                          if (bankAccounts.isEmpty) ...[
                            verticalSpace(8),
                            Text(
                              '* 간편결제 계좌 등록 후 결제가 진행됩니다',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.w800,
                                height: 1.40,
                              ),
                            ),
                          ],
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

  // ───────────────────────────────────────────────────────────────────────────
  // UI HELPERS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildAddressText({
    required String label,
    required String name,
    required String phone,
    required String address,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyles.abeezee16px400wPblack.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        verticalSpace(5),
        Text(name, style: _greyStyle()),
        Text(phone, style: _greyStyle()),
        Text(address, style: _greyStyle()),
      ],
    );
  }

  TextStyle _greyStyle() => TextStyle(
    fontSize: 15,
    color: Colors.grey[800],
    fontFamily: 'NotoSans',
    fontWeight: FontWeight.w400,
    height: 1.40,
  );

  Widget _buildRadioOption({
    required int value,
    required String label,
    required StateSetter setStateSheet,
  }) {
    return Row(
      children: [
        Transform.scale(
          scale: 20 / 15,
          child: Radio<int>(
            value: value,
            groupValue: selectedOption,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            onChanged: (v) {
              setStateSheet(() => selectedOption = v!);
              setState(() {});
            },
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w800,
            color: ColorsManager.primaryblack,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCashReceiptFields() => [
    UnderlineTextField(
      controller: nameController,
      hintText: '이름',
      obscureText: false,
      keyboardType: TextInputType.text,
      validator:
          (val) => (val == null || val.trim().isEmpty) ? '이름을 입력해주세요' : null,
      onChanged: (_) => null,
    ),
    SizedBox(height: 10),
    UnderlineTextField(
      controller: emailController,
      hintText: '이메일',
      obscureText: false,
      keyboardType: TextInputType.emailAddress,
      validator: (val) {
        if (val == null || val.trim().isEmpty) return '이메일을 입력해주세요';
        if (!RegExp(r'^.+@.+\..+$').hasMatch(val.trim())) {
          return '유효한 이메일을 입력해주세요';
        }
        return null;
      },
      onChanged: (_) => null,
    ),
    SizedBox(height: 10),
    UnderlineTextField(
      controller: phoneController,
      hintText: '전화번호',
      obscureText: false,
      keyboardType: TextInputType.phone,
      validator: (val) {
        if (val == null || val.trim().isEmpty) return '전화번호를 입력해주세요';
        if (!RegExp(
          r'^01([0|1|6|7|8|9])-?([0-9]{3,4})-?([0-9]{4})$',
        ).hasMatch(val)) {
          return '유효한 한국 전화번호를 입력하세요';
        }
        return null;
      },
      onChanged: (_) => null,
    ),
  ];

  List<Widget> _buildTaxInvoiceFields(StateSetter setStateSheet) => [
    DropdownButtonFormField<String>(
      dropdownColor: Colors.white,
      value: invoiceeType,
      items:
          [
            '사업자',
            '개인',
            '외국인',
          ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (val) {
        setStateSheet(() => invoiceeType = val ?? '사업자');
      },
      decoration: const InputDecoration(
        border: UnderlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),
      icon: const Icon(Icons.keyboard_arrow_down),
    ),
    SizedBox(height: 10),
    UnderlineTextField(
      obscureText: false,
      controller: invoiceeCorpNumController,
      hintText: '공급받는자 사업자번호',
      keyboardType: TextInputType.number,
      validator: (val) {
        if (val == null || val.trim().isEmpty) return '사업자번호를 입력해주세요';
        final cleaned = val.trim().replaceAll('-', '');
        if (!RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
          return '사업자번호는 숫자만 입력 가능합니다';
        }
        if (cleaned.length != 10) {
          return '사업자번호는 숫자 10자리여야 합니다 (예: 123-45-67890)';
        }
        return null;
      },
      onChanged: (_) => null,
    ),
    SizedBox(height: 10),
    UnderlineTextField(
      obscureText: false,
      controller: invoiceeCorpNameController,
      hintText: '공급받는자 상호',
      keyboardType: TextInputType.text,
      validator: (val) {
        if (val == null || val.trim().isEmpty) return '이름을 입력해주세요';
        if (val.trim().length > 200) return '입력은 최대 200자까지 가능합니다';
        return null;
      },
      onChanged: (_) => null,
    ),
    SizedBox(height: 10),
    UnderlineTextField(
      obscureText: false,
      controller: invoiceeCEONameController,
      hintText: '공급받는자 대표자 성명',
      keyboardType: TextInputType.text,
      validator: (val) {
        if (val == null || val.trim().isEmpty) return '대표자 성명을 입력해주세요';
        if (val.trim().length > 200) return '입력은 최대 200자까지 가능합니다';
        return null;
      },
      onChanged: (_) => null,
    ),
    SizedBox(height: 10),
    UnderlineTextField(
      controller: emailController,
      hintText: '이메일',
      obscureText: false,
      keyboardType: TextInputType.emailAddress,
      validator: (val) {
        if (val == null || val.trim().isEmpty) return '이메일을 입력해주세요';
        if (!RegExp(r'^.+@.+\..+$').hasMatch(val.trim())) {
          return '유효한 이메일을 입력해주세요';
        }
        return null;
      },
      onChanged: (_) => null,
    ),
    SizedBox(height: 10),
    UnderlineTextField(
      controller: phoneController,
      hintText: '전화번호',
      obscureText: false,
      keyboardType: TextInputType.phone,
      validator: (val) {
        if (val == null || val.trim().isEmpty) return '전화번호를 입력해주세요';
        if (!RegExp(
          r'^01([0|1|6|7|8|9])-?([0-9]{3,4})-?([0-9]{4})$',
        ).hasMatch(val)) {
          return '유효한 한국 전화번호를 입력하세요';
        }
        return null;
      },
      onChanged: (_) => null,
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT URL LAUNCHERS
//
// Top-level void functions — called without await from _handlePlaceOrder.
// LaunchMode.externalApplication opens the system browser so the Payple
// widget runs in its own context, outside the Flutter webview.
// ─────────────────────────────────────────────────────────────────────────────

void _launchBankPaymentPage(
  String amount,
  String userId,
  String phoneNo,
  String paymentId,
  String option,
) {
  launchUrl(
    Uri.parse(
      'https://pay.pang2chocolate.com/b-payment.html'
      '?paymentId=$paymentId&amount=$amount&userId=$userId'
      '&phoneNo=$phoneNo&option=$option',
    ),
    mode: LaunchMode.externalApplication,
  );
}

void _launchBankRpaymentPage(
  String amount,
  String userId,
  String phoneNo,
  String paymentId,
  String payerId,
  String option,
) {
  launchUrl(
    Uri.parse(
      'https://pay.pang2chocolate.com/r-b-payment.html'
      '?paymentId=$paymentId&amount=$amount&userId=$userId'
      '&phoneNo=$phoneNo&payerId=$payerId&option=$option',
    ),
    mode: LaunchMode.externalApplication,
  );
}
