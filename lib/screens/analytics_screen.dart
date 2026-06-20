import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/auth_store.dart';
import '../models/batch_store.dart';
import '../models/device_config_store.dart';
import '../models/environmental_log_store.dart';
import '../models/firebase_database_service.dart';
import '../models/monitoring_store.dart';
import '../models/temperature_settings_store.dart';
import '../widgets/splash_background.dart';
import '../widgets/user_avatar_content.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  final String? initialBatchName;

  const AnalyticsScreen({super.key, this.initialBatchName});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final List<String> _batches;
  late String _selectedBatch;
  late Future<_AnalyticsData> _analyticsFuture;
  int _selectedNavIndex = 1;
  String? _selectedEnvironmentalLogDay;
  Timer? _analyticsRefreshTimer;

  @override
  void initState() {
    super.initState();
    _batches = BatchStore.instance.batches.map((batch) => batch.name).toList();
    final initialBatch = widget.initialBatchName;
    _selectedBatch =
        initialBatch != null && _batches.contains(initialBatch)
        ? initialBatch
        : _batches.isEmpty
        ? 'Default Batch'
        : _batches.first;
    TemperatureSettingsStore.instance.loadFor(_selectedBatch);
    _analyticsFuture = _loadAndRecordAnalytics();
    EnvironmentalLogStore.instance.addListener(
      _handleEnvironmentalLogRecorded,
    );
    _analyticsRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshLogs(),
    );
  }

  @override
  void dispose() {
    EnvironmentalLogStore.instance.removeListener(
      _handleEnvironmentalLogRecorded,
    );
    _analyticsRefreshTimer?.cancel();
    super.dispose();
  }

  void _handleEnvironmentalLogRecorded() {
    _refreshLogs();
  }

  void _refreshLogs() {
    if (!mounted) {
      return;
    }
    setState(() {
      _analyticsFuture = _loadAndRecordAnalytics();
    });
  }

  void _goHome() {
    Navigator.of(context).pop();
  }

  BatchItem? get _selectedBatchItem =>
      BatchStore.instance.findByName(_selectedBatch);

  ({String label, Color color}) _temperatureIndicator(
    double temperature,
    BatchTemperatureSettings settings,
  ) {
    if (temperature == 0) {
      return (label: 'No Data', color: const Color(0xFF64748B));
    }
    if (temperature < settings.minTemperature) {
      return (label: 'Low', color: const Color(0xFF2563EB));
    }
    if (temperature > settings.maxTemperature) {
      return (label: 'High', color: const Color(0xFFE53935));
    }
    return (label: 'Normal', color: const Color(0xFF16A34A));
  }

  Future<_AnalyticsData> _loadAndRecordAnalytics() async {
    final results = await Future.wait<dynamic>([
      EnvironmentalLogStore.instance.fetchRecentLogs(limit: 120),
      _safeLoadConfig(
        DeviceConfigStore.instance.loadWaterConfig(batchName: _selectedBatch),
      ),
      _safeLoadConfig(
        DeviceConfigStore.instance.loadFeederConfig(batchName: _selectedBatch),
      ),
      _safeLoadConfig(
        DeviceConfigStore.instance.loadVentilationConfig(
          batchName: _selectedBatch,
        ),
      ),
      _safeLoadConfig(
        DeviceConfigStore.instance.loadLightingConfig(
          batchName: _selectedBatch,
        ),
      ),
      _loadMortalityInsights(),
    ]);

    final logs = results[0] as List<EnvironmentalLog>;
    final waterConfig = results[1] as Map<String, dynamic>?;
    final feederConfig = results[2] as Map<String, dynamic>?;
    final ventilationConfig = results[3] as Map<String, dynamic>?;
    final lightingConfig = results[4] as Map<String, dynamic>?;
    final mortalityInsights = results[5] as _MortalityInsights;

    final data = _buildAnalytics(
      logs,
      waterConfig,
      feederConfig,
      ventilationConfig,
      lightingConfig,
      mortalityInsights,
    );
    await _recordAnalyticsSnapshot(data);
    return data;
  }

  _AnalyticsData _buildAnalytics(
    List<EnvironmentalLog> logs,
    Map<String, dynamic>? waterConfig,
    Map<String, dynamic>? feederConfig,
    Map<String, dynamic>? ventilationConfig,
    Map<String, dynamic>? lightingConfig,
    _MortalityInsights mortalityInsights,
  ) {
    final telemetry = MonitoringStore.instance.snapshotFor(_selectedBatch);
    final batchLogs = _logsForSelectedBatch(logs);
    final fifteenMinuteLogs = _averageLogsByFifteenMinutes(batchLogs);
    final latestLog = batchLogs.isEmpty ? null : batchLogs.last;
    final latestFifteenMinuteLog = fifteenMinuteLogs.isEmpty
        ? null
        : fifteenMinuteLogs.last;
    final temperatureChartLogs = fifteenMinuteLogs
        .where((log) => log.temperature > 0)
        .toList();
    final humidityChartLogs = fifteenMinuteLogs
        .where((log) => log.humidity > 0)
        .toList();
    final displayedAverageTemperature =
        latestFifteenMinuteLog?.temperature ??
        (telemetry.temperature > 0
        ? telemetry.temperature
        : latestLog?.temperature ?? 0.0);
    final displayedAverageHumidity =
        latestFifteenMinuteLog?.humidity ??
        (telemetry.humidity > 0
        ? telemetry.humidity
        : latestLog?.humidity ?? 0.0);

    final totalChickens = BatchStore.instance.totalBirdsFor(_selectedBatch);
    final mortalityCount = BatchStore.instance.mortalityCountFor(
      _selectedBatch,
    );
    final aliveChickens = (totalChickens - mortalityCount)
        .clamp(0, totalChickens)
        .toInt();
    final survivalRate = totalChickens == 0
        ? 0.0
        : (aliveChickens / totalChickens) * 100;

    final configuredWaterTankLevel = _readPercentValue(waterConfig, const [
      'tank_level',
      'water_level',
      'level_percent',
      'tank_level_percent',
    ]);
    final waterTankLevel = telemetry.isWaterLevelLive
        ? telemetry.waterLevelPercent
        : telemetry.waterLevelPercent > 0
        ? telemetry.waterLevelPercent
        : latestLog?.waterLevelPercent != null &&
              latestLog!.waterLevelPercent > 0
        ? latestLog.waterLevelPercent
        : configuredWaterTankLevel;
    final configuredFeederLevel = _readPercentValue(feederConfig, const [
      'feeder_level',
      'feed_level',
      'fill_level',
      'level_percent',
    ]);
    final feederLevel = telemetry.isFeederLevelLive
        ? telemetry.feederLevelPercent
        : telemetry.feederDistanceCm > 0
        ? telemetry.feederLevelPercent
        : configuredFeederLevel;

    final waterDeviceCount = _readDeviceCount(waterConfig);
    final feederDeviceCount = _readDeviceCount(feederConfig);
    final ventilationDeviceCount = _readDeviceCount(ventilationConfig);
    final lightingDeviceCount = _readDeviceCount(lightingConfig);
    final totalDeviceCount =
        waterDeviceCount +
        feederDeviceCount +
        ventilationDeviceCount +
        lightingDeviceCount;
    final activeSchedules =
        _countActiveSchedules(waterConfig) +
        _countActiveSchedules(feederConfig) +
        _countActiveSchedules(ventilationConfig) +
        _countActiveSchedules(lightingConfig);
    final deviceUsageItems = [
      ..._readDeviceUsageItems(
        waterConfig,
        category: 'Water',
        color: const Color(0xFF0284C7),
        icon: Icons.water_drop_outlined,
        includeGlobalSchedules: true,
      ),
      ..._readDeviceUsageItems(
        feederConfig,
        category: 'Feeder',
        color: const Color(0xFFB45309),
        icon: Icons.restaurant_outlined,
        includeGlobalSchedules: true,
      ),
      ..._readDeviceUsageItems(
        ventilationConfig,
        category: 'Ventilation',
        color: const Color(0xFF2E7D32),
        icon: Icons.air_rounded,
      ),
      ..._readDeviceUsageItems(
        lightingConfig,
        category: 'Lighting',
        color: const Color(0xFF8F7A3D),
        icon: Icons.lightbulb_outline_rounded,
      ),
    ];
    final enabledDeviceCount = deviceUsageItems
        .where((item) => item.enabled)
        .length;

    return _AnalyticsData(
      averageTemperature: displayedAverageTemperature,
      averageHumidity: displayedAverageHumidity,
      sensorLive: telemetry.isLive,
      waterSensorLive: telemetry.isWaterLevelLive,
      aliveChickens: aliveChickens,
      totalChickens: totalChickens,
      mortalityCount: mortalityCount,
      survivalRate: survivalRate,
      waterTankLevel: waterTankLevel,
      feederLevel: feederLevel,
      waterDeviceCount: waterDeviceCount,
      feederDeviceCount: feederDeviceCount,
      ventilationDeviceCount: ventilationDeviceCount,
      lightingDeviceCount: lightingDeviceCount,
      totalDeviceCount: totalDeviceCount,
      enabledDeviceCount: enabledDeviceCount,
      activeSchedules: activeSchedules,
      deviceUsageItems: deviceUsageItems,
      logs: fifteenMinuteLogs,
      temperatureChartLogs: temperatureChartLogs.takeLast(12),
      humidityChartLogs: humidityChartLogs.takeLast(16),
      mortalityReasonCounts: mortalityInsights.reasonCounts,
      mortalityIntervalCounts: mortalityInsights.intervalCounts,
    );
  }

  List<EnvironmentalLog> _logsForSelectedBatch(List<EnvironmentalLog> logs) {
    final batch = BatchStore.instance.findByName(_selectedBatch);
    if (batch == null) {
      return logs;
    }

    final batchKeys = <String>{
      batch.stableId,
      batch.name,
      _safeKey(batch.name),
      if (_batches.isNotEmpty && _selectedBatch == _batches.first)
        'default_batch',
    };

    final filtered = logs.where((log) {
      final logKey = _safeKey(log.batchId);
      return batchKeys.contains(log.batchId) || batchKeys.contains(logKey);
    }).toList();

    if (filtered.isEmpty && BatchStore.instance.batches.length == 1) {
      return logs;
    }

    return filtered;
  }

  List<EnvironmentalLog> _averageLogsByFifteenMinutes(
    List<EnvironmentalLog> logs,
  ) {
    if (logs.isEmpty) {
      return const [];
    }

    final buckets = <DateTime, List<EnvironmentalLog>>{};
    for (final log in logs) {
      if (log.temperature <= 0 || log.humidity <= 0) {
        continue;
      }
      final time = log.recordedAt;
      final bucketStart = DateTime(
        time.year,
        time.month,
        time.day,
        time.hour,
        (time.minute ~/ 15) * 15,
      );
      buckets.putIfAbsent(bucketStart, () => []).add(log);
    }

    final averages = buckets.entries.map((entry) {
      final bucketLogs = entry.value;
      final temperature =
          bucketLogs.fold<double>(0, (sum, log) => sum + log.temperature) /
          bucketLogs.length;
      final humidity =
          bucketLogs.fold<double>(0, (sum, log) => sum + log.humidity) /
          bucketLogs.length;
      final latestLog = bucketLogs.reduce(
        (current, next) =>
            next.recordedAt.isAfter(current.recordedAt) ? next : current,
      );

      return EnvironmentalLog(
        id: 'avg15_${entry.key.millisecondsSinceEpoch}',
        batchId: latestLog.batchId,
        deviceId: latestLog.deviceId,
        temperature: double.parse(temperature.toStringAsFixed(1)),
        humidity: double.parse(humidity.toStringAsFixed(0)),
        waterLevelPercent: latestLog.waterLevelPercent,
        waterDistanceCm: latestLog.waterDistanceCm,
        feederLevelPercent: latestLog.feederLevelPercent,
        feederDistanceCm: latestLog.feederDistanceCm,
        recordedAt: latestLog.recordedAt.toLocal(),
      );
    }).toList();

    averages.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return averages;
  }

  Future<void> _recordAnalyticsSnapshot(_AnalyticsData data) async {
    final user = AuthStore.instance.currentUser;
    if (user == null ||
        (data.averageTemperature <= 0 &&
            data.averageHumidity <= 0 &&
            data.waterTankLevel == null)) {
      return;
    }

    final batchKey = _safeKey(_selectedBatch);
    final latestPath =
        'user_data/${user.id}/latest_analytics_by_batch/$batchKey.json';
    final database = FirebaseDatabaseService.instance;
    final previous = await database.get(latestPath);
    if (previous is Map<String, dynamic>) {
      final previousRecordedAt = _tryReadDate(previous['recorded_at']);
      if (previousRecordedAt != null &&
          DateTime.now().difference(previousRecordedAt) <
              const Duration(minutes: 15)) {
        return;
      }
    }

    final payload = {
      'batch_name': _selectedBatch,
      'average_temperature': double.parse(
        data.averageTemperature.toStringAsFixed(1),
      ),
      'average_humidity': double.parse(data.averageHumidity.toStringAsFixed(0)),
      'total_chickens': data.totalChickens,
      'mortality_count': data.mortalityCount,
      'alive_chickens': data.aliveChickens,
      'survival_rate': double.parse(data.survivalRate.toStringAsFixed(1)),
      'water_tank_level': data.waterTankLevel,
      'feeder_level': data.feederLevel,
      'water_device_count': data.waterDeviceCount,
      'feeder_device_count': data.feederDeviceCount,
      'ventilation_device_count': data.ventilationDeviceCount,
      'lighting_device_count': data.lightingDeviceCount,
      'total_device_count': data.totalDeviceCount,
      'active_schedule_count': data.activeSchedules,
      'environmental_log_count': data.logs.length,
      'recorded_at': {'.sv': 'timestamp'},
    };

    await database.put(latestPath, payload);
    await database.post(
      'user_data/${user.id}/analytics_snapshots.json',
      payload,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF4F7F3),
      body: SplashBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _Header(onProfile: () => ProfileScreen.show(context)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    MonitoringStore.instance,
                    TemperatureSettingsStore.instance,
                  ]),
                  builder: (context, _) {
                    return FutureBuilder<_AnalyticsData>(
                      future: _analyticsFuture,
                      builder: (context, snapshot) {
                        final isLoading =
                            snapshot.connectionState == ConnectionState.waiting;
                        final data =
                            snapshot.data ??
                            _buildAnalytics(
                              const [],
                              null,
                              null,
                              null,
                              null,
                              const _MortalityInsights.empty(),
                            );
                        final telemetry = MonitoringStore.instance.snapshotFor(
                          _selectedBatch,
                        );
                        final logs = data.logs;
                        final displayedTemperature = data.averageTemperature;
                        final displayedHumidity = data.averageHumidity;
                        final displayedWaterLevel = telemetry.isWaterLevelLive
                            ? telemetry.waterLevelPercent
                            : data.waterTankLevel;
                        final displayedFeederLevel =
                            telemetry.isFeederLevelLive
                            ? telemetry.feederLevelPercent
                            : data.feederLevel;
                        final temperatureSettings =
                            TemperatureSettingsStore.instance.settingsFor(
                              _selectedBatch,
                            );
                        final temperatureIndicator = _temperatureIndicator(
                          displayedTemperature,
                          temperatureSettings,
                        );
                        final selectedBatchItem = _selectedBatchItem;
                        final sensorNotices = <_SensorNotice>[
                          if (!isLoading &&
                              !telemetry.isLive)
                            _SensorNotice(
                              text: displayedTemperature > 0 ||
                                      displayedHumidity > 0
                                  ? 'Environmental sensors are offline. Showing the last recorded values.'
                                  : 'Environmental sensors are offline. No recent readings available.',
                              icon: Icons.sensors_off_outlined,
                            ),
                          if (!isLoading &&
                              !telemetry.isWaterLevelLive)
                            _SensorNotice(
                              text: displayedWaterLevel != null
                                  ? 'Water sensor is offline. Showing the last recorded level.'
                                  : 'Water sensor is offline. No recent level available.',
                              icon: Icons.water_drop_outlined,
                            ),
                          if (!isLoading &&
                              !telemetry.isFeederLevelLive)
                            _SensorNotice(
                              text: displayedFeederLevel != null
                                  ? 'Feeder sensor is offline. Showing the last recorded level.'
                                  : 'Feeder sensor is offline. No recent level available.',
                              icon: Icons.restaurant_outlined,
                            ),
                        ];

                        return RefreshIndicator(
                          onRefresh: () async => _refreshLogs(),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedBatch.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF58705A),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _refreshLogs,
                                    style: IconButton.styleFrom(
                                      hoverColor: const Color(0xFF0BB13F)
                                          .withOpacity(0.08),
                                      highlightColor: const Color(0xFF0BB13F)
                                          .withOpacity(0.12),
                                    ),
                                    icon: const Icon(Icons.refresh_rounded),
                                    color: const Color(0xFF2E7D32),
                                  ),
                                  if (_batches.isNotEmpty) _batchDropdown(),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (selectedBatchItem != null) ...[
                                _BatchCycleStrip(
                                  batch: selectedBatchItem,
                                  sensorNotices: sensorNotices,
                                ),
                                const SizedBox(height: 14),
                              ] else
                                const SizedBox(height: 14),
                              if (snapshot.hasError)
                                const _StatusBanner(
                                  text:
                                      'Could not load every analytics source. Showing the latest available values.',
                                  icon: Icons.cloud_off_outlined,
                                )
                              else if (isLoading)
                                const _StatusBanner(
                                  text: 'Loading Firebase analytics...',
                                  icon: Icons.cloud_sync_outlined,
                                )
                              else if (logs.isEmpty)
                                const _StatusBanner(
                                  text:
                                      'No environmental logs yet for this batch. Keep the ESP32 online to build analytics history.',
                                  icon: Icons.history_rounded,
                                ),
                              if (snapshot.hasError ||
                                  isLoading ||
                                  logs.isEmpty)
                                const SizedBox(height: 12),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 148,
                                children: [
                                  _MetricCard(
                                    icon: Icons.thermostat_outlined,
                                    iconColor: temperatureIndicator.color,
                                    trend: telemetry.isLive
                                        ? temperatureIndicator.label
                                        : displayedTemperature > 0
                                        ? 'Offline'
                                        : 'No data',
                                    trendColor: telemetry.isLive
                                        ? temperatureIndicator.color
                                        : const Color(0xFF64748B),
                                    value:
                                        '${displayedTemperature.toStringAsFixed(1)}\u00B0C',
                                    label: 'Temperature',
                                  ),
                                  _MetricCard(
                                    icon: Icons.water_drop_outlined,
                                    iconColor: const Color(0xFF3D7BFF),
                                    trend: telemetry.isLive
                                        ? 'Live sensor'
                                        : displayedHumidity > 0
                                        ? 'Offline'
                                        : 'No data',
                                    trendColor: telemetry.isLive
                                        ? const Color(0xFF3D7BFF)
                                        : const Color(0xFF64748B),
                                    value:
                                        '${displayedHumidity.toStringAsFixed(0)}%',
                                    label: 'Humidity',
                                  ),
                                  _MetricCard(
                                    icon: Icons.water_drop_outlined,
                                    iconColor: const Color(0xFF0284C7),
                                    trend: telemetry.isWaterLevelLive
                                        ? 'Live sensor'
                                        : displayedWaterLevel != null
                                        ? 'Offline'
                                        : data.waterDeviceCount > 0
                                        ? 'Empty'
                                        : 'No sensor',
                                    trendColor: telemetry.isWaterLevelLive
                                        ? const Color(0xFF0284C7)
                                        : const Color(0xFF64748B),
                                    value: displayedWaterLevel != null
                                        ? '${displayedWaterLevel.toStringAsFixed(0)}%'
                                        : '0%',
                                    label: 'Water Tank Level',
                                  ),
                                  _MetricCard(
                                    icon: Icons.restaurant_outlined,
                                    iconColor: const Color(0xFFB45309),
                                    trend: telemetry.isFeederLevelLive
                                        ? 'Live sensor'
                                        : displayedFeederLevel != null
                                        ? 'Offline'
                                        : data.feederDeviceCount > 0
                                        ? 'Empty'
                                        : 'No sensor',
                                    trendColor: telemetry.isFeederLevelLive
                                        ? const Color(0xFFB45309)
                                        : const Color(0xFF64748B),
                                    value: displayedFeederLevel != null
                                        ? '${displayedFeederLevel.toStringAsFixed(0)}%'
                                        : '0%',
                                    label: 'Feeder Level',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const _SectionLabel('TEMPERATURE TRENDS'),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  18,
                                  14,
                                  12,
                                ),
                                decoration: _panelDecoration(),
                                child: _TemperatureChart(
                                  logs: data.temperatureChartLogs,
                                  settings: temperatureSettings,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const _SectionLabel('HUMIDITY TRENDS'),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: _panelDecoration(),
                                child: _HumidityTrendsPanel(data: data),
                              ),
                              const SizedBox(height: 18),
                              const _SectionLabel('MORTALITY ANALYSIS'),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: _panelDecoration(),
                                child: _MortalityAnalysisPanel(data: data),
                              ),
                              const SizedBox(height: 18),
                              const _SectionLabel('DEVICE USAGE ANALYTICS'),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: _panelDecoration(),
                                child: _DeviceUsageAnalyticsPanel(data: data),
                              ),
                              const SizedBox(height: 18),
                              const _SectionLabel('ENVIRONMENTAL LOGS'),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: _panelDecoration(),
                                child: _EnvironmentalLogsPanel(
                                  logs: logs,
                                  selectedDayKey: _selectedEnvironmentalLogDay,
                                  onSelectedDayChanged: (value) {
                                    setState(() {
                                      _selectedEnvironmentalLogDay = value;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 120),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
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
            color: Colors.white.withOpacity(0.68),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.74)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF18321C).withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
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
                onTap: _goHome,
              ),
              _BottomNavItem(
                icon: Icons.show_chart_rounded,
                label: 'Analytics',
                selected: _selectedNavIndex == 1,
                onTap: () => setState(() => _selectedNavIndex = 1),
              ),
              _BottomNavItem(
                icon: Icons.description_outlined,
                label: 'Reports',
                selected: _selectedNavIndex == 2,
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ReportsScreen(
                        initialBatchName: _selectedBatch,
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

  Widget _batchDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E9E4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBatch,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: _batches
              .map(
                (batch) => DropdownMenuItem<String>(
                  value: batch,
                  child: Text(
                    batch,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF26412C),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              TemperatureSettingsStore.instance.loadFor(value);
              setState(() {
                _selectedBatch = value;
                _analyticsFuture = _loadAndRecordAnalytics();
              });
            }
          },
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE3E9E4)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  double? _readPercentValue(
    Map<String, dynamic>? json,
    List<String> candidateKeys,
  ) {
    if (json == null) {
      return null;
    }

    for (final key in candidateKeys) {
      final value = json[key];
      if (value is num) {
        return value.toDouble().clamp(0, 100).toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed.clamp(0, 100).toDouble();
        }
      }
    }

    return null;
  }

  int _readDeviceCount(Map<String, dynamic>? json) {
    if (json == null) {
      return 0;
    }

    final devices = json['devices'];
    if (devices is List<dynamic>) {
      return devices.length;
    }

    return 0;
  }

  int _countActiveSchedules(Map<String, dynamic>? json) {
    if (json == null) {
      return 0;
    }

    final labels = <String>[
      ...(json['global_schedules'] as List<dynamic>? ?? const []).map(
        (value) => value.toString(),
      ),
    ];

    final rawDeviceSchedules = json['device_schedules'];
    if (rawDeviceSchedules is Map<String, dynamic>) {
      for (final schedules in rawDeviceSchedules.values) {
        final entries = schedules as List<dynamic>? ?? const [];
        labels.addAll(entries.map((value) => value.toString()));
      }
    }

    return _countActiveScheduleLabels(labels);
  }

  List<_DeviceUsageItem> _readDeviceUsageItems(
    Map<String, dynamic>? json, {
    required String category,
    required Color color,
    required IconData icon,
    bool includeGlobalSchedules = false,
  }) {
    if (json == null) {
      return const [];
    }

    final globalScheduleCount = includeGlobalSchedules
        ? _countActiveScheduleLabels(
            (json['global_schedules'] as List<dynamic>? ?? const []).map(
              (value) => value.toString(),
            ),
          )
        : 0;
    final scheduleCounts = <String, int>{};
    final rawDeviceSchedules = json['device_schedules'];
    if (rawDeviceSchedules is Map<String, dynamic>) {
      for (final entry in rawDeviceSchedules.entries) {
        final schedules = (entry.value as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
        scheduleCounts[entry.key] =
            _countActiveScheduleLabels(schedules) + globalScheduleCount;
      }
    }

    final devices = json['devices'];
    if (devices is! List<dynamic>) {
      return const [];
    }

    return devices.whereType<Map<String, dynamic>>().map((device) {
      final id = device['id']?.toString().trim() ?? '';
      final name = device['name']?.toString().trim() ?? '';
      final description = device['description']?.toString().trim() ?? '';
      final enabled = device['enabled'] == true;
      final scheduleCount = scheduleCounts[id] ?? globalScheduleCount;
      return _DeviceUsageItem(
        category: category,
        name: name.isEmpty ? '$category Device' : name,
        id: id.isEmpty ? 'No ID' : id,
        description: description,
        enabled: enabled,
        scheduleCount: scheduleCount,
        color: color,
        icon: icon,
      );
    }).toList();
  }

  int _countActiveScheduleLabels(Iterable<String> labels) {
    return labels.where(_isActiveScheduleLabel).length;
  }

  bool _isActiveScheduleLabel(String label) {
    final normalized = label.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final parts = normalized
        .split('-')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty || !_looksLikeTimeLabel(parts.first)) {
      return false;
    }

    return parts.any((part) => part.toLowerCase() == 'active');
  }

  bool _looksLikeTimeLabel(String label) {
    return RegExp(r'^[0-9]{1,2}:[0-9]{2}\s*[APap][Mm]$').hasMatch(label);
  }

  String _safeKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<Map<String, dynamic>?> _safeLoadConfig(
    Future<Map<String, dynamic>?> future,
  ) async {
    try {
      return await future;
    } on Object {
      return null;
    }
  }

  Future<_MortalityInsights> _loadMortalityInsights() async {
    final user = AuthStore.instance.currentUser;
    final batch = BatchStore.instance.findByName(_selectedBatch);
    if (user == null || batch == null) {
      return const _MortalityInsights.empty();
    }

    final path =
        'user_data/${user.id}/mortality_records/${batch.stableId}.json';
    try {
      final response = await FirebaseDatabaseService.instance.get(path);
      if (response is! Map<String, dynamic>) {
        return const _MortalityInsights.empty();
      }

      final totals = <String, int>{};
      final intervals = List<int>.filled(7, 0);
      for (final value in response.values) {
        if (value is! Map<String, dynamic>) {
          continue;
        }
        final deaths = _readInt(value['deaths']);
        if (deaths <= 0) {
          continue;
        }
        final rawReason = value['note']?.toString().trim() ?? '';
        final reason = rawReason.isEmpty ? 'Unspecified' : rawReason;
        totals.update(
          reason,
          (current) => current + deaths,
          ifAbsent: () => deaths,
        );
        final recordedAt = _readDate(value['recorded_at'] ?? value['date']);
        final intervalIndex = ((recordedAt.hour - 6) / 2).floor();
        if (intervalIndex >= 0 && intervalIndex < intervals.length) {
          intervals[intervalIndex] += deaths;
        }
      }
      return _MortalityInsights(
        reasonCounts: totals,
        intervalCounts: intervals,
      );
    } on Object {
      return const _MortalityInsights.empty();
    }
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  DateTime _readDate(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  DateTime? _tryReadDate(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class _AnalyticsData {
  final double averageTemperature;
  final double averageHumidity;
  final bool sensorLive;
  final bool waterSensorLive;
  final int aliveChickens;
  final int totalChickens;
  final int mortalityCount;
  final double survivalRate;
  final double? waterTankLevel;
  final double? feederLevel;
  final int waterDeviceCount;
  final int feederDeviceCount;
  final int ventilationDeviceCount;
  final int lightingDeviceCount;
  final int totalDeviceCount;
  final int enabledDeviceCount;
  final int activeSchedules;
  final List<_DeviceUsageItem> deviceUsageItems;
  final List<EnvironmentalLog> logs;
  final List<EnvironmentalLog> temperatureChartLogs;
  final List<EnvironmentalLog> humidityChartLogs;
  final Map<String, int> mortalityReasonCounts;
  final List<int> mortalityIntervalCounts;

  const _AnalyticsData({
    required this.averageTemperature,
    required this.averageHumidity,
    required this.sensorLive,
    required this.waterSensorLive,
    required this.aliveChickens,
    required this.totalChickens,
    required this.mortalityCount,
    required this.survivalRate,
    required this.waterTankLevel,
    required this.feederLevel,
    required this.waterDeviceCount,
    required this.feederDeviceCount,
    required this.ventilationDeviceCount,
    required this.lightingDeviceCount,
    required this.totalDeviceCount,
    required this.enabledDeviceCount,
    required this.activeSchedules,
    required this.deviceUsageItems,
    required this.logs,
    required this.temperatureChartLogs,
    required this.humidityChartLogs,
    required this.mortalityReasonCounts,
    required this.mortalityIntervalCounts,
  });

  double get mortalityRate =>
      totalChickens == 0 ? 0.0 : (mortalityCount / totalChickens) * 100;
}

class _MortalityInsights {
  final Map<String, int> reasonCounts;
  final List<int> intervalCounts;

  const _MortalityInsights({
    required this.reasonCounts,
    required this.intervalCounts,
  });

  const _MortalityInsights.empty()
    : reasonCounts = const {},
      intervalCounts = const [0, 0, 0, 0, 0, 0, 0];
}

class _DeviceUsageItem {
  final String category;
  final String name;
  final String id;
  final String description;
  final bool enabled;
  final int scheduleCount;
  final Color color;
  final IconData icon;

  const _DeviceUsageItem({
    required this.category,
    required this.name,
    required this.id,
    required this.description,
    required this.enabled,
    required this.scheduleCount,
    required this.color,
    required this.icon,
  });
}

class _Header extends StatelessWidget {
  final VoidCallback onProfile;

  const _Header({required this.onProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F6F2F), Color(0xFF47A34A)],
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
                  'Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Firebase environmental logs every 15 minutes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onProfile,
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
                    AuthStore.instance.currentUser?.profilePhotoBase64 ?? '',
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
    );
  }
}

class _BatchCycleStrip extends StatelessWidget {
  final BatchItem batch;
  final List<_SensorNotice> sensorNotices;

  const _BatchCycleStrip({
    required this.batch,
    required this.sensorNotices,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sensorNotices.isNotEmpty) ...[
            _SensorNotificationButton(notices: sensorNotices),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: _BatchCycleChip(
              icon: Icons.event_available_outlined,
              label: batch.startedAt,
              centerContent: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: _BatchCycleChip(
              icon: Icons.calendar_today_outlined,
              label: batch.dayLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchCycleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool centerContent;

  const _BatchCycleChip({
    required this.icon,
    required this.label,
    this.centerContent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE6EE)),
      ),
      child: Row(
        mainAxisAlignment:
            centerContent ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6F7D90)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF526173),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorNotice {
  final String text;
  final IconData icon;

  const _SensorNotice({required this.text, required this.icon});
}

class _SensorNotificationButton extends StatelessWidget {
  final List<_SensorNotice> notices;

  const _SensorNotificationButton({required this.notices});

  void _showNotices(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SplashBackground(
            child: _SensorNoticeDialog(notices: notices),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showNotices(context),
        borderRadius: BorderRadius.circular(12),
        splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
        highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
        hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
        child: Ink(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE6ECF2)),
          ),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: Color(0xFF2E7D32),
                  size: 19,
                ),
                Positioned(
                  right: -7,
                  top: -7,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2453D),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '${notices.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
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

class _SensorNoticeDialog extends StatelessWidget {
  final List<_SensorNotice> notices;

  const _SensorNoticeDialog({required this.notices});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF2E7D32),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Sensor notifications',
                      style: TextStyle(
                        color: Color(0xFF1F2D21),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
                      highlightColor: const Color(0xFF0BB13F).withOpacity(0.12),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF516154),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final notice in notices) ...[
                _SensorNoticeTile(notice: notice),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SensorNoticeTile extends StatelessWidget {
  final _SensorNotice notice;

  const _SensorNoticeTile({required this.notice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBF6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCEBDD)),
      ),
      child: Row(
        children: [
          Icon(notice.icon, color: const Color(0xFF2E7D32), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notice.text,
              style: const TextStyle(
                color: Color(0xFF405142),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String text;
  final IconData icon;

  const _StatusBanner({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBF6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCEBDD)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2E7D32), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF405142),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Color(0xFF58705A),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String trend;
  final Color trendColor;
  final String value;
  final String label;
  final Color backgroundColor;
  final Color borderColor;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.trend,
    required this.trendColor,
    required this.value,
    required this.label,
    Color? backgroundColor,
    Color? borderColor,
  }) : backgroundColor = backgroundColor ?? const Color(0xFFFFFFFF),
       borderColor = borderColor ?? const Color(0xFFE3E9E4);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: trendColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: trendColor.withOpacity(0.18)),
                    ),
                    child: Text(
                      trend,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: trendColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemperatureChart extends StatelessWidget {
  final List<EnvironmentalLog> logs;
  final BatchTemperatureSettings settings;

  const _TemperatureChart({
    required this.logs,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final points = logs
        .map(
          (log) => _TrendPoint(
            value: log.temperature,
            recordedAt: log.recordedAt,
          ),
        )
        .toList();
    final values = points.map((point) => point.value).toList();
    final latestValue = values.isEmpty ? 0.0 : values.last;
    final averageValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a + b) / values.length;
    final scale = _TrendScale.temperature(values);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightTile(
                label: 'Latest',
                value: '${latestValue.toStringAsFixed(1)}\u00B0C',
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightTile(
                label: 'Average',
                value: '${averageValue.toStringAsFixed(1)}\u00B0C',
                color: const Color(0xFF5C6BC0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightTile(
                label: 'Target',
                value:
                    '${_formatTargetTemperature(settings.minTemperature)}-'
                    '${_formatTargetTemperature(settings.maxTemperature)}\u00B0C',
                color: const Color(0xFFB58F2A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _InteractiveTrendChart(
          points: points,
          scale: scale,
          unit: '\u00B0C',
          emptyText: 'Waiting for temperature history',
          minimumTarget: settings.minTemperature,
          maximumTarget: settings.maxTemperature,
          targetLabel: 'Configured target',
        ),
      ],
    );
  }

  String _formatTargetTemperature(double value) {
    return value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

class _HumidityTrendsPanel extends StatelessWidget {
  final _AnalyticsData data;

  const _HumidityTrendsPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final points = data.humidityChartLogs
        .map(
          (log) =>
              _TrendPoint(value: log.humidity, recordedAt: log.recordedAt),
        )
        .toList();
    final values = points.map((point) => point.value).toList();
    final minValue = values.isEmpty ? 0.0 : values.reduce(math.min);
    final maxValue = values.isEmpty ? 0.0 : values.reduce(math.max);
    final latestValue = values.isEmpty ? 0.0 : values.last;
    final averageValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a + b) / values.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightTile(
                label: 'Latest',
                value: '${latestValue.toStringAsFixed(0)}%',
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightTile(
                label: 'Average',
                value: '${averageValue.toStringAsFixed(0)}%',
                color: const Color(0xFF2F7F77),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightTile(
                label: 'Observed Range',
                value: values.isEmpty
                    ? '--'
                    : values.length == 1
                    ? '${latestValue.toStringAsFixed(0)}%'
                    : '${minValue.toStringAsFixed(0)}-${maxValue.toStringAsFixed(0)}%',
                color: const Color(0xFF8F7A3D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _InteractiveTrendChart(
          points: points,
          scale: _TrendScale.humidity(values),
          unit: '%',
          emptyText: 'Waiting for humidity history',
        ),
      ],
    );
  }
}

class _MortalityAnalysisPanel extends StatelessWidget {
  final _AnalyticsData data;

  const _MortalityAnalysisPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightTile(
                label: 'Total Flock',
                value: data.totalChickens.toString(),
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightTile(
                label: 'Mortality',
                value: data.mortalityCount.toString(),
                color: const Color(0xFF9C6B35),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightTile(
                label: 'Survival Rate',
                value: '${data.survivalRate.toStringAsFixed(1)}%',
                color: const Color(0xFF2F7F77),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _MortalityReasonChart(
          reasons: data.mortalityReasonCounts,
          totalDeaths: data.mortalityCount,
        ),
      ],
    );
  }
}

class _DeviceUsageAnalyticsPanel extends StatefulWidget {
  final _AnalyticsData data;

  const _DeviceUsageAnalyticsPanel({required this.data});

  @override
  State<_DeviceUsageAnalyticsPanel> createState() =>
      _DeviceUsageAnalyticsPanelState();
}

class _DeviceUsageAnalyticsPanelState
    extends State<_DeviceUsageAnalyticsPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems = <String, List<_DeviceUsageItem>>{};
    for (final item in widget.data.deviceUsageItems) {
      groupedItems
          .putIfAbsent(item.category, () => <_DeviceUsageItem>[])
          .add(item);
    }
    for (final items in groupedItems.values) {
      items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    final categorySummaries = [
      _DeviceCategorySummary(
        label: 'Water',
        count: groupedItems['Water']?.length ?? 0,
        color: const Color(0xFF0284C7),
        icon: Icons.water_drop_outlined,
      ),
      _DeviceCategorySummary(
        label: 'Feeder',
        count: groupedItems['Feeder']?.length ?? 0,
        color: const Color(0xFFB45309),
        icon: Icons.restaurant_outlined,
      ),
      _DeviceCategorySummary(
        label: 'Ventilation',
        count: groupedItems['Ventilation']?.length ?? 0,
        color: const Color(0xFF2E7D32),
        icon: Icons.air_rounded,
      ),
      _DeviceCategorySummary(
        label: 'Lighting',
        count: groupedItems['Lighting']?.length ?? 0,
        color: const Color(0xFF8F7A3D),
        icon: Icons.lightbulb_outline_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _InsightTile(
                label: 'Saved Devices',
                value: widget.data.totalDeviceCount.toString(),
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightTile(
                label: 'Enabled',
                value: widget.data.enabledDeviceCount.toString(),
                color: const Color(0xFF2F7F77),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightTile(
                label: 'Schedules',
                value: widget.data.activeSchedules.toString(),
                color: const Color(0xFF8F7A3D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 78,
          children: [
            for (final summary in categorySummaries)
              _DeviceCategorySummaryTile(summary: summary),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.data.deviceUsageItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FAF7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDCE9DD)),
            ),
            child: const Text(
              'No saved devices from Controls yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8D98B2),
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF6FAF7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDCE9DD)),
            ),
            child: SizedBox(
              height: 280,
              child: RawScrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                radius: const Radius.circular(999),
                thickness: 6,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: categorySummaries
                      .where((summary) => summary.count > 0)
                      .length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final visibleSummaries = categorySummaries
                        .where((summary) => summary.count > 0)
                        .toList();
                    final summary = visibleSummaries[index];
                    return _DeviceUsageGroupCard(
                      items: groupedItems[summary.label] ?? const [],
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TrendPoint {
  final double value;
  final DateTime recordedAt;

  const _TrendPoint({required this.value, required this.recordedAt});
}

class _TrendScale {
  final double minimum;
  final double maximum;
  final double step;

  const _TrendScale({
    required this.minimum,
    required this.maximum,
    required this.step,
  });

  List<double> get labels => List<double>.generate(
    ((maximum - minimum) / step).round() + 1,
    (index) => maximum - (index * step),
  );

  factory _TrendScale.temperature(List<double> values) {
    if (values.isEmpty) {
      return const _TrendScale(minimum: 28, maximum: 34, step: 1);
    }
    final rawMinimum = values.reduce(math.min).floorToDouble();
    var rawMaximum = values.reduce(math.max).ceilToDouble() + 1;
    if (rawMaximum - rawMinimum < 3) {
      rawMaximum = rawMinimum + 3;
    }
    final range = rawMaximum - rawMinimum;
    final step = range <= 5
        ? 1.0
        : range <= 10
        ? 2.0
        : range <= 20
        ? 5.0
        : 10.0;
    return _TrendScale(
      minimum: (rawMinimum / step).floorToDouble() * step,
      maximum: (rawMaximum / step).ceilToDouble() * step,
      step: step,
    );
  }

  factory _TrendScale.humidity(List<double> values) {
    if (values.isEmpty) {
      return const _TrendScale(minimum: 60, maximum: 80, step: 5);
    }
    var rawMinimum = values.reduce(math.min).floorToDouble() - 1;
    var rawMaximum = values.reduce(math.max).ceilToDouble() + 1;
    if (rawMaximum - rawMinimum < 4) {
      final midpoint = (rawMinimum + rawMaximum) / 2;
      rawMinimum = midpoint.floorToDouble() - 2;
      rawMaximum = rawMinimum + 4;
    }
    final range = rawMaximum - rawMinimum;
    final step = range <= 6
        ? 1.0
        : range <= 12
        ? 2.0
        : range <= 25
        ? 5.0
        : 10.0;
    return _TrendScale(
      minimum: math
          .max(0.0, (rawMinimum / step).floorToDouble() * step)
          .toDouble(),
      maximum: math
          .min(100.0, (rawMaximum / step).ceilToDouble() * step)
          .toDouble(),
      step: step,
    );
  }
}

class _InteractiveTrendChart extends StatefulWidget {
  final List<_TrendPoint> points;
  final _TrendScale scale;
  final String unit;
  final String emptyText;
  final double? minimumTarget;
  final double? maximumTarget;
  final String? targetLabel;

  const _InteractiveTrendChart({
    required this.points,
    required this.scale,
    required this.unit,
    required this.emptyText,
    this.minimumTarget,
    this.maximumTarget,
    this.targetLabel,
  });

  @override
  State<_InteractiveTrendChart> createState() =>
      _InteractiveTrendChartState();
}

class _InteractiveTrendChartState extends State<_InteractiveTrendChart> {
  int? _selectedIndex;

  static const Duration _gapThreshold = Duration(minutes: 25);

  @override
  void didUpdateWidget(covariant _InteractiveTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex != null &&
        _selectedIndex! >= widget.points.length) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            widget.emptyText,
            style: const TextStyle(
              color: Color(0xFF8D98B2),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final labels = widget.scale.labels;
    final gapCount = _countGaps(widget.points);
    final latest = widget.points.last.recordedAt;

    return Container(
      height: 270,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E4D8)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: labels
                        .map(
                          (value) => Text(
                            _axisLabel(value),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF7B8794),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final selectedIndex = _selectedIndex;
                            final selectedPoint = selectedIndex == null
                                ? null
                                : widget.points[selectedIndex];
                            final selectedOffset = selectedIndex == null
                                ? null
                                : _offsetFor(
                                    selectedIndex,
                                    constraints.biggest,
                                  );
                            final maximumTooltipLeft = math.max(
                              0.0,
                              constraints.maxWidth - 124,
                            );
                            final maximumTooltipTop = math.max(
                              0.0,
                              constraints.maxHeight - 48,
                            );

                            return MouseRegion(
                              cursor: SystemMouseCursors.precise,
                              onHover: (event) => _selectNearest(
                                event.localPosition.dx,
                                constraints.maxWidth,
                              ),
                              onExit: (_) {
                                if (_selectedIndex != null) {
                                  setState(() => _selectedIndex = null);
                                }
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) => _selectNearest(
                                  details.localPosition.dx,
                                  constraints.maxWidth,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _TrendLinePainter(
                                          points: widget.points,
                                          scale: widget.scale,
                                          gapThreshold: _gapThreshold,
                                          minimumTarget: widget.minimumTarget,
                                          maximumTarget: widget.maximumTarget,
                                          selectedIndex: selectedIndex,
                                        ),
                                      ),
                                    ),
                                    if (selectedPoint != null &&
                                        selectedOffset != null)
                                      Positioned(
                                        left: (selectedOffset.dx - 62)
                                            .clamp(0.0, maximumTooltipLeft)
                                            .toDouble(),
                                        top: (selectedOffset.dy - 54)
                                            .clamp(0.0, maximumTooltipTop)
                                            .toDouble(),
                                        child: _TrendTooltip(
                                          point: selectedPoint,
                                          unit: widget.unit,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      _TrendTimeAxis(points: widget.points),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 6,
            children: [
              const _ChartDotLegend(
                label: 'Recorded',
                color: Color(0xFF2E7D32),
              ),
              if (widget.targetLabel != null)
                _ChartDotLegend(
                  label: widget.targetLabel!,
                  color: const Color(0xFFB8D8BE),
                ),
              _ChartMetadata(
                icon: Icons.data_usage_rounded,
                text:
                    '${widget.points.length} record${widget.points.length == 1 ? '' : 's'}',
              ),
              _ChartMetadata(
                icon: Icons.schedule_rounded,
                text: 'Updated ${DateFormat('MMM d, h:mm a').format(latest)}',
              ),
              if (gapCount > 0)
                _ChartMetadata(
                  icon: Icons.link_off_rounded,
                  text: '$gapCount data gap${gapCount == 1 ? '' : 's'}',
                  color: const Color(0xFFB45309),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _axisLabel(double value) {
    final suffix = widget.unit == '%' ? '%' : '\u00B0';
    return '${value.toStringAsFixed(0)}$suffix';
  }

  void _selectNearest(double localX, double width) {
    if (widget.points.isEmpty || width <= 0) {
      return;
    }
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < widget.points.length; index++) {
      final distance = (_xFor(index, width) - localX).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    if (_selectedIndex != nearestIndex) {
      setState(() => _selectedIndex = nearestIndex);
    }
  }

  Offset _offsetFor(int index, Size size) {
    final normalized =
        ((widget.points[index].value - widget.scale.minimum) /
                (widget.scale.maximum - widget.scale.minimum))
            .clamp(0.0, 1.0)
            .toDouble();
    return Offset(_xFor(index, size.width), (1 - normalized) * size.height);
  }

  double _xFor(int index, double width) {
    if (widget.points.length == 1) {
      return width / 2;
    }
    return width * (index / (widget.points.length - 1));
  }

  int _countGaps(List<_TrendPoint> points) {
    var count = 0;
    for (var index = 1; index < points.length; index++) {
      if (points[index].recordedAt.difference(points[index - 1].recordedAt) >
          _gapThreshold) {
        count++;
      }
    }
    return count;
  }
}

class _TrendTooltip extends StatelessWidget {
  final _TrendPoint point;
  final String unit;

  const _TrendTooltip({required this.point, required this.unit});

  @override
  Widget build(BuildContext context) {
    final decimals = unit == '%' ? 0 : 1;
    return IgnorePointer(
      child: Container(
        width: 124,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF15361E),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33172A1A),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${point.value.toStringAsFixed(decimals)}$unit',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              DateFormat('MMM d, h:mm a').format(point.recordedAt),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendTimeAxis extends StatelessWidget {
  final List<_TrendPoint> points;

  const _TrendTimeAxis({required this.points});

  @override
  Widget build(BuildContext context) {
    final sampleCount = math.min(4, points.length);
    final indices = <int>{
      for (var index = 0; index < sampleCount; index++)
        sampleCount == 1
            ? 0
            : ((points.length - 1) * (index / (sampleCount - 1))).round(),
    }.toList()..sort();
    final crossesDay = points.first.recordedAt.day != points.last.recordedAt.day;

    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const labelWidth = 82.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final index in indices)
                Positioned(
                  left: _labelLeft(
                    index,
                    points.length,
                    constraints.maxWidth,
                    labelWidth,
                  ),
                  width: labelWidth,
                  child: Text(
                    DateFormat(crossesDay ? 'MMM d, h:mm a' : 'h:mm a')
                        .format(points[index].recordedAt),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF8A96A3),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _labelLeft(
    int index,
    int pointCount,
    double width,
    double labelWidth,
  ) {
    if (width <= labelWidth) {
      return 0;
    }
    final ratio = pointCount <= 1 ? 0.5 : index / (pointCount - 1);
    return ((width * ratio) - (labelWidth / 2))
        .clamp(0.0, width - labelWidth)
        .toDouble();
  }
}

class _ChartMetadata extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ChartMetadata({
    required this.icon,
    required this.text,
    this.color = const Color(0xFF64748B),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EnvironmentalLogsPanel extends StatefulWidget {
  final List<EnvironmentalLog> logs;
  final String? selectedDayKey;
  final ValueChanged<String?> onSelectedDayChanged;

  const _EnvironmentalLogsPanel({
    required this.logs,
    required this.selectedDayKey,
    required this.onSelectedDayChanged,
  });

  @override
  State<_EnvironmentalLogsPanel> createState() =>
      _EnvironmentalLogsPanelState();
}

class _EnvironmentalLogsPanelState extends State<_EnvironmentalLogsPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.logs.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Waiting for 15-minute environmental logs',
            style: TextStyle(
              color: Color(0xFF8D98B2),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final availableDays = <DateTime>[];
    final seenDayKeys = <String>{};
    for (final log in widget.logs.reversed) {
      final dayKey = _environmentalLogDayKey(log.recordedAt);
      if (seenDayKeys.add(dayKey)) {
        availableDays.add(
          DateTime(
            log.recordedAt.year,
            log.recordedAt.month,
            log.recordedAt.day,
          ),
        );
      }
    }

    final filteredLogs = widget.selectedDayKey == null
        ? widget.logs.reversed.toList()
        : widget.logs
              .where(
                (log) =>
                    _environmentalLogDayKey(log.recordedAt) ==
                    widget.selectedDayKey,
              )
              .toList()
              .reversed
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Monitor logs',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF58705A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: widget.selectedDayKey,
                borderRadius: BorderRadius.circular(14),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w700,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All days'),
                  ),
                  ...availableDays.map(
                    (day) => DropdownMenuItem<String?>(
                      value: _environmentalLogDayKey(day),
                      child: Text(_formatEnvironmentalLogDay(day)),
                    ),
                  ),
                ].toList(),
                onChanged: widget.onSelectedDayChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Time',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Temp',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Humidity',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFFE3E9E4)),
        SizedBox(
          height: 280,
          child: RawScrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            interactive: true,
            radius: const Radius.circular(999),
            thickness: 6,
            child: ListView.separated(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              itemCount: filteredLogs.length,
              itemBuilder: (context, index) {
                return _EnvironmentalLogRow(log: filteredLogs[index]);
              },
              separatorBuilder: (context, index) {
                return const Divider(height: 1, color: Color(0xFFE3E9E4));
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _EnvironmentalLogRow extends StatelessWidget {
  final EnvironmentalLog log;

  const _EnvironmentalLogRow({required this.log});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('MMM d, yyyy, h:mm a').format(log.recordedAt),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF172033),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${log.temperature.toStringAsFixed(1)}\u00B0C',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${log.humidity.toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _environmentalLogDayKey(DateTime value) {
  final normalized = DateTime(value.year, value.month, value.day);
  return normalized.toIso8601String();
}

String _formatEnvironmentalLogDay(DateTime value) {
  return DateFormat('MMM d, yyyy').format(value);
}

class _ChartDotLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _ChartDotLegend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF52606D),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MortalityReasonChart extends StatelessWidget {
  final Map<String, int> reasons;
  final int totalDeaths;

  const _MortalityReasonChart({
    required this.reasons,
    required this.totalDeaths,
  });

  @override
  Widget build(BuildContext context) {
    if (totalDeaths <= 0 || reasons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FAF7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCE9DD)),
        ),
        child: const Center(
          child: Text(
            'No mortality reason data yet.',
            style: TextStyle(
              color: Color(0xFF8D98B2),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final entries = reasons.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE9DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mortality breakdown',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF172033),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < entries.length; i++) ...[
            _MortalityReasonRow(
              reason: entries[i].key,
              count: entries[i].value,
              totalDeaths: totalDeaths,
            ),
            if (i != entries.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _MortalityReasonRow extends StatelessWidget {
  final String reason;
  final int count;
  final int totalDeaths;

  const _MortalityReasonRow({
    required this.reason,
    required this.count,
    required this.totalDeaths,
  });

  @override
  Widget build(BuildContext context) {
    final percent = totalDeaths == 0 ? 0.0 : (count / totalDeaths) * 100;
    final widthFactor = totalDeaths == 0
        ? 0.0
        : (count / totalDeaths).clamp(0.0, 1.0);
    const barStartColor = Color(0xFF0B4F1D);
    const barEndColor = Color(0xFF2E7D32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF172033),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 14,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: const Color(0xFFDCE8DD)),
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: widthFactor,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [barStartColor, barEndColor],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x552E7D32),
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const SizedBox(height: double.infinity),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<_TrendPoint> points;
  final _TrendScale scale;
  final Duration gapThreshold;
  final double? minimumTarget;
  final double? maximumTarget;
  final int? selectedIndex;

  const _TrendLinePainter({
    required this.points,
    required this.scale,
    required this.gapThreshold,
    required this.minimumTarget,
    required this.maximumTarget,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const chartGreenStart = Color(0xFF0B4F1D);
    const chartGreenEnd = Color(0xFF2E7D32);
    final leftPad = 2.0;
    final rightPad = 2.0;
    final topPad = 8.0;
    final bottomPad = 10.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = const Color(0xFFE6EEF0)
      ..strokeWidth = 1;
    final targetLinePaint = Paint()
      ..color = const Color(0xFFD3E4F3)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final targetBandPaint = Paint()..color = const Color(0x183FA34D);
    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [chartGreenStart, chartGreenEnd],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Offset.zero & size)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final gapPaint = Paint()
      ..color = const Color(0xFF7BA884)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x550B4F1D), Color(0x1A2E7D32), Color(0x002E7D32)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    final pointFillPaint = Paint()..color = Colors.white;
    final pointStrokePaint = Paint()
      ..color = chartGreenEnd
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final selectedGuidePaint = Paint()
      ..color = const Color(0x66334155)
      ..strokeWidth = 1;

    double yFor(double value) {
      final normalized = ((value - scale.minimum) /
              (scale.maximum - scale.minimum))
          .clamp(0.0, 1.0)
          .toDouble();
      return topPad + (1 - normalized) * chartHeight;
    }

    final gridLineCount = scale.labels.length;
    final gridDivisions = math.max(1, gridLineCount - 1);
    for (var i = 0; i < gridLineCount; i++) {
      final y = topPad + (chartHeight / gridDivisions) * i;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
    }

    void drawDashedLine(double y) {
      const dashWidth = 5.0;
      const dashGap = 4.0;
      var x = leftPad;
      while (x < size.width - rightPad) {
        final nextX = math.min(x + dashWidth, size.width - rightPad);
        canvas.drawLine(Offset(x, y), Offset(nextX, y), targetLinePaint);
        x += dashWidth + dashGap;
      }
    }

    final targetMinimum = minimumTarget;
    final targetMaximum = maximumTarget;
    if (targetMinimum != null && targetMaximum != null) {
      final visibleMinimum = math.max(targetMinimum, scale.minimum);
      final visibleMaximum = math.min(targetMaximum, scale.maximum);
      if (visibleMinimum <= visibleMaximum) {
        canvas.drawRect(
          Rect.fromLTRB(
            leftPad,
            yFor(visibleMaximum),
            size.width - rightPad,
            yFor(visibleMinimum),
          ),
          targetBandPaint,
        );
      }
      if (targetMinimum >= scale.minimum &&
          targetMinimum <= scale.maximum) {
        drawDashedLine(yFor(targetMinimum));
      }
      if (targetMaximum >= scale.minimum &&
          targetMaximum <= scale.maximum) {
        drawDashedLine(yFor(targetMaximum));
      }
    }

    double xFor(int index) {
      if (points.length == 1) {
        return leftPad + chartWidth / 2;
      }
      return leftPad + chartWidth * (index / (points.length - 1));
    }

    Offset pointFor(int index) =>
        Offset(xFor(index), yFor(points[index].value));

    void drawSegment(int start, int end) {
      if (end < start) {
        return;
      }
      final path = Path();
      final fillPath = Path();
      final firstPoint = pointFor(start);
      path.moveTo(firstPoint.dx, firstPoint.dy);
      fillPath.moveTo(firstPoint.dx, size.height - bottomPad);
      fillPath.lineTo(firstPoint.dx, firstPoint.dy);

      for (var index = start + 1; index <= end; index++) {
        final previous = pointFor(index - 1);
        final point = pointFor(index);
        final controlX = previous.dx + ((point.dx - previous.dx) / 2);
        path.cubicTo(
          controlX,
          previous.dy,
          controlX,
          point.dy,
          point.dx,
          point.dy,
        );
        fillPath.cubicTo(
          controlX,
          previous.dy,
          controlX,
          point.dy,
          point.dx,
          point.dy,
        );
      }

      if (end > start) {
        final lastPoint = pointFor(end);
        fillPath.lineTo(lastPoint.dx, size.height - bottomPad);
        fillPath.close();
        canvas.drawPath(fillPath, fillPaint);
        canvas.drawPath(path, linePaint);
      }
    }

    var segmentStart = 0;
    for (var index = 1; index < points.length; index++) {
      if (points[index].recordedAt.difference(points[index - 1].recordedAt) >
          gapThreshold) {
        drawSegment(segmentStart, index - 1);
        segmentStart = index;
      }
    }
    drawSegment(segmentStart, points.length - 1);

    void drawGapConnector(Offset start, Offset end) {
      const dashLength = 5.0;
      const dashGap = 4.0;
      final distance = (end - start).distance;
      if (distance <= 0) {
        return;
      }
      final direction = (end - start) / distance;
      var travelled = 0.0;
      while (travelled < distance) {
        final segmentEnd = math.min(travelled + dashLength, distance);
        canvas.drawLine(
          start + (direction * travelled),
          start + (direction * segmentEnd),
          gapPaint,
        );
        travelled += dashLength + dashGap;
      }
    }

    final gapBoundaryIndices = <int>{};
    for (var index = 1; index < points.length; index++) {
      if (points[index].recordedAt.difference(points[index - 1].recordedAt) >
          gapThreshold) {
        drawGapConnector(pointFor(index - 1), pointFor(index));
        gapBoundaryIndices
          ..add(index - 1)
          ..add(index);
      }
    }

    final markerStep = math.max(1, (points.length / 8).ceil());
    for (var index = 0; index < points.length; index++) {
      final shouldDrawMarker =
          index == 0 ||
          index == points.length - 1 ||
          index % markerStep == 0 ||
          gapBoundaryIndices.contains(index);
      if (!shouldDrawMarker) {
        continue;
      }
      final point = pointFor(index);
      canvas.drawCircle(point, 3.2, pointFillPaint);
      canvas.drawCircle(point, 3.2, pointStrokePaint);
    }

    final activeIndex = selectedIndex;
    if (activeIndex != null &&
        activeIndex >= 0 &&
        activeIndex < points.length) {
      final point = pointFor(activeIndex);
      canvas.drawLine(
        Offset(point.dx, topPad),
        Offset(point.dx, size.height - bottomPad),
        selectedGuidePaint,
      );
      canvas.drawCircle(point, 5.2, pointFillPaint);
      canvas.drawCircle(point, 5.2, pointStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.scale != scale ||
        oldDelegate.gapThreshold != gapThreshold ||
        oldDelegate.minimumTarget != minimumTarget ||
        oldDelegate.maximumTarget != maximumTarget ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _InsightTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InsightTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                color: Color(0xFF172033),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCategorySummary {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _DeviceCategorySummary({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });
}

class _DeviceCategorySummaryTile extends StatelessWidget {
  final _DeviceCategorySummary summary;

  const _DeviceCategorySummaryTile({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: summary.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: summary.color.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(summary.icon, size: 18, color: summary.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  summary.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: summary.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${summary.count} device${summary.count == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceUsageGroupCard extends StatelessWidget {
  final List<_DeviceUsageItem> items;

  const _DeviceUsageGroupCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(items.length, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 10),
          child: _DeviceUsageRow(item: items[index]),
        );
      }),
    );
  }
}

class _DeviceUsageRow extends StatelessWidget {
  final _DeviceUsageItem item;

  const _DeviceUsageRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColor = item.enabled
        ? const Color(0xFF2E7D32)
        : const Color(0xFF7C8A9F);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EFE8)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withOpacity(0.18)),
                ),
                child: Text(
                  item.enabled ? 'Connected' : 'Offline',
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${item.scheduleCount} schedule${item.scheduleCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
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
                color: selected ? const Color(0xFFE8F6EA) : Colors.transparent,
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

extension<T> on List<T> {
  List<T> takeLast(int count) {
    if (length <= count) {
      return List<T>.from(this);
    }
    return sublist(length - count);
  }
}
