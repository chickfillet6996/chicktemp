import 'package:flutter/foundation.dart';

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

  BatchTemperatureSettings settingsFor(String batchName) {
    return _settingsByBatch[batchName] ?? BatchTemperatureSettings.defaults;
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
  }

  void removeBatch(String batchName) {
    final removed = _settingsByBatch.remove(batchName);
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
}
