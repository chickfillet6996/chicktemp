import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'batch_store.dart';
import 'environmental_log_store.dart';
import 'sensor_config.dart';
import 'shared_workspace.dart';

class TelemetryPoint {
  final double temperature;
  final double humidity;
  final double waterLevelPercent;
  final double waterDistanceCm;
  final double feederLevelPercent;
  final double feederDistanceCm;
  final DateTime recordedAt;

  const TelemetryPoint({
    required this.temperature,
    required this.humidity,
    this.waterLevelPercent = 0,
    this.waterDistanceCm = 0,
    this.feederLevelPercent = 0,
    this.feederDistanceCm = 0,
    required this.recordedAt,
  });
}

class BatchTelemetry {
  final double temperature;
  final double humidity;
  final double waterLevelPercent;
  final double waterDistanceCm;
  final double feederLevelPercent;
  final double feederDistanceCm;
  final bool waterPumpEnabled;
  final bool lightBulbEnabled;
  final bool lightBulbOverrideActive;
  final bool ventilationFanEnabled;
  final bool ventilationFanOverrideActive;
  final bool feederServoEnabled;
  final int deaths;
  final List<double> temperatureHistory;
  final List<double> humidityHistory;
  final List<TelemetryPoint> recentReadings;
  final DateTime updatedAt;
  final bool isDeviceLive;
  final bool isLive;
  final bool isWaterLevelLive;
  final bool isFeederLevelLive;

  const BatchTelemetry({
    required this.temperature,
    required this.humidity,
    required this.waterLevelPercent,
    required this.waterDistanceCm,
    required this.feederLevelPercent,
    required this.feederDistanceCm,
    this.waterPumpEnabled = false,
    this.lightBulbEnabled = false,
    this.lightBulbOverrideActive = false,
    this.ventilationFanEnabled = false,
    this.ventilationFanOverrideActive = false,
    this.feederServoEnabled = false,
    required this.deaths,
    required this.temperatureHistory,
    required this.humidityHistory,
    required this.recentReadings,
    required this.updatedAt,
    this.isDeviceLive = false,
    this.isLive = false,
    this.isWaterLevelLive = false,
    this.isFeederLevelLive = false,
  });

  int aliveBirdsFor(int totalBirds) => max(0, totalBirds - deaths);
}

class MonitoringStore extends ChangeNotifier with WidgetsBindingObserver {
  MonitoringStore._();

  static final MonitoringStore instance = MonitoringStore._();

  final Map<String, BatchTelemetry> _telemetryByBatch = {};
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3);
  Timer? _timer;
  bool _polling = false;
  bool _started = false;
  String? _sensorBatchName;
  String? _lastSensorSourceVersion;
  DateTime? _lastSensorSourceChangeAt;
  final Set<String> _cacheRestoreRequests = {};
  final Map<String, DateTime> _lastTelemetryPersistAt = {};

  static const String _sensorUrlOverride = String.fromEnvironment(
    'CHICKTEMP_SENSOR_URL',
    defaultValue: '',
  );
  static const String _telemetryCachePrefix = 'last_sensor_telemetry';

  void start() {
    if (!_started) {
      WidgetsBinding.instance.addObserver(this);
      _started = true;
    }
    _seedMissingBatches();
    _resumePolling();
  }

  void _resumePolling() {
    if (_timer != null) {
      return;
    }
    _tick();
    _timer ??= Timer.periodic(const Duration(seconds: 4), (_) => _tick());
  }

  void _pausePolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumePolling();
    } else {
      _pausePolling();
    }
  }

  void _seedMissingBatches() {
    for (final batch in BatchStore.instance.batches) {
      _telemetryByBatch.putIfAbsent(batch.name, _seedTelemetry);
    }
    notifyListeners();
  }

  BatchItem? _sensorBatch() {
    final batches = BatchStore.instance.batches;
    if (batches.isEmpty) {
      _sensorBatchName = null;
      return null;
    }

    final savedName = _sensorBatchName;
    if (savedName != null) {
      for (final batch in batches) {
        if (batch.name == savedName && _isActiveBatch(batch)) {
          return batch;
        }
      }
    }

    final preferredBatch = _preferredSensorBatch(batches);
    _sensorBatchName = preferredBatch.name;
    return preferredBatch;
  }

  BatchItem _preferredSensorBatch(List<BatchItem> batches) {
    for (final batch in batches) {
      if (_isActiveBatch(batch)) {
        return batch;
      }
    }

    for (final batch in batches) {
      final key = '${batch.name} ${batch.stableId}'.toLowerCase();
      if (key.contains('batch 1') ||
          key.contains('batch_1') ||
          key.contains('broiler_batch_1')) {
        return batch;
      }
    }

    return batches.last;
  }

  bool _isActiveBatch(BatchItem batch) {
    return batch.status.toUpperCase() == 'ACTIVE';
  }

  BatchTelemetry snapshotFor(String batchName) {
    final telemetry = _telemetryByBatch.putIfAbsent(batchName, _seedTelemetry);
    _restoreCachedTelemetry(batchName);
    return telemetry;
  }

  int totalBirdsFor(String batchName) {
    final batch = BatchStore.instance.batches
        .where((item) => item.name == batchName)
        .toList();
    if (batch.isEmpty) {
      return 500;
    }

    final birdsLabel = batch.first.birdsLabel;
    final digits = RegExp(r'\d+').firstMatch(birdsLabel)?.group(0);
    return int.tryParse(digits ?? '') ?? 500;
  }

  void removeBatch(String batchName) {
    final removed = _telemetryByBatch.remove(batchName);
    _removeCachedTelemetry(batchName);
    if (_sensorBatchName == batchName) {
      _sensorBatchName = null;
    }
    if (removed != null) {
      notifyListeners();
    }
  }

  void resetForAccountSwitch() {
    _telemetryByBatch.clear();
    _sensorBatchName = null;
    _cacheRestoreRequests.clear();
    _lastTelemetryPersistAt.clear();
    notifyListeners();
  }

  Future<void> _tick() async {
    if (_polling) {
      return;
    }
    final reading = await _pollSensor();
    if (reading == null) {
      _markSensorOffline();
      return;
    }

    _applySensorReading(reading);
  }

  BatchTelemetry _seedTelemetry() {
    return BatchTelemetry(
      temperature: 0,
      humidity: 0,
      waterLevelPercent: 0,
      waterDistanceCm: 0,
      feederLevelPercent: 0,
      feederDistanceCm: 0,
      waterPumpEnabled: false,
      lightBulbEnabled: false,
      lightBulbOverrideActive: false,
      ventilationFanEnabled: false,
      ventilationFanOverrideActive: false,
      feederServoEnabled: false,
      deaths: 0,
      temperatureHistory: List<double>.filled(8, 0),
      humidityHistory: List<double>.filled(8, 0),
      recentReadings: const [],
      updatedAt: DateTime.now(),
    );
  }

  Future<_SensorReading?> _pollSensor() async {
    if (_polling) {
      return null;
    }

    _polling = true;
    try {
      final request = await _httpClient.getUrl(Uri.parse(_sensorUrl));
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        return null;
      }

      final temperature = _readDouble(json, [
        'temperature',
        'temp',
        'temperature_c',
      ]);
      final humidity = _readDouble(json, ['humidity', 'humidity_percent']);
      if (temperature == null || humidity == null) {
        return null;
      }

      final status = json['status'];
      final waterLevel = _readDouble(json, [
        'water_level_percent',
        'water_level',
      ]);
      final waterDistance = _readDouble(json, [
        'water_distance_cm',
        'distance_cm',
      ]);
      final feederLevel = _readDouble(json, [
        'feeder_level_percent',
        'feeder_level',
      ]);
      final feederDistance = _readDouble(json, ['feeder_distance_cm']);
      final waterPumpEnabled = _readBool(json, ['water_pump_enabled']);
      final lightBulbEnabled = _readBool(json, ['light_bulb_enabled']);
      final lightBulbOverrideActive = _readBool(json, [
        'light_bulb_override_active',
      ]);
      final ventilationFanEnabled = _readBool(json, [
        'ventilation_fan_enabled',
      ]);
      final ventilationFanOverrideActive = _readBool(json, [
        'ventilation_fan_override_active',
      ]);
      final feederServoEnabled = _readBool(json, ['feeder_servo_enabled']);
      final rawSourceUpdatedAt = json['updated_at'] ?? json['updatedAt'];
      final sourceUpdatedAt = _readDateTime(rawSourceUpdatedAt);
      final isFirebaseSource = _sensorUrl == SensorConfig.firebaseSensorUrl;
      final isFresh = _isSensorReadingFresh(
        rawSourceUpdatedAt: rawSourceUpdatedAt,
        sourceUpdatedAt: sourceUpdatedAt,
        isFirebaseSource: isFirebaseSource,
      );
      final hasWaterReading = waterLevel != null && waterDistance != null;
      final hasFeederReading = feederLevel != null && feederDistance != null;
      return _SensorReading(
        temperature: double.parse(temperature.toStringAsFixed(1)),
        humidity: double.parse(humidity.toStringAsFixed(0)),
        waterLevelPercent: double.parse(
          (waterLevel ?? 0).clamp(0, 100).toStringAsFixed(0),
        ),
        waterDistanceCm: double.parse(
          (waterDistance ?? 0).toStringAsFixed(1),
        ),
        feederLevelPercent: double.parse(
          (feederLevel ?? 0).clamp(0, 100).toStringAsFixed(0),
        ),
        feederDistanceCm: double.parse(
          (feederDistance ?? 0).toStringAsFixed(1),
        ),
        waterPumpEnabled: waterPumpEnabled ?? false,
        lightBulbEnabled: lightBulbEnabled ?? false,
        lightBulbOverrideActive: lightBulbOverrideActive ?? false,
        ventilationFanEnabled: ventilationFanEnabled ?? false,
        ventilationFanOverrideActive: ventilationFanOverrideActive ?? false,
        feederServoEnabled: feederServoEnabled ?? false,
        isDeviceLive: isFresh,
        isLive: status == 'ok' && isFresh,
        isWaterLevelLive:
            hasWaterReading &&
            isFresh &&
            (json['water_status'] == null || json['water_status'] == 'ok'),
        isFeederLevelLive:
            hasFeederReading &&
            isFresh &&
            (json['feeder_status'] == null || json['feeder_status'] == 'ok'),
      );
    } on Object {
      return null;
    } finally {
      _polling = false;
    }
  }

  String get _sensorUrl {
    if (_sensorUrlOverride.isNotEmpty) {
      return _sensorUrlOverride;
    }
    if (SensorConfig.firebaseSensorUrl.isNotEmpty) {
      return SensorConfig.firebaseSensorUrl;
    }

    return SensorConfig.directEsp32SensorUrl;
  }

  double? _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  bool? _readBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) {
        return value;
      }
      if (value is String) {
        if (value.toLowerCase() == 'true') {
          return true;
        }
        if (value.toLowerCase() == 'false') {
          return false;
        }
      }
    }

    return null;
  }

  DateTime? _readDateTime(dynamic value) {
    if (value is num) {
      final milliseconds = value.toInt();
      if (milliseconds < 1000000000000) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  bool _isSensorReadingFresh({
    required dynamic rawSourceUpdatedAt,
    required DateTime? sourceUpdatedAt,
    required bool isFirebaseSource,
  }) {
    if (!isFirebaseSource) {
      return true;
    }

    final now = DateTime.now();
    if (sourceUpdatedAt != null) {
      return now.difference(sourceUpdatedAt).abs() <=
          const Duration(seconds: 20);
    }

    // Older ESP32 firmware sends millis() instead of a calendar timestamp.
    // Treat it as live only while that uptime value continues to change.
    final sourceVersion = rawSourceUpdatedAt?.toString();
    if (sourceVersion == null || sourceVersion.isEmpty) {
      return false;
    }
    if (sourceVersion != _lastSensorSourceVersion) {
      _lastSensorSourceVersion = sourceVersion;
      _lastSensorSourceChangeAt = now;
    }

    final changedAt = _lastSensorSourceChangeAt;
    return changedAt != null &&
        now.difference(changedAt) <= const Duration(seconds: 20);
  }

  void _markSensorOffline() {
    var changed = false;
    for (final batch in BatchStore.instance.batches) {
      final previous = _telemetryByBatch[batch.name] ?? _seedTelemetry();
      if (previous.isLive ||
          previous.isDeviceLive ||
          previous.isWaterLevelLive ||
          previous.isFeederLevelLive) {
        _telemetryByBatch[batch.name] = BatchTelemetry(
          temperature: previous.temperature,
          humidity: previous.humidity,
          waterLevelPercent: previous.waterLevelPercent,
          waterDistanceCm: previous.waterDistanceCm,
          feederLevelPercent: previous.feederLevelPercent,
          feederDistanceCm: previous.feederDistanceCm,
          waterPumpEnabled: previous.waterPumpEnabled,
          lightBulbEnabled: previous.lightBulbEnabled,
          lightBulbOverrideActive: previous.lightBulbOverrideActive,
          ventilationFanEnabled: previous.ventilationFanEnabled,
          ventilationFanOverrideActive: previous.ventilationFanOverrideActive,
          feederServoEnabled: previous.feederServoEnabled,
          deaths: previous.deaths,
          temperatureHistory: previous.temperatureHistory,
          humidityHistory: previous.humidityHistory,
          recentReadings: previous.recentReadings,
          updatedAt: previous.updatedAt,
          isDeviceLive: false,
          isLive: false,
          isWaterLevelLive: false,
          isFeederLevelLive: false,
        );
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _applySensorReading(_SensorReading reading) {
    final sensorBatch = _sensorBatch();
    if (sensorBatch == null) {
      return;
    }

    final previous =
        _telemetryByBatch[sensorBatch.name] ?? _seedTelemetry();
    final nextTelemetry = _withSensorReading(previous, reading);
    _telemetryByBatch[sensorBatch.name] = nextTelemetry;
    if (reading.isLive ||
        reading.isDeviceLive ||
        reading.isWaterLevelLive ||
        reading.isFeederLevelLive) {
      unawaited(_persistTelemetry(sensorBatch.name, nextTelemetry));
    }
    if (nextTelemetry.temperature > 0 && nextTelemetry.humidity > 0) {
      unawaited(
        EnvironmentalLogStore.instance.recordTelemetryIfDue(
          batch: sensorBatch,
          temperature: nextTelemetry.temperature,
          humidity: nextTelemetry.humidity,
          waterLevelPercent: nextTelemetry.waterLevelPercent,
          waterDistanceCm: nextTelemetry.waterDistanceCm,
          feederLevelPercent: nextTelemetry.feederLevelPercent,
          feederDistanceCm: nextTelemetry.feederDistanceCm,
        ),
      );
    }
    notifyListeners();
  }

  BatchTelemetry _withSensorReading(
    BatchTelemetry current,
    _SensorReading reading,
  ) {
    if (!reading.isLive) {
      return BatchTelemetry(
        temperature: current.temperature,
        humidity: current.humidity,
        waterLevelPercent: reading.isWaterLevelLive
            ? reading.waterLevelPercent
            : current.waterLevelPercent,
        waterDistanceCm: reading.isWaterLevelLive
            ? reading.waterDistanceCm
            : current.waterDistanceCm,
        feederLevelPercent: reading.isFeederLevelLive
            ? reading.feederLevelPercent
            : current.feederLevelPercent,
        feederDistanceCm: reading.isFeederLevelLive
            ? reading.feederDistanceCm
            : current.feederDistanceCm,
        waterPumpEnabled: reading.waterPumpEnabled,
        lightBulbEnabled: reading.lightBulbEnabled,
        lightBulbOverrideActive: reading.lightBulbOverrideActive,
        ventilationFanEnabled: reading.ventilationFanEnabled,
        ventilationFanOverrideActive: reading.ventilationFanOverrideActive,
        feederServoEnabled: reading.feederServoEnabled,
        deaths: current.deaths,
        temperatureHistory: current.temperatureHistory,
        humidityHistory: current.humidityHistory,
        recentReadings: current.recentReadings,
        updatedAt:
            reading.isDeviceLive ||
                reading.isWaterLevelLive ||
                reading.isFeederLevelLive
            ? DateTime.now()
            : current.updatedAt,
        isDeviceLive: reading.isDeviceLive,
        isLive: false,
        isWaterLevelLive: reading.isWaterLevelLive,
        isFeederLevelLive: reading.isFeederLevelLive,
      );
    }

    final nextTemperatureHistory = [
      ...current.temperatureHistory.skip(1),
      reading.temperature,
    ].take(8).toList();

    final nextHumidityHistory = [
      ...current.humidityHistory.skip(1),
      reading.humidity,
    ].take(8).toList();

    final nextWaterLevel = reading.isWaterLevelLive
        ? reading.waterLevelPercent
        : current.waterLevelPercent;
    final nextWaterDistance = reading.isWaterLevelLive
        ? reading.waterDistanceCm
        : current.waterDistanceCm;
    final nextFeederLevel = reading.isFeederLevelLive
        ? reading.feederLevelPercent
        : current.feederLevelPercent;
    final nextFeederDistance = reading.isFeederLevelLive
        ? reading.feederDistanceCm
        : current.feederDistanceCm;

    final nextReadings = [
      ...current.recentReadings,
      TelemetryPoint(
        temperature: reading.temperature,
        humidity: reading.humidity,
        waterLevelPercent: nextWaterLevel,
        waterDistanceCm: nextWaterDistance,
        feederLevelPercent: nextFeederLevel,
        feederDistanceCm: nextFeederDistance,
        recordedAt: DateTime.now(),
      ),
    ].takeLast(24);

    return BatchTelemetry(
      temperature: reading.temperature,
      humidity: reading.humidity,
      waterLevelPercent: nextWaterLevel,
      waterDistanceCm: nextWaterDistance,
      feederLevelPercent: nextFeederLevel,
      feederDistanceCm: nextFeederDistance,
      waterPumpEnabled: reading.waterPumpEnabled,
      lightBulbEnabled: reading.lightBulbEnabled,
      lightBulbOverrideActive: reading.lightBulbOverrideActive,
      ventilationFanEnabled: reading.ventilationFanEnabled,
      ventilationFanOverrideActive: reading.ventilationFanOverrideActive,
      feederServoEnabled: reading.feederServoEnabled,
      deaths: current.deaths,
      temperatureHistory: nextTemperatureHistory,
      humidityHistory: nextHumidityHistory,
      recentReadings: nextReadings,
      updatedAt: DateTime.now(),
      isDeviceLive: reading.isDeviceLive,
      isLive: reading.isLive,
      isWaterLevelLive: reading.isWaterLevelLive,
      isFeederLevelLive: reading.isFeederLevelLive,
    );
  }

  Future<void> _restoreCachedTelemetry(String batchName) async {
    final cacheKey = _cacheKey(batchName);
    if (cacheKey == null || !_cacheRestoreRequests.add(cacheKey)) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) {
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final current = _telemetryByBatch[batchName] ?? _seedTelemetry();
      if (current.isLive ||
          current.isDeviceLive ||
          current.isWaterLevelLive ||
          current.isFeederLevelLive) {
        return;
      }

      final temperature = _cachedDouble(decoded['temperature']);
      final humidity = _cachedDouble(decoded['humidity']);
      final waterLevel = _cachedDouble(decoded['water_level_percent']);
      final waterDistance = _cachedDouble(decoded['water_distance_cm']);
      final feederLevel = _cachedDouble(decoded['feeder_level_percent']);
      final feederDistance = _cachedDouble(decoded['feeder_distance_cm']);
      final waterPumpEnabled = _cachedBool(decoded['water_pump_enabled']);
      final lightBulbEnabled = _cachedBool(decoded['light_bulb_enabled']);
      final lightBulbOverrideActive = _cachedBool(
        decoded['light_bulb_override_active'],
      );
      final ventilationFanEnabled = _cachedBool(
        decoded['ventilation_fan_enabled'],
      );
      final ventilationFanOverrideActive = _cachedBool(
        decoded['ventilation_fan_override_active'],
      );
      final feederServoEnabled = _cachedBool(decoded['feeder_servo_enabled']);
      final updatedAt =
          DateTime.tryParse(decoded['updated_at']?.toString() ?? '') ??
          current.updatedAt;

      if (temperature == null &&
          humidity == null &&
          waterLevel == null &&
          waterDistance == null &&
          feederLevel == null &&
          feederDistance == null) {
        return;
      }

      _telemetryByBatch[batchName] = BatchTelemetry(
        temperature: temperature ?? current.temperature,
        humidity: humidity ?? current.humidity,
        waterLevelPercent: waterLevel ?? current.waterLevelPercent,
        waterDistanceCm: waterDistance ?? current.waterDistanceCm,
        feederLevelPercent: feederLevel ?? current.feederLevelPercent,
        feederDistanceCm: feederDistance ?? current.feederDistanceCm,
        waterPumpEnabled: waterPumpEnabled ?? current.waterPumpEnabled,
        lightBulbEnabled: lightBulbEnabled ?? current.lightBulbEnabled,
        lightBulbOverrideActive:
            lightBulbOverrideActive ?? current.lightBulbOverrideActive,
        ventilationFanEnabled:
            ventilationFanEnabled ?? current.ventilationFanEnabled,
        ventilationFanOverrideActive:
            ventilationFanOverrideActive ?? current.ventilationFanOverrideActive,
        feederServoEnabled: feederServoEnabled ?? current.feederServoEnabled,
        deaths: current.deaths,
        temperatureHistory: current.temperatureHistory,
        humidityHistory: current.humidityHistory,
        recentReadings: current.recentReadings,
        updatedAt: updatedAt,
        isDeviceLive: false,
        isLive: false,
        isWaterLevelLive: false,
        isFeederLevelLive: false,
      );
      notifyListeners();
    } on Object {
      // A damaged cache should never prevent live monitoring.
    }
  }

  Future<void> _persistTelemetry(
    String batchName,
    BatchTelemetry telemetry,
  ) async {
    final cacheKey = _cacheKey(batchName);
    if (cacheKey == null) {
      return;
    }
    final now = DateTime.now();
    final lastPersistedAt = _lastTelemetryPersistAt[cacheKey];
    if (lastPersistedAt != null &&
        now.difference(lastPersistedAt) < const Duration(seconds: 30)) {
      return;
    }
    _lastTelemetryPersistAt[cacheKey] = now;

    final payload = jsonEncode({
      'temperature': telemetry.temperature,
      'humidity': telemetry.humidity,
      'water_level_percent': telemetry.waterLevelPercent,
      'water_distance_cm': telemetry.waterDistanceCm,
      'feeder_level_percent': telemetry.feederLevelPercent,
      'feeder_distance_cm': telemetry.feederDistanceCm,
      'water_pump_enabled': telemetry.waterPumpEnabled,
      'light_bulb_enabled': telemetry.lightBulbEnabled,
      'light_bulb_override_active': telemetry.lightBulbOverrideActive,
      'ventilation_fan_enabled': telemetry.ventilationFanEnabled,
      'ventilation_fan_override_active':
          telemetry.ventilationFanOverrideActive,
      'feeder_servo_enabled': telemetry.feederServoEnabled,
      'updated_at': telemetry.updatedAt.toIso8601String(),
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, payload);
    } on Object {
      if (_lastTelemetryPersistAt[cacheKey] == now) {
        _lastTelemetryPersistAt.remove(cacheKey);
      }
      // Live sensor updates continue even if local storage is unavailable.
    }
  }

  Future<void> _removeCachedTelemetry(String batchName) async {
    final cacheKey = _cacheKey(batchName);
    if (cacheKey == null) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cacheKey);
    } on Object {
      // Removing a batch should still succeed if cache cleanup fails.
    }
  }

  String? _cacheKey(String batchName) {
    final batch = BatchStore.instance.findByName(batchName);
    final batchId = batch?.stableId ?? batchName;
    return SharedWorkspace.localKey(
      '${_telemetryCachePrefix}_${_safeCacheKey(batchId)}',
    );
  }

  String _safeCacheKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  double? _cachedDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  bool? _cachedBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      if (value.toLowerCase() == 'true') {
        return true;
      }
      if (value.toLowerCase() == 'false') {
        return false;
      }
    }
    return null;
  }
}

class _SensorReading {
  final double temperature;
  final double humidity;
  final double waterLevelPercent;
  final double waterDistanceCm;
  final double feederLevelPercent;
  final double feederDistanceCm;
  final bool waterPumpEnabled;
  final bool lightBulbEnabled;
  final bool lightBulbOverrideActive;
  final bool ventilationFanEnabled;
  final bool ventilationFanOverrideActive;
  final bool feederServoEnabled;
  final bool isDeviceLive;
  final bool isLive;
  final bool isWaterLevelLive;
  final bool isFeederLevelLive;

  const _SensorReading({
    required this.temperature,
    required this.humidity,
    required this.waterLevelPercent,
    required this.waterDistanceCm,
    required this.feederLevelPercent,
    required this.feederDistanceCm,
    required this.waterPumpEnabled,
    required this.lightBulbEnabled,
    required this.lightBulbOverrideActive,
    required this.ventilationFanEnabled,
    required this.ventilationFanOverrideActive,
    required this.feederServoEnabled,
    required this.isDeviceLive,
    required this.isLive,
    required this.isWaterLevelLive,
    required this.isFeederLevelLive,
  });
}

extension on List<TelemetryPoint> {
  List<TelemetryPoint> takeLast(int count) {
    if (length <= count) {
      return List<TelemetryPoint>.from(this);
    }

    return sublist(length - count);
  }
}
