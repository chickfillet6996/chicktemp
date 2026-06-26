import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'batch_store.dart';
import 'device_config_store.dart';
import 'shared_workspace.dart';

class BatchTemperatureSettings {
  final double minTemperature;
  final double maxTemperature;

  const BatchTemperatureSettings({
    required this.minTemperature,
    required this.maxTemperature,
  });

  static const defaults = BatchTemperatureSettings(
    minTemperature: 28,
    maxTemperature: 35,
  );
}

enum TemperatureCondition {
  noSensor,
  low,
  normal,
  high,
}

class TemperatureSettingsStore extends ChangeNotifier {
  TemperatureSettingsStore._();

  static final TemperatureSettingsStore instance = TemperatureSettingsStore._();

  final Map<String, BatchTemperatureSettings> _settingsByBatch = {};
  final Set<String> _loadedKeys = {};
  final Set<String> _loadingKeys = {};

  BatchTemperatureSettings settingsFor(String batchName) {
    return _settingsByBatch[batchName] ?? BatchTemperatureSettings.defaults;
  }

  Future<void> loadFor(String batchName, {bool forceRefresh = false}) async {
    final key = _storageKey(batchName);
    if (key == null ||
        (!forceRefresh && _loadedKeys.contains(key)) ||
        !_loadingKeys.add(key)) {
      return;
    }

    try {
      final remoteSettings = await _loadRemote(batchName);
      if (remoteSettings != null) {
        _settingsByBatch[batchName] = remoteSettings;
        _loadedKeys.add(key);
        notifyListeners();
        unawaited(
          _persist(
            batchName,
            minTemperature: remoteSettings.minTemperature,
            maxTemperature: remoteSettings.maxTemperature,
          ),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final minTemperature = prefs.getDouble('${key}_min');
      final maxTemperature = prefs.getDouble('${key}_max');
      if (minTemperature != null &&
          maxTemperature != null &&
          minTemperature < maxTemperature) {
        _settingsByBatch[batchName] = BatchTemperatureSettings(
          minTemperature: minTemperature,
          maxTemperature: maxTemperature,
        );
        notifyListeners();
      }
      _loadedKeys.add(key);
    } finally {
      _loadingKeys.remove(key);
    }
  }

  Future<BatchTemperatureSettings?> _loadRemote(String batchName) async {
    try {
      final data = await DeviceConfigStore.instance
          .loadTemperatureAutomationControl(batchName: batchName);
      if (data == null) {
        return null;
      }

      final minTemperature = _toDouble(data['min_temperature']);
      final maxTemperature = _toDouble(data['max_temperature']);
      if (minTemperature == null ||
          maxTemperature == null ||
          minTemperature >= maxTemperature) {
        return null;
      }

      return BatchTemperatureSettings(
        minTemperature: minTemperature,
        maxTemperature: maxTemperature,
      );
    } on Object {
      return null;
    }
  }

  void resetForAccountSwitch() {
    _settingsByBatch.clear();
    _loadedKeys.clear();
    _loadingKeys.clear();
    notifyListeners();
  }

  void updateFor(
    String batchName, {
    required double minTemperature,
    required double maxTemperature,
  }) {
    _settingsByBatch[batchName] = BatchTemperatureSettings(
      minTemperature: minTemperature,
      maxTemperature: maxTemperature,
    );
    notifyListeners();
    unawaited(
      _persist(
        batchName,
        minTemperature: minTemperature,
        maxTemperature: maxTemperature,
      ),
    );
  }

  void removeBatch(String batchName) {
    final removed = _settingsByBatch.remove(batchName);
    unawaited(_removePersisted(batchName));
    if (removed != null) {
      notifyListeners();
    }
  }

  TemperatureCondition classify(
    String batchName,
    double temperature, {
    required bool isLive,
  }) {
    if (!isLive) {
      return TemperatureCondition.noSensor;
    }

    final settings = settingsFor(batchName);
    if (temperature < settings.minTemperature) {
      return TemperatureCondition.low;
    }
    if (temperature > settings.maxTemperature) {
      return TemperatureCondition.high;
    }

    return TemperatureCondition.normal;
  }

  Future<void> _persist(
    String batchName, {
    required double minTemperature,
    required double maxTemperature,
  }) async {
    final key = _storageKey(batchName);
    if (key == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${key}_min', minTemperature);
    await prefs.setDouble('${key}_max', maxTemperature);
    _loadedKeys.add(key);
  }

  Future<void> _removePersisted(String batchName) async {
    final key = _storageKey(batchName);
    if (key == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${key}_min');
    await prefs.remove('${key}_max');
    _loadedKeys.remove(key);
  }

  String? _storageKey(String batchName) {
    final batch = BatchStore.instance.findByName(batchName);
    final batchId = batch?.stableId ?? batchName;
    return SharedWorkspace.localKey('temperature_settings_${_safeKey(batchId)}');
  }

  String _safeKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
