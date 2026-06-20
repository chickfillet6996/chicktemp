import 'package:flutter/material.dart';

import 'analytics_screen.dart';
import 'lighting_screen.dart';
import '../models/auth_store.dart';
import '../models/device_config_store.dart';
import '../models/monitoring_store.dart';
import '../models/temperature_settings_store.dart';
import '../widgets/splash_background.dart';
import '../widgets/user_avatar_content.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'water_screen.dart';

class ControlsScreen extends StatefulWidget {
  final String batchName;

  const ControlsScreen({
    super.key,
    required this.batchName,
  });

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  int _selectedNavIndex = 0;
  bool _ventilationExpanded = false;
  bool _temperatureExpanded = false;
  bool _feederExpanded = false;
  bool _waterExpanded = false;
  bool _lightingExpanded = false;
  bool _mainFeederEnabled = false;
  bool _mainWaterEnabled = false;
  final List<_VentilationDevice> _ventilationDevices = [];
  final List<_FeederDevice> _feederDevices = [];
  final List<WaterDevice> _waterDevices = [];
  final List<LightingDevice> _lightingDevices = [];
  final List<String> _feederGlobalSchedules = [];
  final List<String> _waterGlobalSchedules = [];
  final Map<String, List<String>> _lightingSchedulesByDeviceId = {};
  final Map<String, List<String>> _feederSchedulesByDeviceId = {};
  final Map<String, List<String>> _waterSchedulesByDeviceId = {};
  final TextEditingController _minTempController = TextEditingController(text: '28');
  final TextEditingController _maxTempController = TextEditingController(text: '35');

  @override
  void initState() {
    super.initState();
    final settings = TemperatureSettingsStore.instance.settingsFor(widget.batchName);
    _minTempController.text = _formatTemperatureInput(settings.minTemperature);
    _maxTempController.text = _formatTemperatureInput(settings.maxTemperature);
    _loadTemperatureSettings();
    _loadSavedDeviceConfigs();
  }

  Future<void> _loadTemperatureSettings() async {
    await TemperatureSettingsStore.instance.loadFor(widget.batchName);
    if (!mounted) {
      return;
    }
    final settings = TemperatureSettingsStore.instance.settingsFor(
      widget.batchName,
    );
    setState(() {
      _minTempController.text = _formatTemperatureInput(
        settings.minTemperature,
      );
      _maxTempController.text = _formatTemperatureInput(
        settings.maxTemperature,
      );
    });
  }

  @override
  void dispose() {
    _minTempController.dispose();
    _maxTempController.dispose();
    super.dispose();
  }

  String _formatTemperatureInput(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  String _temperatureStatusLabel(TemperatureCondition condition) {
    switch (condition) {
      case TemperatureCondition.low:
        return 'LOW';
      case TemperatureCondition.high:
        return 'HIGH';
      case TemperatureCondition.normal:
        return 'NORMAL';
      case TemperatureCondition.noSensor:
        return 'NO SENSOR';
    }
  }

  Color _temperatureStatusColor(TemperatureCondition condition) {
    switch (condition) {
      case TemperatureCondition.low:
        return const Color(0xFF2563EB);
      case TemperatureCondition.high:
        return const Color(0xFFE53935);
      case TemperatureCondition.normal:
        return const Color(0xFF24B26A);
      case TemperatureCondition.noSensor:
        return const Color(0xFF6B7280);
    }
  }

  void _saveTemperatureSettings() {
    final minTemperature = double.tryParse(_minTempController.text.trim());
    final maxTemperature = double.tryParse(_maxTempController.text.trim());

    if (minTemperature == null || maxTemperature == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid minimum and maximum temperatures.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (minTemperature >= maxTemperature) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum temperature must be lower than maximum temperature.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    TemperatureSettingsStore.instance.updateFor(
      widget.batchName,
      minTemperature: minTemperature,
      maxTemperature: maxTemperature,
    );

    setState(() {
      _minTempController.text = _formatTemperatureInput(minTemperature);
      _maxTempController.text = _formatTemperatureInput(maxTemperature);
      _temperatureExpanded = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Temperature settings saved'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleVentilation() {
    setState(() {
      _ventilationExpanded = !_ventilationExpanded;
    });
    _persistVentilationConfig();
  }

  void _toggleFeeder() {
    setState(() {
      _feederExpanded = !_feederExpanded;
    });
    _persistFeederConfig();
  }

  void _toggleWater() {
    setState(() {
      _waterExpanded = !_waterExpanded;
    });
    _persistWaterConfig();
  }

  void _toggleLighting() {
    setState(() {
      _lightingExpanded = !_lightingExpanded;
    });
    _persistLightingConfig();
  }

  Future<void> _openAddVentilationDeviceSheet() async {
    final result = await showModalBottomSheet<_VentilationDevice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddVentilationDeviceSheet(),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _ventilationDevices.insert(0, result);
      _ventilationExpanded = true;
    });
    _persistVentilationConfig();
  }

  Future<void> _openAddFeederDeviceSheet() async {
    final result = await showModalBottomSheet<_FeederDevice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFeederDeviceSheet(),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _feederDevices.insert(0, result);
      _feederExpanded = true;
    });
    _persistFeederConfig();
  }

  Future<void> _openAddFeederScheduleSheet({String? deviceId}) async {
    final result = await showModalBottomSheet<_FeederScheduleDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFeederScheduleSheet(),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      final label = '${result.time} - ${result.active ? 'Active' : 'Inactive'}';
      if (deviceId == null) {
        _feederGlobalSchedules.insert(0, label);
      } else {
        _feederSchedulesByDeviceId.putIfAbsent(deviceId, () => []).insert(0, label);
      }
    });
    _persistFeederConfig();
  }

  Future<void> _loadSavedDeviceConfigs() async {
    await Future.wait([
      _loadSavedVentilationConfig(),
      _loadSavedFeederConfig(),
      _loadSavedWaterConfig(),
      _loadSavedLightingConfig(),
    ]);
  }

  Future<void> _loadSavedVentilationConfig() async {
    try {
      final data = await DeviceConfigStore.instance.loadVentilationConfig(
        batchName: widget.batchName,
      );
      if (!mounted || data == null) {
        return;
      }

      final savedDevices = (data['devices'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_VentilationDevice.fromJson)
          .toList();

      setState(() {
        _ventilationDevices
          ..clear()
          ..addAll(savedDevices);
        _ventilationExpanded = data['expanded'] as bool? ?? _ventilationExpanded;
      });
    } on Object catch (_) {
      // Keep local defaults if the saved config cannot be loaded.
    }
  }

  Future<void> _loadSavedFeederConfig() async {
    try {
      final data = await DeviceConfigStore.instance.loadFeederConfig(
        batchName: widget.batchName,
      );
      if (!mounted || data == null) {
        return;
      }

      final savedDevices = (data['devices'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_FeederDevice.fromJson)
          .toList();
      final savedGlobalSchedules =
          (data['global_schedules'] as List<dynamic>? ?? const [])
              .map((entry) => entry.toString())
              .toList();
      final savedDeviceSchedules = <String, List<String>>{};
      final rawDeviceSchedules = data['device_schedules'];
      if (rawDeviceSchedules is Map<String, dynamic>) {
        for (final entry in rawDeviceSchedules.entries) {
          savedDeviceSchedules[entry.key] =
              (entry.value as List<dynamic>? ?? const [])
                  .map((item) => item.toString())
                  .toList();
        }
      }

      setState(() {
        _feederDevices
          ..clear()
          ..addAll(savedDevices);
        _feederGlobalSchedules
          ..clear()
          ..addAll(savedGlobalSchedules);
        _feederSchedulesByDeviceId
          ..clear()
          ..addAll(savedDeviceSchedules);
        _mainFeederEnabled = data['main_enabled'] == true;
        _feederExpanded = data['expanded'] as bool? ?? _feederExpanded;
      });
    } on Object catch (_) {
      // Keep local defaults if the saved config cannot be loaded.
    }
  }

  Future<void> _persistVentilationConfig() async {
    try {
      await DeviceConfigStore.instance.saveVentilationConfig(
        batchName: widget.batchName,
        data: {
          'expanded': _ventilationExpanded,
          'devices': _ventilationDevices
              .map((device) => device.toJson())
              .toList(),
        },
      );
    } on Object catch (_) {
      // Ignore transient save failures in the controls UI.
    }
  }

  Future<void> _persistFeederConfig() async {
    try {
      await DeviceConfigStore.instance.saveFeederConfig(
        batchName: widget.batchName,
        data: {
          'main_enabled': _mainFeederEnabled,
          'expanded': _feederExpanded,
          'devices': _feederDevices.map((device) => device.toJson()).toList(),
          'global_schedules': List<String>.from(_feederGlobalSchedules),
          'device_schedules': {
            for (final entry in _feederSchedulesByDeviceId.entries)
              entry.key: List<String>.from(entry.value),
          },
        },
      );
    } on Object catch (_) {
      // Ignore transient save failures in the controls UI.
    }
  }

  Future<void> _loadSavedWaterConfig() async {
    try {
      final data = await DeviceConfigStore.instance.loadWaterConfig(
        batchName: widget.batchName,
      );
      if (!mounted || data == null) {
        return;
      }

      final savedDevices = (data['devices'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WaterDevice.fromJson)
          .toList();
      final savedGlobalSchedules =
          (data['global_schedules'] as List<dynamic>? ?? const [])
              .map((entry) => entry.toString())
              .toList();
      final savedDeviceSchedules = <String, List<String>>{};
      final rawDeviceSchedules = data['device_schedules'];
      if (rawDeviceSchedules is Map<String, dynamic>) {
        for (final entry in rawDeviceSchedules.entries) {
          savedDeviceSchedules[entry.key] =
              (entry.value as List<dynamic>? ?? const [])
                  .map((item) => item.toString())
                  .toList();
        }
      }

      setState(() {
        _waterDevices
          ..clear()
          ..addAll(savedDevices);
        _waterGlobalSchedules
          ..clear()
          ..addAll(savedGlobalSchedules);
        _waterSchedulesByDeviceId
          ..clear()
          ..addAll(savedDeviceSchedules);
        _mainWaterEnabled = data['main_enabled'] == true;
        _waterExpanded = data['expanded'] as bool? ?? _waterExpanded;
      });
    } on Object catch (_) {}
  }

  Future<void> _persistWaterConfig() async {
    try {
      await DeviceConfigStore.instance.saveWaterConfig(
        batchName: widget.batchName,
        data: {
          'main_enabled': _mainWaterEnabled,
          'expanded': _waterExpanded,
          'devices': _waterDevices.map((device) => device.toJson()).toList(),
          'global_schedules': List<String>.from(_waterGlobalSchedules),
          'device_schedules': {
            for (final entry in _waterSchedulesByDeviceId.entries)
              entry.key: List<String>.from(entry.value),
          },
        },
      );
    } on Object catch (_) {}
  }

  Future<void> _loadSavedLightingConfig() async {
    try {
      final data = await DeviceConfigStore.instance.loadLightingConfig(
        batchName: widget.batchName,
      );
      if (!mounted || data == null) {
        return;
      }

      final savedDevices = (data['devices'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LightingDevice.fromJson)
          .toList();
      final savedDeviceSchedules = <String, List<String>>{};
      final rawDeviceSchedules = data['device_schedules'];
      if (rawDeviceSchedules is Map<String, dynamic>) {
        for (final entry in rawDeviceSchedules.entries) {
          savedDeviceSchedules[entry.key] =
              (entry.value as List<dynamic>? ?? const [])
                  .map((item) => item.toString())
                  .toList();
        }
      }

      setState(() {
        _lightingDevices
          ..clear()
          ..addAll(savedDevices);
        _lightingSchedulesByDeviceId
          ..clear()
          ..addAll(savedDeviceSchedules);
        _lightingExpanded = data['expanded'] as bool? ?? _lightingExpanded;
      });
    } on Object catch (_) {}
  }

  Future<void> _persistLightingConfig() async {
    try {
      await DeviceConfigStore.instance.saveLightingConfig(
        batchName: widget.batchName,
        data: {
          'expanded': _lightingExpanded,
          'devices': _lightingDevices
              .map((device) => device.toJson())
              .toList(),
          'device_schedules': {
            for (final entry in _lightingSchedulesByDeviceId.entries)
              entry.key: List<String>.from(entry.value),
          },
        },
      );
    } on Object catch (_) {}
  }

  Future<void> _openAddWaterDeviceSheet() async {
    final result = await showModalBottomSheet<WaterDevice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddWaterDeviceSheet(),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _waterDevices.insert(0, result);
      _waterExpanded = true;
    });
    _persistWaterConfig();
  }

  Future<void> _openAddWaterScheduleSheet({String? deviceId}) async {
    final result = await showModalBottomSheet<WaterScheduleDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddWaterScheduleSheet(),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      final label = '${result.time} - ${result.active ? 'Active' : 'Inactive'}';
      if (deviceId == null) {
        _waterGlobalSchedules.insert(0, label);
      } else {
        _waterSchedulesByDeviceId.putIfAbsent(deviceId, () => []).insert(0, label);
      }
    });
    _persistWaterConfig();
  }

  Future<void> _openAddLightingDeviceSheet() async {
    final result = await showModalBottomSheet<LightingDevice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddLightingDeviceSheet(),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _lightingDevices.insert(0, result);
      _lightingExpanded = true;
    });
    _persistLightingConfig();
  }

  Future<void> _openAddLightingScheduleSheet({String? deviceId}) async {
    final result = await showModalBottomSheet<LightingScheduleDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddLightingScheduleSheet(),
    );

    if (!mounted || result == null || deviceId == null) {
      return;
    }

    setState(() {
      final label =
          '${result.time} - ${result.action} - ${result.active ? 'Active' : 'Inactive'}';
      _lightingSchedulesByDeviceId.putIfAbsent(deviceId, () => []).insert(0, label);
    });
    _persistLightingConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF4F7F3),
      body: SplashBackground(
        child: SafeArea(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.circle, size: 8, color: Colors.white70),
                                SizedBox(width: 8),
                                Text(
                                  'CHICKTEMP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Dashboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Live farm overview',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => ProfileScreen.show(context),
                        borderRadius: BorderRadius.circular(14),
                        splashColor: Colors.white.withOpacity(0.18),
                        highlightColor: Colors.white.withOpacity(0.12),
                        hoverColor: Colors.white.withOpacity(0.08),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                          alignment: Alignment.center,
                          child: UserAvatarContent(
                            initials: AuthStore.instance.currentUserInitials,
                            profilePhotoBase64:
                                AuthStore.instance.currentUser
                                    ?.profilePhotoBase64 ??
                                '',
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IntrinsicWidth(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF124A22),
                        side: const BorderSide(color: Color(0xFFD9E8DE)),
                        backgroundColor: const Color(0xFFF5FBF6),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        minimumSize: const Size(0, 42),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      label: Text(
                        'Back to ${widget.batchName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'CLIMATE & ENVIRONMENT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D3E30),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                  _VentilationDropdownCard(
                    expanded: _ventilationExpanded,
                    devices: _ventilationDevices,
                  onTapHeader: _toggleVentilation,
                  onAddDevice: _openAddVentilationDeviceSheet,
                  onDeleteDevice: (index) {
                    setState(() {
                      _ventilationDevices.removeAt(index);
                    });
                    _persistVentilationConfig();
                  },
                  onToggleDevice: (index, value) {
                    setState(() {
                      _ventilationDevices[index] = _ventilationDevices[index].copyWith(enabled: value);
                    });
                    _persistVentilationConfig();
                  },
                  onSetSpeed: (index, speed) {
                    setState(() {
                      _ventilationDevices[index] = _ventilationDevices[index].copyWith(speed: speed);
                    });
                    _persistVentilationConfig();
                  },
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    MonitoringStore.instance,
                    TemperatureSettingsStore.instance,
                  ]),
                  builder: (context, _) {
                    final telemetry = MonitoringStore.instance.snapshotFor(widget.batchName);
                    final settings = TemperatureSettingsStore.instance.settingsFor(widget.batchName);
                    final condition = TemperatureSettingsStore.instance.classify(
                      widget.batchName,
                      telemetry.temperature,
                      isLive: telemetry.isLive,
                    );

                    return _TemperatureDropdownCard(
                      expanded: _temperatureExpanded,
                      minController: _minTempController,
                      maxController: _maxTempController,
                      minTemperature: settings.minTemperature,
                      maxTemperature: settings.maxTemperature,
                      currentTemperatureText: telemetry.isLive
                          ? '${telemetry.temperature.toStringAsFixed(1)}°C'
                          : 'No sensor',
                      currentStatusLabel: _temperatureStatusLabel(condition),
                      currentStatusColor: _temperatureStatusColor(condition),
                      onTapHeader: () {
                        setState(() {
                          _temperatureExpanded = !_temperatureExpanded;
                        });
                      },
                      onSave: _saveTemperatureSettings,
                      onTempChanged: () => setState(() {}),
                    );
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'RESOURCES & LIGHTING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D3E30),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                _FeederDropdownCard(
                    expanded: _feederExpanded,
                    devices: _feederDevices,
                    masterEnabled: _mainFeederEnabled,
                    onTapHeader: _toggleFeeder,
                    onAddDevice: _openAddFeederDeviceSheet,
                    onAddGlobalSchedule: () => _openAddFeederScheduleSheet(),
                    onAddDeviceSchedule: (index) => _openAddFeederScheduleSheet(
                      deviceId: _feederDevices[index].id,
                    ),
                    onToggleMaster: (value) {
                      setState(() {
                        _mainFeederEnabled = value;
                      });
                      _persistFeederConfig();
                    },
                    onDeleteDevice: (index) {
                      setState(() {
                        if (index >= 0 && index < _feederDevices.length) {
                          final removedDevice = _feederDevices.removeAt(index);
                          _feederSchedulesByDeviceId.remove(removedDevice.id);
                        }
                      });
                      _persistFeederConfig();
                    },
                    onToggleDevice: (index, value) {
                      setState(() {
                        if (index >= 0 && index < _feederDevices.length) {
                          _feederDevices[index].enabled = value;
                        }
                      });
                      _persistFeederConfig();
                    },
                    globalSchedules: _feederGlobalSchedules,
                    deviceSchedules: _feederSchedulesByDeviceId,
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: MonitoringStore.instance,
                  builder: (context, _) {
                    final telemetry =
                        MonitoringStore.instance.snapshotFor(widget.batchName);
                    return WaterSupplyDropdownCard(
                  expanded: _waterExpanded,
                  devices: _waterDevices,
                  masterEnabled: _mainWaterEnabled,
                  waterLevelPercent: telemetry.waterLevelPercent,
                  waterDistanceCm: telemetry.waterDistanceCm,
                  waterLevelLive: telemetry.isWaterLevelLive,
                  hideDefaultsWhenEmpty:
                      AuthStore.instance.currentUser?.startsWithEmptyControls ??
                      false,
                  onTapHeader: _toggleWater,
                  onAddDevice: _openAddWaterDeviceSheet,
                  onAddGlobalSchedule: () => _openAddWaterScheduleSheet(),
                  onAddDeviceSchedule: (index) => _openAddWaterScheduleSheet(
                    deviceId: _waterDevices[index].id,
                  ),
                  onToggleMaster: (value) {
                    setState(() {
                      _mainWaterEnabled = value;
                    });
                    _persistWaterConfig();
                  },
                  onDeleteDevice: (index) {
                    setState(() {
                      if (index >= 0 && index < _waterDevices.length) {
                        final removedDevice = _waterDevices.removeAt(index);
                        _waterSchedulesByDeviceId.remove(removedDevice.id);
                      }
                    });
                    _persistWaterConfig();
                  },
                  onToggleDevice: (index, value) {
                    setState(() {
                      _waterDevices[index] = _waterDevices[index].copyWith(enabled: value);
                    });
                    _persistWaterConfig();
                  },
                  globalSchedules: _waterGlobalSchedules,
                  deviceSchedules: _waterSchedulesByDeviceId,
                    );
                  },
                ),
                const SizedBox(height: 12),
                LightingSystemDropdownCard(
                  expanded: _lightingExpanded,
                  devices: _lightingDevices,
                  onTapHeader: _toggleLighting,
                  onAddDevice: _openAddLightingDeviceSheet,
                  onAddSchedule: (index) => _openAddLightingScheduleSheet(
                    deviceId: _lightingDevices[index].id,
                  ),
                  onDeleteDevice: (index) {
                    setState(() {
                      if (index >= 0 && index < _lightingDevices.length) {
                        final removedDevice = _lightingDevices.removeAt(index);
                        _lightingSchedulesByDeviceId.remove(removedDevice.id);
                      }
                    });
                    _persistLightingConfig();
                  },
                  onToggleDevice: (index, value) {
                    setState(() {
                      _lightingDevices[index] = _lightingDevices[index].copyWith(enabled: value);
                    });
                    _persistLightingConfig();
                  },
                  onSetBrightness: (index, brightness) {
                    setState(() {
                      _lightingDevices[index] = _lightingDevices[index].copyWith(brightness: brightness);
                    });
                    _persistLightingConfig();
                  },
                  deviceSchedules: _lightingSchedulesByDeviceId,
                ),
                const SizedBox(height: 120),
              ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.42),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.58),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF18321C).withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: _selectedNavIndex == 0,
                onTap: () => Navigator.of(context).pop(),
              ),
              _BottomNavItem(
                icon: Icons.show_chart_rounded,
                label: 'Analytics',
                selected: _selectedNavIndex == 1,
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AnalyticsScreen(
                        initialBatchName: widget.batchName,
                      ),
                    ),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.description_outlined,
                label: 'Reports',
                selected: _selectedNavIndex == 2,
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ReportsScreen(
                        initialBatchName: widget.batchName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemperatureDropdownCard extends StatelessWidget {
  final bool expanded;
  final TextEditingController minController;
  final TextEditingController maxController;
  final double minTemperature;
  final double maxTemperature;
  final String currentTemperatureText;
  final String currentStatusLabel;
  final Color currentStatusColor;
  final VoidCallback onTapHeader;
  final VoidCallback onSave;
  final VoidCallback onTempChanged;

  const _TemperatureDropdownCard({
    required this.expanded,
    required this.minController,
    required this.maxController,
    required this.minTemperature,
    required this.maxTemperature,
    required this.currentTemperatureText,
    required this.currentStatusLabel,
    required this.currentStatusColor,
    required this.onTapHeader,
    required this.onSave,
    required this.onTempChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9E9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTapHeader,
            borderRadius: BorderRadius.circular(24),
            splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
            highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
            hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.thermostat_outlined, color: Color(0xFFE53935), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Temperature Control',
                          style: TextStyle(
                            color: Color(0xFF132015),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$currentStatusLabel • $currentTemperatureText',
                          style: TextStyle(
                            color: currentStatusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD6D6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFE53935), size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5ECE7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _TempInputBox(
                            label: 'MIN TEMP (\u00B0C)',
                            controller: minController,
                            onChanged: (_) => onTempChanged(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TempInputBox(
                            label: 'MAX TEMP (\u00B0C)',
                            controller: maxController,
                            onChanged: (_) => onTempChanged(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Fan turns ON when above ${maxTemperature.toStringAsFixed(maxTemperature % 1 == 0 ? 0 : 1)}\u00B0C',
                      style: const TextStyle(
                        color: Color(0xFF5C6C7C),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Heater turns ON when below ${minTemperature.toStringAsFixed(minTemperature % 1 == 0 ? 0 : 1)}\u00B0C',
                      style: const TextStyle(
                        color: Color(0xFF5C6C7C),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: onSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF21414),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(
                          'Save Settings',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _FeederDropdownCard extends StatelessWidget {
  final bool expanded;
  final List<_FeederDevice> devices;
  final bool masterEnabled;
  final VoidCallback onTapHeader;
  final VoidCallback onAddDevice;
  final VoidCallback onAddGlobalSchedule;
  final void Function(int index) onAddDeviceSchedule;
  final ValueChanged<bool> onToggleMaster;
  final ValueChanged<int> onDeleteDevice;
  final void Function(int index, bool value) onToggleDevice;
  final List<String> globalSchedules;
  final Map<String, List<String>> deviceSchedules;

  const _FeederDropdownCard({
    required this.expanded,
    required this.devices,
    required this.masterEnabled,
    required this.onTapHeader,
    required this.onAddDevice,
    required this.onAddGlobalSchedule,
    required this.onAddDeviceSchedule,
    required this.onToggleMaster,
    required this.onDeleteDevice,
    required this.onToggleDevice,
    required this.globalSchedules,
    required this.deviceSchedules,
  });

  @override
  Widget build(BuildContext context) {
    final hasDevice = devices.isNotEmpty;
    final headerColor = hasDevice ? const Color(0xFFFCEFD9) : const Color(0xFFF8E7D0);
    final iconColor = const Color(0xFFF57C00);
    final subtitle =
        hasDevice ? '${devices.length} Device${devices.length == 1 ? '' : 's'} Connected' : 'No Devices';

    return Container(
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTapHeader,
            borderRadius: BorderRadius.circular(24),
            splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
            highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
            hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.flash_on_outlined, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Auto Feeder Lines',
                          style: TextStyle(
                            color: Color(0xFF8B3D00),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFFB84D00),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDAB7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFB84D00), size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _FeederControlCard(
                    enabled: masterEnabled,
                    onChanged: onToggleMaster,
                  ),
                  const SizedBox(height: 12),
                  _FeederScheduleCard(
                    title: 'MANAGE SCHEDULE',
                    buttonLabel: '+ Add Schedule',
                    schedules: globalSchedules,
                    emptyText: 'No global schedule set',
                    onAddSchedule: onAddGlobalSchedule,
                  ),
                  const SizedBox(height: 12),
                  if (hasDevice)
                    ...List.generate(devices.length, (index) {
                      final isLast = index == devices.length - 1;
                      final device = devices[index];
                      final schedules = deviceSchedules[device.id] ?? const <String>[];
                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                        child: Column(
                          children: [
                            _FeederDeviceCard(
                              index: index,
                              device: device,
                              onDeleteDevice: onDeleteDevice,
                              onToggleDevice: onToggleDevice,
                            ),
                            const SizedBox(height: 12),
                            _FeederScheduleCard(
                              title: 'FEEDING SCHEDULE',
                              buttonLabel: '+ Add Schedule',
                              schedules: schedules,
                              emptyText: 'No feeding schedule set for this device',
                              onAddSchedule: () => onAddDeviceSchedule(index),
                            ),
                          ],
                        ),
                      );
                    })
                  else
                    _EmptyFeederPlaceholder(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: onAddDevice,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5A1A),
                        side: const BorderSide(color: Color(0xFFF0E0C7)),
                        backgroundColor: const Color(0xFFFFF6EA),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Add Auto Feeder Lines Device',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _FeederControlCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _FeederControlCard({
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E9E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Main Feeder Control',
                  style: TextStyle(
                    color: Color(0xFF233047),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Master trigger inactive -\nIndividual controls still active',
                  style: TextStyle(
                    color: Color(0xFF93A0B6),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            enabled ? 'ON' : 'OFF',
            style: TextStyle(
              color: enabled ? Color(0xFF24B26A) : Color(0xFF93A0B6),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: const Color(0xFF24B26A),
            activeTrackColor: const Color(0xFFB9EBC9),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD9E4D9),
          ),
        ],
      ),
    );
  }
}

class _FeederScheduleCard extends StatelessWidget {
  final String title;
  final String buttonLabel;
  final List<String> schedules;
  final String emptyText;
  final VoidCallback onAddSchedule;

  const _FeederScheduleCard({
    required this.title,
    required this.buttonLabel,
    required this.schedules,
    required this.emptyText,
    required this.onAddSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E9E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFB2BCCB),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onAddSchedule,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF24B26A),
                  side: const BorderSide(color: Color(0xFFA8E7B8)),
                  backgroundColor: const Color(0xFFF1FFF4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (schedules.isEmpty)
            Container(
              width: double.infinity,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9AA8BD),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Column(
              children: schedules
                  .map(
                    (schedule) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          schedule,
                          style: const TextStyle(
                            color: Color(0xFF5E6B7F),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _FeederDeviceCard extends StatelessWidget {
  final int index;
  final _FeederDevice device;
  final ValueChanged<int> onDeleteDevice;
  final void Function(int index, bool value) onToggleDevice;

  const _FeederDeviceCard({
    required this.index,
    required this.device,
    required this.onDeleteDevice,
    required this.onToggleDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E9E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    color: Color(0xFF233047),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  device.description.isNotEmpty ? device.description : device.id,
                  style: const TextStyle(
                    color: Color(0xFF93A0B6),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onDeleteDevice(index),
            style: IconButton.styleFrom(
              hoverColor: const Color(0xFFE53935).withOpacity(0.08),
              highlightColor: const Color(0xFFE53935).withOpacity(0.12),
            ),
            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFD0D7E5)),
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete device',
          ),
          Text(
            device.enabled ? 'ON' : 'OFF',
            style: TextStyle(
              color: device.enabled ? Color(0xFF24B26A) : Color(0xFF93A0B6),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: device.enabled,
            onChanged: (value) => onToggleDevice(index, value),
            activeColor: const Color(0xFF24B26A),
            activeTrackColor: const Color(0xFFB9EBC9),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD9E4D9),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeederPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'No devices added yet',
        style: TextStyle(
          color: Color(0xFF9AA8BD),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AddFeederDeviceSheet extends StatefulWidget {
  const _AddFeederDeviceSheet();

  @override
  State<_AddFeederDeviceSheet> createState() => _AddFeederDeviceSheetState();
}

class _AddFeederDeviceSheetState extends State<_AddFeederDeviceSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _typeController = TextEditingController(text: 'Feeder');
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _typeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      _FeederDevice(
        name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Auto Feeder 1',
        id: _idController.text.trim().isNotEmpty ? _idController.text.trim() : 'FED001',
        type: _typeController.text.trim().isNotEmpty ? _typeController.text.trim() : 'Feeder',
        description: _descriptionController.text.trim(),
        enabled: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.72;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF7FCF8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add New Device',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(999),
                      splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
                      highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
                      hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFDCE5DD)),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _SheetLabel('DEVICE NAME'),
                const SizedBox(height: 6),
                _SheetTextField(controller: _nameController, hintText: 'e.g. Ventilation Fan 2'),
                const SizedBox(height: 10),
                const _SheetLabel('DEVICE ID'),
                const SizedBox(height: 6),
                _SheetTextField(controller: _idController, hintText: 'e.g. FAN002'),
                const SizedBox(height: 10),
                const _SheetLabel('DEVICE TYPE'),
                const SizedBox(height: 6),
                _SheetTextField(controller: _typeController, hintText: 'Feeder'),
                const SizedBox(height: 10),
                const _SheetLabel('DESCRIPTION (OPTIONAL)'),
                const SizedBox(height: 6),
                _SheetTextField(
                  controller: _descriptionController,
                  hintText: 'Enter device details...',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0BB13F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Save Device',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeederScheduleDraft {
  final String time;
  final bool active;

  const _FeederScheduleDraft({
    required this.time,
    required this.active,
  });
}

class _AddFeederScheduleSheet extends StatefulWidget {
  const _AddFeederScheduleSheet();

  @override
  State<_AddFeederScheduleSheet> createState() => _AddFeederScheduleSheetState();
}

class _AddFeederScheduleSheetState extends State<_AddFeederScheduleSheet> {
  bool _active = true;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 6, minute: 0);

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _selectedTime = picked;
    });
  }

  void _save() {
    Navigator.of(context).pop(
      _FeederScheduleDraft(time: _selectedTime.format(context), active: _active),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.45,
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: const BoxDecoration(
          color: Color(0xFFF7FCF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add Feeding Schedule',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(999),
                  splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
                  highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
                  hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFDCE5DD)),
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'All Feeder Devices',
              style: TextStyle(
                color: Color(0xFF8A96AC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const _SheetLabel('FEEDING TIME'),
            const SizedBox(height: 6),
            _TimeField(
              time: _selectedTime,
              onTap: _pickTime,
            ),
            const SizedBox(height: 14),
            const _SheetLabel('STATUS'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    label: 'Active',
                    selected: _active,
                    onTap: () => setState(() => _active = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PillButton(
                    label: 'Inactive',
                    selected: !_active,
                    onTap: () => setState(() => _active = false),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0BB13F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text(
                  'Save Schedule',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeField({
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
      highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
      hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
      child: Ink(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCE4EE)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                time.format(context),
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.schedule_outlined, size: 18, color: Color(0xFFB7C0CD)),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
        highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
        hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8F6EA) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? const Color(0xFFA8E7B8) : const Color(0xFFDCE4EE)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF0B8F39) : const Color(0xFF8A96AC),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TempInputBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const _TempInputBox({
    required this.label,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6A7C99),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.thermostat_outlined, size: 18, color: Color(0xFFB7C0CD)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCE4EE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCE4EE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFF1B4B4)),
            ),
          ),
        ),
      ],
    );
  }
}

class _VentilationDropdownCard extends StatelessWidget {
  final bool expanded;
  final List<_VentilationDevice> devices;
  final VoidCallback onTapHeader;
  final VoidCallback onAddDevice;
  final ValueChanged<int> onDeleteDevice;
  final void Function(int index, bool value) onToggleDevice;
  final void Function(int index, int speed) onSetSpeed;

  const _VentilationDropdownCard({
    required this.expanded,
    required this.devices,
    required this.onTapHeader,
    required this.onAddDevice,
    required this.onDeleteDevice,
    required this.onToggleDevice,
    required this.onSetSpeed,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle =
        devices.isEmpty ? 'No Devices' : '${devices.length} Device${devices.length == 1 ? '' : 's'} Connected';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE7FCEF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTapHeader,
            borderRadius: BorderRadius.circular(24),
            splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
            highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
            hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.air_rounded, color: Color(0xFF24B26A), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ventilation Fans',
                          style: TextStyle(
                            color: Color(0xFF132015),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF314236),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8F1D1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F7A3B), size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  if (devices.isEmpty)
                    _emptyState()
                  else
                    Column(
                      children: List.generate(devices.length, (index) {
                        final device = devices[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: index == devices.length - 1 ? 0 : 12),
                          child: _deviceCard(
                            index,
                            device,
                            onDeleteDevice,
                            onToggleDevice,
                            onSetSpeed,
                          ),
                        );
                      }),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: onAddDevice,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF355C79),
                        side: const BorderSide(color: Color(0xFFDDE7E0)),
                        backgroundColor: const Color(0xFFF3FBF5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Add Ventilation Fans Device',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5ECE7)),
      ),
      child: const Text(
        'No devices added yet',
        style: TextStyle(
          color: Color(0xFF9AA8BD),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _deviceCard(
    int index,
    _VentilationDevice device,
    ValueChanged<int> onDeleteDevice,
    void Function(int index, bool value) onToggleDevice,
    void Function(int index, int speed) onSetSpeed,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5ECE7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      color: Color(0xFF132015),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.id,
                    style: const TextStyle(
                      color: Color(0xFF6E7B8D),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => onDeleteDevice(index),
              style: IconButton.styleFrom(
                hoverColor: const Color(0xFFE53935).withOpacity(0.08),
                highlightColor: const Color(0xFFE53935).withOpacity(0.12),
              ),
              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFB7C0CD)),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            ),
            const SizedBox(width: 4),
            Text(
              device.enabled ? 'ON' : 'OFF',
              style: TextStyle(
                color: device.enabled ? const Color(0xFF24B26A) : const Color(0xFF8A96AC),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: device.enabled,
              onChanged: (value) => onToggleDevice(index, value),
              activeColor: const Color(0xFF24B26A),
              activeTrackColor: const Color(0xFFB9EBC9),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFD9E4D9),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'FAN SPEED',
              style: TextStyle(
                color: Color(0xFFB2BCCB),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            Text(
              'Level ${device.speed}',
              style: const TextStyle(
                color: Color(0xFFB2BCCB),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SpeedButton(
                label: '1',
                selected: device.speed == 1,
                onTap: () => onSetSpeed(index, 1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SpeedButton(
                label: '2',
                selected: device.speed == 2,
                onTap: () => onSetSpeed(index, 2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SpeedButton(
                label: '3',
                selected: device.speed == 3,
                onTap: () => onSetSpeed(index, 3),
              ),
            ),
          ],
        ),
        ],
      ),
    );
  }
}

class _VentilationDevice {
  final String name;
  final String id;
  final String type;
  final String description;
  final bool enabled;
  final int speed;

  _VentilationDevice({
    required this.name,
    required this.id,
    this.type = 'Fan',
    this.description = '',
    this.enabled = false,
    this.speed = 1,
  });

  _VentilationDevice copyWith({
    String? name,
    String? id,
    String? type,
    String? description,
    bool? enabled,
    int? speed,
  }) {
    return _VentilationDevice(
      name: name ?? this.name,
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      speed: speed ?? this.speed,
    );
  }

  factory _VentilationDevice.fromJson(Map<String, dynamic> json) {
    return _VentilationDevice(
      name: json['name']?.toString() ?? 'Ventilation Fan 1',
      id: json['id']?.toString() ?? 'FAN001',
      type: json['type']?.toString() ?? 'Fan',
      description: json['description']?.toString() ?? '',
      enabled: json['enabled'] == true,
      speed: (json['speed'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'type': type,
      'description': description,
      'enabled': enabled,
      'speed': speed,
    };
  }
}

class _FeederDevice {
  String name;
  String id;
  String type;
  String description;
  bool enabled;

  _FeederDevice({
    required this.name,
    required this.id,
    this.type = 'Feeder',
    this.description = '',
    this.enabled = true,
  });

  factory _FeederDevice.fromJson(Map<String, dynamic> json) {
    return _FeederDevice(
      name: json['name']?.toString() ?? 'Auto Feeder 1',
      id: json['id']?.toString() ?? 'FED001',
      type: json['type']?.toString() ?? 'Feeder',
      description: json['description']?.toString() ?? '',
      enabled: json['enabled'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'type': type,
      'description': description,
      'enabled': enabled,
    };
  }
}

class _SpeedButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpeedButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
        highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
        hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFFF8FBFA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF90D6A4) : const Color(0xFFE3E9E4),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0BB13F).withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF0B8F39) : const Color(0xFFB1BAC7),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddVentilationDeviceSheet extends StatefulWidget {
  const _AddVentilationDeviceSheet();

  @override
  State<_AddVentilationDeviceSheet> createState() => _AddVentilationDeviceSheetState();
}

class _AddVentilationDeviceSheetState extends State<_AddVentilationDeviceSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _typeController = TextEditingController(text: 'Fan');
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _typeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Ventilation Fan 1';
    final id = _idController.text.trim().isNotEmpty ? _idController.text.trim() : 'FAN001';
    final type = _typeController.text.trim().isNotEmpty ? _typeController.text.trim() : 'Fan';
    final description = _descriptionController.text.trim();

    Navigator.of(context).pop(
      _VentilationDevice(
        name: name,
        id: id,
        type: type,
        description: description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.72;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF7FCF8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add New Device',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFDCE5DD)),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _SheetLabel('DEVICE NAME'),
                const SizedBox(height: 6),
                _SheetTextField(controller: _nameController, hintText: 'e.g. Ventilation Fan 2'),
                const SizedBox(height: 10),
                const _SheetLabel('DEVICE ID'),
                const SizedBox(height: 6),
                _SheetTextField(controller: _idController, hintText: 'e.g. FAN002'),
                const SizedBox(height: 10),
                const _SheetLabel('DEVICE TYPE'),
                const SizedBox(height: 6),
                _SheetTextField(controller: _typeController, hintText: 'Fan'),
                const SizedBox(height: 10),
                const _SheetLabel('DESCRIPTION (OPTIONAL)'),
                const SizedBox(height: 6),
                _SheetTextField(
                  controller: _descriptionController,
                  hintText: 'Enter device details...',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0BB13F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Save Device',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF6A7C99),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;

  const _SheetTextField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: Color(0xFF111827),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF9AA7BC),
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE4EE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE4EE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF90D6A4)),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2E7D32) : const Color(0xFF8E9AAF);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
        highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
        hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFE8F6EA).withOpacity(0.7)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
