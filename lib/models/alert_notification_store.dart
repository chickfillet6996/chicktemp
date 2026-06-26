import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'batch_store.dart';
import 'device_config_store.dart';
import 'monitoring_store.dart';
import 'shared_workspace.dart';
import 'temperature_settings_store.dart';
import '../services/local_notification_service.dart';

enum AlertSeverity {
  critical,
  warning,
  info,
}

class AlertPreferences {
  final bool highTemperature;
  final bool lowTemperature;
  final bool deviceOffline;
  final bool feedingReminder;
  final bool waterReminder;
  final bool lightingReminder;

  const AlertPreferences({
    this.highTemperature = true,
    this.lowTemperature = true,
    this.deviceOffline = true,
    this.feedingReminder = true,
    this.waterReminder = true,
    this.lightingReminder = true,
  });

  AlertPreferences copyWith({
    bool? highTemperature,
    bool? lowTemperature,
    bool? deviceOffline,
    bool? feedingReminder,
    bool? waterReminder,
    bool? lightingReminder,
  }) {
    return AlertPreferences(
      highTemperature: highTemperature ?? this.highTemperature,
      lowTemperature: lowTemperature ?? this.lowTemperature,
      deviceOffline: deviceOffline ?? this.deviceOffline,
      feedingReminder: feedingReminder ?? this.feedingReminder,
      waterReminder: waterReminder ?? this.waterReminder,
      lightingReminder: lightingReminder ?? this.lightingReminder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'high_temperature': highTemperature,
      'low_temperature': lowTemperature,
      'device_offline': deviceOffline,
      'feeding_reminder': feedingReminder,
      'water_reminder': waterReminder,
      'lighting_reminder': lightingReminder,
    };
  }

  factory AlertPreferences.fromJson(Map<String, dynamic> json) {
    return AlertPreferences(
      highTemperature: json['high_temperature'] as bool? ?? true,
      lowTemperature: json['low_temperature'] as bool? ?? true,
      deviceOffline: json['device_offline'] as bool? ?? true,
      feedingReminder: json['feeding_reminder'] as bool? ?? true,
      waterReminder: json['water_reminder'] as bool? ?? true,
      lightingReminder: json['lighting_reminder'] as bool? ?? true,
    );
  }
}

class AlertNotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final String batchName;
  final String timeLabel;
  final DateTime sortAt;
  final AlertSeverity severity;
  final bool isRead;

  const AlertNotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.batchName,
    required this.timeLabel,
    required this.sortAt,
    required this.severity,
    this.isRead = false,
  });

  AlertNotificationItem copyWith({
    bool? isRead,
  }) {
    return AlertNotificationItem(
      id: id,
      title: title,
      subtitle: subtitle,
      batchName: batchName,
      timeLabel: timeLabel,
      sortAt: sortAt,
      severity: severity,
      isRead: isRead ?? this.isRead,
    );
  }
}

class AlertNotificationStore extends ChangeNotifier {
  AlertNotificationStore._();

  static const String _preferencesPrefix = 'alert_preferences';
  static const String _readIdsPrefix = 'alert_read_ids';
  static const String _notifiedIdsPrefix = 'alert_notified_ids';

  static final AlertNotificationStore instance = AlertNotificationStore._();

  AlertPreferences _preferences = const AlertPreferences();
  List<AlertNotificationItem> _alerts = const [];
  Set<String> _readAlertIds = <String>{};
  Set<String> _notifiedAlertIds = <String>{};
  bool _isLoading = false;
  bool _isLoaded = false;
  bool _refreshQueued = false;
  bool _started = false;
  String? _loadedUserId;

  AlertPreferences get preferences => _preferences;
  List<AlertNotificationItem> get alerts => List.unmodifiable(_alerts);
  bool get isLoading => _isLoading;
  int get unreadCount => _alerts.length;

  void start() {
    if (_started) {
      return;
    }

    _started = true;
    BatchStore.instance.addListener(_handleSourceChanged);
    MonitoringStore.instance.addListener(_handleSourceChanged);
    TemperatureSettingsStore.instance.addListener(_handleSourceChanged);
    unawaited(load());
  }

  Future<void> load() async {
    await _ensureLoaded();
    await refresh();
  }

  void resetForAccountSwitch() {
    _preferences = const AlertPreferences();
    _alerts = const [];
    _readAlertIds = <String>{};
    _notifiedAlertIds = <String>{};
    _isLoading = false;
    _isLoaded = false;
    _refreshQueued = false;
    _loadedUserId = null;
    notifyListeners();
  }

  void _handleSourceChanged() {
    unawaited(refresh());
  }

  Future<void> refresh() async {
    await _ensureLoaded();

    if (_isLoading) {
      _refreshQueued = true;
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final generatedAlerts = await _buildAlerts();
      final activeIds = generatedAlerts.map((alert) => alert.id).toSet();
      final nextReadIds = _readAlertIds.intersection(activeIds);
      final nextNotifiedIds = _notifiedAlertIds.intersection(activeIds);
      final readIdsChanged = nextReadIds.length != _readAlertIds.length;
      final notifiedIdsChanged =
          nextNotifiedIds.length != _notifiedAlertIds.length;
      _readAlertIds = nextReadIds;
      _notifiedAlertIds = nextNotifiedIds;

      if (readIdsChanged) {
        await _saveReadAlertIds();
      }

      final visibleAlerts = generatedAlerts
          .where((alert) => !_readAlertIds.contains(alert.id))
          .toList();
      final newPopupAlerts = visibleAlerts
          .where((alert) => !_notifiedAlertIds.contains(alert.id))
          .toList();

      _alerts = visibleAlerts;

      if (notifiedIdsChanged || newPopupAlerts.isNotEmpty) {
        _notifiedAlertIds = {
          ..._notifiedAlertIds,
          ...newPopupAlerts.map((alert) => alert.id),
        };
        await _saveNotifiedAlertIds();
      }

      unawaited(_showNewAlertPopups(newPopupAlerts));
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    if (_refreshQueued) {
      _refreshQueued = false;
      await refresh();
    }
  }

  Future<void> updatePreferences(AlertPreferences preferences) async {
    _preferences = preferences;
    await _savePreferences();
    notifyListeners();
    await refresh();
  }

  Future<void> toggleRead(String alertId) => markRead(alertId);

  Future<void> markRead(String alertId) async {
    _readAlertIds.add(alertId);
    await _saveReadAlertIds();
    _alerts = _alerts.where((alert) => alert.id != alertId).toList();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    if (_alerts.isEmpty) {
      return;
    }

    _readAlertIds = {
      ..._readAlertIds,
      ..._alerts.map((alert) => alert.id),
    };
    await _saveReadAlertIds();
    _alerts = const [];
    notifyListeners();
  }

  Future<void> _ensureLoaded() async {
    final userId = _currentUserKey;
    if (_isLoaded && _loadedUserId == userId) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final rawPreferences = prefs.getString(_preferencesKey(userId));
    final rawReadIds = prefs.getStringList(_readIdsKey(userId));
    final rawNotifiedIds = prefs.getStringList(_notifiedIdsKey(userId));

    if (rawPreferences != null && rawPreferences.isNotEmpty) {
      final decoded = jsonDecode(rawPreferences);
      if (decoded is Map<String, dynamic>) {
        _preferences = AlertPreferences.fromJson(decoded);
      } else {
        _preferences = const AlertPreferences();
      }
    } else {
      _preferences = const AlertPreferences();
    }

    _readAlertIds = {...?rawReadIds};
    _notifiedAlertIds = {...?rawNotifiedIds};
    _loadedUserId = userId;
    _isLoaded = true;
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _preferencesKey(_currentUserKey),
      jsonEncode(_preferences.toJson()),
    );
  }

  Future<void> _saveReadAlertIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _readIdsKey(_currentUserKey),
      _readAlertIds.toList()..sort(),
    );
  }

  Future<void> _saveNotifiedAlertIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _notifiedIdsKey(_currentUserKey),
      _notifiedAlertIds.toList()..sort(),
    );
  }

  Future<void> _showNewAlertPopups(
    List<AlertNotificationItem> alerts,
  ) async {
    if (alerts.isEmpty) {
      return;
    }

    final alert = alerts.first;
    final extraCount = alerts.length - 1;
    final body = extraCount == 0
        ? alert.subtitle
        : '${alert.subtitle} +$extraCount more alert${extraCount == 1 ? '' : 's'}.';

    try {
      await LocalNotificationService.instance.showAlert(
        id: alert.id,
        title: alert.title,
        body: body,
      );
    } on Object {
      // Alert refresh should never fail just because the OS rejected a popup.
    }
  }

  Future<List<AlertNotificationItem>> _buildAlerts() async {
    final now = DateTime.now();
    final activeBatch = BatchStore.instance.activeBatch;
    if (activeBatch == null) {
      return const [];
    }

    final batches = [activeBatch];
    final sensorBatchName = activeBatch.name;
    final alerts = <AlertNotificationItem>[];

    final futures = batches.map(
      (batch) => _buildBatchAlerts(
        batch: batch,
        now: now,
        sensorBatchName: sensorBatchName,
      ),
    );

    final alertGroups = await Future.wait(futures);
    for (final group in alertGroups) {
      alerts.addAll(group);
    }

    alerts.sort((a, b) => b.sortAt.compareTo(a.sortAt));
    return alerts;
  }

  Future<List<AlertNotificationItem>> _buildBatchAlerts({
    required BatchItem batch,
    required DateTime now,
    required String? sensorBatchName,
  }) async {
    final alerts = <AlertNotificationItem>[];
    final telemetry = MonitoringStore.instance.snapshotFor(batch.name);
    final settings = TemperatureSettingsStore.instance.settingsFor(batch.name);

    if (_preferences.highTemperature &&
        telemetry.isLive &&
        telemetry.temperature > settings.maxTemperature) {
      alerts.add(
        AlertNotificationItem(
          id: 'high_temp_${batch.stableId}',
          title: 'High Temperature Detected',
          subtitle:
              '${_formatTemperature(telemetry.temperature)} in ${batch.name} exceeded ${_formatTemperature(settings.maxTemperature)}.',
          batchName: batch.name,
          timeLabel: _formatTimestamp(telemetry.updatedAt, now: now),
          sortAt: telemetry.updatedAt,
          severity: AlertSeverity.critical,
        ),
      );
    }

    if (_preferences.lowTemperature &&
        telemetry.isLive &&
        telemetry.temperature < settings.minTemperature) {
      alerts.add(
        AlertNotificationItem(
          id: 'low_temp_${batch.stableId}',
          title: 'Low Temperature Detected',
          subtitle:
              '${_formatTemperature(telemetry.temperature)} in ${batch.name} is below the ${_formatTemperature(settings.minTemperature)} minimum.',
          batchName: batch.name,
          timeLabel: _formatTimestamp(telemetry.updatedAt, now: now),
          sortAt: telemetry.updatedAt,
          severity: AlertSeverity.warning,
        ),
      );
    }

    if (_preferences.deviceOffline &&
        sensorBatchName == batch.name &&
        !telemetry.isLive) {
      alerts.add(
        AlertNotificationItem(
          id: 'device_offline_${batch.stableId}',
          title: 'Device Offline',
          subtitle:
              'No live sensor reading is reaching ${batch.name}. Recheck the device connection.',
          batchName: batch.name,
          timeLabel: _formatTimestamp(telemetry.updatedAt, now: now),
          sortAt: telemetry.updatedAt,
          severity: AlertSeverity.warning,
        ),
      );
    }

    final configResults = await Future.wait([
      _preferences.feedingReminder
          ? _safeLoad(
              DeviceConfigStore.instance.loadFeederConfig(batchName: batch.name),
            )
          : Future<Map<String, dynamic>?>.value(null),
      _preferences.waterReminder
          ? _safeLoad(
              DeviceConfigStore.instance.loadWaterConfig(batchName: batch.name),
            )
          : Future<Map<String, dynamic>?>.value(null),
      _preferences.lightingReminder
          ? _safeLoad(
              DeviceConfigStore.instance.loadLightingConfig(batchName: batch.name),
            )
          : Future<Map<String, dynamic>?>.value(null),
    ]);

    if (_preferences.feedingReminder) {
      final nextFeeding = _nextActiveSchedule(configResults[0], now);
      if (nextFeeding != null) {
        alerts.add(
          AlertNotificationItem(
            id: 'feeding_${batch.stableId}_${_scheduleStamp(nextFeeding.nextAt)}',
            title: 'Feeding Schedule Reminder',
            subtitle:
                '${batch.name} has ${nextFeeding.activeCount} active feeding schedule(s). Next run: ${DateFormat('h:mm a').format(nextFeeding.nextAt)}.',
            batchName: batch.name,
            timeLabel: _formatTimestamp(nextFeeding.nextAt, now: now),
            sortAt: nextFeeding.nextAt,
            severity: AlertSeverity.info,
          ),
        );
      }
    }

    if (_preferences.waterReminder) {
      final nextWater = _nextActiveSchedule(configResults[1], now);
      if (nextWater != null) {
        alerts.add(
          AlertNotificationItem(
            id: 'water_${batch.stableId}_${_scheduleStamp(nextWater.nextAt)}',
            title: 'Water Schedule Reminder',
            subtitle:
                '${batch.name} has ${nextWater.activeCount} active water schedule(s). Next release: ${DateFormat('h:mm a').format(nextWater.nextAt)}.',
            batchName: batch.name,
            timeLabel: _formatTimestamp(nextWater.nextAt, now: now),
            sortAt: nextWater.nextAt,
            severity: AlertSeverity.info,
          ),
        );
      }
    }

    if (_preferences.lightingReminder) {
      final nextLighting = _nextActiveSchedule(configResults[2], now);
      if (nextLighting != null) {
        alerts.add(
          AlertNotificationItem(
            id: 'lighting_${batch.stableId}_${_scheduleStamp(nextLighting.nextAt)}',
            title: 'Lighting Schedule Reminder',
            subtitle:
                '${batch.name} has ${nextLighting.activeCount} active lighting schedule(s). Next cycle: ${DateFormat('h:mm a').format(nextLighting.nextAt)}.',
            batchName: batch.name,
            timeLabel: _formatTimestamp(nextLighting.nextAt, now: now),
            sortAt: nextLighting.nextAt,
            severity: AlertSeverity.info,
          ),
        );
      }
    }

    return alerts;
  }

  Future<Map<String, dynamic>?> _safeLoad(
    Future<Map<String, dynamic>?> future,
  ) async {
    try {
      return await future;
    } on Object {
      return null;
    }
  }

  _UpcomingSchedule? _nextActiveSchedule(
    Map<String, dynamic>? config,
    DateTime now,
  ) {
    if (config == null) {
      return null;
    }

    final scheduleLabels = <String>[
      ...(config['global_schedules'] as List<dynamic>? ?? const [])
          .map((value) => value.toString()),
    ];

    final rawDeviceSchedules = config['device_schedules'];
    if (rawDeviceSchedules is Map<String, dynamic>) {
      for (final entry in rawDeviceSchedules.entries) {
        final values = entry.value as List<dynamic>? ?? const [];
        scheduleLabels.addAll(values.map((value) => value.toString()));
      }
    }

    DateTime? nextAt;
    var activeCount = 0;

    for (final label in scheduleLabels) {
      final schedule = _parseScheduleLabel(label, now);
      if (schedule == null || !schedule.isActive) {
        continue;
      }

      activeCount += 1;
      if (nextAt == null || schedule.nextAt.isBefore(nextAt)) {
        nextAt = schedule.nextAt;
      }
    }

    if (nextAt == null || activeCount == 0) {
      return null;
    }

    return _UpcomingSchedule(
      nextAt: nextAt,
      activeCount: activeCount,
    );
  }

  _ParsedSchedule? _parseScheduleLabel(String label, DateTime now) {
    final match = RegExp(
      r'^\s*([0-9]{1,2}:[0-9]{2}\s*[APap][Mm])(?:\s*-\s*(Active|Inactive))?\s*$',
    ).firstMatch(label);
    if (match == null) {
      return null;
    }

    final timeText = match.group(1);
    final statusText = match.group(2)?.toLowerCase();
    if (timeText == null) {
      return null;
    }

    final parsedTime = DateFormat('h:mm a').parseLoose(timeText.toUpperCase());
    var nextAt = DateTime(
      now.year,
      now.month,
      now.day,
      parsedTime.hour,
      parsedTime.minute,
    );

    if (!nextAt.isAfter(now)) {
      nextAt = nextAt.add(const Duration(days: 1));
    }

    return _ParsedSchedule(
      nextAt: nextAt,
      isActive: statusText != 'inactive',
    );
  }

  String _formatTemperature(double value) {
    final text = value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '$text°C';
  }

  String _formatTimestamp(DateTime value, {required DateTime now}) {
    final date = DateTime(value.year, value.month, value.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = date.difference(today).inDays;
    final time = DateFormat('h:mm a').format(value);

    if (difference == 0) {
      return time;
    }
    if (difference == 1) {
      return 'Tomorrow, $time';
    }
    if (difference == -1) {
      return 'Yesterday, $time';
    }
    return DateFormat('MMM d, h:mm a').format(value);
  }

  String _scheduleStamp(DateTime value) {
    return DateFormat('yyyyMMddHHmm').format(value);
  }

  String get _currentUserKey => SharedWorkspace.id;

  String _preferencesKey(String userKey) =>
      SharedWorkspace.localKey('${_preferencesPrefix}_$userKey');
  String _readIdsKey(String userKey) =>
      SharedWorkspace.localKey('${_readIdsPrefix}_$userKey');

  String _notifiedIdsKey(String userKey) =>
      SharedWorkspace.localKey('${_notifiedIdsPrefix}_$userKey');
}

class _ParsedSchedule {
  final DateTime nextAt;
  final bool isActive;

  const _ParsedSchedule({
    required this.nextAt,
    required this.isActive,
  });
}

class _UpcomingSchedule {
  final DateTime nextAt;
  final int activeCount;

  const _UpcomingSchedule({
    required this.nextAt,
    required this.activeCount,
  });
}
