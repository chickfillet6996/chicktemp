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
import '../widgets/splash_background.dart';
import '../widgets/user_avatar_content.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

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
    _selectedBatch = _batches.isEmpty ? 'Default Batch' : _batches.first;
    _analyticsFuture = _loadAndRecordAnalytics();
    _analyticsRefreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _refreshLogs(),
    );
  }

  @override
  void dispose() {
    _analyticsRefreshTimer?.cancel();
    super.dispose();
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

  ({String label, Color color}) _temperatureIndicator(double temperature) {
    if (temperature == 0) {
      return (label: 'No Data', color: const Color(0xFF64748B));
    }
    if (temperature < 28) {
      return (label: 'Low', color: const Color(0xFF2563EB));
    }
    if (temperature > 35) {
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
    final temperatureValues = fifteenMinuteLogs
        .map((log) => log.temperature)
        .toList();
    final humidityValues = fifteenMinuteLogs
        .map((log) => log.humidity)
        .toList();
    final trendTemperatureValues = temperatureValues
        .where((value) => value > 0)
        .toList()
        .takeLast(12);
    final trendHumidityValues = humidityValues
        .where((value) => value > 0)
        .toList()
        .takeLast(16);
    final displayedAverageTemperature = telemetry.isLive
        ? telemetry.temperature
        : telemetry.temperature > 0
        ? telemetry.temperature
        : latestLog?.temperature ?? 0.0;
    final displayedAverageHumidity = telemetry.isLive
        ? telemetry.humidity
        : telemetry.humidity > 0
        ? telemetry.humidity
        : latestLog?.humidity ?? 0.0;

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
    final feederLevel = _readPercentValue(feederConfig, const [
      'feeder_level',
      'feed_level',
      'fill_level',
      'level_percent',
    ]);

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
      temperatureChartValues: trendTemperatureValues,
      humidityChartValues: trendHumidityValues,
      chartLabels: _sampleLogLabels(fifteenMinuteLogs),
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
        recordedAt: entry.key.add(const Duration(minutes: 15)),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _Header(onProfile: () => ProfileScreen.show(context)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedBuilder(
                  animation: MonitoringStore.instance,
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
                        final displayedTemperature = telemetry.isLive
                            ? telemetry.temperature
                            : data.averageTemperature;
                        final displayedHumidity = telemetry.isLive
                            ? telemetry.humidity
                            : data.averageHumidity;
                        final displayedWaterLevel = telemetry.isWaterLevelLive
                            ? telemetry.waterLevelPercent
                            : data.waterTankLevel;
                        final temperatureIndicator = _temperatureIndicator(
                          displayedTemperature,
                        );

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
                                    icon: const Icon(Icons.refresh_rounded),
                                    color: const Color(0xFF2E7D32),
                                  ),
                                  if (_batches.isNotEmpty) _batchDropdown(),
                                ],
                              ),
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
                              if (!isLoading &&
                                  !telemetry.isLive &&
                                  (displayedTemperature > 0 ||
                                      displayedHumidity > 0))
                                const _StatusBanner(
                                  text:
                                      'Environmental sensors are offline. Showing the last recorded values.',
                                  icon: Icons.sensors_off_outlined,
                                ),
                              if (!isLoading &&
                                  !telemetry.isWaterLevelLive &&
                                  displayedWaterLevel != null)
                                const _StatusBanner(
                                  text:
                                      'Water sensor is offline. Showing the last recorded level.',
                                  icon: Icons.water_drop_outlined,
                                ),
                              if (snapshot.hasError ||
                                  isLoading ||
                                  logs.isEmpty ||
                                  !telemetry.isLive ||
                                  (!telemetry.isWaterLevelLive &&
                                      displayedWaterLevel != null))
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
                                    trend: data.feederLevel != null
                                        ? 'Live sensor'
                                        : data.feederDeviceCount > 0
                                        ? 'Empty'
                                        : 'No sensor',
                                    trendColor: const Color(0xFFB45309),
                                    value: data.feederLevel != null
                                        ? '${data.feederLevel!.toStringAsFixed(0)}%'
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
                                  values: data.temperatureChartValues,
                                  labels: data.chartLabels,
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
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
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
  final List<double> temperatureChartValues;
  final List<double> humidityChartValues;
  final List<String> chartLabels;
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
    required this.temperatureChartValues,
    required this.humidityChartValues,
    required this.chartLabels,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Firebase environmental logs every 15 minutes',
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
            onTap: onProfile,
            borderRadius: BorderRadius.circular(14),
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
  final List<double> values;
  final List<String> labels;

  const _TemperatureChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final chartValues = values
        .where((value) => value > 0)
        .toList()
        .takeLast(12);
    final latestValue = chartValues.isEmpty ? 0.0 : chartValues.last;
    final averageValue = chartValues.isEmpty
        ? 0.0
        : chartValues.reduce((a, b) => a + b) / chartValues.length;

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
            const Expanded(
              child: _InsightTile(
                label: 'Target',
                value: '28-35\u00B0C',
                color: Color(0xFFB58F2A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TemperatureLineChart(values: chartValues, labels: labels),
      ],
    );
  }
}

class _HumidityTrendsPanel extends StatelessWidget {
  final _AnalyticsData data;

  const _HumidityTrendsPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final values = data.humidityChartValues
        .where((value) => value > 0)
        .toList()
        .takeLast(16);
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
                label: 'Range',
                value: values.isEmpty
                    ? '--'
                    : '${minValue.toStringAsFixed(0)}-${maxValue.toStringAsFixed(0)}%',
                color: const Color(0xFF8F7A3D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _HumidityBarChart(values: values, labels: data.chartLabels),
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

class _HumidityBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;

  const _HumidityBarChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Waiting for humidity history',
            style: TextStyle(
              color: Color(0xFF8D98B2),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final sampledValues = List<double>.generate(7, (index) {
      if (values.isEmpty) {
        return 0;
      }
      if (values.length == 1) {
        return values.first;
      }
      final sourceIndex = ((values.length - 1) * (index / 6)).round();
      return values[sourceIndex];
    });
    final xLabels = labels;
    const minScale = 0.0;
    const maxScale = 90.0;
    const barGradients = [
      (start: Color(0xFF0B4F1D), end: Color(0xFF2E7D32)),
      (start: Color(0xFF0D5520), end: Color(0xFF347C38)),
      (start: Color(0xFF0F5A21), end: Color(0xFF39843D)),
      (start: Color(0xFF116024), end: Color(0xFF3E8B43)),
      (start: Color(0xFF126526), end: Color(0xFF429349)),
      (start: Color(0xFF146B28), end: Color(0xFF479B4E)),
      (start: Color(0xFF16712B), end: Color(0xFF4CA354)),
    ];

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
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
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 8, bottom: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '90%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7B8794),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '45%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7B8794),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '0%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7B8794),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final targetTop =
                                ((maxScale - 70) / (maxScale - minScale)) *
                                constraints.maxHeight;

                            return Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: targetTop,
                                  child: CustomPaint(
                                    size: Size(constraints.maxWidth, 1.6),
                                    painter: _DashedGuidePainter(),
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < sampledValues.length;
                                      i++
                                    ) ...[
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            width: 26,
                                            height:
                                                (((sampledValues[i].clamp(
                                                              minScale,
                                                              maxScale,
                                                            ) -
                                                            minScale) /
                                                        (maxScale - minScale)) *
                                                    120) +
                                                10,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  barGradients[i %
                                                          barGradients.length]
                                                      .start,
                                                  barGradients[i %
                                                          barGradients.length]
                                                      .end,
                                                ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0x332E7D32,
                                                  ),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (i != sampledValues.length - 1)
                                        const SizedBox(width: 10),
                                    ],
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < xLabels.length; i++) ...[
                            Expanded(
                              child: Text(
                                xLabels[i],
                                textAlign: i == 0
                                    ? TextAlign.left
                                    : i == xLabels.length - 1
                                    ? TextAlign.right
                                    : TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF8A96A3),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (i != xLabels.length - 1)
                              const SizedBox(width: 10),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartDotLegend(label: 'Actual', color: Color(0xFF2E7D32)),
              SizedBox(width: 16),
              _ChartDotLegend(label: 'Target', color: Color(0xFFD3E4F3)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD3E4F3)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashGap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      final nextX = math.min(x + dashWidth, size.width);
      canvas.drawLine(Offset(x, 0), Offset(nextX, 0), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TemperatureLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;

  const _TemperatureLineChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Waiting for sensor history',
            style: TextStyle(
              color: Color(0xFF8D98B2),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final sampledValues = List<double>.generate(7, (index) {
      if (values.isEmpty) {
        return 0;
      }
      if (values.length == 1) {
        return values.first;
      }
      final sourceIndex = ((values.length - 1) * (index / 6)).round();
      return values[sourceIndex];
    });

    final xLabels = labels;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
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
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 8, bottom: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '40',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7B8794),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '20',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7B8794),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '0',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7B8794),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: _TemperatureLinePainter(
                            values: sampledValues,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < xLabels.length; i++) ...[
                            Expanded(
                              child: Text(
                                xLabels[i],
                                textAlign: i == 0
                                    ? TextAlign.left
                                    : i == xLabels.length - 1
                                    ? TextAlign.right
                                    : TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF8A96A3),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartDotLegend(label: 'Actual', color: Color(0xFF2E7D32)),
              SizedBox(width: 16),
              _ChartDotLegend(label: 'Target', color: Color(0xFFD3E4F3)),
            ],
          ),
        ],
      ),
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

List<String> _sampleLogLabels(List<EnvironmentalLog> logs) {
  if (logs.isEmpty) {
    return const ['--', '--', '--', '--', '--', '--', '--'];
  }

  final recentLogs = logs.takeLast(12);
  return List<String>.generate(7, (index) {
    if (recentLogs.length == 1) {
      return DateFormat('h:mm a').format(recentLogs.first.recordedAt);
    }

    final sourceIndex = ((recentLogs.length - 1) * (index / 6)).round();
    return DateFormat('h:mm a').format(recentLogs[sourceIndex].recordedAt);
  });
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

class _TemperatureLinePainter extends CustomPainter {
  final List<double> values;

  const _TemperatureLinePainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    const chartGreenStart = Color(0xFF0B4F1D);
    const chartGreenEnd = Color(0xFF2E7D32);
    final minScale = 0.0;
    final maxScale = 31.0;
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

    double yFor(double value) {
      final normalized = ((value - minScale) / (maxScale - minScale))
          .clamp(0.0, 1.0)
          .toDouble();
      return topPad + (1 - normalized) * chartHeight;
    }

    for (var i = 0; i < 3; i++) {
      final y = topPad + (chartHeight / 2) * i;
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

    drawDashedLine(yFor(28.5));

    Offset pointFor(int index, double value) {
      final denominator = values.length <= 1 ? 1 : values.length - 1;
      final x = leftPad + (chartWidth / denominator) * index;
      return Offset(x, yFor(value));
    }

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < values.length; i++) {
      final point = pointFor(i, values[i]);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
        fillPath.moveTo(point.dx, size.height - bottomPad);
        fillPath.lineTo(point.dx, point.dy);
      } else {
        final previous = pointFor(i - 1, values[i - 1]);
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
    }

    fillPath.lineTo(size.width - rightPad, size.height - bottomPad);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < values.length; i++) {
      final point = pointFor(i, values[i]);
      if (i == 0 || i == values.length - 1 || i == values.length ~/ 2) {
        canvas.drawCircle(point, 3.6, pointFillPaint);
        canvas.drawCircle(point, 3.6, pointStrokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TemperatureLinePainter oldDelegate) {
    return oldDelegate.values != values;
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
    return GestureDetector(
      onTap: onTap,
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
