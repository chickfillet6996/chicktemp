class SharedWorkspace {
  const SharedWorkspace._();

  static const String id = 'main_farm';
  static const String baseAccountEmail = 'aaronasuncion99@gmail.com';
  static const String hardwareControlBatchKey = 'broiler_batch_1';
  static const String firebaseRoot = 'workspaces/$id';
  static const String localKeyPrefix = 'shared_workspace_$id';

  static String path(String childPath) {
    final normalized = childPath
        .trim()
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
    return normalized.isEmpty ? firebaseRoot : '$firebaseRoot/$normalized';
  }

  static String legacyUserPath(String userId, String childPath) {
    final normalized = childPath
        .trim()
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
    return normalized.isEmpty
        ? 'user_data/$userId'
        : 'user_data/$userId/$normalized';
  }

  static String localKey(String suffix) {
    final safeSuffix = suffix
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return safeSuffix.isEmpty
        ? localKeyPrefix
        : '${localKeyPrefix}_$safeSuffix';
  }
}
