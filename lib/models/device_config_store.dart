import 'auth_store.dart';
import 'firebase_database_service.dart';

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
  }) async {
    await _database.put(
      'controls/${_batchKey(batchName)}/water_pump.json',
      {
        'enabled': enabled,
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
  }) async {
    await _database.put(
      'controls/${_batchKey(batchName)}/light_bulb.json',
      {
        'enabled': enabled,
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
        'user_data/${user.id}/$section/$batchKey.json',
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

    final response = await _database.get(
      'user_data/${user.id}/$section/${_batchKey(batchName)}.json',
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return null;
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
      'user_data/${user.id}/$section/${_batchKey(batchName)}.json',
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
}
