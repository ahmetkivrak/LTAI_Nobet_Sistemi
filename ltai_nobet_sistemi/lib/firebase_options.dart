import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDBfAgblGJwuCLzBQIvPzYl9aYr2SOlLpw',
    appId: '1:1057466119258:web:ebd8e33d6eb6b4ef7a5463',
    messagingSenderId: '1057466119258',
    projectId: 'ltai-kule-9c7bd',
    authDomain: 'ltai-kule-9c7bd.firebaseapp.com',
    storageBucket: 'ltai-kule-9c7bd.firebasestorage.app',
  );

  // Android ve iOS için henüz SDK snippet'lerini almadık ama altyapıyı hazır bırakıyorum.
  // Manuel kurulumda şimdilik web üzerinden ilerlemek en hızlısı.
  static const FirebaseOptions android = web; 
  static const FirebaseOptions ios = web;
}
