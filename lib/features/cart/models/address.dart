import 'package:cloud_firestore/cloud_firestore.dart';

class Address {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String detailAddress;
  final bool isDefault;
  final Map<String, dynamic>? addressMap;
  final Timestamp? createdAt;

  Address({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.detailAddress,
    this.isDefault = false,
    this.addressMap,
    this.createdAt,
  });

  // Create Address from Firestore document
  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      detailAddress: map['detailAddress'] ?? '',
      isDefault: map['isDefault'] ?? false,
      addressMap: map['addressMap'],
      createdAt: map['createdAt'],
    );
  }

  // Convert Address to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'detailAddress': detailAddress,
      'isDefault': isDefault,
      'addressMap': addressMap,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  // Create a copy of Address with some changes
  Address copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? detailAddress,
    bool? isDefault,
    Map<String, dynamic>? addressMap,
    Timestamp? createdAt,
  }) {
    return Address(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      detailAddress: detailAddress ?? this.detailAddress,
      isDefault: isDefault ?? this.isDefault,
      addressMap: addressMap ?? this.addressMap,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
