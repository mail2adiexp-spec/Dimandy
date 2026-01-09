// Migration script to copy serviceCategoryId and serviceCategoryName
// from partner_requests to users collection for existing service providers
//
// Run this once: dart run scripts/migrate_service_provider_categories.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

void main() async {
  print('🚀 Starting Service Provider Category Migration...\n');

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;

  try {
    // Step 1: Get all approved service provider partner requests
    print('📋 Fetching approved service provider partner requests...');
    final partnerRequestsSnapshot = await firestore
        .collection('partner_requests')
        .where('role', isEqualTo: 'Service Provider')
        .where('status', isEqualTo: 'approved')
        .get();

    print(
      '   Found ${partnerRequestsSnapshot.docs.length} approved service provider requests\n',
    );

    int updatedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    // Step 2: Process each partner request
    for (final requestDoc in partnerRequestsSnapshot.docs) {
      final requestData = requestDoc.data();
      final email = requestData['email'];
      final serviceCategoryId = requestData['serviceCategoryId'];
      final serviceCategoryName = requestData['serviceCategoryName'];

      print('👤 Processing: $email');

      // Check if category fields exist in partner request
      if (serviceCategoryId == null || serviceCategoryId.isEmpty) {
        print('   ⚠️  Skipped: No serviceCategoryId in partner request');
        skippedCount++;
        continue;
      }

      try {
        // Step 3: Find corresponding user document
        final usersQuery = await firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (usersQuery.docs.isEmpty) {
          print('   ⚠️  Skipped: User document not found');
          skippedCount++;
          continue;
        }

        final userDoc = usersQuery.docs.first;
        final userData = userDoc.data();

        // Check if user is actually a service provider
        if (userData['role'] != 'service_provider') {
          print(
            '   ⚠️  Skipped: User role is not service_provider (${userData['role']})',
          );
          skippedCount++;
          continue;
        }

        // Check if already has category fields
        if (userData['serviceCategoryId'] != null) {
          print('   ℹ️  Skipped: Already has serviceCategoryId');
          skippedCount++;
          continue;
        }

        // Step 4: Update user document with category fields
        await firestore.collection('users').doc(userDoc.id).update({
          'serviceCategoryId': serviceCategoryId,
          'serviceCategoryName': serviceCategoryName ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print(
          '   ✅ Updated: Added category "$serviceCategoryName" (ID: $serviceCategoryId)',
        );
        updatedCount++;
      } catch (e) {
        print('   ❌ Error: $e');
        errorCount++;
      }

      print(''); // Empty line for readability
    }

    // Step 5: Summary
    print('═══════════════════════════════════════════════════════');
    print('📊 Migration Summary:');
    print('   ✅ Successfully updated: $updatedCount users');
    print('   ⚠️  Skipped: $skippedCount users');
    print('   ❌ Errors: $errorCount users');
    print('═══════════════════════════════════════════════════════\n');

    if (updatedCount > 0) {
      print('🎉 Migration completed successfully!');
      print(
        '   Service providers should now appear in their respective categories.',
      );
    } else {
      print('ℹ️  No users were updated.');
      print(
        '   This may be normal if all service providers already have category fields.',
      );
    }
  } catch (e) {
    print('❌ Fatal error during migration: $e');
  }

  print('\n✨ Done!');
}
