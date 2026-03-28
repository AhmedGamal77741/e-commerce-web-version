import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/helpers/spacing.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:ecommerece_app/features/cart/slide_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final formatCurrency = NumberFormat('#,###');

  List<Map<String, dynamic>> bankAccounts = [];
  int selectedBankIndex = 0;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadBankAccounts();
  }

  Future<void> _loadBankAccounts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data();

    if (mounted) {
      setState(() {
        bankAccounts =
            data?['bankAccounts'] != null
                ? List<Map<String, dynamic>>.from(data!['bankAccounts'])
                : [];
        selectedBankIndex = bankAccounts.isNotEmpty ? 0 : -1;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteBankAccount(String payerId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await userRef.get();
    final data = snap.data();
    if (data == null) return;

    final accounts = List<Map<String, dynamic>>.from(
      data['bankAccounts'] ?? [],
    );
    accounts.removeWhere((b) => b['payerId'] == payerId);
    await userRef.update({'bankAccounts': accounts});

    if (mounted) {
      setState(() {
        bankAccounts = accounts;
        selectedBankIndex = accounts.isNotEmpty ? 0 : -1;
      });
    }
  }

  void _showBankPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
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
                            setStateSheet(() {});
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
                                bank['payerId'] as String,
                              );
                              setStateSheet(() {});
                              if (mounted) Navigator.of(context).pop();
                            },
                          ),
                        ),
                        verticalSpace(5),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSubscribe() async {
    if (bankAccounts.isEmpty || selectedBankIndex < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('결제할 계좌를 선택해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
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

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isProcessing = true);
    _showLoadingModal();

    try {
      final response = await _callSubscribeCF(uid: uid, payerId: payerId);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('멤버십 가입이 완료되었습니다 ✓'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        final msg = response['message'] as String? ?? '결제에 실패했습니다. 다시 시도해 주세요.';
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('결제 중 오류가 발생했습니다. 다시 시도해 주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _callSubscribeCF({
    required String uid,
    required String payerId,
  }) async {
    final response = await http.post(
      Uri.parse('https://pay.pang2chocolate.com/api/subscribe'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': uid, 'payerId': payerId}),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        title: const Text(
          '프리미엄 멤버십',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  // ── Benefits card ───────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: ShapeDecoration(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(width: 2, color: Colors.white),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '멤버십 혜택',
                          style: TextStyles.abeezee30px800wW.copyWith(
                            fontFamily: 'ABeeZee',
                          ),
                        ),
                        verticalSpace(40),
                        const Text(
                          '월회비 10,000원\n모든 제품 20% 할인',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                        verticalSpace(40),
                        const Text(
                          '매월 5만원 이상 구매하시는 분은 멤버십 가입을 권합니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'NotoSans',
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  verticalSpace(12),
                  Text(
                    '*등록된 계좌에서 매월 10,000원이 자동 결제됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontFamily: 'NotoSans',
                    ),
                  ),
                  verticalSpace(32),

                  // ── Bank account selector ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    decoration: ShapeDecoration(
                      color: Colors.white10,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.white24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '결제 계좌',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontFamily: 'NotoSans',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              verticalSpace(4),
                              Text(
                                bankAccounts.isEmpty
                                    ? '등록된 계좌가 없습니다'
                                    : (selectedBankIndex >= 0 &&
                                        selectedBankIndex < bankAccounts.length)
                                    ? '${bankAccounts[selectedBankIndex]['bankName']} '
                                        '(${bankAccounts[selectedBankIndex]['bankNum']})'
                                    : '계좌를 선택해주세요',
                                style: TextStyle(
                                  color:
                                      bankAccounts.isEmpty
                                          ? Colors.red[300]
                                          : Colors.white70,
                                  fontSize: 14,
                                  fontFamily: 'NotoSans',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (bankAccounts.length > 1)
                          IconButton(
                            onPressed: _showBankPicker,
                            icon: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

      // ── Bottom bar ────────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          color: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '월 회비',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'NotoSans',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    '10,000원',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'NotoSans',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              verticalSpace(10),
              SlideToPayButton(
                isProcessing: _isProcessing,
                onValidate: () async {
                  if (bankAccounts.isEmpty || selectedBankIndex < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('결제할 계좌를 선택해주세요.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return false;
                  }
                  final payerId =
                      bankAccounts[selectedBankIndex]['payerId'] as String? ??
                      '';
                  if (payerId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('계좌 정보가 올바르지 않습니다.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return false;
                  }
                  return true;
                },
                onSlideComplete: _handleSubscribe,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
