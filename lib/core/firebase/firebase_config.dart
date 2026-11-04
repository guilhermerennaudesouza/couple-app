import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration tailored for Spark free tier.
///
/// Configures Cloud Firestore with offline disk persistence (100MB cache)
/// to ensure full read/write offline-first capability for couples.
class FirebaseConfig {
  /// Spark tier offline cache size: 100 MB (104,857,600 bytes).
  static const int sparkCacheSizeBytes = 104857600;

  /// Returns the Firestore [Settings] with offline disk persistence enabled
  /// and a 100MB cache limit to support offline edits and automatic sync.
  static Settings get firestoreSettings => const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: sparkCacheSizeBytes,
      );

  /// Initializes the default Firebase application (if not already initialized)
  /// and configures Cloud Firestore to use offline disk persistence.
  static Future<void> initialize({FirebaseOptions? options}) async {
    try {
      if (Firebase.apps.isEmpty) {
        if (options != null) {
          await Firebase.initializeApp(options: options);
        } else {
          await Firebase.initializeApp();
        }
      }
      FirebaseFirestore.instance.settings = firestoreSettings;
    } catch (e) {
      // In local unit test environments or prior to google-services.json registration,
      // Firebase.initializeApp() can throw a FirebaseException. We log and keep going.
      debugPrint('FirebaseConfig.initialize warning: $e');
    }
  }
}
