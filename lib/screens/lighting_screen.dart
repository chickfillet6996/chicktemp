import 'package:flutter/material.dart';

class LightingDevice {
  final String name;
  final String id;
  final String type;
  final String description;
  final bool enabled;
  final String brightness;

  const LightingDevice({
    required this.name,
    required this.id,
    required this.type,
    required this.description,
    required this.enabled,
    required this.brightness,
  });

  LightingDevice copyWith({
    String? name,
    String? id,
    String? type,
    String? description,
    bool? enabled,
    String? brightness,
  }) {
    return LightingDevice(
      name: name ?? this.name,
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      brightness: brightness ?? this.brightness,
    );
  }

  factory LightingDevice.fromJson(Map<String, dynamic> json) {
    return LightingDevice(
      name: json['name']?.toString() ?? 'Light 1',
      id: json['id']?.toString() ?? 'LGT001',
      type: json['type']?.toString() ?? 'Lighting',
      description: json['description']?.toString() ?? '',
      enabled: json['enabled'] == true,
      brightness: json['brightness']?.toString() ?? 'Medium',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'type': type,
      'description': description,
      'enabled': enabled,
      'brightness': brightness,
    };
  }
}

class LightingSystemDropdownCard extends StatelessWidget {
  final bool expanded;
  final List<LightingDevice> devices;
  final bool masterEnabled;
  final VoidCallback onTapHeader;
  final VoidCallback onAddDevice;
  final ValueChanged<bool> onToggleMaster;
  final void Function(int index) onAddSchedule;
  final void Function(int index) onDeleteDevice;
  final void Function(int index, bool value) onToggleDevice;
  final void Function(int index, String brightness) onSetBrightness;
  final Map<String, List<String>> deviceSchedules;

  const LightingSystemDropdownCard({
    super.key,
    required this.expanded,
    required this.devices,
    required this.masterEnabled,
    required this.onTapHeader,
    required this.onAddDevice,
    required this.onToggleMaster,
    required this.onAddSchedule,
    required this.onDeleteDevice,
    required this.onToggleDevice,
    required this.onSetBrightness,
    required this.deviceSchedules,
  });

  @override
  Widget build(BuildContext context) {
    final hasDevice = devices.isNotEmpty;
    final subtitle =
        hasDevice ? '${devices.length} Device${devices.length == 1 ? '' : 's'} Connected' : 'No Devices';
    final headerColor = hasDevice ? const Color(0xFFFFF6D6) : const Color(0xFFFFF9E8);

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
                    child: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFD28A00), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lighting System',
                          style: TextStyle(
                            color: Color(0xFF7A4C00),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFFB06B00),
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
                        color: const Color(0xFFFFE9A8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFB06B00), size: 22),
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
                  _LightingRelayControlCard(
                    enabled: masterEnabled,
                    onChanged: onToggleMaster,
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
                            _LightingDeviceCard(
                              device: device,
                              onDelete: () => onDeleteDevice(index),
                              onToggle: (value) => onToggleDevice(index, value),
                              onSetBrightness: (brightness) => onSetBrightness(index, brightness),
                            ),
                            const SizedBox(height: 12),
                            _LightingScheduleCard(
                              title: 'LIGHTING SCHEDULE',
                              buttonLabel: '+ Add Schedule',
                              schedules: schedules,
                              emptyText: 'No lighting schedule set for this device',
                              onAddSchedule: () => onAddSchedule(index),
                            ),
                          ],
                        ),
                      );
                    })
                  else ...[
                    const _EmptyLightingPlaceholder(),
                  ],
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
                        'Add Lighting System Device',
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

class _LightingRelayControlCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _LightingRelayControlCard({
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
              children: const [
                Text(
                  'Light Bulb Relay',
                  style: TextStyle(
                    color: Color(0xFF233047),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Controls relay K2 / IN2.\nBulb uses the separate power line.',
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
              color: enabled ? const Color(0xFFD28A00) : const Color(0xFF93A0B6),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: const Color(0xFFD28A00),
            activeTrackColor: const Color(0xFFFFE9A8),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD9E4D9),
          ),
        ],
      ),
    );
  }
}

class _LightingDeviceCard extends StatelessWidget {
  final LightingDevice? device;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onToggle;
  final ValueChanged<String>? onSetBrightness;

  const _LightingDeviceCard({
    required this.device,
    required this.onDelete,
    required this.onToggle,
    required this.onSetBrightness,
  });

  @override
  Widget build(BuildContext context) {
    if (device == null) {
      return Container(
        width: double.infinity,
        height: 54,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device!.name,
                      style: const TextStyle(
                        color: Color(0xFF233047),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device!.description.isNotEmpty ? device!.description : device!.id,
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
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFD0D7E5)),
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete device',
              ),
              const Text(
                'OFF',
                style: TextStyle(
                  color: Color(0xFF93A0B6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: device!.enabled,
                onChanged: onToggle,
                activeColor: const Color(0xFF24B26A),
                activeTrackColor: const Color(0xFFB9EBC9),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFD9E4D9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'BRIGHTNESS',
                  style: TextStyle(
                    color: Color(0xFFB2BCCB),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Text(
                device!.brightness,
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
                child: _BrightnessButton(
                  label: 'Low',
                  selected: device!.brightness == 'Low',
                  onTap: () => onSetBrightness?.call('Low'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BrightnessButton(
                  label: 'Medium',
                  selected: device!.brightness == 'Medium',
                  onTap: () => onSetBrightness?.call('Medium'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BrightnessButton(
                  label: 'High',
                  selected: device!.brightness == 'High',
                  onTap: () => onSetBrightness?.call('High'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrightnessButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BrightnessButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = {
      'Low': const Color(0xFFB58AD8),
      'Medium': const Color(0xFFF0BE53),
      'High': const Color(0xFFF5A623),
    };
    final color = colors[label] ?? const Color(0xFFF0BE53);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : const Color(0xFFDCE4EE)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : const Color(0xFF8A96AC),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LightingScheduleCard extends StatelessWidget {
  final String title;
  final String buttonLabel;
  final List<String> schedules;
  final String emptyText;
  final VoidCallback onAddSchedule;

  const _LightingScheduleCard({
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
                  foregroundColor: const Color(0xFFF0B400),
                  side: const BorderSide(color: Color(0xFFF6D56D)),
                  backgroundColor: const Color(0xFFFFFAE8),
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

class _EmptyLightingPlaceholder extends StatelessWidget {
  const _EmptyLightingPlaceholder();

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

class AddLightingDeviceSheet extends StatefulWidget {
  const AddLightingDeviceSheet({super.key});

  @override
  State<AddLightingDeviceSheet> createState() => _AddLightingDeviceSheetState();
}

class _AddLightingDeviceSheetState extends State<AddLightingDeviceSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _typeController = TextEditingController(text: 'Lighting');
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
      LightingDevice(
        name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Light 1',
        id: _idController.text.trim().isNotEmpty ? _idController.text.trim() : 'LGT001',
        type: _typeController.text.trim().isNotEmpty ? _typeController.text.trim() : 'Lighting',
        description: _descriptionController.text.trim(),
        enabled: true,
        brightness: 'Medium',
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
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _SheetLabel('DEVICE NAME'),
                const SizedBox(height: 6),
                _SheetTextField(controller: _nameController, hintText: 'e.g. Lighting 1'),
                const SizedBox(height: 10),
                const _SheetLabel('DEVICE ID'),
                const SizedBox(height: 6),
                _SheetTextField(controller: _idController, hintText: 'e.g. LGT001'),
                const SizedBox(height: 10),
                const _SheetLabel('DEVICE TYPE'),
                const SizedBox(height: 6),
                _SheetTextField(controller: _typeController, hintText: 'Lighting'),
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

class LightingScheduleDraft {
  final String time;
  final String action;
  final bool active;

  const LightingScheduleDraft({
    required this.time,
    required this.action,
    required this.active,
  });
}

class AddLightingScheduleSheet extends StatefulWidget {
  const AddLightingScheduleSheet({super.key});

  @override
  State<AddLightingScheduleSheet> createState() => _AddLightingScheduleSheetState();
}

class _AddLightingScheduleSheetState extends State<AddLightingScheduleSheet> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 6, minute: 0);
  String _action = 'Lights ON';
  bool _active = true;

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
      LightingScheduleDraft(
        time: _selectedTime.format(context),
        action: _action,
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
                    'Add Lighting Schedule',
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
            const SizedBox(height: 10),
            const Text(
              'All Lighting Devices',
              style: TextStyle(
                color: Color(0xFF8A96AC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const _SheetLabel('SCHEDULE TIME'),
            const SizedBox(height: 6),
            _TimeField(
              time: _selectedTime,
              onTap: _pickTime,
            ),
            const SizedBox(height: 14),
            const _SheetLabel('ACTION'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    label: 'Lights ON',
                    selected: _action == 'Lights ON',
                    onTap: () => setState(() => _action = 'Lights ON'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PillButton(
                    label: 'Lights OFF',
                    selected: _action == 'Lights OFF',
                    onTap: () => setState(() => _action = 'Lights OFF'),
                  ),
                ),
              ],
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
                  backgroundColor: const Color(0xFFF0B400),
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
            const Icon(Icons.schedule_outlined, size: 18, color: Color(0xFF63748A)),
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
          border: Border.all(color: selected ? const Color(0xFF90E3A9) : const Color(0xFFDCE4EE)),
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
