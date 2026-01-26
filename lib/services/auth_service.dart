import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Convert Firebase User to AppUser with role lookup
  Future<AppUser?> _userFromFirebase(User? user) async {
    if (user == null) return null;
    
    // Fetch user role from Firestore
    UserRole role = UserRole.user;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final roleStr = doc.data()?['role'] as String?;
        if (roleStr == 'admin') {
          role = UserRole.admin;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user role: $e');
      }
    }
    
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      isGuest: user.isAnonymous,
      role: role,
    );
  }

  // Sync version for stream (fetches role afterward)
  AppUser? _userFromFirebaseSync(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      isGuest: user.isAnonymous,
      role: UserRole.user, // Default, will be updated by provider
    );
  }

  // Auth state stream
  Stream<AppUser?> get authStateChanges {
    return _auth.authStateChanges().map(_userFromFirebaseSync);
  }

  // Current user (sync version)
  AppUser? get currentUser => _userFromFirebaseSync(_auth.currentUser);

  // Current user with role (async)
  Future<AppUser?> getCurrentUserWithRole() async {
    return await _userFromFirebase(_auth.currentUser);
  }

  // Email/Password Sign In
  Future<AppUser?> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return await _userFromFirebase(result.user);
  }

  // Email/Password Sign Up
  Future<AppUser?> signUpWithEmail(
      String email, String password, String name) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await result.user?.updateDisplayName(name);
    
    // Create user document in Firestore
    if (result.user != null) {
      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': email,
        'displayName': name,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    
    return await _userFromFirebase(result.user);
  }

  // Google Sign In
  Future<AppUser?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      
      // Ensure user document exists
      if (result.user != null) {
        await _firestore.collection('users').doc(result.user!.uid).set({
          'email': result.user!.email,
          'displayName': result.user!.displayName,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      
      return await _userFromFirebase(result.user);
    } catch (e) {
      if (kDebugMode) {
        print("Google Sign In Error: $e");
        print("Stack trace: ${StackTrace.current}");
      }
      rethrow;
    }
  }

  // Guest Login (Anonymous)
  Future<AppUser?> signInAsGuest() async {
    final result = await _auth.signInAnonymously();
    return await _userFromFirebase(result.user);
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}
