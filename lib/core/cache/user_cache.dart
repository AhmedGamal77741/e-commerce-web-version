import 'package:cloud_firestore/cloud_firestore.dart';

class UserCache {
  static final Map<String, DocumentSnapshot> _cache = {};

  static Future<DocumentSnapshot> getUser(String uid) async {
    if (_cache.containsKey(uid)) {
      return _cache[uid]!;
    }
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    _cache[uid] = doc;
    return doc;
  }
}
