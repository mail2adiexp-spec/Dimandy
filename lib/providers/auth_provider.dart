import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:cloud_functions/cloud_functions.dart';

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

  // New Roles for Multi-State System
  static const String superAdmin = 'super_admin';
  static const String stateAdmin = 'state_admin';
}

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String? phoneNumber;
  final String? photoURL;
  final String? role;
  final String? storeId;
  final String? assignedState; // For State Admins
  final String? state; // For Customers/Sellers
  final String? pincode; // Added pincode
  final Map<String, dynamic> permissions;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    this.phoneNumber,
    this.photoURL,
    this.role,
    this.storeId,
    this.assignedState,
    this.state,
    this.pincode,
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

  // Simple fallback allowlist for admin emails
  // NOTE: For better security, move these to Firestore 'admins' collection or Firebase Custom Claims
  static const Set<String> _adminEmails = {
    'mail2adiexp@gmail.com',
    'sounak@bongbazar.com',
    'admin@bongbazar.com',
    'rfnindrajit@gmail.com',
  };

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

  bool get isSuperAdmin {
    if (_currentUser == null) return false;
    return _currentUser!.role == UserRole.superAdmin ||
        _adminEmails.contains(_currentUser!.email);
  }

  bool get isStateAdmin {
    if (_currentUser == null) return false;
    return _currentUser!.role == UserRole.stateAdmin;
  }

  // Checking if user has ANY admin privileges (Super or State)
  bool get hasAdminAccess {
    return isSuperAdmin || isStateAdmin || isAdministrator;
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser != null) {
      debugPrint('🔄 Auth state changed for user: ${firebaseUser.uid}');

      // Fetch user role from Firestore (SINGLE read)
      String userRole = 'user';
      String? storeId;
      String? assignedState;
      String? state;
      String? pincode;
      Map<String, dynamic> permissions = {};
      String? firestorePhone;
      bool hasAdminRole = false;

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          userRole = data['role'] ?? 'user';
          storeId = data['storeId'] as String?;
          assignedState = data['assignedState'] as String?;
          state = data['state'] as String?;
          pincode =
              data['pincode'] as String? ?? data['servicePincode'] as String?;
          permissions = data['permissions'] as Map<String, dynamic>? ?? {};
          firestorePhone =
              data['phoneNumber'] as String? ?? data['phone'] as String?;
          hasAdminRole = userRole == 'admin';

          // Update lastLogin
          await FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .update({'lastLogin': FieldValue.serverTimestamp()});
        }
      } catch (e) {
        debugPrint('Error fetching user data or updating lastLogin: $e');
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
        storeId: storeId,
        assignedState: assignedState,
        state: state,
        pincode: pincode,
        permissions: permissions,
      );

      debugPrint('✅ User updated - role: $userRole');

      try {
        // 1) Check custom claims
        final token = await firebaseUser.getIdTokenResult(true);
        final claims = token.claims ?? {};
        bool hasAdminClaim = claims['admin'] == true;

        // 2) Check allowed email list (fallback)
        bool isAllowedEmail = _adminEmails.contains(firebaseUser.email);

        _isAdmin = hasAdminClaim || hasAdminRole || isAllowedEmail;
        debugPrint('👑 Admin status: $_isAdmin');
      } catch (e) {
        debugPrint('Error checking admin status: $e');
        _isAdmin = false;
      }
    } else {
      _currentUser = null;
      _isAdmin = false;
    }
    notifyListeners();
  }

  // Helper to generate numeric ID
  Future<String> _generateNextUserId() async {
    final firestore = FirebaseFirestore.instance;
    final counterRef = firestore.doc('stats/user_counters');

    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int currentId = 10000; // Start from 10000
      if (snapshot.exists) {
        currentId = snapshot.data()?['currentId'] ?? 10000;
      }

      final nextId = currentId + 1;
      transaction.set(counterRef, {
        'currentId': nextId,
      }, SetOptions(merge: true));

      return nextId.toString();
    });
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String phoneNumber, // Make phone number mandatory
    String role = 'user',
    String? state,
    String? pincode,
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

        // Generate Numeric ID
        final displayId = await _generateNextUserId();

        await firestore.collection('users').doc(credential.user!.uid).set({
          'id': credential.user!.uid,
          'displayId': displayId, // Added displayId
          'email': email.trim(),
          'name': name.trim(),
          'phoneNumber': phoneNumber.trim(), // Save Phone Number
          'role': role,
          'state': state,
          'pincode': pincode,
          'createdAt': FieldValue.serverTimestamp(),
          'photoURL': null,
          'lastLogin': FieldValue.serverTimestamp(),
        });
        print(
          '✅ User created in Firestore with role: $role and ID: $displayId',
        );
        print('🔍 Saved state: $state, pincode: $pincode');

        // Force reload to ensure AppUser gets fresh Firestore data immediately
        await credential.user?.reload();
        await _onAuthStateChanged(credential.user);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception(
          'Password must be at least 8 characters and include uppercase, lowercase, number, and special character.',
        );
      } else if (e.code == 'email-already-in-use') {
        throw Exception(
          'This email is already registered. Please sign in or use a different email.',
        );
      } else if (e.code == 'invalid-email') {
        throw Exception('Please enter a valid email address.');
      } else if (e.code == 'operation-not-allowed') {
        throw Exception(
          'Email/password sign-up is currently disabled. Please contact support.',
        );
      } else {
        throw Exception(
          e.message ?? 'Unable to create account. Please try again.',
        );
      }
    } catch (e) {
      throw Exception(
        'Network error. Please check your internet connection and try again.',
      );
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
        throw Exception(
          'No account found with this email. Please check your email or sign up.',
        );
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Incorrect email or password. Please try again.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Please enter a valid email address.');
      } else if (e.code == 'user-disabled') {
        throw Exception(
          'This account has been disabled. Please contact support.',
        );
      } else if (e.code == 'too-many-requests') {
        throw Exception(
          'Too many failed attempts. Please wait a moment and try again.',
        );
      } else if (e.code == 'network-request-failed') {
        throw Exception(
          'Network error. Please check your internet connection.',
        );
      } else {
        // Show actual error code for debugging
        throw Exception(
          '${e.message ?? "Unable to sign in. Please try again."} (Code: ${e.code})',
        );
      }
    } catch (e) {
      throw Exception(
        'Network error. Please check your internet connection and try again.',
      );
    }
  }

  String? _verificationId;
  String? get verificationId => _verificationId;

  Future<void> requestOTP(String phoneNumber) async {
    final completer = Completer<void>();
    try {
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+91$phoneNumber'; // default to India
      }
      
      try {
        await _auth.setSettings(appVerificationDisabledForTesting: false);
      } catch (e) {
        debugPrint('Failed to set settings: $e');
      }

      if (kIsWeb) {
        // On Web, use signInWithPhoneNumber which defaults to an invisible reCAPTCHA
        final ConfirmationResult result = await _auth.signInWithPhoneNumber(
          phoneNumber,
        );
        
        _verificationId = result.verificationId;
        if (!completer.isCompleted) completer.complete();
        notifyListeners();
      } else {
        // Mobile platform handling
        await _auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto-resolution (Android only)
            await _auth.signInWithCredential(credential);
            if (!completer.isCompleted) completer.complete();
          },
          verificationFailed: (FirebaseAuthException e) {
            debugPrint('🔴 Firebase Phone Auth Error: ${e.code} - ${e.message}');
            if (!completer.isCompleted) {
              completer.completeError(
                Exception(e.message ?? 'Phone verification failed: ${e.code}'),
              );
            }
          },
          codeSent: (String verificationId, int? resendToken) {
            _verificationId = verificationId;
            if (!completer.isCompleted) completer.complete();
            notifyListeners();
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
            notifyListeners();
          },
        );
      }
      return completer.future;
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
      return completer.future;
    }
  }

  Future<void> verifyOTP(String otpCode) async {
    if (_verificationId == null) {
      throw Exception('Verification ID is missing. Request OTP again.');
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final tempUser = userCredential.user;

      if (tempUser != null) {
        // We successfully signed in with Phone Auth.
        // Now let's check if this phone number already belongs to an existing account.
        try {
          final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('checkAndReturnExistingAccount');
          final result = await callable.call();
          final data = result.data as Map<dynamic, dynamic>;

          if (data['exists'] == true && data['customToken'] != null) {
            final customToken = data['customToken'] as String;
            final originalUid = data['originalUid'] as String;

            if (tempUser.uid != originalUid) {
               // We need to switch to the original account
               debugPrint('🔄 Existing account found. Switching from Phone Auth ID ${tempUser.uid} to original ID $originalUid');
               
               // Sign out of the temporary phone auth account
               await _auth.signOut();
               
               // Sign in to the original account using the custom token
               final newCredential = await _auth.signInWithCustomToken(customToken);
               final finalUser = newCredential.user;
               if (finalUser != null) {
                 await finalUser.reload();
                 await _onAuthStateChanged(finalUser);
               }
               return; // Successfully logged into existing account
            }
          }
        } catch (e) {
          debugPrint('⚠️ Warning: Cloud function checkAndReturnExistingAccount failed: $e');
          // If the cloud function fails (e.g., no internet, or not deployed yet), 
          // we fallback to the normal flow (just continue with the Phone Auth user).
        }

        // If we reach here, it either means:
        // 1. The cloud function returned false (genuinely new user).
        // 2. The temporary phone auth ID is actually the same as the original ID.
        // 3. The cloud function failed so we fallback.
        
        // If it's a completely new user without any existing account
        if (userCredential.additionalUserInfo?.isNewUser == true) {
          final displayId = await _generateNextUserId();
          await FirebaseFirestore.instance.collection('users').doc(tempUser.uid).set({
            'id': tempUser.uid,
            'displayId': displayId,
            'name': 'User',
            'phoneNumber': tempUser.phoneNumber ?? '',
            'role': UserRole.user,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await tempUser.reload();
          await _onAuthStateChanged(tempUser);
        }
      }
    } catch (e) {
      debugPrint('🔴 verifyOTP Error: $e');
      throw Exception('Invalid OTP. Please try again.');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      // Explicitly pass clientId for Web to avoid 'ClientID not set' errors
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb
            ? '110161971301-4krovef2iegma5v33aefbchk8crqqjus.apps.googleusercontent.com'
            : null,
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // The user canceled the sign-in
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        // Check if user exists in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          // Generate Numeric ID
          final displayId = await _generateNextUserId();

          // Create new user
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'id': user.uid,
                'displayId': displayId, // Added displayId
                'email': user.email ?? googleUser.email,
                'name':
                    user.displayName ?? googleUser.displayName ?? 'Google User',
                'role': 'user', // Default role
                'photoURL': user.photoURL ?? googleUser.photoUrl,
                'createdAt': FieldValue.serverTimestamp(),
                'lastLogin': FieldValue.serverTimestamp(),
              });
          print('✅ New Google user created in Firestore with ID: $displayId');
        } else {
          // Update existing user's last login and photo URL if changed
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
                'lastLogin': FieldValue.serverTimestamp(),
                // Optional: Update photo URL if it's missing or changed, but respecting user's choice is better
                if (user.photoURL != null) 'photoURL': user.photoURL,
              });
        }
      }
    } catch (e) {
      debugPrint('🔴 Google Sign-In Error: $e');
      throw Exception('Google Sign-In failed: $e');
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
        throw Exception(
          e.message ?? 'Failed to send reset email. Please try again.',
        );
      }
    } catch (e) {
      throw Exception(
        'Network error. Please check your internet connection and try again.',
      );
    }
  }

  Future<void> updateProfile({
    required String name,
    String? state,
    String? pincode,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      await user.updateDisplayName(name.trim());

      // Update Firestore
      final Map<String, dynamic> updates = {};
      if (state != null) updates['state'] = state;
      if (pincode != null) updates['pincode'] = pincode; // Add pincode update
      // We might want to update name in Firestore too if we store it there (we do)
      updates['name'] = name.trim();

      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(updates, SetOptions(merge: true));
      }

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
    String? password, // Made password optional
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      // Check if user has an email/password provider linked
      bool hasPasswordProvider = user.providerData.any((userInfo) => userInfo.providerId == 'password');

      if (hasPasswordProvider) {
         if (password == null || password.isEmpty) {
            throw Exception('Password required to update email.');
         }
         // Re-authenticate user before email change
         final credential = EmailAuthProvider.credential(
           email: user.email!, // Previous email
           password: password,
         );
         await user.reauthenticateWithCredential(credential);
      }

      // If they don't have an email yet (e.g., OTP login), just update it directly
      if (user.email == null || user.email!.isEmpty) {
         // This skips verification email and just sets it, which is useful for OTP users setting it for the first time
         // Unfortunately Firebase Auth doesn't have a direct `updateEmail` anymore without verification,
         // but we can try verifyBeforeUpdateEmail, which will send a link to the NEW email.
         await user.verifyBeforeUpdateEmail(email.trim());
      } else {
         await user.verifyBeforeUpdateEmail(email.trim());
      }
      
      // Also update in Firestore immediately (or we could wait for webhook if available, but for UX we can update it)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'email': email.trim()},
      );
      // Return success message via a custom result instead of throwing
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

      final trimmedPhone = phoneNumber.trim();

      // Check if phone number is already in use by another account
      QuerySnapshot existingDocs;
      try {
        existingDocs = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: trimmedPhone)
            .get();
      } catch (e) {
        print('Error checking phone uniqueness: $e');
        throw Exception(
          'System Error: Could not verify phone number uniqueness. Details: $e',
        );
      }

      if (existingDocs.docs.isNotEmpty) {
        // If found document is NOT the current user, block it
        for (final doc in existingDocs.docs) {
          if (doc.id != user.uid) {
            throw Exception(
              'This phone number is already associated with another account.',
            );
          }
        }
      }

      // Update phone number in Firestore only
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phoneNumber': trimmedPhone,
      }, SetOptions(merge: true));

      // Refresh the user data to reflect changes in UI
      _onAuthStateChanged(_auth.currentUser);
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
      debugPrint('🔵 Starting image upload...');
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ No user signed in');
        throw Exception('No user signed in');
      }
      debugPrint('✅ User authenticated: ${user.uid}');

      if (imageFile == null && imageBytes == null) {
        debugPrint('❌ No image provided');
        throw Exception('No image provided');
      }

      final imageSize = imageBytes?.length ?? await imageFile!.length();
      debugPrint('📦 Image size: ${(imageSize / 1024).toStringAsFixed(2)} KB');

      // Upload to Firebase Storage using default bucket
      final storage = FirebaseStorage.instance;
      final storageRef = storage
          .ref()
          .child('user_images')
          .child('${user.uid}.jpg');
      debugPrint('📁 Upload path: user_images/${user.uid}.jpg');

      // Decide content type from filename if available
      String contentType = 'image/jpeg';
      if (fileName != null) {
        final lower = fileName.toLowerCase();
        if (lower.endsWith('.png')) contentType = 'image/png';
        if (lower.endsWith('.webp')) contentType = 'image/webp';
      }
      debugPrint('📝 Content-Type: $contentType');

      // Upload based on platform
      UploadTask uploadTask;
      if (imageBytes != null) {
        debugPrint('🌐 Uploading via bytes (Web)...');
        uploadTask = storageRef.putData(
          imageBytes,
          SettableMetadata(
            contentType: contentType,
            cacheControl: 'public, max-age=3600',
          ),
        );
      } else {
        debugPrint('📱 Uploading via file (Mobile/Desktop)...');
        uploadTask = storageRef.putFile(
          imageFile!,
          SettableMetadata(
            contentType: contentType,
            cacheControl: 'public, max-age=3600',
          ),
        );
      }

      debugPrint('⏳ Waiting for upload to complete...');
      final TaskSnapshot snapshot = await uploadTask;
      debugPrint('📊 Upload state: ${snapshot.state.name}');

      if (snapshot.state != TaskState.success) {
        debugPrint('❌ Upload failed with state: ${snapshot.state.name}');
        throw Exception('Upload failed: ${snapshot.state.name}');
      }

      debugPrint('✅ Upload successful! Getting download URL...');
      final downloadURL = await storageRef.getDownloadURL().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('❌ Download URL fetch timeout');
          throw Exception('Failed to get download URL: timeout');
        },
      );
      debugPrint('🔗 Download URL: $downloadURL');

      debugPrint('💾 Updating user profile with photo URL...');
      // Update the photo URL on Firebase Auth
      await user.updatePhotoURL(downloadURL);
      // Reload the user to get the latest data from Firebase
      await user.reload();
      debugPrint('✅ Profile updated successfully!');
      // Manually trigger the state change with the reloaded user object
      _onAuthStateChanged(_auth.currentUser);
      debugPrint('🔄 Auth state refreshed');
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase error: ${e.code} - ${e.message}');
      throw Exception('Firebase error: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      throw Exception('Image upload failed: $e');
    }
  }

  Future<void> refreshUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      debugPrint('🔄 Manually refreshing user profile...');
      // Re-run the logic to fetch firestore data
      await _onAuthStateChanged(user);
    }
  }
}
