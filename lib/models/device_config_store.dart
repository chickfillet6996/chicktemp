import 'auth_store.dart';
import 'firebase_database_service.dart';
import 'shared_workspace.dart';
import 'shared_workspace_migration.dart';

class DeviceConfigStore {
  DeviceConfigStore._();

  static final DeviceConfigStore instance = DeviceConfigStore._();

  final FirebaseDatabaseService _database = FirebaseDatabaseService.instance;

  Future<Map<String, dynamic>?> loadVentilationConfig({
    required String batchName,
  }) async {
    return _loadConfig(section: 'ventilation_configs', batchName: batchName);
  }

  Future<void> saveVentilationConfig({
    required String batchName,
    required Map<String, dynamic> data,
  }) async {
    await _saveConfig(
      section: 'ventilation_configs',
      batchName: batchName,
      data: data,
    );
  }

  Future<void> saveVentilationFanControl({
    required String batchName,
    required bool enabled,
    int? manualOverrideDurationMs,
    bool? manualOverrideCancel,
    int? commandId,
  }) async {
    await _database.put(
      _controlPath('ventilation_fan'),
      {
        'enabled': enabled,
        if (manualOverrideDurationMs != null)
          'manual_override_duration_ms': manualOverrideDurationMs,
        if (manualOverrideCancel != null)
          'manual_override_cancel': manualOverrideCancel,
        if (commandId != null) 'command_id': commandId,
        'source': 'controls_panel',
        'updated_at': {'.sv': 'timestamp'},
      },
    );
  }

  Future<void> saveTemperatureAutomationControl({
    required String batchName,
    required double minTemperature,
    required double maxTemperature,
    bool enabled = true,
  }) async {
    await _database.put(
      _controlPath('temperature_automation'),
      {
        'enabled': enabled,
        'min_temperature': minTemperature,
        'max_temperature': maxTemperature,
        'source': 'temperature_settings',
        'updated_at': {'.sv': 'timestamp'},
      },
    );
  }

  Future<Map<String, dynamic>?> loadTemperatureAutomationControl({
    required String batchName,
  }) async {
    final response = await _database.get(
      _controlPath('temperature_automation'),
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return null;
  }

  Future<Map<String, dynamic>?> loadFeederConfig({
    required String batchName,
  }) async {
    return _loadConfig(section: 'feeder_configs', batchName: batchName);
  }

  Future<void> saveFeederConfig({
    required String batchName,
    required Map<String, dynamic> data,
  }) async {
    await _saveConfig(
      section: 'feeder_configs',
      batchName: batchName,
      data: data,
    );
  }

  Future<void> saveFeederServoControl({
    required String batchName,
    required bool enabled,
    bool? schedulesEnabled,
    int? durationMs,
    double? grams,
    int? commandId,
    List<String>? scheduleCodes,
  }) async {
    await _database.put(
      _controlPath('feeder_servo'),
      {
        'enabled': enabled,
        if (schedulesEnabled != null) 'schedules_enabled': schedulesEnabled,
        if (durationMs != null) 'duration_ms': durationMs,
        if (grams != null) 'grams': grams,
        if (commandId != null) 'command_id': commandId,
        if (scheduleCodes != null) 'schedule_codes': scheduleCodes,
        'source': 'controls_panel',
        'updated_at': {'.sv': 'timestamp'},
      },
    );
  }

  Future<Map<String, dynamic>?> loadWaterConfig({
    required String batchName,
  }) async {
    return _loadConfig(section: 'water_configs', batchName: batchName);
  }

  Future<void> saveWaterConfig({
    required String batchName,
    required Map<String, dynamic> data,
  }) async {
    await _saveConfig(
      section: 'water_configs',
      batchName: batchName,
      data: data,
    );
  }

  Future<void> saveWaterPumpControl({
    required String batchName,
    required bool enabled,
    bool? schedulesEnabled,
    int? durationMs,
    double? liters,
    int? commandId,
    List<String>? scheduleCodes,
  }) async {
    await _database.put(
      _controlPath('water_pump'),
      {
        'enabled': enabled,
        if (schedulesEnabled != null) 'schedules_enabled': schedulesEnabled,
        if (durationMs != null) 'duration_ms': durationMs,
        if (liters != null) 'liters': liters,
        if (commandId != null) 'command_id': commandId,
        if (scheduleCodes != null) 'schedule_codes': scheduleCodes,
        'source': 'controls_panel',
        'updated_at': {'.sv': 'timestamp'},
      },
    );
  }

  Future<Map<String, dynamic>?> loadLightingConfig({
    required String batchName,
  }) async {
    return _loadConfig(section: 'lighting_configs', batchName: batchName);
  }

  Future<void> saveLightingConfig({
    required String batchName,
    required Map<String, dynamic> data,
  }) async {
    await _saveConfig(
      section: 'lighting_configs',
      batchName: batchName,
      data: data,
    );
  }

  Future<void> saveLightBulbControl({
    required String batchName,
    required bool enabled,
    int? manualOverrideDurationMs,
    bool? manualOverrideCancel,
    int? commandId,
  }) async {
    await _database.put(
      _controlPath('light_bulb'),
      {
        'enabled': enabled,
        if (manualOverrideDurationMs != null)
          'manual_override_duration_ms': manualOverrideDurationMs,
        if (manualOverrideCancel != null)
          'manual_override_cancel': manualOverrideCancel,
        if (commandId != null) 'command_id': commandId,
        'source': 'controls_panel',
        'updated_at': {'.sv': 'timestamp'},
      },
    );
  }

  Future<void> deleteAllForBatch({
    required String batchName,
  }) async {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      throw const FirebaseDatabaseException('No signed-in user found.');
    }

    final batchKey = _batchKey(batchName);
    const sections = [
      'ventilation_configs',
      'feeder_configs',
      'water_configs',
      'lighting_configs',
    ];

    for (final section in sections) {
      await _database.delete(
        SharedWorkspace.path('$section/$batchKey.json'),
      );
    }
  }

  Future<Map<String, dynamic>?> _loadConfig({
    required String section,
    required String batchName,
  }) async {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      return null;
    }

    final configPath = '$section/${_batchKey(batchName)}.json';
    final response = await _database.get(
      SharedWorkspace.path(configPath),
    );
    if (response is Map<String, dynamic>) {
      return response;
    }

    final legacyResponse = await _loadLegacyConfig(user.id, configPath);
    if (legacyResponse is Map<String, dynamic>) {
      await _database.put(
        SharedWorkspace.path(configPath),
        Map<String, dynamic>.from(legacyResponse),
      );
      return legacyResponse;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadLegacyConfig(
    String currentUserId,
    String configPath,
  ) async {
    return SharedWorkspaceMigration.instance.loadLegacyMap(
      configPath,
      fallbackUserId: currentUserId,
    );
  }

  Future<void> _saveConfig({
    required String section,
    required String batchName,
    required Map<String, dynamic> data,
  }) async {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      throw const FirebaseDatabaseException('No signed-in user found.');
    }

    await _database.put(
      SharedWorkspace.path('$section/${_batchKey(batchName)}.json'),
      data,
    );
  }

  String _batchKey(String batchName) {
    final key = batchName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return key.isEmpty ? 'default_batch' : key;
  }

  String _controlPath(String controlName) {
    return 'controls/${SharedWorkspace.hardwareControlBatchKey}/$controlName.json';
  }
}
