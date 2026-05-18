class StorageConfig {
  static const String defaultAudioBucket = 'audio';
  // If your bucket is public, set this to true. If you're unsure, false is safer (forces signed URLs).
  static const bool isAudioBucketPublic = false;
  static const int signedUrlExpirySeconds = 3600; // 1 hour
}
