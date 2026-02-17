// features/chat/services/favorites_service.dart
//
// Favorites are stored as a plain List<String> of friend user-IDs on the
// current user's Firestore document under the key "favorites".
//
// This mirrors the existing pattern used for `friends`, `blocked`, etc.
// No extra collection is needed; a simple array-union / array-remove keeps
// the write cheap and the read free (it comes along with the user doc).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _currentUid => FirebaseAuth.instance.currentUser!.uid;

  DocumentReference get _currentUserDoc =>
      _firestore.collection('users').doc(_currentUid);

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Stream of favorite user-IDs for the signed-in user.
  /// Emits immediately with cached data; updates in real-time.
  Stream<List<String>> getFavoriteIdsStream() {
    return _currentUserDoc.snapshots().map((snap) {
      if (!snap.exists) return <String>[];
      final data = snap.data() as Map<String, dynamic>?;
      final raw = data?['favorites'];
      if (raw == null) return <String>[];
      return List<String>.from(raw as List);
    });
  }

  /// One-shot fetch of the current favorite IDs (for non-reactive use).
  Future<List<String>> getFavoriteIds() async {
    final snap = await _currentUserDoc.get();
    if (!snap.exists) return [];
    final data = snap.data() as Map<String, dynamic>?;
    final raw = data?['favorites'];
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Adds [friendId] to the favorites list. Returns true on success.
  Future<bool> addFavorite(String friendId) async {
    try {
      await _currentUserDoc.update({
        'favorites': FieldValue.arrayUnion([friendId]),
      });
      return true;
    } catch (e) {
      debugPrint('FavoritesService.addFavorite error: $e');
      return false;
    }
  }

  /// Removes [friendId] from the favorites list. Returns true on success.
  Future<bool> removeFavorite(String friendId) async {
    try {
      await _currentUserDoc.update({
        'favorites': FieldValue.arrayRemove([friendId]),
      });
      return true;
    } catch (e) {
      debugPrint('FavoritesService.removeFavorite error: $e');
      return false;
    }
  }

  /// Toggles the favorite state of [friendId].
  /// Returns the new state: true = now a favorite, false = removed.
  Future<bool> toggleFavorite(String friendId) async {
    final ids = await getFavoriteIds();
    if (ids.contains(friendId)) {
      await removeFavorite(friendId);
      return false;
    } else {
      await addFavorite(friendId);
      return true;
    }
  }

  /// Quick synchronous check given an already-fetched list of IDs.
  bool isFavorite(String friendId, List<String> favoriteIds) =>
      favoriteIds.contains(friendId);
}
