import 'package:ecommerece_app/features/cart/models/address.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId;

  AddressService({required String userId}) : _userId = userId;

  // Collection reference for addresses
  CollectionReference get _addressesCollection =>
      _firestore.collection('users').doc(_userId).collection('addresses');

  // Reference to the user document
  DocumentReference get _userDocument =>
      _firestore.collection('users').doc(_userId);

  // Delete an address
  Future<bool> deleteAddress(BuildContext context, String addressId) async {
    try {
      DocumentSnapshot userDoc = await _userDocument.get();
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      String? defaultAddressId = userData?['defaultAddressId'];

      WriteBatch batch = _firestore.batch();

      batch.delete(_addressesCollection.doc(addressId));

      // If we are deleting the default address, we should assign a new one if available
      if (defaultAddressId == addressId) {
        QuerySnapshot remainingAddresses =
            await _addressesCollection
                .orderBy('createdAt', descending: true)
                .get();

        // Find the first address that is NOT the one we are deleting
        DocumentSnapshot? nextDefault;
        for (var doc in remainingAddresses.docs) {
          if (doc.id != addressId) {
            nextDefault = doc;
            break;
          }
        }

        if (nextDefault != null) {
          batch.update(_userDocument, {'defaultAddressId': nextDefault.id});
          batch.update(nextDefault.reference, {'isDefault': true});
        } else {
          // No addresses left
          batch.update(_userDocument, {'defaultAddressId': null});
        }
      }

      await batch.commit();

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  // Set address as default
  Future<bool> setAsDefaultAddress(
    BuildContext context,
    String addressId,
  ) async {
    try {
      WriteBatch batch = _firestore.batch();

      // Get only addresses that are currently default
      QuerySnapshot defaultAddresses =
          await _addressesCollection.where('isDefault', isEqualTo: true).get();

      // Set them to non-default
      for (var doc in defaultAddresses.docs) {
        if (doc.id != addressId) {
          batch.update(doc.reference, {'isDefault': false});
        }
      }

      // Set the selected address as default
      batch.update(_addressesCollection.doc(addressId), {'isDefault': true});

      // Update the user document with the new default address ID
      batch.update(_userDocument, {'defaultAddressId': addressId});

      // Commit everything in one go
      await batch.commit();

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  // Helper method to reset isDefault flag on all addresses
  Future<void> resetAllDefaultFlags() async {
    QuerySnapshot addressesSnapshot = await _addressesCollection.get();

    WriteBatch batch = _firestore.batch();
    for (var doc in addressesSnapshot.docs) {
      if (doc.get('isDefault') == true) {
        batch.update(doc.reference, {'isDefault': false});
      }
    }

    if (addressesSnapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  // Get the currently default address
  Future<Address?> getDefaultAddress() async {
    try {
      DocumentSnapshot userDoc = await _userDocument.get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String? defaultAddressId = userData['defaultAddressId'];

      if (defaultAddressId != null) {
        DocumentSnapshot addressDoc =
            await _addressesCollection.doc(defaultAddressId).get();
        if (addressDoc.exists) {
          return Address.fromMap(addressDoc.data() as Map<String, dynamic>);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching default address: $e');
      return null;
    }
  }
}
