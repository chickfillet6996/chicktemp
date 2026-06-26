import 'dart:convert';

import 'firebase_database_service.dart';
import 'shared_workspace.dart';

class SharedWorkspaceMigration {
  SharedWorkspaceMigration._();

  static final SharedWorkspaceMigration instance = SharedWorkspaceMigration._();

  final FirebaseDatabaseService _database = FirebaseDatabaseService.instance;
  String? _baseUserId;
  bool _loadedBaseUserId = false;

  Future<Map<String, dynamic>?> loadLegacyMap(
    String childPath, {
    String? fallbackUserId,
  }) async {
    final normalizedPath = _normalizePath(childPath);
    final triedUserIds = <String>{};

    final baseUserId = await _loadBaseUserId();
    if (baseUserId != null && triedUserIds.add(baseUserId)) {
      final baseData = await _loadLegacyMapForUser(baseUserId, normalizedPath);
      if (baseData != null && baseData.isNotEmpty) {
        return baseData;
      }
    }

    if (fallbackUserId != null && triedUserIds.add(fallbackUserId)) {
      final fallbackData = await _loadLegacyMapForUser(
        fallbackUserId,
        normalizedPath,
      );
      if (fallbackData != null && fallbackData.isNotEmpty) {
        return fallbackData;
      }
    }

    final allLegacyUsers = await _safeGet('user_data.json');
    if (allLegacyUsers is! Map<String, dynamic>) {
      return null;
    }

    for (final entry in allLegacyUsers.entries) {
      if (!triedUserIds.add(entry.key)) {
        continue;
      }
      final userData = entry.value;
      if (userData is! Map<String, dynamic>) {
        continue;
      }
      final value = _readNestedMap(userData, normalizedPath);
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadLegacyMapForUser(
    String userId,
    String childPath,
  ) async {
    final response = await _safeGet(
      '${SharedWorkspace.legacyUserPath(userId, childPath)}.json',
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return null;
  }

  Future<String?> _loadBaseUserId() async {
    if (_loadedBaseUserId) {
      return _baseUserId;
    }
    _loadedBaseUserId = true;

    final emailKey = base64Url
        .encode(utf8.encode(SharedWorkspace.baseAccountEmail))
        .replaceAll('=', '');
    final emailRecord = await _safeGet('users_by_email/$emailKey.json');
    if (emailRecord is Map<String, dynamic>) {
      final userId = emailRecord['user_id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        _baseUserId = userId;
        return _baseUserId;
      }
    }
    if (emailRecord is String && emailRecord.isNotEmpty) {
      _baseUserId = emailRecord;
      return _baseUserId;
    }

    final users = await _safeGet('users.json');
    if (users is Map<String, dynamic>) {
      for (final entry in users.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic> &&
            value['email_address']?.toString().toLowerCase() ==
                SharedWorkspace.baseAccountEmail) {
          _baseUserId = entry.key;
          return _baseUserId;
        }
      }
    }
    return null;
  }

  Future<dynamic> _safeGet(String path) async {
    try {
      return await _database.get(path);
    } on Object {
      return null;
    }
  }

  Map<String, dynamic>? _readNestedMap(
    Map<String, dynamic> source,
    String slashPath,
  ) {
    dynamic cursor = source;
    for (final segment in slashPath.split('/')) {
      if (cursor is! Map<String, dynamic>) {
        return null;
      }
      cursor = cursor[segment];
    }
    return cursor is Map<String, dynamic> ? cursor : null;
  }

  String _normalizePath(String path) {
    return path
        .trim()
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '')
        .replaceAll(RegExp(r'\.json$'), '');
  }
}
