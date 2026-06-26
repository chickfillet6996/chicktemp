import 'package:flutter/material.dart';

import '../widgets/chicktemp_loading.dart';
import '../widgets/control_motion.dart';

class ScheduleRepeat {
  const ScheduleRepeat._();

  static const int allDaysMask = 0x7F;
  static const List<int> displayOrder = [1, 2, 3, 4, 5, 6, 0];
  static const List<String> labels = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  static int maskForDay(int day) => 1 << day;

  static String labelForMask(int mask) {
    final normalized = mask <= 0 ? allDaysMask : mask & allDaysMask;
    if (normalized == allDaysMask) {
      return 'Every day';
    }
    const weekdaysMask = 0x3E;
    const weekendsMask = 0x41;
    if (normalized == weekdaysMask) {
      return 'Weekdays';
    }
    if (normalized == weekendsMask) {
      return 'Weekends';
    }
    return displayOrder
        .where((day) => (normalized & maskForDay(day)) != 0)
        .map((day) => labels[day])
        .join(', ');
  }

  static int maskFromScheduleLabel(String label) {
    final parts = label.split(' - ');
    if (parts.length < 5) {
      return allDaysMask;
    }
    return maskFromRepeatLabel(parts[1]);
  }

  static int maskFromRepeatLabel(String label) {
    final lower = label.trim().toLowerCase();
    if (lower.isEmpty || lower == 'every day' || lower == 'daily') {
      return allDaysMask;
    }
    if (lower == 'weekdays') {
      return 0x3E;
    }
    if (lower == 'weekends') {
      return 0x41;
    }

    var mask = 0;
    for (var day = 0; day < labels.length; day++) {
      if (lower.contains(labels[day].toLowerCase())) {
        mask |= maskForDay(day);
      }
    }
    return mask == 0 ? allDaysMask : mask;
  }
}

class ScheduleDaySelector extends StatelessWidget {
  final int selectedMask;
  final ValueChanged<int> onChanged;
  final Color accentColor;

  const ScheduleDaySelector({
    super.key,
    required this.selectedMask,
    required this.onChanged,
    this.accentColor = const Color(0xFF0BB13F),
  });

  @override
  Widget build(BuildContext context) {
    final normalizedMask = selectedMask <= 0
        ? ScheduleRepeat.allDaysMask
        : selectedMask & ScheduleRepeat.allDaysMask;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final day in ScheduleRepeat.displayOrder)
          _DayChip(
            label: ScheduleRepeat.labels[day],
            selected:
                (normalizedMask & ScheduleRepeat.maskForDay(day)) != 0,
            accentColor: accentColor,
            onTap: () {
              final bit = ScheduleRepeat.maskForDay(day);
              final nextMask = (normalizedMask & bit) == 0
                  ? normalizedMask | bit
                  : normalizedMask & ~bit;
              onChanged(nextMask);
            },
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 46,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accentColor.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accentColor : const Color(0xFFDCE4EE),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accentColor : const Color(0xFF8A96AC),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class WaterScheduleDraft {
  final String time;
  final bool active;
  final double liters;
  final int durationSeconds;
  final int daysMask;

  const WaterScheduleDraft({
    required this.time,
    required this.active,
    required this.liters,
    required this.durationSeconds,
    this.daysMask = ScheduleRepeat.allDaysMask,
  });
}

class WaterDevice {
  final String name;
  final String id;
  final String type;
  final String description;
  final bool enabled;

  const WaterDevice({
    required this.name,
    required this.id,
    required this.type,
    required this.description,
    required this.enabled,
  });

  WaterDevice copyWith({
    String? name,
    String? id,
    String? type,
    String? description,
    bool? enabled,
  }) {
    return WaterDevice(
      name: name ?? this.name,
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
    );
  }

  factory WaterDevice.fromJson(Map<String, dynamic> json) {
    return WaterDevice(
      name: json['name']?.toString() ?? 'Water Line 1',
      id: json['id']?.toString() ?? 'WTR001',
      type: json['type']?.toString() ?? 'Water',
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

class WaterSupplyDropdownCard extends StatelessWidget {
  final bool expanded;
  final List<WaterDevice> devices;
  final bool masterEnabled;
  final bool continuousEnabled;
  final bool manualWaterBusy;
  final VoidCallback onTapHeader;
  final VoidCallback onAddGlobalSchedule;
  final void Function(int index) onAddDeviceSchedule;
  final void Function(int scheduleIndex) onEditGlobalSchedule;
  final void Function(int scheduleIndex) onDeleteGlobalSchedule;
  final void Function(int deviceIndex, int scheduleIndex) onEditDeviceSchedule;
  final void Function(int deviceIndex, int scheduleIndex) onDeleteDeviceSchedule;
  final ValueChanged<bool> onToggleMaster;
  final ValueChanged<bool> onToggleContinuous;
  final VoidCallback onManualWater;
  final void Function(int index) onDeleteDevice;
  final void Function(int index, bool value) onToggleDevice;
  final List<String> globalSchedules;
  final Map<String, List<String>> deviceSchedules;
  final double waterLevelPercent;
  final double waterDistanceCm;
  final bool waterLevelLive;
  final bool hideDefaultsWhenEmpty;

  const WaterSupplyDropdownCard({
    super.key,
    required this.expanded,
    required this.devices,
    required this.masterEnabled,
    required this.continuousEnabled,
    required this.manualWaterBusy,
    required this.onTapHeader,
    required this.onAddGlobalSchedule,
    required this.onAddDeviceSchedule,
    required this.onEditGlobalSchedule,
    required this.onDeleteGlobalSchedule,
    required this.onEditDeviceSchedule,
    required this.onDeleteDeviceSchedule,
    required this.onToggleMaster,
    required this.onToggleContinuous,
    required this.onManualWater,
    required this.onDeleteDevice,
    required this.onToggleDevice,
    required this.globalSchedules,
    required this.deviceSchedules,
    required this.waterLevelPercent,
    required this.waterDistanceCm,
    required this.waterLevelLive,
    this.hideDefaultsWhenEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasDevice = devices.isNotEmpty;
    final showDefaultComponents = hasDevice || !hideDefaultsWhenEmpty;
    final headerColor = hasDevice
        ? const Color(0xFFE6F0FF)
        : const Color(0xFFEAF2FF);
    final subtitle = waterLevelLive ? 'Online' : 'Offline';

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
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.water_drop_outlined,
                      color: Color(0xFF1F5BFF),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Water Supply Lines',
                          style: TextStyle(
                            color: Color(0xFF173A93),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF1F5BFF),
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
                        color: const Color(0xFFCFE0FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF1F5BFF),
                        size: 22,
                      ),
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
                  if (showDefaultComponents) ...[
                    _WaterLevelCard(
                      levelPercent: waterLevelPercent,
                      distanceCm: waterDistanceCm,
                      isLive: waterLevelLive,
                    ),
                    const SizedBox(height: 12),
                    _WaterControlCard(
                      powerEnabled: masterEnabled,
                      continuousEnabled: continuousEnabled,
                      manualWaterBusy: manualWaterBusy,
                      onPowerChanged: onToggleMaster,
                      onContinuousChanged: onToggleContinuous,
                      onManualWater: onManualWater,
                    ),
                    const SizedBox(height: 12),
                    _WaterScheduleCard(
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
                        final device = devices[index];
                        final schedules =
                            deviceSchedules[device.id] ?? const <String>[];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == devices.length - 1 ? 0 : 12,
                          ),
                          child: Column(
                            children: [
                              _WaterDeviceCard(
                                device: device,
                                onDelete: () => onDeleteDevice(index),
                                onChanged: (value) =>
                                    onToggleDevice(index, value),
                              ),
                              const SizedBox(height: 12),
                              _WaterScheduleCard(
                                title: 'WATER SCHEDULE',
                                buttonLabel: '+ Add Schedule',
                                schedules: schedules,
                                emptyText:
                                    'No water schedule set for this device',
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterLevelCard extends StatelessWidget {
  final double levelPercent;
  final double distanceCm;
  final bool isLive;

  const _WaterLevelCard({
    required this.levelPercent,
    required this.distanceCm,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    final level = isLive ? levelPercent.clamp(0, 100).toDouble() : 0.0;
    final levelColor = level <= 20
        ? const Color(0xFFE5484D)
        : level <= 45
        ? const Color(0xFFF59E0B)
        : const Color(0xFF0E9F9A);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLive ? const Color(0xFFF7FFFD) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLive
              ? const Color(0xFFB9ECE8)
              : const Color(0xFFE3E9E4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, color: Color(0xFF0E9F9A), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'HC-SR04 WATER LEVEL',
                  style: TextStyle(
                    color: Color(0xFF233047),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                isLive ? '${level.toStringAsFixed(0)}%' : 'NO READING',
                style: TextStyle(
                  color: isLive ? levelColor : const Color(0xFF93A0B6),
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
            isLive
                ? '${distanceCm.toStringAsFixed(1)} cm between sensor and water surface'
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

class _WaterControlCard extends StatelessWidget {
  final bool powerEnabled;
  final bool continuousEnabled;
  final bool manualWaterBusy;
  final ValueChanged<bool> onPowerChanged;
  final ValueChanged<bool> onContinuousChanged;
  final VoidCallback onManualWater;

  const _WaterControlCard({
    required this.powerEnabled,
    required this.continuousEnabled,
    required this.manualWaterBusy,
    required this.onPowerChanged,
    required this.onContinuousChanged,
    required this.onManualWater,
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
        color: powerEnabled ? const Color(0xFFF8FBFF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: powerEnabled
              ? const Color(0xFFBFD0FF)
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
                      '12V Water Pump Relay',
                      style: TextStyle(
                        color: Color(0xFF233047),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Controls relay K1 / IN1.\nPump uses the separate 12V supply.',
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
                  ? const Color(0xFFEFF5FF)
                  : const Color(0xFFF5F8FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD5E2FF)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continuous Pump',
                        style: TextStyle(
                          color: Color(0xFF173A93),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Keeps water flowing until turned off.',
                        style: TextStyle(
                          color: Color(0xFF637699),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ControlAnimatedStatus(
                  text: continuousActive ? 'PUMPING' : 'IDLE',
                  style: TextStyle(
                    color: continuousActive
                        ? const Color(0xFF1F5BFF)
                        : const Color(0xFF93A0B6),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: continuousActive,
                  onChanged: powerEnabled ? onContinuousChanged : null,
                  activeColor: const Color(0xFF1F5BFF),
                  activeTrackColor: const Color(0xFFCFE0FF),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFD9E4D9),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: powerEnabled && !manualWaterBusy ? onManualWater : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1F5BFF),
                disabledForegroundColor: const Color(0xFF98A2B3),
                side: const BorderSide(color: Color(0xFFBFD0FF)),
                backgroundColor: powerEnabled
                    ? const Color(0xFFF5F8FF)
                    : const Color(0xFFF4F5F7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: manualWaterBusy
                  ? const ChickTempLoading.compact(
                      size: 18,
                      color: Color(0xFF1F5BFF),
                    )
                  : const Icon(Icons.water_drop_outlined, size: 17),
              label: Text(
                manualWaterBusy ? 'Starting Water...' : 'Manual Water by Liters',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterScheduleCard extends StatelessWidget {
  final String title;
  final String buttonLabel;
  final List<String> schedules;
  final String emptyText;
  final VoidCallback onAddSchedule;
  final void Function(int scheduleIndex) onEditSchedule;
  final void Function(int scheduleIndex) onDeleteSchedule;

  const _WaterScheduleCard({
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
                  foregroundColor: const Color(0xFF1F5BFF),
                  side: const BorderSide(color: Color(0xFFBFD0FF)),
                  backgroundColor: const Color(0xFFF5F8FF),
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
              children: List.generate(
                schedules.length,
                (index) {
                  final schedule = schedules[index];
                  return Padding(
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

class _WaterDeviceCard extends StatelessWidget {
  final WaterDevice device;
  final VoidCallback onDelete;
  final ValueChanged<bool> onChanged;

  const _WaterDeviceCard({
    required this.device,
    required this.onDelete,
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
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: Color(0xFFD0D7E5),
            ),
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete device',
          ),
          ControlAnimatedStatus(
            text: device.enabled ? 'ON' : 'OFF',
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

class AddWaterScheduleSheet extends StatefulWidget {
  final WaterScheduleDraft? initialDraft;

  const AddWaterScheduleSheet({super.key, this.initialDraft});

  @override
  State<AddWaterScheduleSheet> createState() => _AddWaterScheduleSheetState();
}

class _AddWaterScheduleSheetState extends State<AddWaterScheduleSheet> {
  static const double _secondsPerLiter = 20;

  late bool _active;
  late TimeOfDay _selectedTime;
  late int _daysMask;
  late final TextEditingController _litersController;

  @override
  void initState() {
    super.initState();
    final initialDraft = widget.initialDraft;
    _active = initialDraft?.active ?? true;
    _selectedTime = _parseTimeOfDay(initialDraft?.time) ??
        const TimeOfDay(hour: 6, minute: 0);
    _daysMask = initialDraft?.daysMask ?? ScheduleRepeat.allDaysMask;
    _litersController = TextEditingController(
      text: initialDraft == null
          ? '1.0'
          : _formatDecimal(initialDraft.liters),
    );
  }

  String _formatDecimal(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
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
    _litersController.dispose();
    super.dispose();
  }

  int get _durationSeconds {
    final liters = double.tryParse(_litersController.text.trim()) ?? 1.0;
    return (liters.clamp(0.1, 20) * _secondsPerLiter).round();
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
    final liters = double.tryParse(_litersController.text.trim());
    if (_daysMask <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose at least one repeat day.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (liters == null || liters <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid water amount in liters.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      WaterScheduleDraft(
        time: _selectedTime.format(context),
        active: _active,
        liters: liters,
        durationSeconds: (liters * _secondsPerLiter).round(),
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
                        ? 'Add Water Schedule'
                        : 'Edit Water Schedule',
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
              'All Water Devices',
              style: TextStyle(
                color: Color(0xFF8A96AC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const _SheetLabel('WATER TIME'),
            const SizedBox(height: 6),
            _TimeField(time: _selectedTime, onTap: _pickTime),
            const SizedBox(height: 14),
            const _SheetLabel('REPEAT DAYS'),
            const SizedBox(height: 8),
            ScheduleDaySelector(
              selectedMask: _daysMask,
              accentColor: const Color(0xFF1F5BFF),
              onChanged: (mask) => setState(() => _daysMask = mask),
            ),
            const SizedBox(height: 14),
            const _SheetLabel('WATER AMOUNT'),
            const SizedBox(height: 6),
            TextField(
              controller: _litersController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                suffixText: 'liters',
                helperText:
                    'Estimated pump time: $_durationSeconds seconds',
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
                  borderSide: const BorderSide(color: Color(0xFF90E3A9)),
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
            Expanded(
              child: Text(
                time.format(context),
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.schedule_outlined,
              size: 18,
              color: Color(0xFF63748A),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAFBF0) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF90E3A9) : const Color(0xFFDCE4EE),
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
