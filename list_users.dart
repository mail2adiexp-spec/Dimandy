import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('Fetching all users...');
  final snapshot = await FirebaseFirestore.instance.collection('users').get();
  print('Total documents: ${snapshot.docs.length}');
  
  for (var doc in snapshot.docs) {
    print('User: ${doc.id} | Name: ${doc['name']} | Role: ${doc['role']} | Email: ${doc['email']}');
  }
}
