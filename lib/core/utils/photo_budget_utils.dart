import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

/// Guards Firestore's 1 MB document limit for Spark-tier Base64 photo storage
/// and provides an in-memory LRU cache to prevent synchronous Base64 decode jank.
class PhotoBudgetUtils {
  /// Maximum number of embedded photos per Firestore document.
  static const int maxPhotosPerDoc = 4;

  /// Safe UTF-8 payload budget for all photos in a single Firestore document (~850 KB).
  static const int maxTotalBytes = 850 * 1024;

  static const int _maxCacheEntries = 40;
  static final LinkedHashMap<String, Uint8List> _decodeCache =
      LinkedHashMap<String, Uint8List>();

  /// Returns `true` if appending [candidateDataUri] keeps the document within
  /// [maxPhotosPerDoc] and [maxTotalBytes].
  static bool canAddPhoto({
    required List<String> existingDataUris,
    required String candidateDataUri,
  }) {
    if (existingDataUris.length >= maxPhotosPerDoc) {
      return false;
    }
    int totalBytes = utf8.encode(candidateDataUri).length;
    for (final uri in existingDataUris) {
      totalBytes += utf8.encode(uri).length;
    }
    return totalBytes <= maxTotalBytes;
  }

  /// Decodes a Base64 Data URI (or `base64:` string) with LRU caching.
  static Uint8List? decodeCachedBase64(String photoUrl) {
    final existing = _decodeCache.remove(photoUrl);
    if (existing != null) {
      // Re-insert at tail to mark most recently used
      _decodeCache[photoUrl] = existing;
      return existing;
    }

    try {
      final base64Data = photoUrl.contains(',')
          ? photoUrl.substring(photoUrl.indexOf(',') + 1)
          : (photoUrl.startsWith('base64:') ? photoUrl.substring(7) : photoUrl);
      final bytes = base64Decode(base64Data);
      if (_decodeCache.length >= _maxCacheEntries) {
        _decodeCache.remove(_decodeCache.keys.first);
      }
      _decodeCache[photoUrl] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }
}
