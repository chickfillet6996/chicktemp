import 'package:flutter/material.dart';

import 'analytics_screen.dart';
import 'controls_screen.dart';
import 'mortality_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import '../models/auth_store.dart';
import '../models/batch_store.dart';
import '../models/environmental_log_store.dart';
import '../models/monitoring_store.dart';
import '../models/temperature_settings_store.dart';
import '../widgets/splash_background.dart';
import '../widgets/user_avatar_content.dart';

class BatchesDashboardScreen extends StatefulWidget {
  final String batchId;
  final String batchName;
  final String status;
  final String startedAt;
  final String dayLabel;
  final String birdsLabel;

  const BatchesDashboardScreen({
    super.key,
    required this.batchId,
    required this.batchName,
    required this.status,
    required this.startedAt,
    required this.dayLabel,
    required this.birdsLabel,
  });

  @override
  State<BatchesDashboardScreen> createState() => _BatchesDashboardScreenState();
}

class _BatchesDashboardScreenState extends State<BatchesDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final Listenable _dashboardListenable = Listenable.merge([
    MonitoringStore.instance,
    TemperatureSettingsStore.instance,
  ]);

  final TextEditingController _currentDayController = TextEditingController();
  final TextEditingController _totalDaysController = TextEditingController();
  late final AnimationController _entranceController;

  int _selectedNavIndex = 0;
  bool _isEditingDay = false;
  EnvironmentalLog? _latestEnvironmentalLog;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _loadLatestEnvironmentalLog();
  }

  BatchItem get _currentBatch {
    return BatchStore.instance.findById(widget.batchId) ??
        BatchStore.instance.findByName(widget.batchName) ??
        BatchItem(
          id: widget.batchId,
          name: widget.batchName,
          status: widget.status,
          startedAt: widget.startedAt,
          dayLabel: widget.dayLabel,
          birdsLabel: widget.birdsLabel,
        );
  }

  ({String currentDay, String totalDays}) _parseDayLabel(String label) {
    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(label);
    if (match != null) {
      return (currentDay: match.group(1)!, totalDays: match.group(2)!);
    }

    return (currentDay: '1', totalDays: '45');
  }

  Future<void> _loadLatestEnvironmentalLog() async {
    final log = await EnvironmentalLogStore.instance.fetchLatestLogForBatch(
      batch: _currentBatch,
    );
    if (!mounted) {
      return;
    }
    setState(() => _latestEnvironmentalLog = log);
  }

  String _updatedText(DateTime updatedAt) {
    final seconds = DateTime.now().difference(updatedAt).inSeconds;
    if (seconds < 10) {
      return 'Updated: Just now';
    }
    if (seconds < 60) {
      return 'Updated: ${seconds}s ago';
    }

    return 'Updated: ${DateTime.now().difference(updatedAt).inMinutes} mins ago';
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
        return const Color(0xFF10A64A);
      case TemperatureCondition.noSensor:
        return const Color(0xFF6B7280);
    }
  }

  ({Color background, Color border, Color text}) _batchStatusColors(
    String status,
  ) {
    if (status.toUpperCase() == 'INACTIVE') {
      return (
        background: const Color(0xFFF1F5F3),
        border: const Color(0xFFD5DEDA),
        text: const Color(0xFF5F6F67),
      );
    }

    return (
      background: const Color(0xFFE7F9EC),
      border: const Color(0xFFB6E5C0),
      text: const Color(0xFF1E8E3E),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _currentDayController.dispose();
    _totalDaysController.dispose();
    super.dispose();
  }

  void _startEditingDay(BatchItem batch) {
    final dayParts = _parseDayLabel(batch.dayLabel);
    setState(() {
      _currentDayController.text = dayParts.currentDay;
      _totalDaysController.text = dayParts.totalDays;
      _isEditingDay = true;
    });
  }

  void _cancelEditingDay() {
    setState(() => _isEditingDay = false);
  }

  Future<void> _saveDayLabel(BatchItem batch) async {
    final currentDay = int.tryParse(_currentDayController.text.trim());
    final totalDays = int.tryParse(_totalDaysController.text.trim());

    if (currentDay == null || currentDay <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid current day.')),
      );
      return;
    }

    if (totalDays == null || totalDays <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid total day count.')),
      );
      return;
    }

    if (currentDay > totalDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current day cannot be greater than total days.')),
      );
      return;
    }

    final nextDayLabel = 'Day $currentDay / $totalDays';

    try {
      await BatchStore.instance.updateDayLabel(
        batchId: batch.stableId,
        dayLabel: nextDayLabel,
        notifyListenersOnChange: false,
      );
      if (!mounted) {
        return;
      }
      setState(() => _isEditingDay = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${batch.name} updated to $nextDayLabel.')));
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save day update: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: SplashBackground(
        child: Stack(
          children: [
            const Positioned.fill(child: _DashboardAtmosphere()),
            SafeArea(
              child: AnimatedBuilder(
                animation: _dashboardListenable,
                builder: (context, _) {
              final currentBatch = _currentBatch;
              final dayParts = _parseDayLabel(currentBatch.dayLabel);
              final telemetry = MonitoringStore.instance.snapshotFor(currentBatch.name);
              final savedLog = _latestEnvironmentalLog;
              final displayedTemperature = telemetry.isLive
                  ? telemetry.temperature
                  : telemetry.temperature > 0
                  ? telemetry.temperature
                  : savedLog?.temperature ?? 0.0;
              final displayedHumidity = telemetry.isLive
                  ? telemetry.humidity
                  : telemetry.humidity > 0
                  ? telemetry.humidity
                  : savedLog?.humidity ?? 0.0;
              final displayedWaterLevel = telemetry.isWaterLevelLive
                  ? telemetry.waterLevelPercent
                  : telemetry.waterLevelPercent > 0
                  ? telemetry.waterLevelPercent
                  : savedLog?.waterLevelPercent ?? 0.0;
              final displayedWaterDistance = telemetry.isWaterLevelLive
                  ? telemetry.waterDistanceCm
                  : telemetry.waterDistanceCm > 0
                  ? telemetry.waterDistanceCm
                  : savedLog?.waterDistanceCm ?? 0.0;
              final displayedFeederLevel = telemetry.isFeederLevelLive
                  ? telemetry.feederLevelPercent
                  : telemetry.feederDistanceCm > 0
                  ? telemetry.feederLevelPercent
                  : savedLog?.feederLevelPercent ?? 0.0;
              final displayedFeederDistance = telemetry.isFeederLevelLive
                  ? telemetry.feederDistanceCm
                  : telemetry.feederDistanceCm > 0
                  ? telemetry.feederDistanceCm
                  : savedLog?.feederDistanceCm ?? 0.0;
              final lastEnvironmentUpdate = telemetry.isLive
                  ? telemetry.updatedAt
                  : savedLog?.recordedAt ?? telemetry.updatedAt;
              final condition = TemperatureSettingsStore.instance.classify(
                currentBatch.name,
                displayedTemperature,
                isLive: displayedTemperature > 0,
              );
              final status = telemetry.isLive
                  ? _temperatureStatusLabel(condition)
                  : displayedTemperature > 0
                  ? 'OFFLINE'
                  : 'NO DATA';
              final statusColor = telemetry.isLive
                  ? _temperatureStatusColor(condition)
                  : displayedTemperature > 0
                  ? const Color(0xFFD97706)
                  : const Color(0xFF64748B);
              final humidityStatus = telemetry.isLive
                  ? 'LIVE'
                  : displayedHumidity > 0
                  ? 'OFFLINE'
                  : 'NO DATA';
              final humidityStatusColor = telemetry.isLive
                  ? const Color(0xFF2563EB)
                  : displayedHumidity > 0
                  ? const Color(0xFFD97706)
                  : const Color(0xFF64748B);
              final waterStatus = telemetry.isWaterLevelLive
                  ? 'LIVE'
                  : displayedWaterDistance > 0
                  ? 'OFFLINE'
                  : 'NO DATA';
              final waterStatusColor = telemetry.isWaterLevelLive
                  ? const Color(0xFF0E9F9A)
                  : displayedWaterDistance > 0
                  ? const Color(0xFFD97706)
                  : const Color(0xFF64748B);
              final feederStatus = telemetry.isFeederLevelLive
                  ? 'LIVE'
                  : displayedFeederDistance > 0
                  ? 'OFFLINE'
                  : 'NO DATA';
              final feederStatusColor = telemetry.isFeederLevelLive
                  ? const Color(0xFFB45309)
                  : displayedFeederDistance > 0
                  ? const Color(0xFFD97706)
                  : const Color(0xFF64748B);
              final sourceText = telemetry.isLive
                  ? 'Live sensor'
                  : 'Last recorded';
              final totalBirds = BatchStore.instance.totalBirdsFor(currentBatch.name);
              final deaths = BatchStore.instance.mortalityCountFor(currentBatch.name);
              final batchStatusColors = _batchStatusColors(currentBatch.status);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                    _DashboardReveal(
                      controller: _entranceController,
                      start: 0.00,
                      end: 0.48,
                      child: Container(
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
                                  'Batch Dashboard',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
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
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _PillButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          label: 'Back to Batches',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        _PillButton(
                          icon: Icons.chevron_right_rounded,
                          label: 'Controls',
                          filled: true,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ControlsScreen(batchName: currentBatch.name),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DashboardReveal(
                      controller: _entranceController,
                      start: 0.12,
                      end: 0.62,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.92),
                            const Color(0xFFEAF7EC).withOpacity(0.82),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.88),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1F6F2F).withOpacity(0.09),
                            blurRadius: 22,
                            offset: const Offset(0, 9),
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
                                      currentBatch.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF6C7DA0),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      currentBatch.startedAt,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF7D8794),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: batchStatusColors.background,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: batchStatusColors.border),
                                ),
                                child: Text(
                                  currentBatch.status,
                                  style: TextStyle(
                                    color: batchStatusColors.text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Day ${dayParts.currentDay} ',
                                        style: const TextStyle(
                                          color: Color(0xFF233047),
                                          fontSize: 34,
                                          fontWeight: FontWeight.w800,
                                          height: 1.0,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '/ ${dayParts.totalDays}',
                                        style: const TextStyle(
                                          color: Color(0xFFA8B3C3),
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: () => _startEditingDay(currentBatch),
                                tooltip: 'Edit day',
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFF5F8FB),
                                  side: const BorderSide(color: Color(0xFFDCE5EE)),
                                ),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Color(0xFF5F7DA8),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          if (_isEditingDay) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _currentDayController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Current day',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _totalDaysController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Total days',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _cancelEditingDay,
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => _saveDayLabel(currentBatch),
                                    child: const Text('Save'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _DashboardReveal(
                      controller: _entranceController,
                      start: 0.25,
                      end: 0.78,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ENVIRONMENT OVERVIEW',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF58705A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _EnvironmentCard(
                            icon: Icons.thermostat_outlined,
                            iconColor: const Color(0xFFFF6B4A),
                            statusLabel: status,
                            statusColor: statusColor,
                            statusBackgroundColor: statusColor.withOpacity(0.10),
                            value: '${displayedTemperature.toStringAsFixed(1)}°C',
                            label: 'Temperature',
                            updatedText:
                                '$sourceText - ${_updatedText(lastEnvironmentUpdate)}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _EnvironmentCard(
                            icon: Icons.water_drop_outlined,
                            iconColor: const Color(0xFF3D7BFF),
                            statusLabel: humidityStatus,
                            statusColor: humidityStatusColor,
                            statusBackgroundColor: humidityStatusColor
                                .withOpacity(0.10),
                            value: '${displayedHumidity.toStringAsFixed(0)}%',
                            label: 'Humidity',
                            updatedText:
                                '$sourceText - ${_updatedText(lastEnvironmentUpdate)}',
                            ),
                          ),
                        ],
                      ),
                          ),
                          const SizedBox(height: 12),
                          IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _EnvironmentCard(
                            icon: Icons.water_outlined,
                            iconColor: const Color(0xFF0E9F9A),
                            statusLabel: waterStatus,
                            statusColor: waterStatusColor,
                            statusBackgroundColor: waterStatusColor.withOpacity(
                              0.10,
                            ),
                            value:
                                '${displayedWaterLevel.toStringAsFixed(0)}%',
                            label: 'Water Level',
                            levelProgress: displayedWaterLevel / 100,
                            updatedText: telemetry.isWaterLevelLive
                                ? 'Live | ${displayedWaterDistance.toStringAsFixed(1)} cm'
                                : displayedWaterDistance > 0
                                ? 'Saved | ${displayedWaterDistance.toStringAsFixed(1)} cm'
                                : 'No reading yet',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _EnvironmentCard(
                            icon: Icons.restaurant_outlined,
                            iconColor: const Color(0xFFB45309),
                            statusLabel: feederStatus,
                            statusColor: feederStatusColor,
                            statusBackgroundColor: feederStatusColor
                                .withOpacity(0.10),
                            value:
                                '${displayedFeederLevel.toStringAsFixed(0)}%',
                            label: 'Feeder Level',
                            levelProgress: displayedFeederLevel / 100,
                            updatedText: telemetry.isFeederLevelLive
                                ? 'Live | ${displayedFeederDistance.toStringAsFixed(1)} cm'
                                : displayedFeederDistance > 0
                                ? 'Saved | ${displayedFeederDistance.toStringAsFixed(1)} cm'
                                : 'No reading yet',
                            ),
                          ),
                        ],
                      ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _DashboardReveal(
                      controller: _entranceController,
                      start: 0.42,
                      end: 1.00,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.91),
                            const Color(0xFFF4FAF5).withOpacity(0.80),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.88),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1F6F2F).withOpacity(0.08),
                            blurRadius: 22,
                            offset: const Offset(0, 9),
                          ),
                        ],
                      ),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'CHICKEN STATUS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF58705A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7FBFD),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE5ECF4)),
                                ),
                                child: const Icon(
                                  Icons.egg_alt_outlined,
                                  size: 22,
                                  color: Color(0xFF8FA0B7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'TOTAL CHICKENS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6C7DA0),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentBatch.birdsLabel.split(' ').first,
                            style: const TextStyle(
                              fontSize: 32,
                              height: 1.0,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF243046),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: Color(0xFFE9EEF3)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _CountColumn(
                                  label: 'ALIVE',
                                  labelColor: const Color(0xFF10A64A),
                                  value: (totalBirds - deaths).clamp(0, totalBirds).toString(),
                                ),
                              ),
                              Expanded(
                                child: _CountColumn(
                                  label: 'DEAD',
                                  labelColor: const Color(0xFFFF3A3A),
                                  value: deaths.toString(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _ActionButton(
                            icon: Icons.groups_outlined,
                            label: 'Manage Batch & Mortality',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MortalityScreen(
                                    batchName: currentBatch.name,
                                    dayLabel: currentBatch.dayLabel,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        ),
                      ),
                    ),
                      const SizedBox(height: 120),
                    ],
                  );
                },
              ),
            ),
          ],
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
            border: Border.all(
              color: Colors.white.withOpacity(0.74),
            ),
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
                        initialBatchName: _currentBatch.name,
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
                        initialBatchName: _currentBatch.name,
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

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = filled ? const Color(0xFF1DB954) : const Color(0xFFEAF7EC);
    final foreground = filled ? Colors.white : const Color(0xFF0C7D3A);
    final borderColor = filled ? Colors.transparent : const Color(0xFFD5EBD8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
        highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
        hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: const Color(0xFF1DB954).withOpacity(0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon == Icons.arrow_back_ios_new_rounded)
                Icon(icon, size: 14, color: foreground)
              else
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (icon == Icons.arrow_back_ios_new_rounded) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 8),
                Icon(icon, size: 16, color: foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardReveal extends StatelessWidget {
  final AnimationController controller;
  final double start;
  final double end;
  final Widget child;

  const _DashboardReveal({
    required this.controller,
    required this.start,
    required this.end,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - animation.value)),
            child: child,
          ),
        );
      },
    );
  }
}

class _DashboardAtmosphere extends StatelessWidget {
  const _DashboardAtmosphere();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.82, -0.55),
                  radius: 1.05,
                  colors: [
                    const Color(0xFF72C976).withOpacity(0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 180,
            left: -95,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFAEDDB2).withOpacity(0.18),
                border: Border.all(
                  color: const Color(0xFF78B77D).withOpacity(0.12),
                ),
              ),
            ),
          ),
          Positioned(
            top: 510,
            right: -125,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8DCD92).withOpacity(0.22),
                    const Color(0xFF8DCD92).withOpacity(0.02),
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

class _EnvironmentCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String statusLabel;
  final Color statusColor;
  final Color statusBackgroundColor;
  final String value;
  final String label;
  final String updatedText;
  final double? levelProgress;

  const _EnvironmentCard({
    required this.icon,
    required this.iconColor,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBackgroundColor,
    required this.value,
    required this.label,
    required this.updatedText,
    this.levelProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E9E4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF18321C).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            bottom: -42,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFB8D8BE).withOpacity(0.18),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 18,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB8D8BE).withOpacity(0.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          iconColor.withOpacity(0.18),
                          Colors.white.withOpacity(0.74),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: iconColor.withOpacity(0.14)),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const Spacer(),
                  if (statusLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackgroundColor,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withOpacity(0.22),
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF51607A),
                ),
              ),
              if (levelProgress != null) ...[
                const SizedBox(height: 12),
                _AnimatedLevelBar(
                  progress: levelProgress!,
                  color: iconColor,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                updatedText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF7E8DA5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedLevelBar extends StatelessWidget {
  final double progress;
  final Color color;

  const _AnimatedLevelBar({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Container(
          height: 7,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.68), color],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.20),
                    blurRadius: 7,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CountColumn extends StatelessWidget {
  final String label;
  final Color labelColor;
  final String value;

  const _CountColumn({
    required this.label,
    required this.labelColor,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: labelColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            height: 1.0,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFF1DB954).withOpacity(0.14),
        highlightColor: const Color(0xFF1DB954).withOpacity(0.10),
        hoverColor: const Color(0xFF1DB954).withOpacity(0.08),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE5EE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1DB954)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF45556D),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
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

