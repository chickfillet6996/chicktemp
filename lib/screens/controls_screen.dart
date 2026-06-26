import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'analytics_screen.dart';
import 'lighting_screen.dart';
import '../models/auth_store.dart';
import '../models/device_config_store.dart';
import '../models/monitoring_store.dart';
import '../models/temperature_settings_store.dart';
import '../widgets/chicktemp_loading.dart';
import '../widgets/control_motion.dart';
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
  static const double _waterPumpSecondsPerLiter = 20;
  static const double _feederGramsPerSecond = 40;
  static const double _minimumFeedGrams = 20;
  static const double _feederGramStep = 10;
  static const int _automationOverrideDurationMs = 30 * 60 * 1000;

  int _selectedNavIndex = 0;
  bool _ventilationExpanded = false;
  bool _temperatureExpanded = false;
  bool _feederExpanded = false;
  bool _waterExpanded = false;
  bool _lightingExpanded = false;
  bool _mainFanEnabled = false;
  bool _mainFeederEnabled = false;
  bool _feederContinuousEnabled = false;
  bool _mainWaterEnabled = false;
  bool _waterContinuousEnabled = false;
  bool _mainLightEnabled = false;
  bool _isManualFeedSending = false;
  bool _isManualWaterSending = false;
  bool _isVentilationControlSending = false;
  bool _isLightingControlSending = false;
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

  String? get _controlBusyMessage {
    if (_isManualFeedSending) {
      return 'Starting manual feeding...';
    }
    if (_isManualWaterSending) {
      return 'Starting manual watering...';
    }
    return null;
  }

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
    await TemperatureSettingsStore.instance.loadFor(
      widget.batchName,
      forceRefresh: true,
    );
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

  String _formatDecimal(double value, {int decimals = 1}) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(decimals);
  }

  static String _formatStaticDecimal(double value, {int decimals = 1}) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(decimals);
  }

  static double _normalizeFeedGrams(double grams) {
    final clamped = grams.clamp(_minimumFeedGrams, 500).toDouble();
    final stepped = (clamped / _feederGramStep).ceil() * _feederGramStep;
    return stepped.clamp(_minimumFeedGrams, 500).toDouble();
  }

  static int _durationMsForFeederGrams(double grams) {
    return ((grams / _feederGramsPerSecond) * 1000)
        .round()
        .clamp(1, 60000)
        .toInt();
  }

  static String _durationLabelFromMs(int durationMs) {
    if (durationMs % 1000 == 0) {
      return '${durationMs ~/ 1000}s';
    }
    return '${(durationMs / 1000).toStringAsFixed(1)}s';
  }

  String _timeCodeFromLabel(String label) {
    final timeText = label.split(' - ').first.trim();
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])?$',
    ).firstMatch(timeText);
    if (match == null) {
      return '';
    }

    var hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final period = match.group(3)?.toLowerCase();
    if (period == 'pm' && hour < 12) {
      hour += 12;
    } else if (period == 'am' && hour == 12) {
      hour = 0;
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  List<String> _scheduleCodesFromLabels(
    Iterable<String> labels, {
    required String amountUnit,
    double? secondsPerAmount,
  }) {
    final codes = <String>[];
    final amountPattern = RegExp(
      '([0-9]+(?:\\.[0-9]+)?)\\s*$amountUnit',
      caseSensitive: false,
    );
    final secondsPattern = RegExp(
      r'([0-9]+(?:\.[0-9]+)?)\s*s',
      caseSensitive: false,
    );

    for (final label in labels) {
      final lower = label.toLowerCase();
      final active = lower.contains('active') && !lower.contains('inactive');
      final timeCode = _timeCodeFromLabel(label);
      final daysMask = ScheduleRepeat.maskFromScheduleLabel(label);
      final amountMatch = amountPattern.firstMatch(label);
      final secondsMatch = secondsPattern.firstMatch(label);
      final amount = double.tryParse(amountMatch?.group(1) ?? '');
      final savedSeconds = double.tryParse(secondsMatch?.group(1) ?? '');
      final durationMs = amount != null && secondsPerAmount != null
          ? (amount * secondsPerAmount * 1000).round()
          : savedSeconds == null
              ? null
              : (savedSeconds * 1000).round();
      if (timeCode.isEmpty || amount == null || durationMs == null) {
        continue;
      }
      codes.add(
        '$timeCode|$durationMs|${amount.toStringAsFixed(2)}|${active ? 1 : 0}|$daysMask',
      );
    }
    return codes;
  }

  List<String> _waterScheduleCodes() {
    return _scheduleCodesFromLabels(
      [
        ..._waterGlobalSchedules,
        for (final schedules in _waterSchedulesByDeviceId.values) ...schedules,
      ],
      amountUnit: 'L',
    );
  }

  List<String> _feederScheduleCodes() {
    return _scheduleCodesFromLabels(
      [
        ..._feederGlobalSchedules,
        for (final schedules in _feederSchedulesByDeviceId.values) ...schedules,
      ],
      amountUnit: 'g',
      secondsPerAmount: 1 / _feederGramsPerSecond,
    );
  }

  bool _scheduleActiveFromLabel(String label) {
    final lower = label.toLowerCase();
    return lower.contains('active') && !lower.contains('inactive');
  }

  double _scheduleAmountFromLabel(
    String label, {
    required String amountUnit,
    required double fallback,
  }) {
    final match = RegExp(
      '([0-9]+(?:\\.[0-9]+)?)\\s*$amountUnit',
      caseSensitive: false,
    ).firstMatch(label);
    return double.tryParse(match?.group(1) ?? '') ?? fallback;
  }

  int _scheduleSecondsFromLabel(String label, {required int fallback}) {
    final match = RegExp(r'([0-9]+)\s*s', caseSensitive: false).firstMatch(label);
    return int.tryParse(match?.group(1) ?? '') ?? fallback;
  }

  String _scheduleAlarmKey(String label) {
    return '${_timeCodeFromLabel(label)}|${ScheduleRepeat.maskFromScheduleLabel(label)}';
  }

  bool _hasDuplicateSchedule({
    required String label,
    required Iterable<String> schedules,
    String? ignoredLabel,
  }) {
    final key = _scheduleAlarmKey(label);
    var ignored = false;
    for (final schedule in schedules) {
      if (!ignored && ignoredLabel != null && schedule == ignoredLabel) {
        ignored = true;
        continue;
      }
      if (_scheduleAlarmKey(schedule) == key) {
        return true;
      }
    }
    return false;
  }

  Iterable<String> _allWaterSchedules() sync* {
    yield* _waterGlobalSchedules;
    for (final schedules in _waterSchedulesByDeviceId.values) {
      yield* schedules;
    }
  }

  Iterable<String> _allFeederSchedules() sync* {
    yield* _feederGlobalSchedules;
    for (final schedules in _feederSchedulesByDeviceId.values) {
      yield* schedules;
    }
  }

  WaterScheduleDraft _waterDraftFromLabel(String label) {
    final liters = _scheduleAmountFromLabel(
      label,
      amountUnit: 'L',
      fallback: 1,
    );
    return WaterScheduleDraft(
      time: label.split(' - ').first.trim(),
      active: _scheduleActiveFromLabel(label),
      liters: liters,
      durationSeconds: _scheduleSecondsFromLabel(
        label,
        fallback: (liters * _waterPumpSecondsPerLiter).round(),
      ),
      daysMask: ScheduleRepeat.maskFromScheduleLabel(label),
    );
  }

  _FeederScheduleDraft _feederDraftFromLabel(String label) {
    final grams = _normalizeFeedGrams(
      _scheduleAmountFromLabel(
        label,
        amountUnit: 'g',
        fallback: _minimumFeedGrams,
      ),
    );
    return _FeederScheduleDraft(
      time: label.split(' - ').first.trim(),
      active: _scheduleActiveFromLabel(label),
      grams: grams,
      durationMs: _durationMsForFeederGrams(grams),
      daysMask: ScheduleRepeat.maskFromScheduleLabel(label),
    );
  }

  String _waterScheduleLabel(WaterScheduleDraft draft) {
    final liters = _formatDecimal(draft.liters);
    final repeat = ScheduleRepeat.labelForMask(draft.daysMask);
    return '${draft.time} - $repeat - $liters L - ${draft.durationSeconds}s - ${draft.active ? 'Active' : 'Inactive'}';
  }

  String _feederScheduleLabel(_FeederScheduleDraft draft) {
    final grams = _formatDecimal(draft.grams);
    final repeat = ScheduleRepeat.labelForMask(draft.daysMask);
    return '${draft.time} - $repeat - $grams g - ${_durationLabelFromMs(draft.durationMs)} - ${draft.active ? 'Active' : 'Inactive'}';
  }

  String _normalizedWaterScheduleLabel(String label) {
    return _waterScheduleLabel(_waterDraftFromLabel(label));
  }

  String _normalizedFeederScheduleLabel(String label) {
    return _feederScheduleLabel(_feederDraftFromLabel(label));
  }

  int _esp32SafeCommandId() {
    return DateTime.now().millisecondsSinceEpoch.remainder(1000000000);
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
        return const Color(0xFFE53935);
    }
  }

  Future<void> _saveTemperatureSettings() async {
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

    try {
      await DeviceConfigStore.instance.saveTemperatureAutomationControl(
        batchName: widget.batchName,
        minTemperature: minTemperature,
        maxTemperature: maxTemperature,
      );
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved locally, but Firebase automation was not updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (!mounted) {
      return;
    }

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

  Future<void> _openAddFeederScheduleSheet({
    String? deviceId,
    int? scheduleIndex,
  }) async {
    final existingSchedule = scheduleIndex == null
        ? null
        : deviceId == null
            ? (scheduleIndex >= 0 && scheduleIndex < _feederGlobalSchedules.length
                ? _feederGlobalSchedules[scheduleIndex]
                : null)
            : (_feederSchedulesByDeviceId[deviceId] != null &&
                    scheduleIndex >= 0 &&
                    scheduleIndex < _feederSchedulesByDeviceId[deviceId]!.length
                ? _feederSchedulesByDeviceId[deviceId]![scheduleIndex]
                : null);
    final result = await showModalBottomSheet<_FeederScheduleDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFeederScheduleSheet(
        initialDraft:
            existingSchedule == null ? null : _feederDraftFromLabel(existingSchedule),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final label = _feederScheduleLabel(result);
    if (_hasDuplicateSchedule(
      label: label,
      schedules: _allFeederSchedules(),
      ignoredLabel: existingSchedule,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That feeding schedule already exists.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      if (deviceId == null) {
        if (scheduleIndex != null &&
            scheduleIndex >= 0 &&
            scheduleIndex < _feederGlobalSchedules.length) {
          _feederGlobalSchedules[scheduleIndex] = label;
        } else {
          _feederGlobalSchedules.insert(0, label);
        }
      } else {
        final schedules = _feederSchedulesByDeviceId.putIfAbsent(
          deviceId,
          () => [],
        );
        if (scheduleIndex != null &&
            scheduleIndex >= 0 &&
            scheduleIndex < schedules.length) {
          schedules[scheduleIndex] = label;
        } else {
          schedules.insert(0, label);
        }
      }
    });
    _persistFeederConfig();
  }

  void _deleteFeederSchedule({String? deviceId, required int scheduleIndex}) {
    setState(() {
      if (deviceId == null) {
        if (scheduleIndex >= 0 && scheduleIndex < _feederGlobalSchedules.length) {
          _feederGlobalSchedules.removeAt(scheduleIndex);
        }
      } else {
        final schedules = _feederSchedulesByDeviceId[deviceId];
        if (schedules != null &&
            scheduleIndex >= 0 &&
            scheduleIndex < schedules.length) {
          schedules.removeAt(scheduleIndex);
        }
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

  Future<void> _refreshControls() async {
    try {
      await Future.wait([
        _loadTemperatureSettings(),
        _loadSavedDeviceConfigs(),
      ]);
      MonitoringStore.instance.start();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not refresh controls: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        _mainFanEnabled = data['main_enabled'] == true;
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
              .map((entry) => _normalizedFeederScheduleLabel(entry.toString()))
              .toList();
      final savedDeviceSchedules = <String, List<String>>{};
      final rawDeviceSchedules = data['device_schedules'];
      if (rawDeviceSchedules is Map<String, dynamic>) {
        for (final entry in rawDeviceSchedules.entries) {
          savedDeviceSchedules[entry.key] =
              (entry.value as List<dynamic>? ?? const [])
                  .map((item) => _normalizedFeederScheduleLabel(item.toString()))
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
        _feederContinuousEnabled = data['continuous_enabled'] == true;
        _feederExpanded = data['expanded'] as bool? ?? _feederExpanded;
      });
    } on Object catch (_) {
      // Keep local defaults if the saved config cannot be loaded.
    }
  }

  Future<void> _persistVentilationConfig({
    bool? controlEnabledOverride,
    int? manualOverrideDurationMs,
    bool? manualOverrideCancel,
  }) async {
    try {
      await DeviceConfigStore.instance.saveVentilationConfig(
        batchName: widget.batchName,
        data: {
          'main_enabled': _mainFanEnabled,
          'expanded': _ventilationExpanded,
          'devices': _ventilationDevices
              .map((device) => device.toJson())
              .toList(),
        },
      );
      await DeviceConfigStore.instance.saveVentilationFanControl(
        batchName: widget.batchName,
        enabled: controlEnabledOverride ??
            (_mainFanEnabled ||
                _ventilationDevices.any((device) => device.enabled)),
        manualOverrideDurationMs: manualOverrideDurationMs,
        manualOverrideCancel: manualOverrideCancel,
        commandId:
            manualOverrideDurationMs != null || manualOverrideCancel != null
            ? _esp32SafeCommandId()
            : null,
      );
    } on Object catch (_) {
      // Ignore transient save failures in the controls UI.
    }
  }

  Future<void> _runVentilationControlUpdate(
    Future<void> Function() action,
  ) async {
    if (_isVentilationControlSending) {
      return;
    }

    setState(() => _isVentilationControlSending = true);
    try {
      await Future.wait([
        action(),
        Future<void>.delayed(const Duration(milliseconds: 550)),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isVentilationControlSending = false);
      }
    }
  }

  Future<void> _setVentilationOverride(bool value) {
    return _runVentilationControlUpdate(() async {
      if (mounted) {
        setState(() => _mainFanEnabled = value);
      }
      await _persistVentilationConfig(
        controlEnabledOverride: value,
        manualOverrideDurationMs: _automationOverrideDurationMs,
      );
    });
  }

  Future<void> _resumeVentilationAuto() {
    return _runVentilationControlUpdate(() {
      return _persistVentilationConfig(manualOverrideCancel: true);
    });
  }

  Future<void> _persistFeederConfig() async {
    try {
      await DeviceConfigStore.instance.saveFeederConfig(
        batchName: widget.batchName,
        data: {
          'main_enabled': _mainFeederEnabled,
          'continuous_enabled': _feederContinuousEnabled,
          'expanded': _feederExpanded,
          'devices': _feederDevices.map((device) => device.toJson()).toList(),
          'global_schedules': List<String>.from(_feederGlobalSchedules),
          'device_schedules': {
            for (final entry in _feederSchedulesByDeviceId.entries)
              entry.key: List<String>.from(entry.value),
          },
        },
      );
      await DeviceConfigStore.instance.saveFeederServoControl(
        batchName: widget.batchName,
        enabled: _mainFeederEnabled && _feederContinuousEnabled,
        schedulesEnabled: _mainFeederEnabled,
        scheduleCodes: _feederScheduleCodes(),
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
              .map((entry) => _normalizedWaterScheduleLabel(entry.toString()))
              .toList();
      final savedDeviceSchedules = <String, List<String>>{};
      final rawDeviceSchedules = data['device_schedules'];
      if (rawDeviceSchedules is Map<String, dynamic>) {
        for (final entry in rawDeviceSchedules.entries) {
          savedDeviceSchedules[entry.key] =
              (entry.value as List<dynamic>? ?? const [])
                  .map((item) => _normalizedWaterScheduleLabel(item.toString()))
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
        _waterContinuousEnabled = data['continuous_enabled'] == true;
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
          'continuous_enabled': _waterContinuousEnabled,
          'expanded': _waterExpanded,
          'devices': _waterDevices.map((device) => device.toJson()).toList(),
          'global_schedules': List<String>.from(_waterGlobalSchedules),
          'device_schedules': {
            for (final entry in _waterSchedulesByDeviceId.entries)
              entry.key: List<String>.from(entry.value),
          },
        },
      );
      await DeviceConfigStore.instance.saveWaterPumpControl(
        batchName: widget.batchName,
        enabled: _mainWaterEnabled && _waterContinuousEnabled,
        schedulesEnabled: _mainWaterEnabled,
        scheduleCodes: _waterScheduleCodes(),
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
        _mainLightEnabled = data['main_enabled'] == true;
        _lightingExpanded = data['expanded'] as bool? ?? _lightingExpanded;
      });
    } on Object catch (_) {}
  }

  Future<void> _persistLightingConfig({
    bool? controlEnabledOverride,
    int? manualOverrideDurationMs,
    bool? manualOverrideCancel,
  }) async {
    try {
      await DeviceConfigStore.instance.saveLightingConfig(
        batchName: widget.batchName,
        data: {
          'main_enabled': _mainLightEnabled,
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
      await DeviceConfigStore.instance.saveLightBulbControl(
        batchName: widget.batchName,
        enabled: controlEnabledOverride ??
            (_mainLightEnabled ||
                _lightingDevices.any((device) => device.enabled)),
        manualOverrideDurationMs: manualOverrideDurationMs,
        manualOverrideCancel: manualOverrideCancel,
        commandId:
            manualOverrideDurationMs != null || manualOverrideCancel != null
            ? _esp32SafeCommandId()
            : null,
      );
    } on Object catch (_) {}
  }

  Future<void> _runLightingControlUpdate(
    Future<void> Function() action,
  ) async {
    if (_isLightingControlSending) {
      return;
    }

    setState(() => _isLightingControlSending = true);
    try {
      await Future.wait([
        action(),
        Future<void>.delayed(const Duration(milliseconds: 550)),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isLightingControlSending = false);
      }
    }
  }

  Future<void> _setLightingOverride(bool value) {
    return _runLightingControlUpdate(() async {
      if (mounted) {
        setState(() => _mainLightEnabled = value);
      }
      await _persistLightingConfig(
        controlEnabledOverride: value,
        manualOverrideDurationMs: _automationOverrideDurationMs,
      );
    });
  }

  Future<void> _resumeLightingAuto() {
    return _runLightingControlUpdate(() {
      return _persistLightingConfig(manualOverrideCancel: true);
    });
  }

  Future<void> _openAddWaterScheduleSheet({
    String? deviceId,
    int? scheduleIndex,
  }) async {
    final existingSchedule = scheduleIndex == null
        ? null
        : deviceId == null
            ? (scheduleIndex >= 0 && scheduleIndex < _waterGlobalSchedules.length
                ? _waterGlobalSchedules[scheduleIndex]
                : null)
            : (_waterSchedulesByDeviceId[deviceId] != null &&
                    scheduleIndex >= 0 &&
                    scheduleIndex < _waterSchedulesByDeviceId[deviceId]!.length
                ? _waterSchedulesByDeviceId[deviceId]![scheduleIndex]
                : null);
    final result = await showModalBottomSheet<WaterScheduleDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddWaterScheduleSheet(
        initialDraft:
            existingSchedule == null ? null : _waterDraftFromLabel(existingSchedule),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final label = _waterScheduleLabel(result);
    if (_hasDuplicateSchedule(
      label: label,
      schedules: _allWaterSchedules(),
      ignoredLabel: existingSchedule,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That water schedule already exists.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      if (deviceId == null) {
        if (scheduleIndex != null &&
            scheduleIndex >= 0 &&
            scheduleIndex < _waterGlobalSchedules.length) {
          _waterGlobalSchedules[scheduleIndex] = label;
        } else {
          _waterGlobalSchedules.insert(0, label);
        }
      } else {
        final schedules = _waterSchedulesByDeviceId.putIfAbsent(
          deviceId,
          () => [],
        );
        if (scheduleIndex != null &&
            scheduleIndex >= 0 &&
            scheduleIndex < schedules.length) {
          schedules[scheduleIndex] = label;
        } else {
          schedules.insert(0, label);
        }
      }
    });
    _persistWaterConfig();
  }

  void _deleteWaterSchedule({String? deviceId, required int scheduleIndex}) {
    setState(() {
      if (deviceId == null) {
        if (scheduleIndex >= 0 && scheduleIndex < _waterGlobalSchedules.length) {
          _waterGlobalSchedules.removeAt(scheduleIndex);
        }
      } else {
        final schedules = _waterSchedulesByDeviceId[deviceId];
        if (schedules != null &&
            scheduleIndex >= 0 &&
            scheduleIndex < schedules.length) {
          schedules.removeAt(scheduleIndex);
        }
      }
    });
    _persistWaterConfig();
  }

  Future<void> _openManualWaterSheet() async {
    if (!_mainWaterEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turn on Water Pump Power before manual watering.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<_AmountCommandDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AmountCommandSheet(
        title: 'Manual Watering',
        amountLabel: 'WATER AMOUNT',
        unitLabel: 'liters',
        initialAmount: '1.0',
        accentColor: Color(0xFF1F5BFF),
        estimateDescription: 'Estimated pump time',
        secondsPerUnit: _waterPumpSecondsPerLiter,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() => _isManualWaterSending = true);
    try {
      await DeviceConfigStore.instance.saveWaterPumpControl(
        batchName: widget.batchName,
        enabled: _waterContinuousEnabled,
        schedulesEnabled: _mainWaterEnabled,
        liters: result.amount,
        durationMs: result.durationMs,
        commandId: _esp32SafeCommandId(),
        scheduleCodes: _waterScheduleCodes(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Watering ${_formatDecimal(result.amount)} L for ${result.durationLabel}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start manual watering: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isManualWaterSending = false);
      }
    }
  }

  Future<void> _openManualFeedSheet() async {
    if (!_mainFeederEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turn on Feeder Power before manual feeding.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<_AmountCommandDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AmountCommandSheet(
        title: 'Manual Feeding',
        amountLabel: 'FEED AMOUNT',
        unitLabel: 'grams',
        initialAmount: '20',
        accentColor: Color(0xFFF57C00),
        estimateDescription: 'Estimated gate-open time',
        secondsPerUnit: 1 / _feederGramsPerSecond,
        minAmount: _minimumFeedGrams,
        amountStep: _feederGramStep,
        wholeNumberOnly: true,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() => _isManualFeedSending = true);
    try {
      await DeviceConfigStore.instance.saveFeederServoControl(
        batchName: widget.batchName,
        enabled: _feederContinuousEnabled,
        schedulesEnabled: _mainFeederEnabled,
        grams: result.amount,
        durationMs: result.durationMs,
        commandId: _esp32SafeCommandId(),
        scheduleCodes: _feederScheduleCodes(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Feeding ${_formatDecimal(result.amount)} g for ${result.durationLabel}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start manual feeding: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isManualFeedSending = false);
      }
    }
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
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refreshControls,
                child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                AnimatedBuilder(
                  animation: MonitoringStore.instance,
                  builder: (context, _) {
                    final telemetry =
                        MonitoringStore.instance.snapshotFor(widget.batchName);
                    final displayedFanEnabled = _isVentilationControlSending
                        ? _mainFanEnabled
                        : telemetry.isDeviceLive
                        ? telemetry.ventilationFanEnabled
                        : _mainFanEnabled;
                    return _VentilationDropdownCard(
                      expanded: _ventilationExpanded,
                      devices: _ventilationDevices,
                      masterEnabled: displayedFanEnabled,
                      overrideActive: telemetry.ventilationFanOverrideActive,
                      deviceOnline: telemetry.isDeviceLive,
                      controlBusy: _isVentilationControlSending,
                      onTapHeader: _toggleVentilation,
                      onToggleMaster: (value) {
                        _setVentilationOverride(value);
                      },
                      onForceStop: () {
                        _setVentilationOverride(false);
                      },
                      onResumeAuto: () {
                        _resumeVentilationAuto();
                      },
                      onDeleteDevice: (index) {
                        setState(() {
                          _ventilationDevices.removeAt(index);
                        });
                        _persistVentilationConfig();
                      },
                      onToggleDevice: (index, value) {
                        setState(() {
                          _ventilationDevices[index] =
                              _ventilationDevices[index].copyWith(
                            enabled: value,
                          );
                        });
                        _persistVentilationConfig();
                      },
                      onSetSpeed: (index, speed) {
                        setState(() {
                          _ventilationDevices[index] =
                              _ventilationDevices[index].copyWith(
                            speed: speed,
                          );
                        });
                        _persistVentilationConfig();
                      },
                    );
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
                      currentTemperatureText: telemetry.temperature > 0
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
                AnimatedBuilder(
                  animation: MonitoringStore.instance,
                  builder: (context, _) {
                    final telemetry =
                        MonitoringStore.instance.snapshotFor(widget.batchName);
                    return _FeederDropdownCard(
                    expanded: _feederExpanded,
                    devices: _feederDevices,
                    masterEnabled: _mainFeederEnabled,
                    continuousEnabled: _feederContinuousEnabled,
                    manualFeedBusy: _isManualFeedSending,
                    feederLevelPercent: telemetry.feederLevelPercent,
                    feederDistanceCm: telemetry.feederDistanceCm,
                    feederLevelLive: telemetry.isFeederLevelLive,
                    onTapHeader: _toggleFeeder,
                    onAddGlobalSchedule: () => _openAddFeederScheduleSheet(),
                    onAddDeviceSchedule: (index) => _openAddFeederScheduleSheet(
                      deviceId: _feederDevices[index].id,
                    ),
                    onEditGlobalSchedule: (scheduleIndex) =>
                        _openAddFeederScheduleSheet(scheduleIndex: scheduleIndex),
                    onDeleteGlobalSchedule: (scheduleIndex) =>
                        _deleteFeederSchedule(scheduleIndex: scheduleIndex),
                    onEditDeviceSchedule: (deviceIndex, scheduleIndex) =>
                        _openAddFeederScheduleSheet(
                      deviceId: _feederDevices[deviceIndex].id,
                      scheduleIndex: scheduleIndex,
                    ),
                    onDeleteDeviceSchedule: (deviceIndex, scheduleIndex) =>
                        _deleteFeederSchedule(
                      deviceId: _feederDevices[deviceIndex].id,
                      scheduleIndex: scheduleIndex,
                    ),
                    onManualFeed: _openManualFeedSheet,
                    onToggleMaster: (value) {
                      setState(() {
                        _mainFeederEnabled = value;
                        if (!value) {
                          _feederContinuousEnabled = false;
                        }
                      });
                      _persistFeederConfig();
                    },
                    onToggleContinuous: (value) {
                      setState(() {
                        _feederContinuousEnabled = value;
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
                    );
                  },
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
                  continuousEnabled: _waterContinuousEnabled,
                  manualWaterBusy: _isManualWaterSending,
                  waterLevelPercent: telemetry.waterLevelPercent,
                  waterDistanceCm: telemetry.waterDistanceCm,
                  waterLevelLive: telemetry.isWaterLevelLive,
                  hideDefaultsWhenEmpty: false,
                  onTapHeader: _toggleWater,
                  onAddGlobalSchedule: () => _openAddWaterScheduleSheet(),
                  onAddDeviceSchedule: (index) => _openAddWaterScheduleSheet(
                    deviceId: _waterDevices[index].id,
                  ),
                  onEditGlobalSchedule: (scheduleIndex) =>
                      _openAddWaterScheduleSheet(scheduleIndex: scheduleIndex),
                  onDeleteGlobalSchedule: (scheduleIndex) => _deleteWaterSchedule(
                    scheduleIndex: scheduleIndex,
                  ),
                  onEditDeviceSchedule: (deviceIndex, scheduleIndex) =>
                      _openAddWaterScheduleSheet(
                    deviceId: _waterDevices[deviceIndex].id,
                    scheduleIndex: scheduleIndex,
                  ),
                  onDeleteDeviceSchedule: (deviceIndex, scheduleIndex) =>
                      _deleteWaterSchedule(
                    deviceId: _waterDevices[deviceIndex].id,
                    scheduleIndex: scheduleIndex,
                  ),
                  onManualWater: _openManualWaterSheet,
                  onToggleMaster: (value) {
                    setState(() {
                      _mainWaterEnabled = value;
                      if (!value) {
                        _waterContinuousEnabled = false;
                      }
                    });
                    _persistWaterConfig();
                  },
                  onToggleContinuous: (value) {
                    setState(() {
                      _waterContinuousEnabled = value;
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
                AnimatedBuilder(
                  animation: MonitoringStore.instance,
                  builder: (context, _) {
                    final telemetry =
                        MonitoringStore.instance.snapshotFor(widget.batchName);
                    final displayedLightEnabled = _isLightingControlSending
                        ? _mainLightEnabled
                        : telemetry.isDeviceLive
                        ? telemetry.lightBulbEnabled
                        : _mainLightEnabled;
                    return LightingSystemDropdownCard(
                      expanded: _lightingExpanded,
                      devices: _lightingDevices,
                      masterEnabled: displayedLightEnabled,
                      overrideActive: telemetry.lightBulbOverrideActive,
                      deviceOnline: telemetry.isDeviceLive,
                      controlBusy: _isLightingControlSending,
                      onTapHeader: _toggleLighting,
                      onToggleMaster: (value) {
                        _setLightingOverride(value);
                      },
                      onForceStop: () {
                        _setLightingOverride(false);
                      },
                      onResumeAuto: () {
                        _resumeLightingAuto();
                      },
                      onAddSchedule: (index) => _openAddLightingScheduleSheet(
                        deviceId: _lightingDevices[index].id,
                      ),
                      onDeleteDevice: (index) {
                        setState(() {
                          if (index >= 0 && index < _lightingDevices.length) {
                            final removedDevice =
                                _lightingDevices.removeAt(index);
                            _lightingSchedulesByDeviceId
                                .remove(removedDevice.id);
                          }
                        });
                        _persistLightingConfig();
                      },
                      onToggleDevice: (index, value) {
                        setState(() {
                          _lightingDevices[index] =
                              _lightingDevices[index].copyWith(enabled: value);
                        });
                        _persistLightingConfig();
                      },
                      onSetBrightness: (index, brightness) {
                        setState(() {
                          _lightingDevices[index] = _lightingDevices[index]
                              .copyWith(brightness: brightness);
                        });
                        _persistLightingConfig();
                      },
                      deviceSchedules: _lightingSchedulesByDeviceId,
                    );
                  },
                ),
                const SizedBox(height: 120),
              ],
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 104,
                child: _ControlBusyOverlay(message: _controlBusyMessage),
              ),
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

class _ControlBusyOverlay extends StatelessWidget {
  final String? message;

  const _ControlBusyOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: message == null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: message == null
            ? const SizedBox.shrink(key: ValueKey('idle'))
            : DecoratedBox(
                key: ValueKey(message),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDDEBDD)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF18321C).withOpacity(0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ChickTempLoading.compact(
                        size: 24,
                        color: Color(0xFF0BB13F),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message!,
                          style: const TextStyle(
                            color: Color(0xFF233047),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
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
  final Future<void> Function() onSave;
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
          ControlReveal(
            expanded: expanded,
            child: Padding(
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
                        onPressed: () {
                          onSave();
                        },
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
  final bool continuousEnabled;
  final bool manualFeedBusy;
  final double feederLevelPercent;
  final double feederDistanceCm;
  final bool feederLevelLive;
  final VoidCallback onTapHeader;
  final VoidCallback onAddGlobalSchedule;
  final void Function(int index) onAddDeviceSchedule;
  final void Function(int scheduleIndex) onEditGlobalSchedule;
  final void Function(int scheduleIndex) onDeleteGlobalSchedule;
  final void Function(int deviceIndex, int scheduleIndex) onEditDeviceSchedule;
  final void Function(int deviceIndex, int scheduleIndex) onDeleteDeviceSchedule;
  final VoidCallback onManualFeed;
  final ValueChanged<bool> onToggleMaster;
  final ValueChanged<bool> onToggleContinuous;
  final ValueChanged<int> onDeleteDevice;
  final void Function(int index, bool value) onToggleDevice;
  final List<String> globalSchedules;
  final Map<String, List<String>> deviceSchedules;

  const _FeederDropdownCard({
    required this.expanded,
    required this.devices,
    required this.masterEnabled,
    required this.continuousEnabled,
    required this.manualFeedBusy,
    required this.feederLevelPercent,
    required this.feederDistanceCm,
    required this.feederLevelLive,
    required this.onTapHeader,
    required this.onAddGlobalSchedule,
    required this.onAddDeviceSchedule,
    required this.onEditGlobalSchedule,
    required this.onDeleteGlobalSchedule,
    required this.onEditDeviceSchedule,
    required this.onDeleteDeviceSchedule,
    required this.onManualFeed,
    required this.onToggleMaster,
    required this.onToggleContinuous,
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
    final subtitle = feederLevelLive ? 'Online' : 'Offline';

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
          ControlReveal(
            expanded: expanded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _FeederControlCard(
                    powerEnabled: masterEnabled,
                    continuousEnabled: continuousEnabled,
                    manualFeedBusy: manualFeedBusy,
                    onPowerChanged: onToggleMaster,
                    onContinuousChanged: onToggleContinuous,
                    onManualFeed: onManualFeed,
                  ),
                  const SizedBox(height: 12),
                  _FeederLevelCard(
                    levelPercent: feederLevelPercent,
                    distanceCm: feederDistanceCm,
                    isLive: feederLevelLive,
                  ),
                  const SizedBox(height: 12),
                  _FeederScheduleCard(
                    title: 'MANAGE SCHEDULE',
                    buttonLabel: '+ Add Schedule',
                    schedules: globalSchedules,
                    emptyText: 'No global schedule set',
                    onAddSchedule: onAddGlobalSchedule,
                    onEditSchedule: onEditGlobalSchedule,
                    onDeleteSchedule: onDeleteGlobalSchedule,
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
                              onEditSchedule: (scheduleIndex) =>
                                  onEditDeviceSchedule(index, scheduleIndex),
                              onDeleteSchedule: (scheduleIndex) =>
                                  onDeleteDeviceSchedule(index, scheduleIndex),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _FeederLevelCard extends StatelessWidget {
  final double levelPercent;
  final double distanceCm;
  final bool isLive;

  const _FeederLevelCard({
    required this.levelPercent,
    required this.distanceCm,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    final hasReading = isLive;
    final level = hasReading ? levelPercent.clamp(0, 100).toDouble() : 0.0;
    final levelColor = level <= 20
        ? const Color(0xFFE5484D)
        : level <= 45
            ? const Color(0xFFF59E0B)
            : const Color(0xFFF57C00);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasReading ? const Color(0xFFFFFCF7) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasReading
              ? const Color(0xFFFFD6A7)
              : const Color(0xFFE3E9E4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, color: Color(0xFFF57C00), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'HC-SR04 FEEDER LEVEL',
                  style: TextStyle(
                    color: Color(0xFF233047),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                hasReading ? '${level.toStringAsFixed(0)}%' : 'NO READING',
                style: TextStyle(
                  color: hasReading ? levelColor : const Color(0xFF93A0B6),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: level / 100,
              minHeight: 12,
              backgroundColor: const Color(0xFFE8EFF2),
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasReading
                ? '${distanceCm.toStringAsFixed(1)} cm between sensor and feed surface'
                : 'Waiting for the ultrasonic sensor',
            style: const TextStyle(
              color: Color(0xFF93A0B6),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
class _FeederControlCard extends StatelessWidget {
  final bool powerEnabled;
  final bool continuousEnabled;
  final bool manualFeedBusy;
  final ValueChanged<bool> onPowerChanged;
  final ValueChanged<bool> onContinuousChanged;
  final VoidCallback onManualFeed;

  const _FeederControlCard({
    required this.powerEnabled,
    required this.continuousEnabled,
    required this.manualFeedBusy,
    required this.onPowerChanged,
    required this.onContinuousChanged,
    required this.onManualFeed,
  });

  @override
  Widget build(BuildContext context) {
    final continuousActive = powerEnabled && continuousEnabled;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: powerEnabled ? const Color(0xFFFFFCF7) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: powerEnabled
              ? const Color(0xFFFFD6A7)
              : const Color(0xFFE3E9E4),
        ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'SG90 Feeder Servo',
                      style: TextStyle(
                        color: Color(0xFF233047),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Signal on GPIO 33.\nOpens the feeder gate by timed portions.',
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
              ControlAnimatedStatus(
                text: powerEnabled ? 'ON' : 'OFF',
                style: TextStyle(
                  color: powerEnabled
                      ? const Color(0xFF24B26A)
                      : const Color(0xFF93A0B6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: powerEnabled,
                onChanged: onPowerChanged,
                activeColor: const Color(0xFF24B26A),
                activeTrackColor: const Color(0xFFB9EBC9),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFD9E4D9),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: continuousActive
                  ? const Color(0xFFFFF2DD)
                  : const Color(0xFFFFF8ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFE0B8)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continuous Gate',
                        style: TextStyle(
                          color: Color(0xFF7A3B00),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Keeps the feeder gate open until turned off.',
                        style: TextStyle(
                          color: Color(0xFF9A6A3A),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ControlAnimatedStatus(
                  text: continuousActive ? 'OPEN' : 'CLOSED',
                  style: TextStyle(
                    color: continuousActive
                        ? const Color(0xFFF57C00)
                        : const Color(0xFF93A0B6),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: continuousActive,
                  onChanged: powerEnabled ? onContinuousChanged : null,
                  activeColor: const Color(0xFFF57C00),
                  activeTrackColor: const Color(0xFFFFD6A7),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFE6DED2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: powerEnabled && !manualFeedBusy ? onManualFeed : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF57C00),
                disabledForegroundColor: const Color(0xFF98A2B3),
                side: const BorderSide(color: Color(0xFFFFD0A6)),
                backgroundColor: powerEnabled
                    ? const Color(0xFFFFF6EA)
                    : const Color(0xFFF4F5F7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: manualFeedBusy
                  ? const ChickTempLoading.compact(
                      size: 18,
                      color: Color(0xFFF57C00),
                    )
                  : const Icon(Icons.restaurant_rounded, size: 17),
              label: Text(
                manualFeedBusy ? 'Starting Feed...' : 'Manual Feed by Grams',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
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
  final void Function(int scheduleIndex) onEditSchedule;
  final void Function(int scheduleIndex) onDeleteSchedule;

  const _FeederScheduleCard({
    required this.title,
    required this.buttonLabel,
    required this.schedules,
    required this.emptyText,
    required this.onAddSchedule,
    required this.onEditSchedule,
    required this.onDeleteSchedule,
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
              children: List.generate(
                schedules.length,
                (index) {
                  final schedule = schedules[index];
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                schedule,
                                style: const TextStyle(
                                  color: Color(0xFF5E6B7F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => onEditSchedule(index),
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 17,
                                color: Color(0xFF7E8DA3),
                              ),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Edit schedule',
                            ),
                            IconButton(
                              onPressed: () => onDeleteSchedule(index),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 17,
                                color: Color(0xFFE36A6A),
                              ),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Delete schedule',
                            ),
                          ],
                          ),
                      ),
                    );
                },
              ),
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
class _AmountCommandDraft {
  final double amount;
  final int durationMs;

  const _AmountCommandDraft({
    required this.amount,
    required this.durationMs,
  });

  String get durationLabel {
    return _ControlsScreenState._durationLabelFromMs(durationMs);
  }
}

class _AmountCommandSheet extends StatefulWidget {
  final String title;
  final String amountLabel;
  final String unitLabel;
  final String initialAmount;
  final Color accentColor;
  final String estimateDescription;
  final double secondsPerUnit;
  final double minAmount;
  final double? amountStep;
  final bool wholeNumberOnly;

  const _AmountCommandSheet({
    required this.title,
    required this.amountLabel,
    required this.unitLabel,
    required this.initialAmount,
    required this.accentColor,
    required this.estimateDescription,
    required this.secondsPerUnit,
    this.minAmount = 0,
    this.amountStep,
    this.wholeNumberOnly = false,
  });

  @override
  State<_AmountCommandSheet> createState() => _AmountCommandSheetState();
}

class _AmountCommandSheetState extends State<_AmountCommandSheet> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.initialAmount);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _durationMs {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final effectiveAmount = amount < widget.minAmount ? widget.minAmount : amount;
    return (effectiveAmount * widget.secondsPerUnit * 1000)
        .round()
        .clamp(1, 300000)
        .toInt();
  }

  String get _durationLabel {
    return _ControlsScreenState._durationLabelFromMs(_durationMs);
  }

  bool _isValidStep(double amount) {
    final step = widget.amountStep;
    if (step == null || step <= 0) {
      return true;
    }
    final multiplier = amount / step;
    return (multiplier - multiplier.round()).abs() < 0.000001;
  }

  void _run() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enter a valid amount in ${widget.unitLabel}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (amount < widget.minAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum is ${_ControlsScreenState._formatStaticDecimal(widget.minAmount)} ${widget.unitLabel}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_isValidStep(amount)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use 10-gram steps only: 20, 30, 40, and so on.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _AmountCommandDraft(
        amount: amount,
        durationMs: (amount * widget.secondsPerUnit * 1000)
            .round()
            .clamp(1, 300000)
            .toInt(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.42,
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
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
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
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SheetLabel(widget.amountLabel),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: widget.wholeNumberOnly
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: widget.wholeNumberOnly
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                suffixText: widget.unitLabel,
                helperText:
                    '${widget.estimateDescription}: $_durationLabel',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
                  borderSide: BorderSide(color: widget.accentColor),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _run,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text(
                  'Run Now',
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

class _FeederScheduleDraft {
  final String time;
  final bool active;
  final double grams;
  final int durationMs;
  final int daysMask;

  const _FeederScheduleDraft({
    required this.time,
    required this.active,
    required this.grams,
    required this.durationMs,
    this.daysMask = ScheduleRepeat.allDaysMask,
  });
}

class _AddFeederScheduleSheet extends StatefulWidget {
  final _FeederScheduleDraft? initialDraft;

  const _AddFeederScheduleSheet({this.initialDraft});

  @override
  State<_AddFeederScheduleSheet> createState() => _AddFeederScheduleSheetState();
}

class _AddFeederScheduleSheetState extends State<_AddFeederScheduleSheet> {
  late bool _active;
  late TimeOfDay _selectedTime;
  late int _daysMask;
  late final TextEditingController _gramsController;

  @override
  void initState() {
    super.initState();
    final initialDraft = widget.initialDraft;
    _active = initialDraft?.active ?? true;
    _selectedTime = _parseTimeOfDay(initialDraft?.time) ??
        const TimeOfDay(hour: 6, minute: 0);
    _daysMask = initialDraft?.daysMask ?? ScheduleRepeat.allDaysMask;
    _gramsController = TextEditingController(
      text: initialDraft == null
          ? '20'
          : _ControlsScreenState._formatStaticDecimal(initialDraft.grams),
    );
  }

  TimeOfDay? _parseTimeOfDay(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])?$',
    ).firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    var hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final period = match.group(3)?.toLowerCase();
    if (period == 'pm' && hour < 12) {
      hour += 12;
    } else if (period == 'am' && hour == 12) {
      hour = 0;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  int get _durationMs {
    final grams = double.tryParse(_gramsController.text.trim()) ?? 20;
    return _ControlsScreenState._durationMsForFeederGrams(
      grams
          .clamp(_ControlsScreenState._minimumFeedGrams, 500)
          .toDouble(),
    );
  }

  String get _durationLabel {
    return _ControlsScreenState._durationLabelFromMs(_durationMs);
  }

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
    final grams = double.tryParse(_gramsController.text.trim());
    if (_daysMask <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose at least one repeat day.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (grams == null || grams < _ControlsScreenState._minimumFeedGrams) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum feed amount is 20 grams.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (grams % _ControlsScreenState._feederGramStep != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use 10-gram steps only: 20, 30, 40, and so on.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _FeederScheduleDraft(
        time: _selectedTime.format(context),
        active: _active,
        grams: grams,
        durationMs: _ControlsScreenState._durationMsForFeederGrams(grams),
        daysMask: _daysMask,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.72,
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
                Expanded(
                  child: Text(
                    widget.initialDraft == null
                        ? 'Add Feeding Schedule'
                        : 'Edit Feeding Schedule',
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
            const _SheetLabel('REPEAT DAYS'),
            const SizedBox(height: 8),
            ScheduleDaySelector(
              selectedMask: _daysMask,
              onChanged: (mask) => setState(() => _daysMask = mask),
            ),
            const SizedBox(height: 14),
            const _SheetLabel('FEED AMOUNT'),
            const SizedBox(height: 6),
            TextField(
              controller: _gramsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                suffixText: 'grams',
                helperText:
                    'Minimum 20g, then 10g steps. Estimated gate-open time: $_durationLabel',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
                  borderSide: const BorderSide(color: Color(0xFFA8E7B8)),
                ),
              ),
            ),
            const SizedBox(height: 12),
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

class _VentilationRelayControlCard extends StatelessWidget {
  final bool enabled;
  final bool overrideActive;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final VoidCallback onForceStop;
  final VoidCallback onResumeAuto;

  const _VentilationRelayControlCard({
    required this.enabled,
    required this.overrideActive,
    required this.busy,
    required this.onChanged,
    required this.onForceStop,
    required this.onResumeAuto,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF8FFFA) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled
              ? const Color(0xFFB9EBC9)
              : const Color(0xFFE3E9E4),
        ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '5V Ventilation Fan Relay',
                      style: TextStyle(
                        color: Color(0xFF233047),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Controls relay K3 / IN3.\nFan uses the separate 5V supply.',
                      style: TextStyle(
                        color: Color(0xFF93A0B6),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    if (overrideActive) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Manual override active',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ControlAnimatedStatus(
                text: enabled ? 'ON' : 'OFF',
                style: TextStyle(
                  color: enabled
                      ? const Color(0xFF24B26A)
                      : const Color(0xFF93A0B6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              _ControlSpinnerSlot(
                busy: busy,
                color: const Color(0xFF24B26A),
              ),
              const SizedBox(width: 8),
              Switch(
                value: enabled,
                onChanged: busy ? null : onChanged,
                activeColor: const Color(0xFF24B26A),
                activeTrackColor: const Color(0xFFB9EBC9),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFD9E4D9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ControlActionSwitcher(
            child: overrideActive
                ? SizedBox(
                    key: const ValueKey('ventilation-resume-auto'),
              width: double.infinity,
              height: 40,
              child: FilledButton.icon(
                onPressed: busy ? null : onResumeAuto,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: busy
                    ? const _ButtonSpinner(color: Colors.white)
                    : const Icon(Icons.autorenew_rounded, size: 17),
                label: Text(
                  busy ? 'Resuming...' : 'Resume Temperature Auto',
                ),
              ),
            )
                : enabled
                    ? SizedBox(
                        key: const ValueKey('ventilation-force-stop'),
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onForceStop,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB42318),
                  side: const BorderSide(color: Color(0xFFF1C6C2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: busy
                    ? const _ButtonSpinner(color: Color(0xFFB42318))
                    : const Icon(Icons.power_settings_new_rounded, size: 17),
                label: Text(
                  busy ? 'Stopping...' : 'Force Stop for 30 Minutes',
                ),
              ),
            )
                    : Container(
                        key: const ValueKey('ventilation-ready'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4FAF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDDEBDD)),
              ),
              child: const Text(
                'Auto mode is ready. The switch creates a 30-minute manual override.',
                style: TextStyle(
                  color: Color(0xFF607268),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VentilationDropdownCard extends StatelessWidget {
  final bool expanded;
  final List<_VentilationDevice> devices;
  final bool masterEnabled;
  final bool overrideActive;
  final bool deviceOnline;
  final bool controlBusy;
  final VoidCallback onTapHeader;
  final ValueChanged<bool> onToggleMaster;
  final VoidCallback onForceStop;
  final VoidCallback onResumeAuto;
  final ValueChanged<int> onDeleteDevice;
  final void Function(int index, bool value) onToggleDevice;
  final void Function(int index, int speed) onSetSpeed;

  const _VentilationDropdownCard({
    required this.expanded,
    required this.devices,
    required this.masterEnabled,
    required this.overrideActive,
    required this.deviceOnline,
    required this.controlBusy,
    required this.onTapHeader,
    required this.onToggleMaster,
    required this.onForceStop,
    required this.onResumeAuto,
    required this.onDeleteDevice,
    required this.onToggleDevice,
    required this.onSetSpeed,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = deviceOnline ? 'Online' : 'Offline';

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
                            color: Color(0xFF0B8F39),
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
          ControlReveal(
            expanded: expanded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _VentilationRelayControlCard(
                    enabled: masterEnabled,
                    overrideActive: overrideActive,
                    busy: controlBusy,
                    onChanged: onToggleMaster,
                    onForceStop: onForceStop,
                    onResumeAuto: onResumeAuto,
                  ),
                  const SizedBox(height: 12),
                  if (devices.isNotEmpty)
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
                ],
              ),
            ),
          ),
        ],
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
            ControlAnimatedStatus(
              text: device.enabled ? 'ON' : 'OFF',
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

class _ControlSpinnerSlot extends StatelessWidget {
  final bool busy;
  final Color color;

  const _ControlSpinnerSlot({
    required this.busy,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: busy
            ? _ButtonSpinner(
                key: const ValueKey('control-spinner'),
                color: color,
              )
            : const SizedBox.shrink(key: ValueKey('control-idle')),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  final Color color;

  const _ButtonSpinner({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(color),
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
