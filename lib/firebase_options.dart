// File generated for default/placeholder Firebase options.
// Replace with your real Firebase configuration by running: flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDeVBshSrGHm3uTave-py0Yzg64wyA0U0E',
    appId: '1:875181118672:web:f0ab10edb8887728ad3ad5',
    messagingSenderId: '875181118672',
    projectId: 'klinixy-68521',
    authDomain: 'klinixy-68521.firebaseapp.com',
    storageBucket: 'klinixy-68521.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCfz1UIhPNbTOWBcq8yG7szLpuh3qrGWdM',
    appId: '1:875181118672:android:4b1ca6ca3e05e4fbad3ad5',
    messagingSenderId: '875181118672',
    projectId: 'klinixy-68521',
    storageBucket: 'klinixy-68521.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderKeyForBuildValidationOnly',
    appId: '1:1234567890:ios:abcdef1234567890',
    messagingSenderId: '1234567890',
    projectId: 'pharmacist-dashboard-demo',
    storageBucket: 'pharmacist-dashboard-demo.appspot.com',
    iosBundleId: 'com.example.pharmacistDashboard',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderKeyForBuildValidationOnly',
    appId: '1:1234567890:ios:abcdef1234567890',
    messagingSenderId: '1234567890',
    projectId: 'pharmacist-dashboard-demo',
    storageBucket: 'pharmacist-dashboard-demo.appspot.com',
    iosBundleId: 'com.example.pharmacistDashboard',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDeVBshSrGHm3uTave-py0Yzg64wyA0U0E',
    appId: '1:875181118672:web:e3b42bd6e7779a03ad3ad5',
    messagingSenderId: '875181118672',
    projectId: 'klinixy-68521',
    authDomain: 'klinixy-68521.firebaseapp.com',
    storageBucket: 'klinixy-68521.firebasestorage.app',
  );

}
