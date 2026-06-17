import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/cart/services/kakao_service.dart';
import 'package:ecommerece_app/features/cart/sub_screens/address_search_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddAddressScreen extends StatefulWidget {
  /// When true, a "나중에 추가하기" skip action appears in the AppBar.
  /// The NavBar passes true; the address-list screen passes false (or omits it).
  final bool showSkip;

  const AddAddressScreen({Key? key, this.showSkip = false}) : super(key: key);

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _detailAddressController =
      TextEditingController();
  bool _isDefaultAddress = true;
  Map<String, dynamic> _address = {};

  final _formKey = GlobalKey<FormState>();

  String? _addressError;

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    super.dispose();
  }

  void _searchAddress() async {
    final kakaoService = KakaoApiService(
      apiKey: '772742afea4cfac8c58ed62cfa7d1777',
    );

    final result = await showDialog(
      context: context,
      builder: (context) => AddressSearchDialog(kakaoService: kakaoService),
    );

    if (result != null) {
      setState(() {
        _addressController.text = result['address_name'];
        _address = result;
        _addressError = null;
      });
    }
  }

  bool _validateName() {
    if (_nameController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  bool _validatePhone() {
    final phoneRegExp = RegExp(
      r'^01([0|1|6|7|8|9])-?([0-9]{3,4})-?([0-9]{4})$',
    );
    if (_phoneController.text.trim().isEmpty) {
      return false;
    } else if (!phoneRegExp.hasMatch(_phoneController.text.trim())) {
      return false;
    }
    return true;
  }

  bool _validateAddress() {
    if (_addressController.text.trim().isEmpty) {
      setState(() => _addressError = '배송 주소를 입력해주세요');
      return false;
    }
    setState(() => _addressError = null);
    return true;
  }

  bool _validateDetailAddress() {
    if (_detailAddressController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  bool _validateAll() {
    return _validateName() &
        _validatePhone() &
        _validateAddress() &
        _validateDetailAddress();
  }

  Future<void> _saveAddress() async {
    if (!_validateAll()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다')));
          setState(() => _isLoading = false);
        }
        return;
      }

      final addressesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses');

      // Check if this is the first address
      final addressesSnapshot = await addressesRef.limit(1).get();
      final bool isFirstAddress = addressesSnapshot.docs.isEmpty;
      final bool shouldBeDefault = _isDefaultAddress || isFirstAddress;

      final batch = FirebaseFirestore.instance.batch();

      if (shouldBeDefault && !isFirstAddress) {
        // Reset existing defaults
        final defaultAddresses =
            await addressesRef.where('isDefault', isEqualTo: true).get();
        for (var doc in defaultAddresses.docs) {
          batch.update(doc.reference, {'isDefault': false});
        }
      }

      final docRef = addressesRef.doc();
      final addressData = {
        'id': docRef.id,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'detailAddress': _detailAddressController.text.trim(),
        'isDefault': shouldBeDefault,
        'addressMap': _address,
        'createdAt': FieldValue.serverTimestamp(),
      };

      batch.set(docRef, addressData);

      if (shouldBeDefault) {
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(user.uid),
          {'defaultAddressId': docRef.id},
        );
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('배송지가 저장되었습니다')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          '주문/결제',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        // ── Skip action — only shown when launched from NavBar gate ──────
        actions:
            widget.showSkip
                ? [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      '나중에',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ]
                : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Center(
                  child: Text(
                    '배송지 추가',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                const Divider(),

                // ── Recipient name ──────────────────────────────────────
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: '받는 사람',
                    hintStyle: const TextStyle(color: Color(0xFF86828B)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    errorText: null, // Will be set dynamically
                  ),
                  onChanged: (_) => _validateName(),
                ),
                const SizedBox(height: 12),

                // ── Phone ───────────────────────────────────────────────
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '휴대폰 번호',
                    hintStyle: const TextStyle(color: Color(0xFF86828B)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    errorText: null,
                  ),
                  onChanged: (_) => _validatePhone(),
                ),
                const SizedBox(height: 12),

                // ── Address search ──────────────────────────────────────
                TextField(
                  controller: _addressController,
                  readOnly: true,
                  onTap: _searchAddress,
                  decoration: InputDecoration(
                    hintText: '배송 주소',
                    hintStyle: const TextStyle(color: Color(0xFF86828B)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: const ImageIcon(
                      AssetImage('assets/Frame 4.png'),
                      color: Colors.black,
                      size: 25,
                    ),
                    errorText: _addressError,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Detail address ──────────────────────────────────────
                TextField(
                  controller: _detailAddressController,
                  decoration: InputDecoration(
                    hintText: '상세 주소',
                    hintStyle: const TextStyle(color: Color(0xFF86828B)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    errorText: null,
                  ),
                  onChanged: (_) => _validateDetailAddress(),
                ),
                const SizedBox(height: 16),

                // ── Default address checkbox ────────────────────────────
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _isDefaultAddress,
                        onChanged: (value) {
                          setState(() => _isDefaultAddress = value ?? false);
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: BorderSide(color: Colors.grey[400]!),
                        activeColor: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '기본 배송지로 설정',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Save button ─────────────────────────────────────────
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                          : const Text(
                            '저장',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
