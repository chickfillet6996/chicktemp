import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/auth_store.dart';
import '../models/batch_store.dart';
import '../models/firebase_database_service.dart';
import '../models/shared_workspace.dart';
import '../models/shared_workspace_migration.dart';
import 'analytics_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import '../widgets/chicktemp_loading.dart';
import '../widgets/splash_background.dart';
import '../widgets/user_avatar_content.dart';

class MortalityScreen extends StatefulWidget {
  final String batchName;
  final String dayLabel;

  const MortalityScreen({
    super.key,
    required this.batchName,
    required this.dayLabel,
  });

  @override
  State<MortalityScreen> createState() => _MortalityScreenState();
}

class _MortalityScreenState extends State<MortalityScreen> {
  final TextEditingController _deathsController = TextEditingController(text: '0');
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final List<_MortalityRecord> _records = [];
  late DateTime _selectedDate;

  int _selectedNavIndex = 0;
  bool _isLoadingRecords = true;

  int get _initialBirdCount => BatchStore.instance.totalBirdsFor(widget.batchName);
  int get _totalDeaths => _records.fold<int>(0, (sum, record) => sum + record.deaths);

  int get _aliveBirds => (_initialBirdCount - _totalDeaths).clamp(0, _initialBirdCount).toInt();

  double get _lossPercent => _initialBirdCount == 0 ? 0 : (_totalDeaths / _initialBirdCount) * 100;

  String get _formattedSelectedDate => DateFormat('dd/MM/yyyy').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateController.text = _formattedSelectedDate;
    _loadMortalityRecords();
  }

  @override
  void dispose() {
    _deathsController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2E7D32),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1F2937),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
      _dateController.text = _formattedSelectedDate;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _batchId {
    final batch = BatchStore.instance.findByName(widget.batchName);
    if (batch != null) {
      return batch.stableId;
    }

    final fallback = widget.batchName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return fallback.isEmpty ? 'default_batch' : fallback;
  }

  String get _recordPath {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      return '';
    }
    return SharedWorkspace.path('mortality_records/$_batchId');
  }

  Future<void> _loadMortalityRecords() async {
    final path = _recordPath;
    if (path.isEmpty) {
      setState(() => _isLoadingRecords = false);
      return;
    }

    try {
      var response = await FirebaseDatabaseService.instance.get('$path.json');
      if (response is! Map<String, dynamic> || response.isEmpty) {
        final legacyResponse = await _loadLegacyMortalityRecords();
        if (legacyResponse is Map<String, dynamic> &&
            legacyResponse.isNotEmpty) {
          response = legacyResponse;
          await FirebaseDatabaseService.instance.put(
            '$path.json',
            Map<String, dynamic>.from(legacyResponse),
          );
        }
      }
      final records = <_MortalityRecord>[];
      if (response is Map<String, dynamic>) {
        for (final entry in response.entries) {
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            records.add(_MortalityRecord.fromJson(entry.key, value));
          }
        }
      }
      records.sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) {
        return;
      }
      setState(() {
        _records
          ..clear()
          ..addAll(records);
        _isLoadingRecords = false;
      });
      BatchStore.instance.setMortalityCount(widget.batchName, _totalDeaths);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingRecords = false);
      _showMessage('Could not load mortality records: $error');
    }
  }

  Future<Map<String, dynamic>?> _loadLegacyMortalityRecords() async {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      return null;
    }
    return SharedWorkspaceMigration.instance.loadLegacyMap(
      'mortality_records/$_batchId',
      fallbackUserId: user.id,
    );
  }

  Future<void> _refreshMortality() async {
    try {
      await BatchStore.instance.loadForCurrentUser();
    } on Object {
      // Mortality records can still refresh from the currently cached batch.
    }
    await _loadMortalityRecords();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addMortalityRecord() async {
    final deaths = int.tryParse(_deathsController.text.trim());
    final note = _noteController.text.trim();

    if (deaths == null || deaths <= 0) {
      _showMessage('Enter a valid death count greater than zero.');
      return;
    }

    if (_totalDeaths + deaths > _initialBirdCount) {
      _showMessage('That would exceed the remaining birds in this batch.');
      return;
    }

    final record = _MortalityRecord(
      id: 'mort_${DateTime.now().millisecondsSinceEpoch}',
      deaths: deaths,
      date: _selectedDate,
      note: note,
    );

    setState(() {
      _records.insert(
        0,
        record,
      );
      _deathsController.text = '0';
      _noteController.clear();
    });
    BatchStore.instance.setMortalityCount(widget.batchName, _totalDeaths);

    final path = _recordPath;
    if (path.isNotEmpty) {
      await FirebaseDatabaseService.instance.put(
        '$path/${record.id}.json',
        record.toJson(batchId: _batchId),
      );
    }

    _showMessage('Mortality record saved for $_formattedSelectedDate.');
  }

  Future<void> _deleteRecord(int index) async {
    final record = _records[index];
    setState(() {
      _records.removeAt(index);
    });
    BatchStore.instance.setMortalityCount(widget.batchName, _totalDeaths);

    final path = _recordPath;
    if (path.isNotEmpty) {
      await FirebaseDatabaseService.instance.delete('$path/${record.id}.json');
    }

    _showMessage('Removed ${record.deaths} death(s) from the history.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF4F7F3),
      body: SplashBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshMortality,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                              'Cycle Management',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Batch & Mortality',
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(16),
                        splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
                        highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
                        hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
                        child: Ink(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE3E9E4)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.batchName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF172033),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'BATCH & MORTALITY MANAGEMENT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF58705A).withOpacity(0.95),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatusCard(
                        value: _initialBirdCount.toString(),
                        label: 'TOTAL',
                        foreground: Color(0xFF233047),
                        background: Color(0xFFFFFFFF),
                        border: Color(0xFFE3E9E4),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _StatusCard(
                        value: _aliveBirds.toString(),
                        label: 'ALIVE',
                        foreground: Color(0xFF2E7D32),
                        background: Color(0xFFF4FBF6),
                        border: Color(0xFFDCEBDD),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _StatusCard(
                        value: _totalDeaths.toString(),
                        label: 'DEAD',
                        foreground: Color(0xFF9C6B35),
                        background: Color(0xFFF6FAF7),
                        border: Color(0xFFDCE9DD),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _StatusCard(
                        value: '${_lossPercent.toStringAsFixed(1)}%',
                        label: 'LOSS %',
                        foreground: Color(0xFF8F7A3D),
                        background: Color(0xFFF6FAF7),
                        border: Color(0xFFDCE9DD),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4FBF6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.sick_outlined, size: 16, color: Color(0xFF2E7D32)),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'RECORD MORTALITY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF58705A),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final deadField = _InputField(
                            label: 'DEAD CHICKENS',
                            controller: _deathsController,
                            hintText: '0',
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            keyboardType: TextInputType.number,
                          );
                          final dateField = _InputField(
                            label: 'DATE',
                            controller: _dateController,
                            hintText: '30/05/2026',
                            readOnly: true,
                            onTap: _pickDate,
                            suffixIcon: const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF1F2937)),
                          );

                          return Row(
                            children: [
                              Expanded(flex: 5, child: deadField),
                              const SizedBox(width: 8),
                              Expanded(flex: 6, child: dateField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _InputField(
                        label: 'NOTE / REASON',
                        controller: _noteController,
                        hintText: 'e.g. Heat stress, Disease outbreak...',
                        helperText: '(optional)',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                          onPressed: _addMortalityRecord,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                            'Add Mortality Record',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                          const Expanded(
                            child: Text(
                              'MORTALITY HISTORY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF58705A),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Text(
                            '${_records.length} record${_records.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF5E6B7E).withOpacity(0.95),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4FBF6),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFFDCEBDD)),
                            ),
                            child: Text(
                              'Total: $_totalDeaths',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_isLoadingRecords)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: ChickTempLoading(
                              text: 'Loading mortality records...',
                              size: 48,
                            ),
                          ),
                        )
                      else if (_records.isEmpty)
                        const _EmptyHistory()
                      else
                        Column(
                          children: List.generate(_records.length, (index) {
                            final record = _records[index];
                            return Padding(
                              padding: EdgeInsets.only(bottom: index == _records.length - 1 ? 0 : 12),
                              child: _MortalityRecordTile(
                                record: record,
                                onDelete: () => _deleteRecord(index),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
                  const SizedBox(height: 24),
              ],
            ),
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
                    MaterialPageRoute(
                      builder: (_) => AnalyticsScreen(
                        initialBatchName: widget.batchName,
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
                        initialBatchName: widget.batchName,
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

class _StatusCard extends StatelessWidget {
  final String value;
  final String label;
  final Color foreground;
  final Color background;
  final Color border;

  const _StatusCard({
    required this.value,
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: foreground,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3F4A5A),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final String? helperText;
  final TextEditingController controller;
  final String hintText;
  final Widget? suffixIcon;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _InputField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.helperText,
    this.suffixIcon,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
              letterSpacing: 0.3,
            ),
            children: [
              TextSpan(text: label),
              if (helperText != null)
                TextSpan(
                  text: ' $helperText',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFF8A96AC),
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: const Color(0xFFF6FAF7),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCE9DD)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCE9DD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF2E7D32)),
            ),
          ),
        ),
      ],
    );
  }
}

class _MortalityRecordTile extends StatelessWidget {
  final _MortalityRecord record;
  final VoidCallback onDelete;

  const _MortalityRecordTile({
    required this.record,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE9DD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF4FBF6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.sick_outlined, color: Color(0xFF9C6B35), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.deaths} death(s)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(record.date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (record.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    record.note,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            style: IconButton.styleFrom(
              hoverColor: const Color(0xFFE53935).withOpacity(0.08),
              highlightColor: const Color(0xFFE53935).withOpacity(0.12),
            ),
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE53935)),
            tooltip: 'Delete record',
          ),
        ],
      ),
    );
  }
}

class _MortalityRecord {
  final String id;
  final int deaths;
  final DateTime date;
  final String note;

  const _MortalityRecord({
    required this.id,
    required this.deaths,
    required this.date,
    required this.note,
  });

  factory _MortalityRecord.fromJson(String id, Map<String, dynamic> json) {
    return _MortalityRecord(
      id: id,
      deaths: _readInt(json['deaths']),
      date: _readDate(json['date']),
      note: json['note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson({required String batchId}) {
    return {
      'record_id': id,
      'batch_id': batchId,
      'deaths': deaths,
      'date': date.toIso8601String(),
      'note': note,
      'recorded_at': {'.sv': 'timestamp'},
    };
  }

  static int _readInt(dynamic value) {
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

  static DateTime _readDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.now();
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE9DD)),
      ),
      child: Column(
        children: const [
          CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFE8F6EA),
            child: Icon(Icons.description_outlined, color: Color(0xFF2E7D32)),
          ),
          SizedBox(height: 16),
          Text(
            'No mortality records yet.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF58705A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Records you add will appear here.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8D98B2),
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
