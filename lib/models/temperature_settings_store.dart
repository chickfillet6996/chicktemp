import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_store.dart';
import 'batch_store.dart';

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

  Future<void> loadFor(String batchName) async {
    final key = _storageKey(batchName);
    if (key == null || _loadedKeys.contains(key) || !_loadingKeys.add(key)) {
      return;
    }

    try {
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
    final userId = AuthStore.instance.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return null;
    }
    final batch = BatchStore.instance.findByName(batchName);
    final batchId = batch?.stableId ?? batchName;
    return 'temperature_settings_${_safeKey(userId)}_${_safeKey(batchId)}';
  }

  String _safeKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
