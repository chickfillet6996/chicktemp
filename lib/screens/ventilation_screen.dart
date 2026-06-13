import 'package:flutter/material.dart';

import 'analytics_screen.dart';
import '../models/auth_store.dart';
import '../models/device_config_store.dart';
import '../widgets/user_avatar_content.dart';
import 'reports_screen.dart';

class VentilationScreen extends StatefulWidget {
  final String batchName;

  const VentilationScreen({
    super.key,
    required this.batchName,
  });

  @override
  State<VentilationScreen> createState() => _VentilationScreenState();
}

class _VentilationScreenState extends State<VentilationScreen> {
  final List<_FanDevice> _devices = [];
  int _selectedNavIndex = 0;
  bool _expanded = true;
  bool _isLoading = true;

  bool get _hasDevices => _devices.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadSavedDevices();
  }

  void _addDevice(_FanDeviceDraft device) {
    setState(() {
      _devices.insert(
        0,
        _FanDevice(
          name: device.name,
          id: device.id,
          type: device.type,
          description: device.description,
        ),
      );
    });
    _persistDevices();
  }

  void _removeDeviceAt(int index) {
    setState(() {
      _devices.removeAt(index);
    });
    _persistDevices();
  }

  void _setDeviceEnabled(int index, bool value) {
    setState(() {
      _devices[index].enabled = value;
    });
    _persistDevices();
  }

  void _setDeviceSpeed(int index, int speed) {
    setState(() {
      _devices[index].speed = speed;
    });
    _persistDevices();
  }

  Future<void> _openAddDeviceSheet() async {
    final device = await showModalBottomSheet<_FanDeviceDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddDeviceSheet(batchName: widget.batchName),
    );

    if (!mounted || device == null) {
      return;
    }

    _addDevice(device);
  }

  Future<void> _loadSavedDevices() async {
    try {
      final data = await DeviceConfigStore.instance.loadVentilationConfig(
        batchName: widget.batchName,
      );
      if (!mounted) {
        return;
      }

      final savedDevices = (data?['devices'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_FanDevice.fromJson)
          .toList();

      setState(() {
        _devices
          ..clear()
          ..addAll(savedDevices);
        _expanded = data?['expanded'] as bool? ?? true;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('Could not load ventilation devices: $error');
    }
  }

  Future<void> _persistDevices() async {
    try {
      await DeviceConfigStore.instance.saveVentilationConfig(
        batchName: widget.batchName,
        data: {
          'expanded': _expanded,
          'devices': _devices.map((device) => device.toJson()).toList(),
        },
      );
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Could not save ventilation devices: $error');
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

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF4FAF5),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -80,
              child: _SoftShape(color: const Color(0xFF2E7D32).withOpacity(0.08), size: 240),
            ),
            Positioned(
              top: 150,
              left: -70,
              child: _SoftShape(color: const Color(0xFFBFE8C6).withOpacity(0.22), size: 190),
            ),
            Positioned(
              bottom: 110,
              right: -80,
              child: _SoftShape(color: const Color(0xFFBFE8C6).withOpacity(0.18), size: 260),
            ),
            ListView(
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
                              'Dashboard',
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
                      Container(
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
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _BackPill(label: 'Back to ${widget.batchName}', onTap: () => Navigator.of(context).pop()),
                const SizedBox(height: 16),
                const Text(
                  'CLIMATE & ENVIRONMENT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF305E3A),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF9EB),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFD7EDD9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() => _expanded = !_expanded);
                          _persistDevices();
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDFF7E2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCAF2D3),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.air_rounded, color: Color(0xFF118743), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ventilation Fans',
                                      style: TextStyle(
                                        color: Color(0xFF12411F),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
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
                                turns: _expanded ? 0.0 : -0.5,
                                duration: const Duration(milliseconds: 180),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC9F1D3),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F7A3B), size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: 12),
                        if (_isLoading)
                          _buildLoadingState()
                        else if (_hasDevices)
                          _buildDeviceList()
                        else
                          _buildEmptyState(),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: _openAddDeviceSheet,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF355C79),
                              side: const BorderSide(color: Color(0xFFDDE7E0)),
                              backgroundColor: Colors.white,
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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

  Widget _buildEmptyState() {
    return Container(
      key: const ValueKey('empty'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5ECE7)),
      ),
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'No devices added yet',
          style: TextStyle(
            color: Color(0xFF9AA8BD),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      key: const ValueKey('loading'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5ECE7)),
      ),
      child: const SizedBox(
        height: 58,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF0BB13F),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return Column(
      key: const ValueKey('device_list'),
      children: List.generate(_devices.length, (index) {
        final device = _devices[index];
        final isLast = index == _devices.length - 1;

        return Container(
          margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(
                            color: Color(0xFF132015),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          device.id,
                          style: const TextStyle(
                            color: Color(0xFF6E7B8D),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeDeviceAt(index),
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
                  const SizedBox(width: 4),
                  Switch(
                    value: device.enabled,
                    onChanged: (value) => _setDeviceEnabled(index, value),
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
                      color: Color(0xFF0B8F39),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _SpeedButton(label: '1', selected: device.speed == 1, onTap: () => _setDeviceSpeed(index, 1))),
                  const SizedBox(width: 8),
                  Expanded(child: _SpeedButton(label: '2', selected: device.speed == 2, onTap: () => _setDeviceSpeed(index, 2))),
                  const SizedBox(width: 8),
                  Expanded(child: _SpeedButton(label: '3', selected: device.speed == 3, onTap: () => _setDeviceSpeed(index, 3))),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _BackPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BackPill({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7EC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD5EBD8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF0C7D3A)),
            const SizedBox(width: 8),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0C7D3A),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FanDevice {
  String name;
  String id;
  String type;
  String description;
  bool enabled;
  int speed;

  _FanDevice({
    required this.name,
    required this.id,
    required this.type,
    required this.description,
  })  : enabled = false,
        speed = 1;

  factory _FanDevice.fromJson(Map<String, dynamic> json) {
    return _FanDevice(
      name: json['name']?.toString() ?? 'Ventilation Fan 1',
      id: json['id']?.toString() ?? 'FAN001',
      type: json['type']?.toString() ?? 'Fan',
      description: json['description']?.toString() ?? '',
    )
      ..enabled = json['enabled'] == true
      ..speed = (json['speed'] as num?)?.toInt() ?? 1;
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

class _FanDeviceDraft {
  final String name;
  final String id;
  final String type;
  final String description;

  const _FanDeviceDraft({
    required this.name,
    required this.id,
    required this.type,
    required this.description,
  });
}

class AddDeviceSheet extends StatefulWidget {
  final String batchName;

  const AddDeviceSheet({
    super.key,
    required this.batchName,
  });

  @override
  State<AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<AddDeviceSheet> {
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _deviceTypeController = TextEditingController(text: 'Fan');
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _deviceNameController.dispose();
    _deviceIdController.dispose();
    _deviceTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _deviceNameController.text.trim().isNotEmpty
        ? _deviceNameController.text.trim()
        : 'Ventilation Fan 1';
    final id = _deviceIdController.text.trim().isNotEmpty ? _deviceIdController.text.trim() : 'FAN001';

    Navigator.of(context).pop(
      _FanDeviceDraft(
        name: name,
        id: id,
        type: _deviceTypeController.text.trim().isNotEmpty ? _deviceTypeController.text.trim() : 'Fan',
        description: _descriptionController.text.trim(),
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
                mainAxisSize: MainAxisSize.min,
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
                _SheetField(
                  label: 'DEVICE NAME',
                  hintText: 'e.g. Ventilation Fan 2',
                  controller: _deviceNameController,
                ),
                const SizedBox(height: 10),
                _SheetField(
                  label: 'DEVICE ID',
                  hintText: 'e.g. FAN002',
                  controller: _deviceIdController,
                ),
                const SizedBox(height: 10),
                _SheetField(
                  label: 'DEVICE TYPE',
                  hintText: 'Fan',
                  controller: _deviceTypeController,
                ),
                const SizedBox(height: 10),
                _SheetField(
                  label: 'DESCRIPTION (OPTIONAL)',
                  hintText: 'Enter device details...',
                  controller: _descriptionController,
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

class _SheetField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final int maxLines;

  const _SheetField({
    required this.label,
    required this.hintText,
    required this.controller,
    this.maxLines = 1,
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
        ),
      ],
    );
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFF8FBFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFF90D6A4) : const Color(0xFFE3E9E4)),
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

  const _SoftShape({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
