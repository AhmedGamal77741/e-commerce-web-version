// services/contact_service.dart
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Request contact permission
  Future<bool> requestContactPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  // Get phone contacts
  Future<List<Contact>> getPhoneContacts() async {
    final hasPermission = await requestContactPermission();
    if (!hasPermission) {
      throw Exception('Contact permission denied');
    }

    final contacts = await FlutterContacts.getContacts();
    return contacts
        .where((contact) => contact.phones.isNotEmpty == true)
        .toList();
  }

  // Extract and normalize phone numbers from contacts
  List<String> extractPhoneNumbers(List<Contact> contacts) {
    final phoneNumbers = <String>[];

    for (final contact in contacts) {
      if (contact.phones.isNotEmpty) {
        for (final phone in contact.phones) {
          final normalizedNumber = _normalizePhoneNumber(phone.number);
          if (normalizedNumber.isNotEmpty &&
              !phoneNumbers.contains(normalizedNumber)) {
            phoneNumbers.add(normalizedNumber);
          }
        }
      }
    }

    return phoneNumbers;
  }

  // Normalize phone number
  String _normalizePhoneNumber(String phoneNumber) {
    String normalized = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (normalized.startsWith('0')) {
      normalized = '+82${normalized.substring(1)}';
    } else if (normalized.startsWith('1') && normalized.length == 10) {
      normalized = '+1$normalized';
    } else if (!normalized.startsWith('+')) {
      normalized = '+1$normalized';
    }

    return normalized;
  }

  // Find users by phone numbers
  Future<List<MyUser>> findUsersByPhoneNumbers(
    List<String> phoneNumbers,
  ) async {
    if (phoneNumbers.isEmpty) return [];

    final List<MyUser> allUsers = [];

    for (int i = 0; i < phoneNumbers.length; i += 10) {
      final batch = phoneNumbers.skip(i).take(10).toList();

      final querySnapshot =
          await _firestore
              .collection('users')
              .where('phoneNumber', whereIn: batch)
              .where('phoneVerified', isEqualTo: true)
              .get();

      final users =
          querySnapshot.docs
              .map((doc) => MyUser.fromDocument(doc.data()))
              .where((user) => user.userId != currentUserId)
              .toList();

      allUsers.addAll(users);
    }

    return allUsers;
  }

  // Auto-add friends from contacts
  Future<int> syncAndAddFriendsFromContacts() async {
    try {
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final currentUser = MyUser.fromDocument(currentUserDoc.data()!);

      final contacts = await getPhoneContacts();
      final contactPhoneNumbers = extractPhoneNumbers(contacts);

      final matchingUsers = await findUsersByPhoneNumbers(contactPhoneNumbers);

      final newFriends =
          matchingUsers
              .where((user) => !currentUser.friends.contains(user.userId))
              .toList();

      if (newFriends.isEmpty) return 0;

      return await _autoAddFriends(newFriends.map((u) => u.userId).toList());
    } catch (e) {
      print('Error syncing contacts: $e');
      return 0;
    }
  }

  // Auto-add multiple friends
  Future<int> _autoAddFriends(List<String> userIds) async {
    if (userIds.isEmpty) return 0;

    final batch = _firestore.batch();

    try {
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'friends': FieldValue.arrayUnion(userIds),
      });

      for (final userId in userIds) {
        batch.update(_firestore.collection('users').doc(userId), {
          'friends': FieldValue.arrayUnion([currentUserId]),
        });
      }

      await batch.commit();
      return userIds.length;
    } catch (e) {
      print('Error auto-adding friends: $e');
      return 0;
    }
  }
}
