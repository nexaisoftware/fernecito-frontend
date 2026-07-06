library;

import 'package:firebase_core/firebase_core.dart';

class ConfigPushWeb {
  static const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
  );
  static const vapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');

  static bool get habilitada =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty &&
      vapidKey.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
  );
}
