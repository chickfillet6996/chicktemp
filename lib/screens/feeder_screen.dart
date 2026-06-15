import 'package:flutter/material.dart';

import 'analytics_screen.dart';
import '../models/auth_store.dart';
import '../models/device_config_store.dart';
import '../models/monitoring_store.dart';
import '../widgets/user_avatar_content.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';

class FeederScreen extends StatefulWidget {
  final String batchName;

  const FeederScreen({super.key, required this.batchName});

  @override
  State<FeederScreen> createState() => _FeederScreenState();
}

class _FeederScreenState extends State<FeederScreen> {
  final List<_FeederDevice> _devices = [];
  final List<String> _globalSchedules = [];
  final Map<String, List<String>> _deviceSchedules = {};
  bool _mainEnabled = false;
  bool _expanded = true;
  int _selectedNavIndex = 0;
  bool _isLoading = true;

  bool get _hasDevices => _devices.isNotEmpty;

  @override
  void initState() {
    super.initState();
    MonitoringStore.instance.addListener(_onTelemetryChanged);
    MonitoringStore.instance.start();
    _loadSavedConfig();
  }

  @override
  void dispose() {
    MonitoringStore.instance.removeListener(_onTelemetryChanged);
    super.dispose();
  }

  void _onTelemetryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
    _persistConfig();
  }

  Future<void> _openAddDeviceSheet() async {
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
      _devices.insert(0, result);
      _expanded = true;
    });
    _persistConfig();
  }

  Future<void> _openAddScheduleSheet({String? deviceId}) async {
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
        _globalSchedules.add(label);
      } else {
        _deviceSchedules.putIfAbsent(deviceId, () => <String>[]).add(label);
      }
    });
    _persistConfig();
  }

  Future<void> _loadSavedConfig() async {
    try {
      final data = await DeviceConfigStore.instance.loadFeederConfig(
        batchName: widget.batchName,
      );
      if (!mounted) {
        return;
      }

      final savedDevices = (data?['devices'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_FeederDevice.fromJson)
          .toList();
      final savedGlobalSchedules =
          (data?['global_schedules'] as List<dynamic>? ?? const [])
              .map((entry) => entry.toString())
              .toList();
      final savedDeviceSchedules = <String, List<String>>{};
      final rawDeviceSchedules = data?['device_schedules'];
      if (rawDeviceSchedules is Map<String, dynamic>) {
        for (final entry in rawDeviceSchedules.entries) {
          savedDeviceSchedules[entry.key] = (entry.value as List<dynamic>? ??
                  const [])
              .map((item) => item.toString())
              .toList();
        }
      }

      setState(() {
        _devices
          ..clear()
          ..addAll(savedDevices);
        _globalSchedules
          ..clear()
          ..addAll(savedGlobalSchedules);
        _deviceSchedules
          ..clear()
          ..addAll(savedDeviceSchedules);
        _mainEnabled = data?['main_enabled'] == true;
        _expanded = data?['expanded'] as bool? ?? true;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('Could not load feeder settings: $error');
    }
  }

  Future<void> _persistConfig() async {
    try {
      await DeviceConfigStore.instance.saveFeederConfig(
        batchName: widget.batchName,
        data: {
          'main_enabled': _mainEnabled,
          'expanded': _expanded,
          'devices': _devices.map((device) => device.toJson()).toList(),
          'global_schedules': List<String>.from(_globalSchedules),
          'device_schedules': {
            for (final entry in _deviceSchedules.entries)
              entry.key: List<String>.from(entry.value),
          },
        },
      );
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Could not save feeder settings: $error');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _hasDevices
        ? '${_devices.length} Device${_devices.length == 1 ? '' : 's'} Connected'
        : 'No Devices';
    final headerTint = _hasDevices
        ? const Color(0xFFFCEFD9)
        : const Color(0xFFF8E7D0);

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF4F7F3),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -70,
              child: _SoftShape(
                color: const Color(0xFF2E7D32).withOpacity(0.08),
                size: 230,
              ),
            ),
            Positioned(
              top: 160,
              left: -70,
              child: _SoftShape(
                color: const Color(0xFFBFE8C6).withOpacity(0.24),
                size: 190,
              ),
            ),
            Positioned(
              bottom: 100,
              right: -80,
              child: _SoftShape(
                color: const Color(0xFFBFE8C6).withOpacity(0.2),
                size: 260,
              ),
            ),
            ListView(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Colors.white70,
                                ),
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
                              'Auto Feeders',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Feeding control and schedules',
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
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
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
                _FeederDropdownHeader(
                  tint: headerTint,
                  subtitle: subtitle,
                  expanded: _expanded,
                  onTap: _toggleExpanded,
                ),
                const SizedBox(height: 12),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: _expanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0BB13F),
                            ),
                          ),
                        )
                      : _buildExpandedContent(),
                  secondChild: const SizedBox.shrink(),
                ),
                const SizedBox(height: 120),
              ],
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

  Widget _buildExpandedContent() {
    final hasDevice = _hasDevices;
    final telemetry = MonitoringStore.instance.snapshotFor(widget.batchName);

    return Column(
      children: [
        _FeederLevelCard(telemetry: telemetry),
        const SizedBox(height: 12),
        _FeederControlCard(
          enabled: _mainEnabled,
          onChanged: (value) {
            setState(() {
              _mainEnabled = value;
            });
            _persistConfig();
          },
        ),
        const SizedBox(height: 12),
        _FeederScheduleCard(
          title: 'MANAGE SCHEDULE',
          buttonLabel: '+ Add Schedule',
          emptyText: 'No global schedule set',
          schedules: _globalSchedules,
          onAddSchedule: () => _openAddScheduleSheet(),
        ),
        if (hasDevice)
          ...List.generate(_devices.length, (index) {
            final device = _devices[index];
            final schedules = _deviceSchedules[device.id] ?? const <String>[];
            final isLast = index == _devices.length - 1;
            return Padding(
              padding: EdgeInsets.only(top: 12, bottom: isLast ? 0 : 12),
              child: Column(
                children: [
                  _FeederDeviceCard(
                    index: index,
                    device: device,
                    onDeleteDevice: (deleteIndex) {
                      setState(() {
                        if (deleteIndex >= 0 && deleteIndex < _devices.length) {
                          final removedDevice = _devices.removeAt(deleteIndex);
                          _deviceSchedules.remove(removedDevice.id);
                        }
                      });
                      _persistConfig();
                    },
                    onToggleDevice: (deviceIndex, value) {
                      setState(() {
                        if (deviceIndex >= 0 && deviceIndex < _devices.length) {
                          _devices[deviceIndex] = _devices[deviceIndex]
                              .copyWith(enabled: value);
                        }
                      });
                      _persistConfig();
                    },
                  ),
                  const SizedBox(height: 12),
                  _FeederScheduleCard(
                    title: 'FEEDING SCHEDULE',
                    buttonLabel: '+ Add Schedule',
                    emptyText: 'No feeding schedule set for this device',
                    schedules: schedules,
                    onAddSchedule: () =>
                        _openAddScheduleSheet(deviceId: device.id),
                  ),
                ],
              ),
            );
          })
        else ...[
          const SizedBox(height: 12),
          const _EmptyFeederPlaceholder(),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _openAddDeviceSheet,
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
    );
  }
}

class _FeederLevelCard extends StatelessWidget {
  final BatchTelemetry telemetry;

  const _FeederLevelCard({required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final hasReading =
        telemetry.isFeederLevelLive || telemetry.feederDistanceCm > 0;
    final level = hasReading ? telemetry.feederLevelPercent : 0.0;
    final status = telemetry.isFeederLevelLive
        ? 'LIVE'
        : hasReading
        ? 'OFFLINE'
        : 'NO DATA';
    final statusColor = telemetry.isFeederLevelLive
        ? const Color(0xFF2E7D32)
        : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0DFC4)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFCE9CB),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.restaurant_outlined,
              color: Color(0xFFB45309),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Feeder Level',
                  style: TextStyle(
                    color: Color(0xFF5D4930),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasReading ? '${level.toStringAsFixed(0)}%' : '--',
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeederDropdownHeader extends StatelessWidget {
  final Color tint;
  final String subtitle;
  final bool expanded;
  final VoidCallback onTap;

  const _FeederDropdownHeader({
    required this.tint,
    required this.subtitle,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
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
                child: const Icon(
                  Icons.flash_on_outlined,
                  color: Color(0xFFF57C00),
                  size: 24,
                ),
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
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFFB84D00),
                    size: 22,
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

class _FeederControlCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _FeederControlCard({required this.enabled, required this.onChanged});

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
              color: enabled
                  ? const Color(0xFF24B26A)
                  : const Color(0xFF93A0B6),
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
  final String emptyText;
  final List<String> schedules;
  final VoidCallback onAddSchedule;

  const _FeederScheduleCard({
    required this.title,
    required this.buttonLabel,
    required this.emptyText,
    required this.schedules,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
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
                  device.description.isNotEmpty
                      ? device.description
                      : device.id,
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
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: Color(0xFFD0D7E5),
            ),
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete device',
          ),
          Text(
            device.enabled ? 'ON' : 'OFF',
            style: TextStyle(
              color: device.enabled
                  ? const Color(0xFF24B26A)
                  : const Color(0xFF93A0B6),
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

class _FeederDevice {
  final String name;
  final String id;
  final String type;
  final String description;
  final bool enabled;

  const _FeederDevice({
    required this.name,
    required this.id,
    required this.type,
    required this.description,
    required this.enabled,
  });

  _FeederDevice copyWith({
    String? name,
    String? id,
    String? type,
    String? description,
    bool? enabled,
  }) {
    return _FeederDevice(
      name: name ?? this.name,
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
    );
  }

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

class _EmptyFeederPlaceholder extends StatelessWidget {
  const _EmptyFeederPlaceholder();

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
  final TextEditingController _typeController = TextEditingController(
    text: 'Feeder',
  );
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
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'Auto Feeder 1',
        id: _idController.text.trim().isNotEmpty
            ? _idController.text.trim()
            : 'FED001',
        type: _typeController.text.trim().isNotEmpty
            ? _typeController.text.trim()
            : 'Feeder',
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
                const SizedBox(height: 14),
                const _SheetLabel('DEVICE NAME'),
                const SizedBox(height: 6),
                _SheetTextField(
                  controller: _nameController,
                  hintText: 'e.g. Ventilation Fan 2',
                ),
                const SizedBox(height: 10),
                const _SheetLabel('DEVICE ID'),
                const SizedBox(height: 6),
                _SheetTextField(
                  controller: _idController,
                  hintText: 'e.g. FAN002',
                ),
                const SizedBox(height: 10),
                const _SheetLabel('DEVICE TYPE'),
                const SizedBox(height: 6),
                _SheetTextField(
                  controller: _typeController,
                  hintText: 'Feeder',
                ),
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

  const _FeederScheduleDraft({required this.time, required this.active});
}

class _AddFeederScheduleSheet extends StatefulWidget {
  const _AddFeederScheduleSheet();

  @override
  State<_AddFeederScheduleSheet> createState() =>
      _AddFeederScheduleSheetState();
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
      _FeederScheduleDraft(
        time: _selectedTime.format(context),
        active: _active,
      ),
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
            _TimeField(time: _selectedTime, onTap: _pickTime),
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

  const _TimeField({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCE4EE)),
        ),
        child: Row(
          children: [
            Text(
              time.format(context),
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.schedule_outlined,
              size: 18,
              color: Color(0xFFB7C0CD),
            ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F6EA) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFA8E7B8) : const Color(0xFFDCE4EE),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF0B8F39) : const Color(0xFF8A96AC),
            fontWeight: FontWeight.w800,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
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

class _SoftShape extends StatelessWidget {
  final Color color;
  final double size;

  const _SoftShape({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
