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

class _BatchesDashboardScreenState extends State<BatchesDashboardScreen> {
  late final Listenable _dashboardListenable = Listenable.merge([
    MonitoringStore.instance,
    TemperatureSettingsStore.instance,
  ]);

  final TextEditingController _currentDayController = TextEditingController();
  final TextEditingController _totalDaysController = TextEditingController();

  int _selectedNavIndex = 0;
  bool _isEditingDay = false;
  EnvironmentalLog? _latestEnvironmentalLog;

  @override
  void initState() {
    super.initState();
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
      backgroundColor: const Color(0xFFF6FAF7),
      body: SplashBackground(
        child: SafeArea(
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
                  : 'OFFLINE';
              final statusColor = telemetry.isLive
                  ? _temperatureStatusColor(condition)
                  : const Color(0xFF6B7280);
              final sourceText = telemetry.isLive
                  ? 'Live sensor'
                  : 'Last recorded';
              final totalBirds = BatchStore.instance.totalBirdsFor(currentBatch.name);
              final deaths = BatchStore.instance.mortalityCountFor(currentBatch.name);
              final batchStatusColors = _batchStatusColors(currentBatch.status);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                    Container(
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
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
                    const SizedBox(height: 18),
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
                    Row(
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
                            statusLabel: telemetry.isLive ? '' : 'OFFLINE',
                            statusColor: telemetry.isLive
                                ? const Color(0xFF3D7BFF)
                                : const Color(0xFF6B7280),
                            statusBackgroundColor: telemetry.isLive
                                ? const Color(0x143D7BFF)
                                : const Color(0x146B7280),
                            value: '${displayedHumidity.toStringAsFixed(0)}%',
                            label: 'Humidity',
                            updatedText:
                                '$sourceText - ${_updatedText(lastEnvironmentUpdate)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _EnvironmentCard(
                      icon: Icons.water_outlined,
                      iconColor: const Color(0xFF0E9F9A),
                      statusLabel:
                          telemetry.isWaterLevelLive ? 'LIVE' : 'OFFLINE',
                      statusColor: telemetry.isWaterLevelLive
                          ? const Color(0xFF0E9F9A)
                          : const Color(0xFF6B7280),
                      statusBackgroundColor: telemetry.isWaterLevelLive
                          ? const Color(0x140E9F9A)
                          : const Color(0x146B7280),
                      value: '${displayedWaterLevel.toStringAsFixed(0)}%',
                      label: 'Water Level',
                      updatedText: telemetry.isWaterLevelLive
                          ? 'HC-SR04 - ${displayedWaterDistance.toStringAsFixed(1)} cm from water'
                          : displayedWaterDistance > 0
                          ? 'Last recorded - ${displayedWaterDistance.toStringAsFixed(1)} cm from water'
                          : 'No recorded water reading',
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE3E9E4)),
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
                    const SizedBox(height: 120),
                ],
              );
            },
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
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  );
                },
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
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

  const _EnvironmentCard({
    required this.icon,
    required this.iconColor,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBackgroundColor,
    required this.value,
    required this.label,
    required this.updatedText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E9E4)),
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
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              if (statusLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBackgroundColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withOpacity(0.22)),
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
          const SizedBox(height: 10),
          Text(
            updatedText,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF92A0B7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
        child: Container(
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

