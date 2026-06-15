import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_store.dart';
import 'batch_store.dart';
import 'firebase_database_service.dart';

class EnvironmentalLog {
  final String id;
  final String batchId;
  final String deviceId;
  final double temperature;
  final double humidity;
  final double waterLevelPercent;
  final double waterDistanceCm;
  final double feederLevelPercent;
  final double feederDistanceCm;
  final DateTime recordedAt;

  const EnvironmentalLog({
    required this.id,
    required this.batchId,
    required this.deviceId,
    required this.temperature,
    required this.humidity,
    this.waterLevelPercent = 0,
    this.waterDistanceCm = 0,
    this.feederLevelPercent = 0,
    this.feederDistanceCm = 0,
    required this.recordedAt,
  });

  factory EnvironmentalLog.fromJson(String id, Map<String, dynamic> json) {
    return EnvironmentalLog(
      id: id,
      batchId: json['batch_id']?.toString() ?? 'default_batch',
      deviceId: json['device_id']?.toString() ?? 'esp32-dht22-hcsr04',
      temperature: _readDouble(json['temperature']),
      humidity: _readDouble(json['humidity']),
      waterLevelPercent: _readDouble(json['water_level_percent']),
      waterDistanceCm: _readDouble(json['water_distance_cm']),
      feederLevelPercent: _readDouble(json['feeder_level_percent']),
      feederDistanceCm: _readDouble(json['feeder_distance_cm']),
      recordedAt: _readDate(json['recorded_at']),
    );
  }

  Map<String, dynamic> toJson({String? userId}) {
    return {
      if (userId != null) 'user_id': userId,
      'batch_id': batchId,
      'device_id': deviceId,
      'temperature': temperature,
      'humidity': humidity,
      'water_level_percent': waterLevelPercent,
      'water_distance_cm': waterDistanceCm,
      'feeder_level_percent': feederLevelPercent,
      'feeder_distance_cm': feederDistanceCm,
      'aggregation_minutes': 15,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  static DateTime _readDate(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }
}

class EnvironmentalLogStore extends ChangeNotifier {
  EnvironmentalLogStore._();

  static final EnvironmentalLogStore instance = EnvironmentalLogStore._();

  final FirebaseDatabaseService _database = FirebaseDatabaseService.instance;
  final Set<String> _recordingBatchKeys = {};
  final Map<String, DateTime> _lastRecordAttempts = {};
  final Map<String, DateTime?> _lastRecordedAtByKey = {};
  final Map<String, Set<String>> _syncedLogIdsByUser = {};
  final Set<String> _loadedSyncedUsers = {};
  final Set<String> _syncingUsers = {};

  static const Duration recordingInterval = Duration(minutes: 15);
  static const Duration retryInterval = Duration(seconds: 10);

  Future<void> recordTelemetryIfDue({
    required BatchItem batch,
    required double temperature,
    required double humidity,
    required double waterLevelPercent,
    required double waterDistanceCm,
    required double feederLevelPercent,
    required double feederDistanceCm,
  }) async {
    final user = AuthStore.instance.currentUser;
    if (user == null || temperature <= 0 || humidity <= 0) {
      return;
    }

    final recordKey = '${user.id}_${batch.stableId}';
    if (!_recordingBatchKeys.add(recordKey)) {
      return;
    }

    try {
      final now = DateTime.now();
      final lastAttempt = _lastRecordAttempts[recordKey];
      if (lastAttempt != null && now.difference(lastAttempt) < retryInterval) {
        return;
      }
      _lastRecordAttempts[recordKey] = now;

      final lastRecordedAt = await _lastRecordedAt(recordKey);
      if (lastRecordedAt != null &&
          now.difference(lastRecordedAt) < recordingInterval) {
        return;
      }

      final log = EnvironmentalLog(
        id: 'app_${now.millisecondsSinceEpoch}',
        batchId: batch.stableId,
        deviceId: 'chicktemp-app',
        temperature: double.parse(temperature.toStringAsFixed(1)),
        humidity: double.parse(humidity.toStringAsFixed(0)),
        waterLevelPercent: double.parse(
          waterLevelPercent.clamp(0, 100).toStringAsFixed(0),
        ),
        waterDistanceCm: double.parse(waterDistanceCm.toStringAsFixed(1)),
        feederLevelPercent: double.parse(
          feederLevelPercent.clamp(0, 100).toStringAsFixed(0),
        ),
        feederDistanceCm: double.parse(feederDistanceCm.toStringAsFixed(1)),
        recordedAt: now,
      );
      await _appendLocalLog(user.id, log);
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = _lastRecordedTimestampKey(recordKey);
      await prefs.setString(timestampKey, now.toIso8601String());
      _lastRecordedAtByKey[recordKey] = now;
      notifyListeners();

      try {
        await _database.put(
          'environmental_logs/${log.id}.json',
          log.toJson(userId: user.id),
        );
        await _markLogSynced(user.id, log.id);
      } on Object {
        // Cached records are retried when Analytics loads again.
      }
    } on Object {
      // Monitoring continues if device storage is temporarily unavailable.
    } finally {
      _recordingBatchKeys.remove(recordKey);
    }
  }

  Future<List<EnvironmentalLog>> fetchRecentLogs({int limit = 48}) async {
    final userId = AuthStore.instance.currentUser?.id;
    final localLogs = userId == null
        ? <EnvironmentalLog>[]
        : await _loadLocalLogs(userId);
    if (userId != null && localLogs.isNotEmpty) {
      unawaited(_syncLocalLogs(userId, localLogs));
    }

    final logsById = <String, EnvironmentalLog>{
      for (final log in localLogs) log.id: log,
    };
    try {
      final response = await _database.get('environmental_logs.json');
      if (response is Map<String, dynamic>) {
        for (final entry in response.entries) {
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            logsById[entry.key] = EnvironmentalLog.fromJson(entry.key, value);
          }
        }
      }
    } on Object {
      // Local history remains available while Firebase is unreachable.
    }

    final logs = logsById.values.toList();
    logs.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    if (userId != null) {
      final cachedLogs = logs.take(240).toList().reversed.toList();
      try {
        await _saveLocalLogs(userId, cachedLogs);
      } on Object {
        // Fresh Firebase history remains usable if local caching fails.
      }
    }
    return logs.take(limit).toList().reversed.toList();
  }

  Future<EnvironmentalLog?> fetchLatestLogForBatch({
    required BatchItem batch,
    int searchLimit = 240,
  }) async {
    final logs = await fetchRecentLogs(limit: searchLimit);
    final batchKeys = <String>{
      batch.stableId,
      batch.name,
      _safeKey(batch.name),
    };

    for (final log in logs.reversed) {
      if (batchKeys.contains(log.batchId) ||
          batchKeys.contains(_safeKey(log.batchId))) {
        return log;
      }
    }

    if (BatchStore.instance.batches.length == 1 && logs.isNotEmpty) {
      return logs.last;
    }
    return null;
  }

  Future<void> deleteLogsForBatch({
    required BatchItem batch,
  }) async {
    final userId = AuthStore.instance.currentUser?.id;
    if (userId != null) {
      final localLogs = await _loadLocalLogs(userId);
      final retainedLogs = localLogs
          .where(
            (log) =>
                log.batchId != batch.stableId &&
                _safeKey(log.batchId) != _safeKey(batch.name),
          )
          .toList();
      await _saveLocalLogs(userId, retainedLogs);
    }

    final response = await _database.get('environmental_logs.json');
    if (response is! Map<String, dynamic>) {
      return;
    }

    final validBatchIds = <String>{
      batch.stableId,
      _safeKey(batch.name),
    };

    for (final entry in response.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) {
        continue;
      }

      final log = EnvironmentalLog.fromJson(entry.key, value);
      if (!validBatchIds.contains(log.batchId)) {
        continue;
      }

      await _database.delete('environmental_logs/${entry.key}.json');
    }
  }

  String _safeKey(String value) {
    final key = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return key.isEmpty ? 'default_batch' : key;
  }

  String _lastRecordedTimestampKey(String recordKey) {
    final safeKey = _safeKey(recordKey);
    return 'last_environmental_log_$safeKey';
  }

  Future<void> _appendLocalLog(String userId, EnvironmentalLog log) async {
    final logs = await _loadLocalLogs(userId);
    logs.add(log);
    logs.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final retainedLogs = logs.length <= 240
        ? logs
        : logs.sublist(logs.length - 240);
    await _saveLocalLogs(userId, retainedLogs);
  }

  Future<List<EnvironmentalLog>> _loadLocalLogs(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localLogsKey(userId));
    if (raw == null || raw.isEmpty) {
      return <EnvironmentalLog>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return <EnvironmentalLog>[];
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(
            (entry) => EnvironmentalLog.fromJson(
              entry['id']?.toString() ?? '',
              entry,
            ),
          )
          .where((log) => log.id.isNotEmpty)
          .toList();
    } on Object {
      return <EnvironmentalLog>[];
    }
  }

  Future<void> _saveLocalLogs(
    String userId,
    List<EnvironmentalLog> logs,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedLogs = logs
        .map((log) => {'id': log.id, ...log.toJson(userId: userId)})
        .toList();
    await prefs.setString(_localLogsKey(userId), jsonEncode(encodedLogs));
  }

  Future<void> _syncLocalLogs(
    String userId,
    List<EnvironmentalLog> logs,
  ) async {
    if (!_syncingUsers.add(userId)) {
      return;
    }

    try {
      final syncedIds = await _syncedLogIds(userId);
      var changed = false;
      for (final log in logs.where(
        (item) => item.id.startsWith('app_') && !syncedIds.contains(item.id),
      )) {
        try {
          await _database.put(
            'environmental_logs/${log.id}.json',
            log.toJson(userId: userId),
          );
          syncedIds.add(log.id);
          changed = true;
        } on Object {
          break;
        }
      }
      if (changed) {
        await _saveSyncedLogIds(userId, syncedIds);
      }
    } finally {
      _syncingUsers.remove(userId);
    }
  }

  String _localLogsKey(String userId) {
    return 'cached_environmental_logs_${_safeKey(userId)}';
  }

  Future<DateTime?> _lastRecordedAt(String recordKey) async {
    if (_lastRecordedAtByKey.containsKey(recordKey)) {
      return _lastRecordedAtByKey[recordKey];
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastRecordedTimestampKey(recordKey));
    final value = raw == null ? null : DateTime.tryParse(raw);
    _lastRecordedAtByKey[recordKey] = value;
    return value;
  }

  Future<Set<String>> _syncedLogIds(String userId) async {
    final existing = _syncedLogIdsByUser[userId];
    if (existing != null && _loadedSyncedUsers.contains(userId)) {
      return existing;
    }

    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_syncedLogsKey(userId))?.toSet() ?? <String>{};
    _syncedLogIdsByUser[userId] = ids;
    _loadedSyncedUsers.add(userId);
    return ids;
  }

  Future<void> _markLogSynced(String userId, String logId) async {
    final syncedIds = await _syncedLogIds(userId);
    if (syncedIds.add(logId)) {
      await _saveSyncedLogIds(userId, syncedIds);
    }
  }

  Future<void> _saveSyncedLogIds(
    String userId,
    Set<String> syncedIds,
  ) async {
    final retainedIds = syncedIds.length <= 300
        ? syncedIds.toList()
        : syncedIds.skip(syncedIds.length - 300).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_syncedLogsKey(userId), retainedIds);
  }

  String _syncedLogsKey(String userId) {
    return 'synced_environmental_logs_${_safeKey(userId)}';
  }
}
