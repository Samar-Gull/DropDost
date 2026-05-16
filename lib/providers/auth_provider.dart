import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // Sign up
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String userType,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      UserModel newUser = UserModel(
        uid: credential.user!.uid,
        name: name,
        email: email,
        phone: phone,
        userType: userType,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(newUser.toMap());
      await _syncMessagingToken(credential.user!.uid);

      _currentUser = newUser;
      notifyListeners();

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An error occurred. Please try again.';
    }
  }

  // Sign in
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Fetch user data
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (userDoc.exists) {
        _currentUser = UserModel.fromMap(
          userDoc.data() as Map<String, dynamic>,
        );
        await _syncMessagingToken(credential.user!.uid);
        notifyListeners();
      }

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An error occurred. Please try again.';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // Check if user is logged in
  Future<void> checkAuthState() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        _currentUser = UserModel.fromMap(
          userDoc.data() as Map<String, dynamic>,
        );
        await _syncMessagingToken(user.uid);
        notifyListeners();
      }
    }
  }

  Future<String?> updateProfile({
    required String name,
    required String phone,
    String? profilePhotoBase64,
  }) async {
    final user = _currentUser;
    if (user == null) return 'Please sign in again.';

    try {
      final updates = <String, dynamic>{'name': name, 'phone': phone};
      if (profilePhotoBase64 != null) {
        updates['profilePhotoBase64'] = profilePhotoBase64;
      }

      await _firestore.collection('users').doc(user.uid).update(updates);

      _currentUser = user.copyWith(
        name: name,
        phone: phone,
        profilePhotoBase64: profilePhotoBase64,
      );
      notifyListeners();
      return null;
    } catch (e) {
      return 'Profile update failed. Please try again.';
    }
  }

  Future<void> _syncMessagingToken(String uid) async {
    try {
      await _messaging.requestPermission();
      final token = await _messaging.getToken();
      if (token == null) return;

      await _firestore.collection('users').doc(uid).update({'fcmToken': token});

      _messaging.onTokenRefresh.listen((newToken) {
        _firestore.collection('users').doc(uid).update({'fcmToken': newToken});
      });
    } catch (_) {
      // Token sync is best-effort; Firestore in-app notifications still work.
    }
  }
}
