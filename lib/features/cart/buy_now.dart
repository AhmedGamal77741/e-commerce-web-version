import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/routing/routes.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/underline_text_filed.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:ecommerece_app/features/cart/models/address.dart';
import 'package:ecommerece_app/features/cart/slide_button.dart';
import 'package:ecommerece_app/features/cart/sub_screens/address_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class BuyNow extends StatefulWidget {
  final String? paymentId;
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

  // ── Controllers ───────────────────────────────────────────────────────────
  final deliveryAddressController = TextEditingController();
  final phoneController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();

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

  // ── Receipt option ────────────────────────────────────────────────────────
  int selectedOption = 1;

  // ── Bank accounts ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> bankAccounts = [];
  int selectedBankIndex = -1;

  // ── pending_buynow data ───────────────────────────────────────────────────
  Map<String, dynamic>? pendingBuynowData;
  int pendingPrice = 0;
  int pendingQuantity = 0;

  // ── Payment state ─────────────────────────────────────────────────────────
  bool isProcessing = false;
  String? currentPaymentId;

  // ── Guards ────────────────────────────────────────────────────────────────
  bool _bankAccountsFetched = false;

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _loadPendingBuynowData();
    await Future.wait([_fetchBankAccounts(), _loadCachedUserValues()]);
    await _ensureCachedAddressAndInstructions(uid);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bankAccountsFetched) {
      _bankAccountsFetched = true;
    } else {
      _fetchBankAccounts();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DATA FETCHING
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _fetchBankAccounts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data();
    if (data != null && data['bankAccounts'] != null) {
      final accounts = List<Map<String, dynamic>>.from(data['bankAccounts']);
      if (mounted)
        setState(() {
          bankAccounts = accounts;
          selectedBankIndex = accounts.isNotEmpty ? 0 : -1;
        });
    } else {
      if (mounted)
        setState(() {
          bankAccounts = [];
          selectedBankIndex = -1;
        });
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
      if (doc.exists && mounted) {
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

      final cachedInstr = data['deliveryInstructions'] as String? ?? '';
      if (deliveryRequests.contains(cachedInstr)) {
        selectedRequest = cachedInstr;
        manualRequest = null;
      } else if (cachedInstr.isNotEmpty) {
        selectedRequest = '직접입력';
        manualRequest = cachedInstr;
      }

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

  Future<void> _ensureCachedAddressAndInstructions(String uid) async {
    final hasAddress = address.id.isNotEmpty;
    final hasInstr =
        selectedRequest != '문앞' ||
        (manualRequest != null && manualRequest!.isNotEmpty);

    if (hasAddress && hasInstr) return;

    final cacheRef = FirebaseFirestore.instance
        .collection('usercached_values')
        .doc(uid);

    if (!hasAddress) {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userSnap = await userRef.get();
      if (!userSnap.exists) return;

      final userData = userSnap.data() as Map<String, dynamic>;
      final defaultAddressId = userData['defaultAddressId'] as String?;
      if (defaultAddressId == null || defaultAddressId.isEmpty) return;

      final addrSnap =
          await userRef.collection('addresses').doc(defaultAddressId).get();
      if (!addrSnap.exists) return;

      final addr = addrSnap.data() as Map<String, dynamic>;
      final resolved = Address(
        id: addr['id'] ?? defaultAddressId,
        name: addr['name'] ?? '',
        phone: addr['phone'] ?? '',
        address: addr['address'] ?? '',
        detailAddress: addr['detailAddress'] ?? '',
        isDefault: addr['isDefault'] ?? false,
        addressMap: addr['addressMap'] ?? {},
      );

      if (mounted)
        setState(() {
          address = resolved;
          deliveryAddressController.text = resolved.address;
        });

      final addressPatch = {
        'deliveryAddressId': resolved.id,
        'deliveryAddress': resolved.address,
        'deliveryAddressDetail': resolved.detailAddress,
        'recipientName': resolved.name,
        'recipientPhone': resolved.phone,
      };
      await cacheRef.set(addressPatch, SetOptions(merge: true));
      _patchPendingBuynow(addressPatch);
    }

    if (!hasInstr) {
      final instrFromOrder =
          (pendingBuynowData?['deliveryInstructions'] ?? '') as String;
      if (instrFromOrder.isNotEmpty) {
        if (deliveryRequests.contains(instrFromOrder)) {
          if (mounted) setState(() => selectedRequest = instrFromOrder);
        } else {
          if (mounted) {
            setState(() {
              selectedRequest = '직접입력';
              manualRequest = instrFromOrder;
            });
          }
        }
        await cacheRef.set({
          'deliveryInstructions': instrFromOrder,
        }, SetOptions(merge: true));
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BANK ACCOUNT DELETE
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _deleteBankAccount(String uid, String payerId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await userRef.get();
    final data = snap.data();
    if (data == null) return;

    final accounts = List<Map<String, dynamic>>.from(
      data['bankAccounts'] ?? [],
    );
    accounts.removeWhere((b) => b['payerId'] == payerId);
    await userRef.update({'bankAccounts': accounts});

    if (mounted)
      setState(() {
        bankAccounts = accounts;
        selectedBankIndex = accounts.isNotEmpty ? 0 : -1;
      });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PATCH pending_buynow
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
      _patchPendingBuynow(patch);
      _saveCachedUserValues();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CACHE SAVE
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
  // BANK REGISTRATION
  // ───────────────────────────────────────────────────────────────────────────

  void _launchBankRegistration(String uid) {
    final regPaymentId = FirebaseFirestore.instance.collection('_tmp').doc().id;

    launchUrl(
      Uri.parse(
        'https://pay.pang2chocolate.com/bank-register.html'
        '?userId=${Uri.encodeComponent(uid)}'
        '&paymentId=${Uri.encodeComponent(regPaymentId)}'
        '&phoneNo=${Uri.encodeComponent(phoneController.text.trim())}'
        '&option=${Uri.encodeComponent(selectedOption.toString())}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ORDER PLACEMENT
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _handlePlaceOrder(String uid) async {
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

    if (bankAccounts.isEmpty || selectedBankIndex < 0) {
      _showBankAccountBottomSheet(uid);
      return;
    }

    final payerId = bankAccounts[selectedBankIndex]['payerId'] as String? ?? '';
    if (payerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('계좌 정보가 올바르지 않습니다. 계좌를 다시 등록해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final paymentId = widget.paymentId;
    if (paymentId == null || paymentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('주문 처리 중 오류가 발생했습니다. 다시 시도해 주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final dm = pendingBuynowData?['deliveryManagerId']?.toString() ?? '';

    await _saveCachedUserValues();

    _patchPendingBuynow({
      'deliveryInstructions':
          selectedRequest == '직접입력'
              ? (manualRequest?.trim() ?? '')
              : selectedRequest,
    });
    setState(() => isProcessing = true);
    _showLoadingModal();

    try {
      final response = await http.post(
        Uri.parse('https://pay.pang2chocolate.com/api/charge-bank'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': uid,
          'paymentId': paymentId,
          'payerId': payerId,
          'option': selectedOption.toString(),
          if (dm.isNotEmpty) 'dm': dm,
        }),
      );

      final result = jsonDecode(response.body) as Map<String, dynamic>;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (result['success'] == true) {
        if (mounted) context.go(Routes.orderCompleteScreen);
      } else {
        final msg = result['message'] as String? ?? '결제에 실패했습니다. 다시 시도해 주세요.';
        if (mounted) {
          setState(() => isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('결제 중 오류가 발생했습니다. 다시 시도해 주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLoadingModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const PopScope(
            canPop: false,
            child: Center(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.black),
                      SizedBox(height: 16),
                      Text(
                        '결제 처리 중입니다...',
                        style: TextStyle(
                          fontFamily: 'NotoSans',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '잠시만 기다려 주세요',
                        style: TextStyle(
                          fontFamily: 'NotoSans',
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BANK ACCOUNT BOTTOM SHEET
  // ───────────────────────────────────────────────────────────────────────────

  void _showBankAccountBottomSheet(String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
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
                    final bank = entry.value;
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.account_balance,
                            color: Colors.black,
                          ),
                          title: Text(
                            '${bank['bankName']} (${bank['bankNum']})',
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
                            setState(() => selectedBankIndex = idx);
                            setStateDialog(() {});
                            Navigator.of(context).pop();
                          },
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.black,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      title: const Text('계좌 삭제'),
                                      content: Text(
                                        '${bank['bankName']} (${bank['bankNum']}) '
                                        '계좌를 삭제하시겠습니까?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, false),
                                          child: const Text(
                                            '취소',
                                            style: TextStyle(
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, true),
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.black,
                                          ),
                                          child: const Text(
                                            '삭제',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                              if (confirm != true) return;
                              await _deleteBankAccount(
                                uid,
                                bank['payerId'] as String,
                              );
                              setStateDialog(() {});
                              if (!mounted) return;
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                        verticalSpace(5),
                      ],
                    );
                  }),
                  verticalSpace(8),
                  WideTextButton(
                    txt: '새 계좌 등록하기',
                    func: () {
                      Navigator.of(context).pop();
                      _launchBankRegistration(uid);
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
          title: const Text(
            '주문 / 결제',
            style: TextStyle(
              fontFamily: 'NotoSans',
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        body: Padding(
          padding: const EdgeInsets.only(left: 15, top: 10, right: 15),
          child: ListView(
            children: [
              // ── Product summary ───────────────────────────────────────
              _buildSectionCard(
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.w400,
                                height: 1.40,
                              ),
                            ),
                            verticalSpace(8),
                            Text(
                              '$pendingQuantity 개',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontFamily: 'NotoSans',
                                fontWeight: FontWeight.w400,
                                height: 1.40,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${formatCurrency.format(pendingPrice)} 원',
                              style: const TextStyle(
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

              // ── Address ───────────────────────────────────────────────
              _buildSectionCard(
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
                                  final userData = snapshot.data?.data();
                                  if (userData == null ||
                                      (userData['defaultAddressId'] ?? '')
                                          .isEmpty) {
                                    return _buildNoAddress();
                                  }
                                  return FutureBuilder(
                                    future:
                                        FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(uid)
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
                      icon: const Icon(
                        Icons.arrow_forward_ios_sharp,
                        size: 30,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              verticalSpace(10),

              // ── Delivery request ──────────────────────────────────────
              _buildSectionCard(
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
                                selectedRequest == '직접입력' &&
                                        manualRequest != null &&
                                        manualRequest!.isNotEmpty
                                    ? manualRequest!
                                    : selectedRequest,
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 16,
                                  fontFamily: 'NotoSans',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              if (selectedRequest == '직접입력') ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  initialValue: manualRequest,
                                  onChanged: (text) {
                                    setState(() => manualRequest = text);
                                  },
                                  decoration: const InputDecoration(
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
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            size: 30,
                            color: Colors.black,
                          ),
                          onPressed:
                              () => _showDeliveryRequestSheet(setStateDropdown),
                        ),
                      ],
                    );
                  },
                ),
              ),
              verticalSpace(10),

              // ── Bank account ──────────────────────────────────────────
              _buildSectionCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '결제 계좌',
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
                            bankAccounts.isEmpty
                                ? '등록된 계좌가 없습니다'
                                : (selectedBankIndex >= 0 &&
                                    selectedBankIndex < bankAccounts.length)
                                ? '${bankAccounts[selectedBankIndex]['bankName']} '
                                    '(${bankAccounts[selectedBankIndex]['bankNum']})'
                                : '계좌를 선택해주세요',
                            style: TextStyle(
                              fontSize: 15,
                              color:
                                  bankAccounts.isEmpty
                                      ? Colors.red[300]
                                      : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showBankAccountBottomSheet(uid),
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        size: 30,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              verticalSpace(10),

              // ── Receipt / invoice ─────────────────────────────────────
              _buildSectionCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
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
                      onPressed: _showReceiptBottomSheet,
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        size: 30,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              verticalSpace(15),
            ],
          ),
        ),

        // ── Bottom bar ────────────────────────────────────────────────────
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '총 결제 금액 ',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontFamily: 'NotoSans',
                      fontWeight: FontWeight.w700,
                      height: 1.40,
                    ),
                  ),
                  Text(
                    '${formatCurrency.format(pendingPrice)} 원',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontFamily: 'NotoSans',
                      fontWeight: FontWeight.w700,
                      height: 1.40,
                    ),
                  ),
                ],
              ),
              verticalSpace(8),
              SlideToPayButton(
                isProcessing: isProcessing,
                onValidate: () async {
                  if (selectedOption != 1 && selectedOption != 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('현금 영수증 또는 세금 계산서를 선택해주세요'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return false;
                  }
                  if (!_validateReceiptTypeFields()) return false;
                  if (bankAccounts.isEmpty || selectedBankIndex < 0) {
                    _showBankAccountBottomSheet(uid);
                    return false;
                  }
                  final payerId =
                      bankAccounts[selectedBankIndex]['payerId'] as String? ??
                      '';
                  if (payerId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('계좌 정보가 올바르지 않습니다. 계좌를 다시 등록해주세요.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return false;
                  }
                  return true;
                },
                onSlideComplete: () => _handlePlaceOrder(uid),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI HELPERS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 0, 15),
      decoration: ShapeDecoration(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1.5, color: Colors.black),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: child,
    );
  }

  Widget _buildNoAddress() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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

  void _showDeliveryRequestSheet(StateSetter setStateDropdown) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                deliveryRequests
                    .map(
                      (request) => ListTile(
                        title: Text(
                          request,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onTap: () {
                          setStateDropdown(() {
                            selectedRequest = request;
                            if (selectedRequest != '직접입력') manualRequest = null;
                          });
                          setState(() {});
                          Navigator.pop(context);
                        },
                      ),
                    )
                    .toList(),
          ),
        );
      },
    );
  }

  void _showReceiptBottomSheet() {
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
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _bottomSheetFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildRadioOption(
                            value: 1,
                            label: '현금 영수증',
                            setStateSheet: setStateRadio,
                          ),
                          _buildRadioOption(
                            value: 2,
                            label: '세금 계산서',
                            setStateSheet: setStateRadio,
                          ),
                        ],
                      ),
                      if (selectedOption == 1)
                        ..._buildCashReceiptFields()
                      else
                        ..._buildTaxInvoiceFields(setStateRadio),
                      verticalSpace(10),
                      WideTextButton(
                        txt: '저장',
                        func: () async {
                          if (!_bottomSheetFormKey.currentState!.validate())
                            return;
                          final success = await _saveCachedUserValues(
                            showFeedback: true,
                          );
                          if (success && mounted) Navigator.pop(context);
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
  }

  Widget _buildRadioOption({
    required int value,
    required String label,
    required StateSetter setStateSheet,
  }) {
    return Row(
      children: [
        Radio<int>(
          value: value,
          groupValue: selectedOption,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          onChanged: (v) {
            setStateSheet(() => selectedOption = v!);
            setState(() {});
          },
        ),
        Text(
          label,
          style: const TextStyle(
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
    const SizedBox(height: 10),
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
    const SizedBox(height: 10),
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
    const SizedBox(height: 10),
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
    const SizedBox(height: 10),
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
    const SizedBox(height: 10),
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
    const SizedBox(height: 10),
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
    const SizedBox(height: 10),
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
