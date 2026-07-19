import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase web options are not configured. Add a Firebase web app and '
        'rerun FlutterFire configuration.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase options are only configured for Android and iOS.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAPmfhpIjJcwGFSb_hSdahNjmfAE9NuLd8',
    appId: '1:625050349217:android:c7a8cfd8519bf904930ae0',
    messagingSenderId: '625050349217',
    projectId: 'b4y2-pj',
    storageBucket: 'b4y2-pj.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBGGJxrSpcT22B9IszYIuEczyDPHoTX990',
    appId: '1:625050349217:ios:cad5c368065ba15a930ae0',
    messagingSenderId: '625050349217',
    projectId: 'b4y2-pj',
    storageBucket: 'b4y2-pj.firebasestorage.app',
    iosBundleId: 'com.example.b4y',
  );
}
