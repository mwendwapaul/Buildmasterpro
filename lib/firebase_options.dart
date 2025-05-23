// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
    apiKey: 'AIzaSyBJoXnow_4AV_SDV2fRMSBBlpS8KpBeR_U',
    appId: '1:168277520180:web:77de7121eead332c683f61',
    messagingSenderId: '168277520180',
    projectId: 'build-master-pro',
    authDomain: 'build-master-pro.firebaseapp.com',
    storageBucket: 'build-master-pro.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDq55seEkcTymJiIY4uLAZFCaEkEFsemFw',
    appId: '1:168277520180:android:50cb29e2607fec69683f61',
    messagingSenderId: '168277520180',
    projectId: 'build-master-pro',
    storageBucket: 'build-master-pro.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDZZhtyKPH3JWcBylQtDuuIEyVNFInIntk',
    appId: '1:168277520180:ios:495d58598c8a60da683f61',
    messagingSenderId: '168277520180',
    projectId: 'build-master-pro',
    storageBucket: 'build-master-pro.firebasestorage.app',
    androidClientId: '168277520180-0unbdt7crdh986hmuujeuji2scit4gje.apps.googleusercontent.com',
    iosClientId: '168277520180-rd0b4gkrhigogdorlvbdkrkpl6otmkdr.apps.googleusercontent.com',
    iosBundleId: 'com.example.buildMasterpro',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDZZhtyKPH3JWcBylQtDuuIEyVNFInIntk',
    appId: '1:168277520180:ios:495d58598c8a60da683f61',
    messagingSenderId: '168277520180',
    projectId: 'build-master-pro',
    storageBucket: 'build-master-pro.firebasestorage.app',
    androidClientId: '168277520180-0unbdt7crdh986hmuujeuji2scit4gje.apps.googleusercontent.com',
    iosClientId: '168277520180-rd0b4gkrhigogdorlvbdkrkpl6otmkdr.apps.googleusercontent.com',
    iosBundleId: 'com.example.buildMasterpro',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBJoXnow_4AV_SDV2fRMSBBlpS8KpBeR_U',
    appId: '1:168277520180:web:dffb257404eaea5e683f61',
    messagingSenderId: '168277520180',
    projectId: 'build-master-pro',
    authDomain: 'build-master-pro.firebaseapp.com',
    storageBucket: 'build-master-pro.firebasestorage.app',
  );

}