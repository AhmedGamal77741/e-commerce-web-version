import 'package:ecommerece_app/core/theming/colors.dart';
import 'package:ecommerece_app/features/cart/models/address.dart';
import 'package:ecommerece_app/features/cart/services/address_service.dart';
import 'package:ecommerece_app/features/cart/sub_screens/add_address_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({Key? key}) : super(key: key);

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다')));
    }

    final addressService = AddressService(userId: currentUser.uid);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: 21),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '배송지 변경',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Add Address Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton(
              onPressed: () => _navigateToAddressForm(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black87),
                minimumSize: Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 14),
                  SizedBox(width: 4),
                  Text('배송지 추가', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),

          // Address List
          Expanded(
            child:
                _isProcessing
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<QuerySnapshot>(
                      stream:
                          _firestore
                              .collection('users')
                              .doc(currentUser.uid)
                              .collection('addresses')
                              .orderBy('isDefault', descending: true)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('오류가 발생했습니다: ${snapshot.error}'),
                          );
                        }

                        final addresses = snapshot.data?.docs ?? [];

                        if (addresses.isEmpty) {
                          return const Center(child: Text('등록된 배송지가 없습니다'));
                        }

                        return ListView.separated(
                          itemCount: addresses.length,
                          separatorBuilder:
                              (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final address = Address.fromMap(
                              addresses[index].data() as Map<String, dynamic>,
                            );

                            return InkWell(
                              onTap: () => _selectAddress(address),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Address information
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                address.name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            address.phone,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            address.detailAddress,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            decoration: BoxDecoration(
                                              color:
                                                  address.isDefault
                                                      ? Colors.grey.shade200
                                                      : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                            child: TextButton(
                                              onPressed:
                                                  address.isDefault
                                                      ? () {}
                                                      : () async {
                                                        setState(() {
                                                          _isProcessing = true;
                                                        });
                                                        await addressService
                                                            .deleteAddress(
                                                              context,
                                                              addresses[index]
                                                                  .id,
                                                            );
                                                        setState(() {
                                                          _isProcessing = false;
                                                        });
                                                      },

                                              style: TextButton.styleFrom(
                                                fixedSize: Size(48, 30),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                side: BorderSide(
                                                  color: Colors.grey.shade300,
                                                  width: 1.0,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        4.0,
                                                      ),
                                                ),
                                              ),
                                              child: Text(
                                                '삭제',
                                                style: TextStyle(
                                                  color:
                                                      ColorsManager
                                                          .primaryblack,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    (address.isDefault)
                                        ? Container(
                                          margin: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                          child: const Text(
                                            '기본배송지',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        )
                                        : TextButton(
                                          onPressed: () async {
                                            setState(() {
                                              _isProcessing = true;
                                            });
                                            await addressService
                                                .setAsDefaultAddress(
                                                  context,
                                                  addresses[index].id,
                                                );
                                            setState(() {
                                              _isProcessing = false;
                                            });
                                          },
                                          style: TextButton.styleFrom(
                                            fixedSize: Size(48, 30),
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            side: BorderSide(
                                              color: Colors.grey.shade300,
                                              width: 1.0,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4.0),
                                            ),
                                          ),
                                          child: Text(
                                            '선택',
                                            style: TextStyle(
                                              color: ColorsManager.primaryblack,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),

                                    // Edit button
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddressForm(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddAddressScreen()),
    );

    if (result == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('배송지 정보가 저장되었습니다')));
    }
  }

  void _selectAddress(Address address) {
    // Handle selection logic - for example, navigate back with the selected address
    Navigator.pop(context, address);
  }
}
