import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert_notification_store.dart';
import '../models/auth_store.dart';
import '../models/batch_store.dart';
import '../models/monitoring_store.dart';
import '../models/temperature_settings_store.dart';
import '../widgets/chicktemp_loading.dart';
import '../widgets/settings_back_card.dart';
import '../widgets/settings_overlay_sheet.dart';
import '../widgets/user_avatar_content.dart';

class AlertNotificationsScreen extends StatefulWidget {
  const AlertNotificationsScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AlertNotificationsScreen()),
    );
  }

  @override
  State<AlertNotificationsScreen> createState() =>
      _AlertNotificationsScreenState();
}

class _AlertNotificationsScreenState extends State<AlertNotificationsScreen> {
  final AlertNotificationStore _alertStore = AlertNotificationStore.instance;

  @override
  void initState() {
    super.initState();
    _alertStore.addListener(_handleStoreChanged);
    BatchStore.instance.addListener(_handleSourceChanged);
    MonitoringStore.instance.addListener(_handleSourceChanged);
    TemperatureSettingsStore.instance.addListener(_handleSourceChanged);
    unawaited(_alertStore.load());
  }

  @override
  void dispose() {
    _alertStore.removeListener(_handleStoreChanged);
    BatchStore.instance.removeListener(_handleSourceChanged);
    MonitoringStore.instance.removeListener(_handleSourceChanged);
    TemperatureSettingsStore.instance.removeListener(_handleSourceChanged);
    super.dispose();
  }

  void _handleStoreChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleSourceChanged() {
    unawaited(_alertStore.refresh());
  }

  Future<void> _updatePreferences(AlertPreferences preferences) async {
    await _alertStore.updatePreferences(preferences);
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _alertStore.preferences;
    final alerts = _alertStore.alerts;
    final unreadCount = _alertStore.unreadCount;
    final isLoading = _alertStore.isLoading;

    return SettingsOverlaySheet(
      headerBand: const _HeaderBand(),
      backgroundPainter: const _LeafLinePainter(),
      child: RefreshIndicator(
        color: const Color(0xFF14AE5C),
        onRefresh: _alertStore.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          children: [
                                                _TopBar(
                                                  onBack: () => Navigator.of(
                                                    context,
                                                  ).pop(),
                                                ),
                                                const SizedBox(height: 30),
                                                Text(
                                                  unreadCount == 0
                                                      ? 'Everything is caught up.'
                                                      : '$unreadCount unread alert${unreadCount == 1 ? '' : 's'}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF8A96AC),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 18),
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 34,
                                                      height: 34,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFEFF3FB,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .notifications_none_rounded,
                                                        size: 18,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    const Expanded(
                                                      child: Text(
                                                        'SYSTEM ALERTS',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Color(
                                                            0xFF344054,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    _HeaderActionButton(
                                                      label: 'Mark all read',
                                                      icon: Icons
                                                          .check_circle_outline,
                                                      enabled:
                                                          alerts.isNotEmpty &&
                                                          unreadCount > 0,
                                                      onPressed: () =>
                                                          unawaited(
                                                            _alertStore
                                                                .markAllRead(),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                if (isLoading && alerts.isEmpty)
                                                  const _LoadingCard()
                                                else if (alerts.isEmpty)
                                                  const _EmptyAlertCard()
                                                else
                                                  ...alerts.map(
                                                    (alert) => Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 12,
                                                          ),
                                                      child: _AlertCard(
                                                        alert: alert,
                                                        onToggleRead: () =>
                                                            unawaited(
                                                              _alertStore
                                                                  .toggleRead(
                                                                    alert.id,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 10),
                                                const Text(
                                                  'ALERT PREFERENCES',
                                                  style: TextStyle(
                                                    color: Color(0xFFA4ACBA),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.35,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.92),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          18,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFE7ECE5,
                                                      ),
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.05),
                                                        blurRadius: 12,
                                                        offset: const Offset(
                                                          0,
                                                          5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      _SwitchRow(
                                                        label:
                                                            'High Temperature Alert',
                                                        value: preferences
                                                            .highTemperature,
                                                        onChanged: (value) =>
                                                            _updatePreferences(
                                                              preferences.copyWith(
                                                                highTemperature:
                                                                    value,
                                                              ),
                                                            ),
                                                      ),
                                                      const Divider(
                                                        height: 1,
                                                        indent: 18,
                                                        endIndent: 18,
                                                        color: Color(
                                                          0xFFF0F2F4,
                                                        ),
                                                      ),
                                                      _SwitchRow(
                                                        label:
                                                            'Low Temperature Alert',
                                                        value: preferences
                                                            .lowTemperature,
                                                        onChanged: (value) =>
                                                            _updatePreferences(
                                                              preferences.copyWith(
                                                                lowTemperature:
                                                                    value,
                                                              ),
                                                            ),
                                                      ),
                                                      const Divider(
                                                        height: 1,
                                                        indent: 18,
                                                        endIndent: 18,
                                                        color: Color(
                                                          0xFFF0F2F4,
                                                        ),
                                                      ),
                                                      _SwitchRow(
                                                        label:
                                                            'Device Offline Alert',
                                                        value: preferences
                                                            .deviceOffline,
                                                        onChanged: (value) =>
                                                            _updatePreferences(
                                                              preferences.copyWith(
                                                                deviceOffline:
                                                                    value,
                                                              ),
                                                            ),
                                                      ),
                                                      const Divider(
                                                        height: 1,
                                                        indent: 18,
                                                        endIndent: 18,
                                                        color: Color(
                                                          0xFFF0F2F4,
                                                        ),
                                                      ),
                                                      _SwitchRow(
                                                        label:
                                                            'Feeding Reminder',
                                                        value: preferences
                                                            .feedingReminder,
                                                        onChanged: (value) =>
                                                            _updatePreferences(
                                                              preferences.copyWith(
                                                                feedingReminder:
                                                                    value,
                                                              ),
                                                            ),
                                                      ),
                                                      const Divider(
                                                        height: 1,
                                                        indent: 18,
                                                        endIndent: 18,
                                                        color: Color(
                                                          0xFFF0F2F4,
                                                        ),
                                                      ),
                                                      _SwitchRow(
                                                        label:
                                                            'Water Reminder',
                                                        value: preferences
                                                            .waterReminder,
                                                        onChanged: (value) =>
                                                            _updatePreferences(
                                                              preferences.copyWith(
                                                                waterReminder:
                                                                    value,
                                                              ),
                                                            ),
                                                      ),
                                                      const Divider(
                                                        height: 1,
                                                        indent: 18,
                                                        endIndent: 18,
                                                        color: Color(
                                                          0xFFF0F2F4,
                                                        ),
                                                      ),
                                                      _SwitchRow(
                                                        label:
                                                            'Lighting Reminder',
                                                        value: preferences
                                                            .lightingReminder,
                                                        onChanged: (value) =>
                                                            _updatePreferences(
                                                              preferences.copyWith(
                                                                lightingReminder:
                                                                    value,
                                                              ),
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SettingsBackCard(onTap: onBack);
  }
}

class _HeaderActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _HeaderActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1E8E3E),
        disabledForegroundColor: const Color(0xFF9FB7A5),
        side: BorderSide(
          color: enabled
              ? const Color(0xFFB6E5C0)
              : const Color(0xFFD9E4D9),
        ),
        backgroundColor: enabled
            ? const Color(0xFFEAFBF0)
            : const Color(0xFFF2F6F2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4ECE4)),
      ),
      child: const Row(
        children: [
          ChickTempLoading.compact(
            size: 24,
            color: Color(0xFF14AE5C),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading alerts and reminders...',
              style: TextStyle(
                color: Color(0xFF52627D),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAlertCard extends StatelessWidget {
  const _EmptyAlertCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3ECE3)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 22,
            color: Color(0xFF24B26A),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active alerts',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Temperature, device status, and schedule reminders will appear here.',
                  style: TextStyle(
                    color: Color(0xFF7C879A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _AlertCard extends StatelessWidget {
  final AlertNotificationItem alert;
  final VoidCallback onToggleRead;

  const _AlertCard({
    required this.alert,
    required this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(alert.severity, isRead: alert.isRead);

    return InkWell(
      onTap: onToggleRead,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: alert.isRead ? 0.74 : 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.tint,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.iconBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(palette.icon, color: palette.titleColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: TextStyle(
                              color: palette.titleColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          alert.timeLabel,
                          style: const TextStyle(
                            color: Color(0xFF8A96AC),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.subtitle,
                      style: TextStyle(
                        color: palette.subtitleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            alert.batchName,
                            style: const TextStyle(
                              color: Color(0xFF52627D),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          alert.isRead ? 'Marked read' : 'Tap to mark read',
                          style: TextStyle(
                            color: palette.subtitleColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _AlertPalette _paletteFor(AlertSeverity severity, {required bool isRead}) {
    switch (severity) {
      case AlertSeverity.critical:
        return _AlertPalette(
          tint: isRead ? const Color(0xFFFFF6F6) : const Color(0xFFFFF0F0),
          border: const Color(0xFFFFCFCF),
          iconBackground: const Color(0xFFFFE1E1),
          icon: Icons.thermostat_outlined,
          titleColor: const Color(0xFF8D170F),
          subtitleColor: const Color(0xFF6A4A45),
        );
      case AlertSeverity.warning:
        return _AlertPalette(
          tint: isRead ? const Color(0xFFFFFBF5) : const Color(0xFFFFF7EE),
          border: const Color(0xFFFFD39F),
          iconBackground: const Color(0xFFFFE7CB),
          icon: Icons.wifi_off_rounded,
          titleColor: const Color(0xFF9A4A00),
          subtitleColor: const Color(0xFF6A4A45),
        );
      case AlertSeverity.info:
        return _AlertPalette(
          tint: isRead ? const Color(0xFFFCFDFF) : const Color(0xFFF8FBFF),
          border: const Color(0xFFDCE7F6),
          iconBackground: const Color(0xFFEAF1FF),
          icon: Icons.schedule_outlined,
          titleColor: const Color(0xFF52627D),
          subtitleColor: const Color(0xFF8A96AC),
        );
    }
  }
}

class _AlertPalette {
  final Color tint;
  final Color border;
  final Color iconBackground;
  final IconData icon;
  final Color titleColor;
  final Color subtitleColor;

  const _AlertPalette({
    required this.tint,
    required this.border,
    required this.iconBackground,
    required this.icon,
    required this.titleColor,
    required this.subtitleColor,
  });
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(
            value: value,
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

class _HeaderBand extends StatelessWidget {
  const _HeaderBand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
                    'Alerts & Notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Track updates, warnings, and reminders',
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
                    AuthStore.instance.currentUser?.profilePhotoBase64 ?? '',
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
    );
  }
}

class _LeafLinePainter extends CustomPainter {
  const _LeafLinePainter();

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
