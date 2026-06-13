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
  final DateTime recordedAt;

  const EnvironmentalLog({
    required this.id,
    required this.batchId,
    required this.deviceId,
    required this.temperature,
    required this.humidity,
    this.waterLevelPercent = 0,
    this.waterDistanceCm = 0,
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
      recordedAt: _readDate(json['recorded_at']),
    );
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
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

class EnvironmentalLogStore {
  EnvironmentalLogStore._();

  static final EnvironmentalLogStore instance = EnvironmentalLogStore._();

  final FirebaseDatabaseService _database = FirebaseDatabaseService.instance;

  Future<List<EnvironmentalLog>> fetchRecentLogs({int limit = 48}) async {
    final response = await _database.get('environmental_logs.json');
    if (response is! Map<String, dynamic>) {
      return const [];
    }

    final logs = <EnvironmentalLog>[];
    for (final entry in response.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        logs.add(EnvironmentalLog.fromJson(entry.key, value));
      }
    }

    logs.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
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
}
