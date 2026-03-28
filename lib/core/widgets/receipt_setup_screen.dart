import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/core/theming/styles.dart';
import 'package:ecommerece_app/core/widgets/underline_text_filed.dart';
import 'package:ecommerece_app/core/widgets/wide_text_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReceiptSetupScreen extends StatefulWidget {
  final String source; // 'shop' or 'sub'
  const ReceiptSetupScreen({super.key, this.source = 'shop'});

  @override
  State<ReceiptSetupScreen> createState() => _ReceiptSetupScreenState();
}

class _ReceiptSetupScreenState extends State<ReceiptSetupScreen> {
  // ── Receipt / invoice fields ──────────────────────────────────────────────
  String invoiceeType = '사업자';
  final invoiceeCorpNumController = TextEditingController();
  final invoiceeCorpNameController = TextEditingController();
  final invoiceeCEONameController = TextEditingController();
  final phoneController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();

  int selectedOption = 1; // 1 = cash receipt, 2 = tax invoice

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCachedValues();
  }

  @override
  void dispose() {
    invoiceeCorpNumController.dispose();
    invoiceeCorpNameController.dispose();
    invoiceeCEONameController.dispose();
    phoneController.dispose();
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  // ── Pre-fill from cache if anything exists ────────────────────────────────
  Future<void> _loadCachedValues() async {
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
    });
  }

  // ── Save to usercached_values ─────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('usercached_values')
          .doc(uid)
          .set({
            'name': nameController.text.trim(),
            'email': emailController.text.trim(),
            'phone': phoneController.text.trim(),
            'invoiceeType': invoiceeType,
            'invoiceeCorpNum': invoiceeCorpNumController.text.trim(),
            'invoiceeCorpName': invoiceeCorpNameController.text.trim(),
            'invoiceeCEOName': invoiceeCEONameController.text.trim(),
            'selectedOption': selectedOption,
          }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          '현금영수증 · 세금계산서',
          style: TextStyle(
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Info text ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '결제 및 구독을 이용하려면\n현금영수증 또는 세금계산서 정보를 먼저 등록해주세요.',
                  style: TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // ── Option selector ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRadioOption(value: 1, label: '현금 영수증'),
                  _buildRadioOption(value: 2, label: '세금 계산서'),
                ],
              ),
              const SizedBox(height: 24),

              // ── Fields ──────────────────────────────────────────────────
              if (selectedOption == 1)
                ..._buildCashReceiptFields()
              else
                ..._buildTaxInvoiceFields(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isSaving
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                      : const Text(
                        '저장하고 계속하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'NotoSans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Radio option builder ──────────────────────────────────────────────────
  Widget _buildRadioOption({required int value, required String label}) {
    return Row(
      children: [
        Radio<int>(
          value: value,
          groupValue: selectedOption,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          onChanged: (v) => setState(() => selectedOption = v!),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w700,
            color: ColorsManager.primaryblack,
          ),
        ),
      ],
    );
  }

  // ── Cash receipt fields ───────────────────────────────────────────────────
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
    const SizedBox(height: 16),
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
    const SizedBox(height: 16),
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

  // ── Tax invoice fields ────────────────────────────────────────────────────
  List<Widget> _buildTaxInvoiceFields() => [
    DropdownButtonFormField<String>(
      dropdownColor: Colors.white,
      value: invoiceeType,
      items:
          [
            '사업자',
            '개인',
            '외국인',
          ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (val) => setState(() => invoiceeType = val ?? '사업자'),
      decoration: const InputDecoration(
        border: UnderlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),
      icon: const Icon(Icons.keyboard_arrow_down),
    ),
    const SizedBox(height: 16),
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
          return '사업자번호는 숫자 10자리여야 합니다';
        }
        return null;
      },
      onChanged: (_) => null,
    ),
    const SizedBox(height: 16),
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
    const SizedBox(height: 16),
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
    const SizedBox(height: 16),
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
    const SizedBox(height: 16),
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
