import 'package:flutter/material.dart';

import 'analytics_screen.dart';
import 'batches_dashboard_screen.dart';
import 'batches_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import '../models/auth_store.dart';
import '../models/batch_store.dart';
import '../models/device_config_store.dart';
import '../models/environmental_log_store.dart';
import '../models/firebase_database_service.dart';
import '../models/monitoring_store.dart';
import '../models/report_record_store.dart';
import '../models/temperature_settings_store.dart';
import '../widgets/splash_background.dart';
import '../widgets/user_avatar_content.dart';

class DashboardScreen extends StatefulWidget {
  final bool promptCreateBatch;

  const DashboardScreen({
    super.key,
    this.promptCreateBatch = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _promptQueued = false;
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _queueBatchPromptIfNeeded();
  }

  void _queueBatchPromptIfNeeded() {
    if (!BatchStore.instance.isEmpty) {
      return;
    }

    if (!widget.promptCreateBatch) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _promptQueued) {
        return;
      }
      _promptQueued = true;
      await _openCreateBatch(showAsPopup: true);
    });
  }

  String get _profileInitials {
    return AuthStore.buildInitials(AuthStore.instance.currentUser?.fullName);
  }

  Future<void> _openCreateBatch({required bool showAsPopup}) async {
    final routeBuilder = MaterialPageRoute<BatchItem>(
      builder: (_) => const CreateBatchScreen(),
    );

    final saved = showAsPopup
        ? await showGeneralDialog<BatchItem>(
            context: context,
            barrierDismissible: false,
            barrierLabel: 'Create Batch',
            barrierColor: Colors.black54,
            pageBuilder: (_, __, ___) => const Material(
              color: Colors.transparent,
              child: CreateBatchScreen(),
            ),
          )
        : await Navigator.of(context).push<BatchItem>(routeBuilder);

    if (!mounted) {
      return;
    }

    if (saved != null) {
      BatchStore.instance.add(saved);

      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Batch Saved'),
            content: Text('${saved.name} was created successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _deleteBatch(BatchItem batch) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Batch?'),
          content: Text('Remove "${batch.name}" from your batch list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await Future.wait([
        DeviceConfigStore.instance.deleteAllForBatch(batchName: batch.name),
        ReportRecordStore.instance.deleteBatchRecords(batchId: batch.stableId),
        EnvironmentalLogStore.instance.deleteLogsForBatch(batch: batch),
        _deleteMortalityRecords(batch.stableId),
      ]);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not fully delete ${batch.name}: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    TemperatureSettingsStore.instance.removeBatch(batch.name);
    MonitoringStore.instance.removeBatch(batch.name);
    BatchStore.instance.remove(batch);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${batch.name} and its saved data were deleted'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteMortalityRecords(String batchId) async {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      throw const FirebaseDatabaseException('No signed-in user found.');
    }

    await FirebaseDatabaseService.instance.delete(
      'user_data/${user.id}/mortality_records/$batchId.json',
    );
  }

  Future<void> _editBatch(BatchItem batch) async {
    final result = await Navigator.of(context).push<BatchItem>(
      MaterialPageRoute(
        builder: (_) => CreateBatchScreen(
          batch: batch,
          isEditing: true,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    BatchStore.instance.update(batch, result);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.name} updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF6FAF7),
      body: SplashBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: BatchStore.instance,
            builder: (context, _) {
              final batches = BatchStore.instance.batches;

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
                                  'Live batch overview',
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
                            onTap: () async {
                              await ProfileScreen.show(context);
                              if (mounted) {
                                setState(() {});
                              }
                            },
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
                                initials: _profileInitials,
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
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'YOUR BATCHES',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF58705A),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _openCreateBatch(showAsPopup: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDFF7E5),
                            foregroundColor: const Color(0xFF1E7D32),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                            'Add Batch',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...batches.map(
                      (batch) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BatchCard(
                          batch: batch,
                          onEdit: () => _editBatch(batch),
                          onDelete: () => _deleteBatch(batch),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BatchesDashboardScreen(
                                  batchId: batch.stableId,
                                  batchName: batch.name,
                                  status: batch.status,
                                  startedAt: batch.startedAt,
                                  dayLabel: batch.dayLabel,
                                  birdsLabel: batch.birdsLabel,
                                ),
                              ),
                            );
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 140),
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
                onTap: () => setState(() => _selectedNavIndex = 0),
              ),
              _BottomNavItem(
                icon: Icons.show_chart_rounded,
                label: 'Analytics',
                selected: _selectedNavIndex == 1,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.description_outlined,
                label: 'Reports',
                selected: _selectedNavIndex == 2,
                onTap: () {
                  Navigator.of(context).push(
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

class _BatchCard extends StatelessWidget {
  final BatchItem batch;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BatchCard({
    required this.batch,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isInactive = batch.status.toUpperCase() == 'INACTIVE';
    final statusBackgroundColor = isInactive
        ? const Color(0xFFF1F5F3)
        : const Color(0xFFE7F9EC);
    final statusBorderColor = isInactive
        ? const Color(0xFFD5DEDA)
        : const Color(0xFFB6E5C0);
    final statusTextColor = isInactive
        ? const Color(0xFF5F6F67)
        : const Color(0xFF1E8E3E);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7EDE8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
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
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            batch.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF233047),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBackgroundColor,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: statusBorderColor),
                          ),
                          child: Text(
                            batch.status,
                            style: TextStyle(
                              color: statusTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CircleActionButton(
                        icon: Icons.edit_outlined,
                        backgroundColor: const Color(0xFFF3F8FF),
                        borderColor: const Color(0xFFD9E4F3),
                        iconColor: const Color(0xFF5F7DA8),
                        onTap: onEdit,
                      ),
                      const SizedBox(width: 8),
                      _CircleActionButton(
                        icon: Icons.delete_outline_rounded,
                        backgroundColor: const Color(0xFFFFF1F1),
                        borderColor: const Color(0xFFFFD3D3),
                        iconColor: const Color(0xFFD64545),
                        onTap: onDelete,
                      ),
                      const SizedBox(width: 8),
                      _CircleActionButton(
                        icon: Icons.chevron_right_rounded,
                        backgroundColor: const Color(0xFFF6F8FB),
                        borderColor: const Color(0xFFE5ECF4),
                        iconColor: const Color(0xFFB4C0D0),
                        onTap: onTap,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                batch.startedAt,
                style: const TextStyle(
                  color: Color(0xFF7D8794),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MiniTag(icon: Icons.calendar_today_outlined, label: batch.dayLabel),
                  const SizedBox(width: 8),
                  _MiniTag(icon: Icons.groups_outlined, label: batch.birdsLabel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6ECF2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8B97A8)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6C7685),
              fontWeight: FontWeight.w600,
            ),
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
