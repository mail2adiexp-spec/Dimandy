import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';

// Role constants
class UserRole {
  static const String user = 'user';
  static const String seller = 'seller';
  static const String serviceProvider = 'service_provider';
  static const String coreStaff = 'core_staff';
  static const String administrator = 'administrator';
  static const String storeManager = 'store_manager';
  static const String manager = 'manager';
  static const String deliveryPartner = 'delivery_partner';
  static const String customerCare = 'customer_care';
}

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String? phoneNumber;
  final String? photoURL;
  final String? role;
  final Map<String, dynamic> permissions;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    this.phoneNumber,
    this.photoURL,
    this.role,
    this.permissions = const {},
  });

  bool hasPermission(String key) {
    // Default to true if permission is not explicitly set to false
    // This ensures backward compatibility
    return permissions[key] != false;
  }
}

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  AppUser? _currentUser;
  bool _isAdmin = false;

  // Simple fallback allowlist for admin emails (requested)
  static const Set<String> _adminEmails = {'mail2adiexp@gmail.com'};

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _isAdmin;

  bool get isSeller {
    if (_currentUser == null) return false;
    final role = _currentUser!.role ?? UserRole.user;
    return role == UserRole.seller || _isAdmin;
  }

  bool get isServiceProvider {
    if (_currentUser == null) return false;
    return _currentUser!.role == UserRole.serviceProvider;
  }

  bool get isCoreStaff {
    if (_currentUser == null) return false;
    return _currentUser!.role == UserRole.coreStaff;
  }

  bool get isAdministrator {
    if (_currentUser == null) return false;
    return _currentUser!.role == UserRole.administrator || _isAdmin;
  }

  bool get isStoreManager {
    if (_currentUser == null) return false;
    return _currentUser!.role == UserRole.storeManager;
  }

  bool get isManager {
    if (_currentUser == null) return false;
    return _currentUser!.role == UserRole.manager;
  }

  bool get isDeliveryPartner {
    if (_currentUser == null) return false;
    return _currentUser!.role == UserRole.deliveryPartner;
  }

  bool get isCustomerCare {
    if (_currentUser == null) return false;
    return _currentUser!.role == UserRole.customerCare;
  }

  void _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser != null) {
      print('🔄 Auth state changed for user: ${firebaseUser.uid}');
      print('📸 PhotoURL: ${firebaseUser.photoURL}');

      // Fetch user role from Firestore
      String userRole = 'user';
      Map<String, dynamic> permissions = {};

      String? firestorePhone;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          userRole = data['role'] ?? 'user';
          permissions = data['permissions'] as Map<String, dynamic>? ?? {};
          firestorePhone = data['phoneNumber'] as String? ?? data['phone'] as String?;
          
          // Update lastLogin
          await FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .update({'lastLogin': FieldValue.serverTimestamp()});
        }
      } catch (e) {
        print('Error fetching user role or updating lastLogin: $e');
      }

      _currentUser = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name:
            firebaseUser.displayName ??
            firebaseUser.email?.split('@').first ??
            'User',
        phoneNumber: firestorePhone ?? firebaseUser.phoneNumber,
        photoURL: firebaseUser.photoURL,
        role: userRole,
        permissions: permissions,
      );

      print(
        '✅ Current user updated with photoURL: ${_currentUser?.photoURL} and role: $userRole',
      );

      try {
        // 1) Check custom claims
        final token = await firebaseUser.getIdTokenResult(true);
        final claims = token.claims ?? {};
        bool hasAdminClaim = claims['admin'] == true;

        // 2) Also check Firestore users/{uid}.role == 'admin'
        bool hasAdminRole = false;
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data();
            if (data != null && data['role'] == 'admin') {
              hasAdminRole = true;
            }
          }
        } catch (e) {
          print('Error checking admin role in Firestore: $e');
        }

        // 3) Check allowed email list (fallback)
        final allowedEmails = [
          'admin@bongbazar.com',
          'sounak@bongbazar.com',
          'mail2adiexp@gmail.com',
        ];
        bool isAllowedEmail = allowedEmails.contains(firebaseUser.email);

        _isAdmin = hasAdminClaim || hasAdminRole || isAllowedEmail;
        print('👑 Admin status: $_isAdmin');
      } catch (e) {
        print('Error checking admin status: $e');
        _isAdmin = false;
      }
    } else {
      _currentUser = null;
      _isAdmin = false;
    }
    notifyListeners();
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String role = 'user', // Default role should be plain user until approved
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      await credential.user?.reload();

      // Save user to Firestore with role (default user)
      if (credential.user != null) {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('users').doc(credential.user!.uid).set({
          'id': credential.user!.uid,
          'email': email.trim(),
          'name': name.trim(),
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          'photoURL': null,
          'phoneNumber': null,
        });
        print('✅ User created in Firestore with role: $role');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception('Password must be at least 8 characters and include uppercase, lowercase, number, and special character.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('This email is already registered. Please sign in or use a different email.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Please enter a valid email address.');
      } else if (e.code == 'operation-not-allowed') {
        throw Exception('Email/password sign-up is currently disabled. Please contact support.');
      } else {
        throw Exception(e.message ?? 'Unable to create account. Please try again.');
      }
    } catch (e) {
      throw Exception('Network error. Please check your internet connection and try again.');
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Debug logging
      debugPrint('🔴 Firebase Auth Error: ${e.code}');
      debugPrint('🔴 Error message: ${e.message}');
      
      // Handle specific error codes (updated for newer Firebase)
      if (e.code == 'user-not-found' || e.code == 'INVALID_LOGIN_CREDENTIALS') {
        throw Exception('No account found with this email. Please check your email or sign up.');
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Incorrect email or password. Please try again.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Please enter a valid email address.');
      } else if (e.code == 'user-disabled') {
        throw Exception('This account has been disabled. Please contact support.');
      } else if (e.code == 'too-many-requests') {
        throw Exception('Too many failed attempts. Please wait a moment and try again.');
      } else if (e.code == 'network-request-failed') {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        // Show actual error code for debugging
        throw Exception('${e.message ?? "Unable to sign in. Please try again."} (Code: ${e.code})');
      }
    } catch (e) {
      throw Exception('Network error. Please check your internet connection and try again.');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No account found with this email address.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Please enter a valid email address.');
      } else {
        throw Exception(e.message ?? 'Failed to send reset email. Please try again.');
      }
    } catch (e) {
      throw Exception('Network error. Please check your internet connection and try again.');
    }
  }

  Future<void> updateProfile({required String name}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');
      await user.updateDisplayName(name.trim());
      await user.reload();
      // Trigger state change to update UI
      _onAuthStateChanged(_auth.currentUser);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Update failed');
    } catch (e) {
      throw Exception('Update failed: $e');
    }
  }

  Future<void> updateEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      // Re-authenticate user before email change
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Update email in Firebase Auth
      await user.verifyBeforeUpdateEmail(email.trim());
      // Also update in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'email': email.trim()},
      );
      throw Exception(
        'Verification email sent. Please check your new email and verify it.',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('This email is already registered');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email format');
      } else if (e.code == 'wrong-password') {
        throw Exception('Incorrect password');
      }
      throw Exception(e.message ?? 'Email update failed');
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> updatePhoneNumber({required String phoneNumber}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');
      // Update phone number in Firestore only
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'phoneNumber': phoneNumber.trim()},
      );
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> updateProfileImage({
    File? imageFile,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    try {
      print('🔵 Starting image upload...');
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user signed in');
        throw Exception('No user signed in');
      }
      print('✅ User authenticated: ${user.uid}');

      if (imageFile == null && imageBytes == null) {
        print('❌ No image provided');
        throw Exception('No image provided');
      }

      final imageSize = imageBytes?.length ?? await imageFile!.length();
      print('📦 Image size: ${(imageSize / 1024).toStringAsFixed(2)} KB');

      // Upload to Firebase Storage with explicit bucket
      final storage = FirebaseStorage.instanceFor(
        bucket: 'gs://bong-bazar-3659f.firebasestorage.app',
      );
      final storageRef = storage
          .ref()
          .child('user_images')
          .child('${user.uid}.jpg');
      print('📁 Upload path: user_images/${user.uid}.jpg');
      print('🪣 Bucket: gs://bong-bazar-3659f.firebasestorage.app');

      // Decide content type from filename if available
      String contentType = 'image/jpeg';
      if (fileName != null) {
        final lower = fileName.toLowerCase();
        if (lower.endsWith('.png')) contentType = 'image/png';
        if (lower.endsWith('.webp')) contentType = 'image/webp';
      }
      print('📝 Content-Type: $contentType');

      // Upload based on platform
      UploadTask uploadTask;
      if (imageBytes != null) {
        print('🌐 Uploading via bytes (Web)...');
        uploadTask = storageRef.putData(
          imageBytes,
          SettableMetadata(
            contentType: contentType,
            cacheControl: 'public, max-age=3600',
          ),
        );
      } else {
        print('📱 Uploading via file (Mobile/Desktop)...');
        uploadTask = storageRef.putFile(
          imageFile!,
          SettableMetadata(
            contentType: contentType,
            cacheControl: 'public, max-age=3600',
          ),
        );
      }

      print('⏳ Waiting for upload to complete...');
      final TaskSnapshot snapshot = await uploadTask;
      print('📊 Upload state: ${snapshot.state.name}');

      if (snapshot.state != TaskState.success) {
        print('❌ Upload failed with state: ${snapshot.state.name}');
        throw Exception('Upload failed: ${snapshot.state.name}');
      }

      print('✅ Upload successful! Getting download URL...');
      final downloadURL = await storageRef.getDownloadURL().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          print('❌ Download URL fetch timeout');
          throw Exception('Failed to get download URL: timeout');
        },
      );
      print('🔗 Download URL: $downloadURL');

      print('💾 Updating user profile with photo URL...');
      // Update the photo URL on Firebase Auth
      await user.updatePhotoURL(downloadURL);
      // Reload the user to get the latest data from Firebase
      await user.reload();
      print('✅ Profile updated successfully!');
      // Manually trigger the state change with the reloaded user object
      _onAuthStateChanged(_auth.currentUser);
      print('🔄 Auth state refreshed');
    } on FirebaseException catch (e) {
      print('❌ Firebase error: ${e.code} - ${e.message}');
      throw Exception('Firebase error: ${e.code} - ${e.message}');
    } catch (e) {
      print('❌ Upload error: $e');
      throw Exception('Image upload failed: $e');
    }
  }
}
