// services/contact_service.dart
import 'dart:convert';

import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    final contacts = await FlutterContacts.getContacts(withProperties: true);
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
          final normalizedNumber = expandEgKrNumber(phone.number);
          if (phone.number.isNotEmpty &&
              !phoneNumbers.contains(normalizedNumber.first)) {
            phoneNumbers.addAll(normalizedNumber);
          }
        }
      }
    }

    return phoneNumbers;
  }

  /// Normalizes a phone number to E.164 format
  /// Example:
  ///   normalizeNumber("01062675821", "EG") -> +201062675821
  ///   normalizeNumber("01012345678", "KR") -> +821012345678
  List<String> expandEgKrNumber(String input) {
    final List<String> results = [];
    final cleaned = input.replaceAll(
      RegExp(r'\s+|-'),
      "",
    ); // remove spaces/dashes

    // Case 1: Egyptian number (+20… or 01…)
    if (cleaned.startsWith("+20")) {
      final local = cleaned.replaceFirst("+20", "0"); // local format
      results.add(cleaned); // keep international
      results.add(local);
    }
    // Case 2: Korean number (+82… or 010…)
    else if (cleaned.startsWith("+82")) {
      final local = cleaned.replaceFirst("+82", "0"); // 010...
      results.add(cleaned);
      results.add(local);
    }
    // Case 3: Ambiguous (doesn't start with +20/+82/01/010)
    else {
      // Try Egypt interpretation
      final egIntl = "+20$cleaned".replaceFirst("0", "");
      results.add(cleaned);
      results.add(egIntl);

      // Try Korea interpretation
      final krIntl = "+82$cleaned".replaceFirst("0", "");
      results.add(krIntl);
    }

    return results.toSet().toList(); // remove duplicates
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

  Future<Map<String, String>> buildContactNameMap(
    List<Contact> contacts,
    List<MyUser> matchingUsers,
    List<String> allPhoneNumbers,
  ) async {
    final map = <String, String>{};

    final phoneToName = <String, String>{};
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        for (final normalized in expandEgKrNumber(phone.number)) {
          phoneToName[normalized] = contact.displayName;
        }
      }
    }
    for (final user in matchingUsers) {
      final normalized = expandEgKrNumber(user.phoneNumber.toString());
      for (final number in normalized) {
        if (phoneToName.containsKey(number)) {
          map[user.userId] = phoneToName[number]!; // ← userId as key
          break;
        }
      }
    }

    return map;
  }

  Future<void> saveContactNameMap(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('contact_name_map', jsonEncode(map));
  }

  Future<Map<String, String>> loadContactNameMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('contact_name_map');
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw));
  }

  Future<String?> getContactNickname(String userId) async {
    final map = await loadContactNameMap();
    return map[userId];
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
      final nameMap = await buildContactNameMap(
        contacts,
        matchingUsers,
        contactPhoneNumbers,
      );
      await saveContactNameMap(nameMap);
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
