import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerece_app/features/auth/signup/data/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<String> uploadImageToFirebaseStorage(XFile? image) async {
  try {
    if (image == null) return "";
    final userId = FirebaseAuth.instance.currentUser!.uid;

    // Compress image before upload
    final originalBytes = await image.readAsBytes();
    final compressedBytes = await FlutterImageCompress.compressWithList(
      originalBytes,
      minWidth: 200,
      minHeight: 200,
      quality: 80,
      format: CompressFormat.jpeg,
    );

    // Get reference to Firebase Storage location
    final Reference storageRef = FirebaseStorage.instance
        .ref()
        .child('user_profile_images')
        .child('$userId.jpg'); // Using user ID as filename

    // Upload the compressed file
    final UploadTask uploadTask = storageRef.putData(compressedBytes);
    final TaskSnapshot snapshot = await uploadTask;

    // Get download URL
    final String downloadUrl = await snapshot.ref.getDownloadURL();

    // Update Firestore and Auth
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'url': downloadUrl,
    });

    await FirebaseAuth.instance.currentUser!.updatePhotoURL(downloadUrl);

    return downloadUrl;
  } catch (e) {
    print('Error uploading image: $e');
    throw Exception('Failed to upload image: $e');
  }
}

class FirebaseUserRepo {
  final FirebaseAuth _firebaseAuth;

  final usersCollection = FirebaseFirestore.instance.collection('users');
  static const String signUpSuccess = "회원가입이 완료되었습니다";
  static const String errorEmailAlreadyInUse = "이미 사용 중인 이메일입니다";
  static const String errorUsernameTaken = "userId가 이미 사용 중입니다.";
  static const String errorPhoneNumberTaken = "전화번호가 이미 사용 중입니다.";
  static const String errorWeakPassword = "비밀번호가 너무 약합니다";
  static const String errorUnknown = "알 수 없는 오류가 발생했습니다";

  FirebaseUserRepo({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Stream<MyUser?> get user {
    return _firebaseAuth.authStateChanges().asyncExpand((firebaseUser) async* {
      print('⚡ authStateChanges fired: $firebaseUser');
      if (firebaseUser == null) {
        // No Firebase user → unauthenticated
        yield null;
      } else {
        final docRef = usersCollection.doc(firebaseUser.uid);
        try {
          final snapshot = await docRef.get();
          if (!snapshot.exists) {
            print('⚠️ User doc does not exist for uid=${firebaseUser.uid}');
            yield null;
          } else {
            final data = snapshot.data()!;
            print('✅ Fetched user data: $data');

            // Safely extract each field, with defaults if missing
            final user = MyUser.fromDocument(data);

            yield user;
          }
        } catch (e, st) {
          print('❌ Error loading user doc: $e\n$st');
          yield null;
        }
      }
    });
  }

  Future<MyUser?> updateUser(MyUser myUser, String password) async {
    try {
      // Update user document with new information
      await usersCollection
          .doc(myUser.userId)
          .update(myUser.toEntity().toDocument());

      // Update auth display name if name was provided
      if (myUser.name != FirebaseAuth.instance.currentUser?.displayName) {
        await FirebaseAuth.instance.currentUser!.updateDisplayName(myUser.name);
      }

      // Update password only if it was provided
      if (password.isNotEmpty) {
        try {
          await FirebaseAuth.instance.currentUser!.updatePassword(password);
        } catch (e) {
          // Handle specific password update errors
          if (e is FirebaseAuthException) {
            // For security-sensitive operations, Firebase might require recent authentication
            if (e.code == 'requires-recent-login') {
              throw Exception('비밀번호 업데이트를 위해 다시 로그인해 주세요');
            }
          }
          rethrow; // Rethrow other errors
        }
      }

      return myUser;
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  Future<String> signUp(MyUser myUser, String password, XFile? image) async {
    try {
      // 1. Check if username (nickname) already exists
      final tagQuery =
          await usersCollection
              .where(
                'tag',
                isEqualTo: myUser.name,
              ) // Assuming 'name' is the field for nickname in Firestore
              .limit(1)
              .get();

      final phoneNumberQuery =
          await usersCollection
              .where(
                'phoneNumber',
                isEqualTo: myUser.phoneNumber,
              ) // Assuming 'name' is the field for nickname in Firestore
              .limit(1)
              .get();

      if (tagQuery.docs.isNotEmpty) {
        return errorUsernameTaken; // Username is already taken
      }

      if (phoneNumberQuery.docs.isNotEmpty) {
        return errorPhoneNumberTaken; // Username is already taken
      }

      // 2. If username is unique, proceed to create user with email and password
      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(
            email: myUser.email,
            password: password,
          );

      myUser.userId = userCredential.user!.uid;

      // 3. Store user details in Firestore
      // It's good practice to do this after successful Firebase Auth creation
      await usersCollection.doc(myUser.userId).set({
        ...myUser.toEntity().toDocument(), // Ensure this maps 'name' correctly
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (image != null) {
        await uploadImageToFirebaseStorage(image);
      }
      // 4. Update Firebase Auth user's profile (optional, but good for consistency)
      // Do this after successfully saving to Firestore to ensure data consistency
      await userCredential.user!.updateDisplayName(myUser.name);
      await userCredential.user!.updatePhotoURL(myUser.url);

      return signUpSuccess; // Indicate success
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during sign up: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
        return errorEmailAlreadyInUse;
      } else if (e.code == 'weak-password') {
        return errorWeakPassword;
      }
      // Handle other specific Firebase Auth errors as needed
      return errorUnknown; // Generic error for other Firebase Auth issues
    } catch (e) {
      print('Generic exception during sign up: ${e.toString()}');
      return errorUnknown; // Generic error for non-Firebase Auth issues
    }
  }

  Future signIn(String email, String password) async {
    try {
      var result = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      var user = result.user;
      print(user);
      return user;
    } catch (e) {
      return null;
    }
  }
}
