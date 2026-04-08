import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  String userId = 'Vit2eRqFmVXh970TE1ADjlkWkug2'; // User from logs
  print('Checking permissions for user: $userId');
  
  final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  if (doc.exists) {
    print('User exists. Role: ${doc['role']}');
    final data = doc.data()!;
    if (data.containsKey('permissions')) {
      print('Permissions: ${data['permissions']}');
    } else {
      print('WARNING: "permissions" field is MISSING.');
    }
  } else {
    print('User document NOT found.');
  }
}
