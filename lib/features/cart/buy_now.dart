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
  // paymentId comes from server (pre-created before navigation)
  final String? paymentId;

  // Optional display hints — real values come from pendingBuynowData
  final String? productName;
  final String? productImgUrl;

  const BuyNow({Key? key, this.paymentId, this.productName, this.productImgUrl})
    : super(key: key);

  @override
  State<BuyNow> createState() => _BuyNowState();
}

class _BuyNowState extends State<BuyNow> {
  // ── Receipt / invoice fields ──────────────────────────────────────────────
  String invoiceeType = '사업자';
  final invoiceeCorpNumController = TextEditingController();
  final invoiceeCorpNameController = TextEditingController();
  final invoiceeCEONameController = TextEditingController();

  // ── Misc controllers ──────────────────────────────────────────────────────
  bool isAddingNewBank = false;
  final deliveryAddressController = TextEditingController();
  final deliveryInstructionsController = TextEditingController();
  final cashReceiptController = TextEditingController();
  final phoneController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();

  // ── Form key (bottom sheet only) ──────────────────────────────────────────
  // Main screen has no inline form fields — all input lives in the bottom sheet.
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

  Map<String, dynamic>? userBank;

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

  // ── Bank accounts ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> bankAccounts = [];
  int selectedBankIndex = 0;

  // ── pending_buynow data loaded from Firestore ─────────────────────────────
  Map<String, dynamic>? pendingBuynowData;
  int pendingPrice = 0;
  int pendingQuantity = 0;

  final formatCurrency = NumberFormat('#,###');

  // ───────────────────────────────────────────────────────────────────────────
  // INIT
  // ───────────────────────────────────────────────────────────────────────────

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
      debugPrint('Error loading pending_buynow: $e');
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
          selectedOption = data['selectedOption'] ?? 1;
        });
      }
    }
  }

  /// Ensures usercached_values has address & delivery instructions so the
  /// backend has a reliable fallback if pending_buynow fields are missing.
  Future<void> _ensureCachedAddressAndInstructions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final cacheRef = FirebaseFirestore.instance
        .collection('usercached_values')
        .doc(uid);
    final cacheSnap = await cacheRef.get();
    final cacheData =
        cacheSnap.exists
            ? cacheSnap.data() as Map<String, dynamic>
            : <String, dynamic>{};

    final hasAddress =
        (cacheData['deliveryAddressId'] ?? '') != '' ||
        (cacheData['deliveryAddress'] ?? '') != '';
    final hasDeliveryInstr = (cacheData['deliveryInstructions'] ?? '') != '';

    if (hasAddress && hasDeliveryInstr) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final userData =
        userSnap.exists
            ? userSnap.data() as Map<String, dynamic>
            : <String, dynamic>{};
    final defaultAddressId = userData['defaultAddressId'] as String?;

    if (!hasAddress &&
        defaultAddressId != null &&
        defaultAddressId.isNotEmpty) {
      final addrSnap =
          await userRef.collection('addresses').doc(defaultAddressId).get();
      if (addrSnap.exists) {
        final addr = addrSnap.data() as Map<String, dynamic>;
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

        final addressPatch = {
          'deliveryAddressId': address.id,
          'deliveryAddress': address.address,
          'deliveryAddressDetail': address.detailAddress,
          'recipientName': address.name,
          'recipientPhone': address.phone,
        };

        await cacheRef.set(addressPatch, SetOptions(merge: true));

        // Also patch pending_buynow so backend's first-priority source is fresh
        _patchPendingBuynow(addressPatch);
      }
    }

    if (!hasDeliveryInstr) {
      final instructions =
          (pendingBuynowData != null &&
                  (pendingBuynowData?['deliveryInstructions'] ?? '') != '')
              ? pendingBuynowData!['deliveryInstructions'] as String
              : '';
      await cacheRef.set({
        'deliveryInstructions': instructions,
      }, SetOptions(merge: true));
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PATCH pending_buynow  (always fire-and-forget — never awaited)
  //
  // Writes the freshest address / delivery data into pending_buynow so the
  // backend reads it from its highest-priority source. This is intentionally
  // synchronous-looking (void, no await at call sites) so it never blocks the
  // user-gesture requirement that mobile browsers enforce on launchUrl.
  // ───────────────────────────────────────────────────────────────────────────

  void _patchPendingBuynow(Map<String, dynamic> fields) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.paymentId == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('pending_buynow')
        .doc(widget.paymentId)
        .set(fields, SetOptions(merge: true))
        .catchError((e) => debugPrint('Failed to patch pending_buynow: $e'));
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

      final patch = {
        'deliveryAddressId': result.id,
        'deliveryAddress': result.address,
        'deliveryAddressDetail': result.detailAddress,
        'recipientName': result.name,
        'recipientPhone': result.phone,
      };

      // Both fire-and-forget — address is now in pending_buynow and cache
      _patchPendingBuynow(patch);
      _saveCachedUserValues();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SAVE CACHE  (full snapshot of all user values including address fields)
  // ───────────────────────────────────────────────────────────────────────────

  Future<bool> _saveCachedUserValues() async {
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
            // Address + delivery fields so backend has a full fallback
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('정보가 저장되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
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
  // VALIDATION
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
  // ORDER PLACEMENT
  //
  // Intentionally void (not async) — zero awaits before launchUrl so the
  // browser's user-gesture requirement is always satisfied on mobile.
  // All data is already written into pending_buynow and usercached_values
  // by the time the user reaches this button.
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

    final paymentId = widget.paymentId;
    if (paymentId == null || paymentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주문 처리 중 오류가 발생했습니다. 다시 시도해주세요.')),
      );
      setState(() => isProcessing = false);
      return;
    }
    currentPaymentId = paymentId;

    String? payerId;
    if (bankAccounts.isNotEmpty &&
        selectedBankIndex >= 0 &&
        selectedBankIndex < bankAccounts.length) {
      payerId = bankAccounts[selectedBankIndex]['payerId'] as String?;
    }

    final dm = pendingBuynowData?['deliveryManagerId']?.toString() ?? '';

    // launchUrl fires immediately — nothing async above this point
    if (payerId != null && payerId.isNotEmpty) {
      _launchBankRpaymentPage(
        totalPrice.toString(),
        uid,
        phoneController.text.trim(),
        paymentId,
        payerId,
        selectedOption.toString(),
        dm,
      );
    } else {
      _launchBankPaymentPage(
        totalPrice.toString(),
        uid,
        phoneController.text.trim(),
        paymentId,
        selectedOption.toString(),
        dm,
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PAYMENT BUTTON  (StreamBuilder on pending_orders)
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

        // No pending doc → show Order button
        if (pendingDoc == null) {
          return WideTextButton(
            txt: '주문',
            func: () => _handlePlaceOrder(totalPrice, uid),
            color: Colors.black,
            txtColor: Colors.white,
          );
        }

        // Failed
        if (status == 'failed') {
          Future.microtask(() async {
            await pendingDoc.reference.delete();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('결제 실패. 다시 시도해주세요.'),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.pop(context);
            }
          });
          return const SizedBox.shrink();
        }

        // Success
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
                style: const TextStyle(color: Colors.green),
              ),
              if (isProcessing) ...[
                SizedBox(height: 8),
                const CircularProgressIndicator(),
              ],
            ],
          );
        }

        // Pending
        if (status == 'pending') {
          return Column(
            children: [
              WideTextButton(
                txt: '결제 진행 중... 취소',
                func: () async {
                  await pendingDoc.reference.delete();
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

        // Fallback
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
  // FINALIZE  (server already handled everything; just cleanup + navigate)
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _finalizeOrderAfterPayment(
    List<QueryDocumentSnapshot> pendingDocs,
    String uid,
  ) async {
    if (!mounted) return;
    setState(() => isProcessing = true);

    try {
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
      ).showSnackBar(const SnackBar(content: Text('주문 완료 처리 중 오류가 발생했습니다.')));
      setState(() => isProcessing = false);
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

    final displayName =
        pendingBuynowData?['product_name'] as String? ??
        widget.productName ??
        '';
    final displayImgUrl =
        pendingBuynowData?['imgUrl'] as String? ?? widget.productImgUrl ?? '';

    return SafeArea(
      child: Scaffold(
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
              // ── Product summary card ──────────────────────────────────────
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
                    Row(
                      children: [
                        if (displayImgUrl.isNotEmpty)
                          Image.network(
                            displayImgUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        horizontalSpace(10),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.w400,
                                height: 1.40,
                              ),
                            ),
                            verticalSpace(8),
                            Text(
                              '${pendingQuantity.toString()} 개',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.w400,
                                height: 1.40,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${formatCurrency.format(pendingPrice)} 원',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.w400,
                                height: 1.40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              verticalSpace(10),

              // ── Address card ──────────────────────────────────────────────
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
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return Center(
                                      child: Text('Error: ${snapshot.error}'),
                                    );
                                  }
                                  if (!snapshot.hasData ||
                                      !snapshot.data!.exists) {
                                    return const Center(
                                      child: Text('User data not found'),
                                    );
                                  }
                                  final userData = snapshot.data?.data();
                                  if (userData == null ||
                                      (userData['defaultAddressId'] ?? '') ==
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
                                            .doc(
                                              FirebaseAuth
                                                  .instance
                                                  .currentUser!
                                                  .uid,
                                            )
                                            .collection('addresses')
                                            .doc(userData['defaultAddressId'])
                                            .get(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      if (!snapshot.hasData ||
                                          !snapshot.data!.exists) {
                                        return const Center(
                                          child: Text('User data not found'),
                                        );
                                      }
                                      final addressData =
                                          snapshot.data!.data()!;
                                      return _buildAddressText(
                                        label: '배송지 정보 (기본 배송지)',
                                        name: addressData['name'] ?? '',
                                        phone: addressData['phone'] ?? '',
                                        address: addressData['address'] ?? '',
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

              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Delivery request card ─────────────────────────────────
                  Container(
                    padding: EdgeInsets.fromLTRB(15, 15, 0, 15),
                    decoration: ShapeDecoration(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(width: 1.5, color: Colors.black),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: StatefulBuilder(
                      builder: (context, setStateDropdown) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '배송 요청사항',
                                    style: TextStyles.abeezee16px400wPblack
                                        .copyWith(fontWeight: FontWeight.w800),
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
                                        setState(() => manualRequest = text);
                                        // Fire and forget — no await, never
                                        // blocks launchUrl gesture chain
                                        _patchPendingBuynow({
                                          'deliveryInstructions': text.trim(),
                                        });
                                        _saveCachedUserValues();
                                      },
                                      decoration: InputDecoration(
                                        labelText: '직접 입력',
                                        hintText: '배송 요청을 입력하세요',
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
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
                                                  (request) => ListTile(
                                                    title: Text(
                                                      request,
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 16,
                                                        fontFamily: 'NotoSans',
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                    ),
                                                    onTap: () {
                                                      setStateDropdown(() {
                                                        selectedRequest =
                                                            request;
                                                        if (selectedRequest !=
                                                            '직접입력') {
                                                          manualRequest = null;
                                                        }
                                                      });
                                                      setState(() {});

                                                      // Fire and forget
                                                      _patchPendingBuynow({
                                                        'deliveryInstructions':
                                                            request == '직접입력'
                                                                ? (manualRequest
                                                                        ?.trim() ??
                                                                    '')
                                                                : request,
                                                      });
                                                      _saveCachedUserValues();

                                                      Navigator.pop(context);
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

                  // ── Bank account card (only if accounts exist) ────────────
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
                                  (bankAccounts.isNotEmpty &&
                                          selectedBankIndex >= 0 &&
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
                                isProcessing ? null : _showBankAccountDialog,
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

                  // ── Receipt / invoice card ────────────────────────────────
                  Container(
                    padding: EdgeInsets.fromLTRB(15, 15, 0, 15),
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
                                  builder: (context, setStateRadio) {
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
                                                    setStateRadio:
                                                        setStateRadio,
                                                  ),
                                                  _buildRadioOption(
                                                    value: 2,
                                                    label: '세금 계산서',
                                                    setStateRadio:
                                                        setStateRadio,
                                                  ),
                                                ],
                                              ),
                                              if (selectedOption == 1)
                                                ..._buildCashReceiptFields()
                                              else
                                                ..._buildTaxInvoiceFields(
                                                  setStateRadio,
                                                ),
                                              verticalSpace(10),
                                              WideTextButton(
                                                txt: '저장',
                                                func: () async {
                                                  if (!_bottomSheetFormKey
                                                      .currentState!
                                                      .validate())
                                                    return;
                                                  final success =
                                                      await _saveCachedUserValues();
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

        // ── Bottom bar ───────────────────────────────────────────────────────
        bottomNavigationBar: Container(
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
              verticalSpace(8),
              _buildPaymentButton(pendingPrice, uid),
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
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SMALL UI HELPERS
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
    required StateSetter setStateRadio,
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
              setStateRadio(() => selectedOption = v!);
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
        if (!RegExp(r'^.+@.+\..+$').hasMatch(val.trim()))
          return '유효한 이메일을 입력해주세요';
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
        ).hasMatch(val))
          return '유효한 한국 전화번호를 입력하세요';
        return null;
      },
      onChanged: (_) => null,
    ),
  ];

  List<Widget> _buildTaxInvoiceFields(StateSetter setStateRadio) => [
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
        setStateRadio(() => invoiceeType = val ?? '사업자');
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
        if (!RegExp(r'^[0-9]+$').hasMatch(cleaned))
          return '사업자번호는 숫자만 입력 가능합니다';
        if (cleaned.length != 10)
          return '사업자번호는 숫자 10자리여야 합니다 (예: 123-45-67890)';
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
        if (!RegExp(r'^.+@.+\..+$').hasMatch(val.trim()))
          return '유효한 이메일을 입력해주세요';
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
        ).hasMatch(val))
          return '유효한 한국 전화번호를 입력하세요';
        return null;
      },
      onChanged: (_) => null,
    ),
  ];

  // ───────────────────────────────────────────────────────────────────────────
  // PAYMENT URL LAUNCHERS
  // ───────────────────────────────────────────────────────────────────────────

  void _launchBankPaymentPage(
    String amount,
    String userId,
    String phoneNo,
    String paymentId,
    String option,
    String dm,
  ) async {
    final url = Uri.parse(
      'https://pay.pang2chocolate.com/b-payment.html'
      '?paymentId=$paymentId&amount=$amount&userId=$userId'
      '&phoneNo=$phoneNo&option=$option&dm=$dm',
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
      'https://pay.pang2chocolate.com/r-b-payment.html'
      '?paymentId=$paymentId&amount=$amount&userId=$userId'
      '&phoneNo=$phoneNo&payerId=$payerId&option=$option&dm=$dm',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
