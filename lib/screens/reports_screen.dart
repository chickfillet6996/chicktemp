import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'analytics_screen.dart';
import '../models/auth_store.dart';
import '../models/batch_store.dart';
import '../models/device_config_store.dart';
import '../models/environmental_log_store.dart';
import '../models/monitoring_store.dart';
import '../models/report_record_store.dart';
import '../widgets/splash_background.dart';
import '../widgets/user_avatar_content.dart';
import 'profile_screen.dart';

enum _ReportsTab { reportCenter, events, maintenance }

enum _ComposerMode { event, maintenance }

enum _ReportTemplate {
  dailyEnvironmental,
  mortality,
  deviceActivity,
  maintenance,
  batchSummary,
}

enum _ExportRange { day, week }

class ReportsScreen extends StatefulWidget {
  final String? initialBatchName;

  const ReportsScreen({super.key, this.initialBatchName});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late String _selectedBatch;
  _ReportsTab _selectedTab = _ReportsTab.reportCenter;
  _ComposerMode? _composerMode;
  _ComposerMode? _editingMode;
  int? _editingIndex;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final Map<String, List<_ReportEntry>> _eventsByBatch = {};
  final Map<String, List<_ReportEntry>> _maintenanceByBatch = {};
  List<EnvironmentalLog> _dailyLogs = const [];
  Map<String, dynamic>? _ventilationConfig;
  Map<String, dynamic>? _feederConfig;
  Map<String, dynamic>? _waterConfig;
  Map<String, dynamic>? _lightingConfig;
  final Map<_ReportTemplate, _ExportRange> _exportRangeByTemplate = {};
  _ReportTemplate? _expandedReportTemplate;
  bool _isLoadingBatchData = false;
  String? _batchLoadError;
  int _selectedNavIndex = 2;

  List<String> get _batches =>
      BatchStore.instance.batches.map((batch) => batch.name).toSet().toList();

  BatchTelemetry get _currentTelemetry =>
      MonitoringStore.instance.snapshotFor(_selectedBatch);

  bool get _hasBatchSelection => _batches.isNotEmpty;

  BatchItem? get _selectedBatchItem =>
      BatchStore.instance.findByName(_selectedBatch);

  @override
  void initState() {
    super.initState();
    final initialBatch = widget.initialBatchName;
    _selectedBatch =
        initialBatch != null && _batches.contains(initialBatch)
        ? initialBatch
        : _batches.isNotEmpty
        ? _batches.first
        : 'Broiler Batch 1';
    _loadBatchData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _openReports() {
    if (_selectedNavIndex == 2) {
      return;
    }
    setState(() => _selectedNavIndex = 2);
  }

  void _setTab(_ReportsTab tab) {
    if (_selectedTab == tab) {
      return;
    }
    setState(() {
      _selectedTab = tab;
      _resetComposer();
    });
  }

  List<_ReportEntry> get _currentEvents =>
      _eventsByBatch.putIfAbsent(_selectedBatch, () => []);

  List<_ReportEntry> get _currentMaintenanceEntries =>
      _maintenanceByBatch.putIfAbsent(_selectedBatch, () => []);

  String get _selectedBatchId {
    final batch = BatchStore.instance.findByName(_selectedBatch);
    if (batch != null) {
      return batch.stableId;
    }

    return _selectedBatch
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Set<String> get _selectedBatchKeys {
    final batch = BatchStore.instance.findByName(_selectedBatch);
    return {_selectedBatch, if (batch != null) batch.stableId, 'default_batch'};
  }

  Future<void> _changeSelectedBatch(String value) async {
    setState(() {
      _selectedBatch = value;
      _resetComposer();
    });
    await _loadBatchData();
  }

  Future<void> _loadBatchData() async {
    setState(() {
      _isLoadingBatchData = true;
      _batchLoadError = null;
    });

    try {
      final results = await Future.wait([
        EnvironmentalLogStore.instance.fetchRecentLogs(limit: 240),
        ReportRecordStore.instance.fetchEntries(
          batchId: _selectedBatchId,
          type: ReportRecordType.event,
        ),
        ReportRecordStore.instance.fetchEntries(
          batchId: _selectedBatchId,
          type: ReportRecordType.maintenance,
        ),
        _safeLoadConfig(
          DeviceConfigStore.instance.loadVentilationConfig(
            batchName: _selectedBatch,
          ),
        ),
        _safeLoadConfig(
          DeviceConfigStore.instance.loadFeederConfig(
            batchName: _selectedBatch,
          ),
        ),
        _safeLoadConfig(
          DeviceConfigStore.instance.loadWaterConfig(batchName: _selectedBatch),
        ),
        _safeLoadConfig(
          DeviceConfigStore.instance.loadLightingConfig(
            batchName: _selectedBatch,
          ),
        ),
      ]);

      final logs =
          (results[0] as List<EnvironmentalLog>)
              .where((log) => _selectedBatchKeys.contains(log.batchId))
              .toList()
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      final events = (results[1] as List<ReportRecord>)
          .map(_ReportEntry.fromRecord)
          .toList();
      final maintenance = (results[2] as List<ReportRecord>)
          .map(_ReportEntry.fromRecord)
          .toList();
      final ventilationConfig = results[3] as Map<String, dynamic>?;
      final feederConfig = results[4] as Map<String, dynamic>?;
      final waterConfig = results[5] as Map<String, dynamic>?;
      final lightingConfig = results[6] as Map<String, dynamic>?;

      if (!mounted) {
        return;
      }

      setState(() {
        _dailyLogs = logs;
        _eventsByBatch[_selectedBatch] = events;
        _maintenanceByBatch[_selectedBatch] = maintenance;
        _ventilationConfig = ventilationConfig;
        _feederConfig = feederConfig;
        _waterConfig = waterConfig;
        _lightingConfig = lightingConfig;
        _isLoadingBatchData = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingBatchData = false;
        _batchLoadError = error.toString();
      });
    }
  }

  void _toggleComposer(_ComposerMode mode) {
    setState(() {
      if (_composerMode == mode) {
        _resetComposer();
      } else {
        _composerMode = mode;
        _editingMode = null;
        _editingIndex = null;
        _titleController.clear();
        _dateController.clear();
        _descriptionController.clear();
      }
    });
  }

  void _resetComposer() {
    _composerMode = null;
    _editingMode = null;
    _editingIndex = null;
    _titleController.clear();
    _dateController.clear();
    _descriptionController.clear();
  }

  void _startEditing(_ComposerMode mode, int index, _ReportEntry entry) {
    setState(() {
      _composerMode = mode;
      _editingMode = mode;
      _editingIndex = index;
      _titleController.text = entry.title;
      _dateController.text = entry.date;
      _descriptionController.text = entry.description;
    });
  }

  Future<void> _deleteEntry(_ComposerMode mode, int index) async {
    final entries = mode == _ComposerMode.event
        ? _currentEvents
        : _currentMaintenanceEntries;
    if (index < 0 || index >= entries.length) {
      return;
    }

    final entry = entries[index];
    try {
      await ReportRecordStore.instance.deleteEntry(
        batchId: _selectedBatchId,
        type: mode == _ComposerMode.event
            ? ReportRecordType.event
            : ReportRecordType.maintenance,
        entryId: entry.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        entries.removeAt(index);
        if (_editingMode == mode && _editingIndex == index) {
          _resetComposer();
        } else if (_editingMode == mode &&
            _editingIndex != null &&
            index < _editingIndex!) {
          _editingIndex = _editingIndex! - 1;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete entry: $error')));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _dateController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    });
  }

  Future<void> _saveComposer() async {
    final title = _titleController.text.trim();
    final date = _dateController.text.trim();
    final description = _descriptionController.text.trim();
    final mode = _composerMode;

    if (title.isEmpty || date.isEmpty || description.isEmpty || mode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields first.')),
      );
      return;
    }

    final existingEntry =
        _editingMode == mode &&
            _editingIndex != null &&
            _editingIndex! >= 0 &&
            _editingIndex! <
                (mode == _ComposerMode.event
                    ? _currentEvents.length
                    : _currentMaintenanceEntries.length)
        ? (mode == _ComposerMode.event
              ? _currentEvents[_editingIndex!]
              : _currentMaintenanceEntries[_editingIndex!])
        : null;

    try {
      final savedRecord = await ReportRecordStore.instance.saveEntry(
        batchId: _selectedBatchId,
        type: mode == _ComposerMode.event
            ? ReportRecordType.event
            : ReportRecordType.maintenance,
        entry: ReportRecord(
          id: existingEntry?.id ?? '',
          title: title,
          date: date,
          description: description,
          updatedAt: DateTime.now(),
        ),
      );

      final savedEntry = _ReportEntry.fromRecord(savedRecord);
      if (!mounted) {
        return;
      }

      setState(() {
        final entries = mode == _ComposerMode.event
            ? _currentEvents
            : _currentMaintenanceEntries;
        if (_editingMode == mode && _editingIndex != null) {
          entries[_editingIndex!] = savedEntry;
        } else {
          entries.insert(0, savedEntry);
        }
        _resetComposer();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save entry: $error')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mode == _ComposerMode.event ? 'Event saved' : 'Maintenance saved',
        ),
      ),
    );
  }

  String get _tabHeaderTitle {
    switch (_selectedTab) {
      case _ReportsTab.reportCenter:
        return 'Report Center';
      case _ReportsTab.events:
        return 'Events';
      case _ReportsTab.maintenance:
        return 'Maintenance';
    }
  }

  String get _sectionTitle {
    switch (_selectedTab) {
      case _ReportsTab.reportCenter:
        return 'REPORT CENTER';
      case _ReportsTab.events:
        return 'EVENTS';
      case _ReportsTab.maintenance:
        return 'MAINTENANCE';
    }
  }

  List<_ReportDefinition> get _reportDefinitions => const [
    _ReportDefinition(
      type: _ReportTemplate.dailyEnvironmental,
      title: 'Daily Environmental Report',
      subtitle: 'Temperature, humidity, and latest environmental data',
      icon: Icons.thermostat_auto_rounded,
      color: Color(0xFF2E7D32),
    ),
    _ReportDefinition(
      type: _ReportTemplate.mortality,
      title: 'Mortality Report',
      subtitle: 'Deaths, survival rate, and flock impact',
      icon: Icons.monitor_heart_outlined,
      color: Color(0xFFB45309),
    ),
    _ReportDefinition(
      type: _ReportTemplate.deviceActivity,
      title: 'Device Activity Report',
      subtitle: 'Sensor status, sync time, and live activity',
      icon: Icons.memory_rounded,
      color: Color(0xFF2563EB),
    ),
    _ReportDefinition(
      type: _ReportTemplate.maintenance,
      title: 'Maintenance Report',
      subtitle: 'Maintenance history and latest service notes',
      icon: Icons.build_circle_outlined,
      color: Color(0xFFE67E22),
    ),
    _ReportDefinition(
      type: _ReportTemplate.batchSummary,
      title: 'Batch Summary Report',
      subtitle: 'Cycle, birds, mortality, and status snapshot',
      icon: Icons.summarize_rounded,
      color: Color(0xFF6D28D9),
    ),
  ];

  void _toggleExpandedReport(_ReportTemplate type) {
    setState(() {
      _expandedReportTemplate = _expandedReportTemplate == type ? null : type;
    });
  }

  _ExportRange _selectedExportRange(_ReportTemplate type) {
    return _exportRangeByTemplate[type] ?? _ExportRange.day;
  }

  void _setExportRange(_ReportTemplate type, _ExportRange range) {
    setState(() {
      _exportRangeByTemplate[type] = range;
    });
  }

  Future<void> _exportReport(
    _ReportTemplate type,
    BatchTelemetry telemetry,
  ) async {
    final exportRange = _selectedExportRange(type);
    final report = _buildReportPreview(type, telemetry, exportRange);
    try {
      final bytes = await _buildPdfBytes(report);
      await Printing.sharePdf(
        bytes: bytes,
        filename: _buildPdfFileName(report.title, exportRange),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export PDF: $error')));
    }
  }

  String _buildPdfFileName(String title, _ExportRange range) {
    final safeTitle = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${safeTitle}_${range.name}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
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

  List<EnvironmentalLog> _reportLogs(BatchTelemetry telemetry) {
    final mergedLogs = <EnvironmentalLog>[
      ..._dailyLogs,
      ..._takeLast(telemetry.recentReadings, 12).map(
        (reading) => EnvironmentalLog(
          id: 'live_${reading.recordedAt.microsecondsSinceEpoch}_${reading.temperature}_${reading.humidity}',
          batchId: _selectedBatchId,
          deviceId: 'live_sensor',
          temperature: reading.temperature,
          humidity: reading.humidity,
          recordedAt: reading.recordedAt,
        ),
      ),
    ]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    final deduped = <EnvironmentalLog>[];
    final seenKeys = <String>{};
    for (final log in mergedLogs) {
      final key =
          '${log.recordedAt.millisecondsSinceEpoch}_${log.temperature}_${log.humidity}_${log.deviceId}';
      if (seenKeys.add(key)) {
        deduped.add(log);
      }
    }
    return deduped;
  }

  List<EnvironmentalLog> _logsForRange(
    List<EnvironmentalLog> logs,
    _ExportRange range,
  ) {
    final threshold = _rangeThreshold(range);
    return logs.where((log) => !log.recordedAt.isBefore(threshold)).toList();
  }

  List<_ReportEntry> _entriesForRange(
    List<_ReportEntry> entries,
    _ExportRange range,
  ) {
    final threshold = _rangeThreshold(range);
    return entries.where((entry) {
      final parsed = _tryParseEntryDate(entry.date);
      if (parsed == null) {
        return false;
      }
      return !parsed.isBefore(threshold);
    }).toList();
  }

  DateTime _rangeThreshold(_ExportRange range) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (range) {
      case _ExportRange.day:
        return todayStart;
      case _ExportRange.week:
        return todayStart.subtract(const Duration(days: 6));
    }
  }

  DateTime? _tryParseEntryDate(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value.trim());
    if (match == null) {
      return null;
    }

    final day = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final year = int.tryParse(match.group(3) ?? '');
    if (day == null || month == null || year == null) {
      return null;
    }

    return DateTime(year, month, day);
  }

  String _exportRangeLabel(_ExportRange range) {
    switch (range) {
      case _ExportRange.day:
        return 'Daily';
      case _ExportRange.week:
        return 'Weekly';
    }
  }

  List<_ReportDeviceUsageItem> _deviceUsageItems() {
    return [
      ..._readDeviceUsageItems(
        _waterConfig,
        category: 'Water',
        includeGlobalSchedules: true,
      ),
      ..._readDeviceUsageItems(
        _feederConfig,
        category: 'Feeder',
        includeGlobalSchedules: true,
      ),
      ..._readDeviceUsageItems(_ventilationConfig, category: 'Ventilation'),
      ..._readDeviceUsageItems(_lightingConfig, category: 'Lighting'),
    ];
  }

  List<_ReportDeviceUsageItem> _readDeviceUsageItems(
    Map<String, dynamic>? json, {
    required String category,
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
      return _ReportDeviceUsageItem(
        category: category,
        name: name.isEmpty ? '$category Device' : name,
        id: id.isEmpty ? 'No ID' : id,
        description: description,
        enabled: device['enabled'] == true,
        scheduleCount: scheduleCounts[id] ?? globalScheduleCount,
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

  Future<Uint8List> _buildPdfBytes(_ReportPreviewData report) async {
    final document = pw.Document();
    final generatedAt = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());
    final batchName = _selectedBatchItem?.name ?? _selectedBatch;
    final compactReport = _compactReportForPdf(report);

    document.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(20),
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Container(
          width: double.infinity,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF2E7D32),
                  borderRadius: pw.BorderRadius.circular(18),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CHICKTEMP',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      compactReport.title,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      compactReport.subtitle,
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  pw.Expanded(child: _buildPdfMetaCard('Batch', batchName)),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildPdfMetaCard('Generated', generatedAt),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF5FAF6),
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFE0EADF)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Summary',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF2E7D32),
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      compactReport.summary,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
              if (compactReport.stats.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text(
                  'Key Metrics',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF23412B),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: compactReport.stats
                      .map((stat) => _buildPdfStatCard(stat))
                      .toList(),
                ),
              ],
              if (compactReport.charts.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text(
                  'Visual Summary',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF2E7D32),
                  ),
                ),
                pw.SizedBox(height: 8),
                ...compactReport.charts.map(_buildPdfChartCard),
              ],
              pw.SizedBox(height: 12),
              ...compactReport.sections.map(_buildPdfSectionCard),
            ],
          ),
        ),
      ),
    );

    return document.save();
  }

  _ReportPreviewData _compactReportForPdf(_ReportPreviewData report) {
    final maxLinesPerSection = report.charts.isEmpty ? 5 : 4;
    final sections = report.sections.take(3).map((section) {
      final trimmedLines = section.lines.take(maxLinesPerSection).toList();
      if (section.lines.length > maxLinesPerSection) {
        trimmedLines.add('More details are available in the app.');
      }
      return _ReportPreviewSection(title: section.title, lines: trimmedLines);
    }).toList();

    final charts = report.charts.take(2).map((chart) {
      return _ReportChartData(
        title: chart.title,
        color: chart.color,
        maxValueOverride: chart.maxValueOverride,
        entries: chart.entries.take(4).toList(),
      );
    }).toList();

    return _ReportPreviewData(
      title: report.title,
      subtitle: report.subtitle,
      summary: report.summary,
      stats: report.stats.take(4).toList(),
      charts: charts,
      sections: sections,
    );
  }

  pw.Widget _buildPdfMetaCard(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8E3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStatCard(_ReportStatData stat) {
    return pw.Container(
      width: 118,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8E3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            stat.label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            stat.value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSectionCard(_ReportPreviewSection section) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8E3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            section.title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF2E7D32),
            ),
          ),
          pw.SizedBox(height: 8),
          ...section.lines.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 4,
                    height: 4,
                    margin: const pw.EdgeInsets.only(top: 5, right: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF4CAF50),
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      line,
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.black,
                        lineSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfChartCard(_ReportChartData chart) {
    final maxValue =
        chart.maxValueOverride ??
        chart.entries.fold<double>(
          0,
          (highest, entry) => math.max(highest, entry.value),
        );

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8E3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            chart.title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: chart.color,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Visual comparison for this report section',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 10),
          ...chart.entries.map((entry) {
            final widthFactor = maxValue <= 0 ? 0.0 : entry.value / maxValue;
            final barWidth = widthFactor <= 0
                ? 0.0
                : math.max(8.0, 170.0 * widthFactor);

            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(
                    width: 82,
                    child: pw.Text(
                      entry.label,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 170,
                    height: 10,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE8EFE9),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Container(
                        width: barWidth,
                        decoration: pw.BoxDecoration(
                          color: chart.color,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Text(
                      entry.formattedValue,
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  _ReportPreviewData _buildReportPreview(
    _ReportTemplate type,
    BatchTelemetry telemetry,
    _ExportRange range,
  ) {
    switch (type) {
      case _ReportTemplate.dailyEnvironmental:
        return _buildDailyEnvironmentalReport(telemetry, range);
      case _ReportTemplate.mortality:
        return _buildMortalityReport(range);
      case _ReportTemplate.deviceActivity:
        return _buildDeviceActivityReport(telemetry, range);
      case _ReportTemplate.maintenance:
        return _buildMaintenanceReport(range);
      case _ReportTemplate.batchSummary:
        return _buildBatchSummaryReport(telemetry, range);
    }
  }

  _ReportPreviewData _buildDailyEnvironmentalReport(
    BatchTelemetry telemetry,
    _ExportRange range,
  ) {
    {
      final logs = _logsForRange(_reportLogs(telemetry), range);
      final latestLog = logs.isNotEmpty ? logs.last : null;
      final temperatures = logs.map((log) => log.temperature).toList();
      final humidities = logs.map((log) => log.humidity).toList();
      final latestTimestamp = latestLog?.recordedAt ?? telemetry.updatedAt;
      final latestTemperature = latestLog?.temperature ?? telemetry.temperature;
      final latestHumidity = latestLog?.humidity ?? telemetry.humidity;
      final averageTemperature = temperatures.isEmpty
          ? latestTemperature
          : temperatures.reduce((a, b) => a + b) / temperatures.length;
      final averageHumidity = humidities.isEmpty
          ? latestHumidity
          : humidities.reduce((a, b) => a + b) / humidities.length;
      final recentLines = _takeLast(logs, 5).reversed.map((log) {
        final time = DateFormat('MMM d, yyyy h:mm a').format(log.recordedAt);
        return '$time | ${log.temperature.toStringAsFixed(1)} C | ${log.humidity.toStringAsFixed(0)}%';
      }).toList();

      return _ReportPreviewData(
        title: 'Daily Environmental Report',
        subtitle:
            '${_exportRangeLabel(range)} temperature and humidity monitoring snapshot',
        summary:
            '${logs.length} environmental reading(s) available for ${_exportRangeLabel(range).toLowerCase()} export of ${_selectedBatchItem?.name ?? _selectedBatch}.',
        stats: [
          _ReportStatData(
            label: 'Latest Temp',
            value: '${latestTemperature.toStringAsFixed(1)} C',
          ),
          _ReportStatData(
            label: 'Latest Humidity',
            value: '${latestHumidity.toStringAsFixed(0)}%',
          ),
          _ReportStatData(
            label: 'Average Temp',
            value: '${averageTemperature.toStringAsFixed(1)} C',
          ),
          _ReportStatData(
            label: 'Average Humidity',
            value: '${averageHumidity.toStringAsFixed(0)}%',
          ),
        ],
        charts: [
          _ReportChartData(
            title: 'Recent Temperature',
            color: PdfColor.fromInt(0xFF2E7D32),
            entries: _takeLast(logs, 8)
                .map(
                  (log) => _ReportChartEntry(
                    label: DateFormat('h:mm a').format(log.recordedAt),
                    value: log.temperature,
                    formattedValue: '${log.temperature.toStringAsFixed(1)} C',
                  ),
                )
                .toList(),
          ),
          _ReportChartData(
            title: 'Recent Humidity',
            color: PdfColor.fromInt(0xFF0F766E),
            entries: _takeLast(logs, 8)
                .map(
                  (log) => _ReportChartEntry(
                    label: DateFormat('h:mm a').format(log.recordedAt),
                    value: log.humidity,
                    formattedValue: '${log.humidity.toStringAsFixed(0)}%',
                  ),
                )
                .toList(),
          ),
        ],
        sections: [
          _ReportPreviewSection(
            title: 'Overview',
            lines: [
              'Latest reading: ${latestTemperature.toStringAsFixed(1)} C and ${latestHumidity.toStringAsFixed(0)}%',
              'Average temperature: ${averageTemperature.toStringAsFixed(1)} C',
              'Average humidity: ${averageHumidity.toStringAsFixed(0)}%',
              'Last updated: ${DateFormat('MMM d, yyyy h:mm a').format(latestTimestamp)}',
            ],
          ),
          _ReportPreviewSection(
            title: 'Recent Environmental Data',
            lines: recentLines.isNotEmpty
                ? recentLines
                : ['No environmental logs are available for this batch yet.'],
          ),
        ],
      );
    }

    /*
    final temperatures = _dailyLogs.isNotEmpty
        ? _dailyLogs.map((log) => log.temperature).toList()
        : telemetry.recentReadings.map((reading) => reading.temperature).toList();
    final humidities = _dailyLogs.isNotEmpty
        ? _dailyLogs.map((log) => log.humidity).toList()
        : telemetry.recentReadings.map((reading) => reading.humidity).toList();
    final latestTimestamp = _dailyLogs.isNotEmpty
        ? _dailyLogs.first.recordedAt
        : telemetry.updatedAt;
    final latestTemperature = _dailyLogs.isNotEmpty
        ? _dailyLogs.first.temperature
        : telemetry.temperature;
    final latestHumidity = _dailyLogs.isNotEmpty
        ? _dailyLogs.first.humidity
        : telemetry.humidity;
    final averageTemperature = temperatures.isEmpty
        ? latestTemperature
        : temperatures.reduce((a, b) => a + b) / temperatures.length;
    final averageHumidity = humidities.isEmpty
        ? latestHumidity
        : humidities.reduce((a, b) => a + b) / humidities.length;

    final recentLines = _dailyLogs.take(5).map((log) {
      final time = DateFormat('MMM d, yyyy h:mm a').format(log.recordedAt);
      return '$time • ${log.temperature.toStringAsFixed(1)}°C • ${log.humidity.toStringAsFixed(0)}%';
    }).toList();

    return _ReportPreviewData(
      title: 'Daily Environmental Report',
      subtitle: 'Temperature and humidity monitoring snapshot',
      summary:
          '${_dailyLogs.length} environmental logs available for ${_selectedBatchItem?.name ?? _selectedBatch}.',
      sections: [
        _ReportPreviewSection(
          title: 'Overview',
          lines: [
            'Latest reading: ${latestTemperature.toStringAsFixed(1)}°C and ${latestHumidity.toStringAsFixed(0)}%',
            'Average temperature: ${averageTemperature.toStringAsFixed(1)}°C',
            'Average humidity: ${averageHumidity.toStringAsFixed(0)}%',
            'Last updated: ${DateFormat('MMM d, yyyy h:mm a').format(latestTimestamp)}',
          ],
        ),
        _ReportPreviewSection(
          title: 'Recent Environmental Data',
          lines: recentLines.isNotEmpty
              ? recentLines
              : ['No environmental logs are available for this batch yet.'],
        ),
      ],
    );
*/
  }

  _ReportPreviewData _buildMortalityReport(_ExportRange range) {
    {
      final totalBirds = BatchStore.instance.totalBirdsFor(_selectedBatch);
      final deaths = BatchStore.instance.mortalityCountFor(_selectedBatch);
      final alive = BatchStore.instance.aliveBirdsFor(_selectedBatch);
      final mortalityRate = totalBirds <= 0 ? 0.0 : (deaths / totalBirds) * 100;
      final survivalRate = totalBirds <= 0 ? 0.0 : (alive / totalBirds) * 100;
      final batch = _selectedBatchItem;

      return _ReportPreviewData(
        title: 'Mortality Report',
        subtitle:
            '${_exportRangeLabel(range)} mortality and flock survival summary',
        summary:
            '$deaths recorded deaths out of $totalBirds birds for ${_exportRangeLabel(range).toLowerCase()} export.',
        stats: [
          _ReportStatData(label: 'Total Flock', value: '$totalBirds'),
          _ReportStatData(label: 'Deaths', value: '$deaths'),
          _ReportStatData(label: 'Alive', value: '$alive'),
          _ReportStatData(
            label: 'Survival Rate',
            value: '${survivalRate.toStringAsFixed(1)}%',
          ),
        ],
        charts: [
          _ReportChartData(
            title: 'Flock Distribution',
            color: PdfColor.fromInt(0xFF2E7D32),
            entries: [
              _ReportChartEntry(
                label: 'Alive',
                value: alive.toDouble(),
                formattedValue: '$alive birds',
              ),
              _ReportChartEntry(
                label: 'Deaths',
                value: deaths.toDouble(),
                formattedValue: '$deaths birds',
              ),
            ],
          ),
          _ReportChartData(
            title: 'Rate Comparison',
            color: PdfColor.fromInt(0xFFB45309),
            maxValueOverride: 100,
            entries: [
              _ReportChartEntry(
                label: 'Survival',
                value: survivalRate,
                formattedValue: '${survivalRate.toStringAsFixed(1)}%',
              ),
              _ReportChartEntry(
                label: 'Mortality',
                value: mortalityRate,
                formattedValue: '${mortalityRate.toStringAsFixed(1)}%',
              ),
            ],
          ),
        ],
        sections: [
          _ReportPreviewSection(
            title: 'Flock Status',
            lines: [
              'Total flock: $totalBirds birds',
              'Recorded deaths: $deaths',
              'Alive birds: $alive',
              'Mortality rate: ${mortalityRate.toStringAsFixed(1)}%',
              'Survival rate: ${survivalRate.toStringAsFixed(1)}%',
            ],
          ),
          _ReportPreviewSection(
            title: 'Cycle Details',
            lines: [
              'Batch status: ${batch?.status ?? 'ACTIVE'}',
              'Cycle progress: ${batch?.dayLabel ?? 'Day 1 / 45'}',
              batch?.startedAt ?? 'Started: Not set',
            ],
          ),
        ],
      );
    }

    /*
    final totalBirds = BatchStore.instance.totalBirdsFor(_selectedBatch);
    final deaths = BatchStore.instance.mortalityCountFor(_selectedBatch);
    final alive = BatchStore.instance.aliveBirdsFor(_selectedBatch);
    final mortalityRate =
        totalBirds <= 0 ? 0.0 : (deaths / totalBirds) * 100;
    final survivalRate = totalBirds <= 0 ? 0.0 : (alive / totalBirds) * 100;
    final batch = _selectedBatchItem;

    return _ReportPreviewData(
      title: 'Mortality Report',
      subtitle: 'Mortality and flock survival summary',
      summary: '$deaths recorded deaths out of $totalBirds birds.',
      sections: [
        _ReportPreviewSection(
          title: 'Flock Status',
          lines: [
            'Total flock: $totalBirds birds',
            'Recorded deaths: $deaths',
            'Alive birds: $alive',
            'Mortality rate: ${mortalityRate.toStringAsFixed(1)}%',
            'Survival rate: ${survivalRate.toStringAsFixed(1)}%',
          ],
        ),
        _ReportPreviewSection(
          title: 'Cycle Details',
          lines: [
            'Batch status: ${batch?.status ?? 'ACTIVE'}',
            'Cycle progress: ${batch?.dayLabel ?? 'Day 1 / 45'}',
            batch?.startedAt ?? 'Started: Not set',
          ],
        ),
      ],
    );
*/
  }

  _ReportPreviewData _buildDeviceActivityReport(
    BatchTelemetry telemetry,
    _ExportRange range,
  ) {
    {
      final deviceItems = _deviceUsageItems();
      final logs = _logsForRange(_reportLogs(telemetry), range);
      final enabledCount = deviceItems.where((item) => item.enabled).length;
      final activeSchedules = deviceItems.fold<int>(
        0,
        (sum, item) => sum + item.scheduleCount,
      );
      final categoryDeviceCounts = <String, int>{};
      final categoryScheduleCounts = <String, int>{};
      for (final item in deviceItems) {
        categoryDeviceCounts.update(
          item.category,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        categoryScheduleCounts.update(
          item.category,
          (value) => value + item.scheduleCount,
          ifAbsent: () => item.scheduleCount,
        );
      }

      final lastLog = logs.isNotEmpty ? logs.last : null;
      final deviceLines = deviceItems.take(8).map((item) {
        final status = item.enabled ? 'Connected' : 'Saved';
        final details = item.description.isEmpty ? '' : ', ${item.description}';
        return '${item.name} (${item.category}, ${item.id}) - $status, ${item.scheduleCount} active schedule(s)$details';
      }).toList();

      return _ReportPreviewData(
        title: 'Device Activity Report',
        subtitle:
            '${_exportRangeLabel(range)} saved devices, active schedules, and live status',
        summary:
            '$enabledCount of ${deviceItems.length} saved device(s) are active for ${_exportRangeLabel(range).toLowerCase()} export of ${_selectedBatchItem?.name ?? _selectedBatch}.',
        stats: [
          _ReportStatData(
            label: 'Saved Devices',
            value: '${deviceItems.length}',
          ),
          _ReportStatData(label: 'Connected', value: '$enabledCount'),
          _ReportStatData(label: 'Active Schedules', value: '$activeSchedules'),
          _ReportStatData(
            label: 'Sensor Status',
            value: telemetry.isLive ? 'Live' : 'Offline',
          ),
        ],
        charts: [
          _ReportChartData(
            title: 'Devices by Category',
            color: PdfColor.fromInt(0xFF2563EB),
            entries: [
              for (final category in const [
                'Water',
                'Feeder',
                'Ventilation',
                'Lighting',
              ])
                _ReportChartEntry(
                  label: category,
                  value: (categoryDeviceCounts[category] ?? 0).toDouble(),
                  formattedValue:
                      '${categoryDeviceCounts[category] ?? 0} device(s)',
                ),
            ],
          ),
          _ReportChartData(
            title: 'Active Schedules by Category',
            color: PdfColor.fromInt(0xFF2E7D32),
            entries: [
              for (final category in const [
                'Water',
                'Feeder',
                'Ventilation',
                'Lighting',
              ])
                _ReportChartEntry(
                  label: category,
                  value: (categoryScheduleCounts[category] ?? 0).toDouble(),
                  formattedValue:
                      '${categoryScheduleCounts[category] ?? 0} active schedule(s)',
                ),
            ],
          ),
        ],
        sections: [
          _ReportPreviewSection(
            title: 'Connection',
            lines: [
              'Status: ${telemetry.isLive ? 'Live' : 'Offline'}',
              'Last sync: ${DateFormat('MMM d, yyyy h:mm a').format(telemetry.updatedAt)}',
              'Configured devices: ${deviceItems.isEmpty ? 'No saved devices yet.' : deviceItems.length}',
            ],
          ),
          _ReportPreviewSection(
            title: 'Saved Devices',
            lines: [
              ...deviceLines,
              if (deviceLines.isEmpty)
                'No device configurations have been saved for this batch yet.',
            ],
          ),
          _ReportPreviewSection(
            title: 'Environment Snapshot',
            lines: [
              'Current temperature: ${telemetry.temperature.toStringAsFixed(1)} C',
              'Current humidity: ${telemetry.humidity.toStringAsFixed(0)}%',
              'Recent telemetry samples: ${logs.length}',
              if (lastLog != null)
                'Latest log source: ${lastLog.deviceId} at ${DateFormat('MMM d, yyyy h:mm a').format(lastLog.recordedAt)}',
            ],
          ),
        ],
      );
    }

    /*
    final deviceIds = _dailyLogs.map((log) => log.deviceId).toSet().toList()
      ..sort();
    final lastLog = _dailyLogs.isNotEmpty ? _dailyLogs.first : null;

    return _ReportPreviewData(
      title: 'Device Activity Report',
      subtitle: 'Live sensor activity and synchronization status',
      summary:
          '${telemetry.isLive ? 'Device is live' : 'Device is offline'} for ${_selectedBatchItem?.name ?? _selectedBatch}.',
      sections: [
        _ReportPreviewSection(
          title: 'Connection',
          lines: [
            'Status: ${telemetry.isLive ? 'Live' : 'Offline'}',
            'Last sync: ${DateFormat('MMM d, yyyy h:mm a').format(telemetry.updatedAt)}',
            'Detected devices: ${deviceIds.isEmpty ? 'esp32-dht22-hcsr04' : deviceIds.join(', ')}',
          ],
        ),
        _ReportPreviewSection(
          title: 'Environment Snapshot',
          lines: [
            'Current temperature: ${telemetry.temperature.toStringAsFixed(1)}°C',
            'Current humidity: ${telemetry.humidity.toStringAsFixed(0)}%',
            'Recent telemetry samples: ${telemetry.recentReadings.length}',
            if (lastLog != null)
              'Latest log source: ${lastLog.deviceId} at ${DateFormat('MMM d, yyyy h:mm a').format(lastLog.recordedAt)}',
          ],
        ),
      ],
    );
*/
  }

  _ReportPreviewData _buildMaintenanceReport(_ExportRange range) {
    final entries = _entriesForRange(_currentMaintenanceEntries, range);
    final recentTasks = entries.take(5).map((entry) {
      return '${entry.date} | ${entry.title}';
    }).toList();
    final latestTask = entries.isNotEmpty ? entries.first : null;
    final groupedByDate = <String, int>{};
    for (final entry in entries) {
      groupedByDate.update(entry.date, (value) => value + 1, ifAbsent: () => 1);
    }

    return _ReportPreviewData(
      title: 'Maintenance Report',
      subtitle:
          '${_exportRangeLabel(range)} maintenance tasks and service notes',
      summary:
          '${entries.length} maintenance record(s) saved for ${_exportRangeLabel(range).toLowerCase()} export of ${_selectedBatchItem?.name ?? _selectedBatch}.',
      stats: [
        _ReportStatData(label: 'Records', value: '${entries.length}'),
        _ReportStatData(
          label: 'Latest Task',
          value: latestTask?.title ?? 'None',
        ),
        _ReportStatData(
          label: 'Latest Date',
          value: latestTask?.date ?? 'Not set',
        ),
      ],
      charts: [
        _ReportChartData(
          title: 'Maintenance Records by Date',
          color: PdfColor.fromInt(0xFFE67E22),
          entries: groupedByDate.entries
              .take(6)
              .map(
                (entry) => _ReportChartEntry(
                  label: entry.key,
                  value: entry.value.toDouble(),
                  formattedValue: '${entry.value} record(s)',
                ),
              )
              .toList(),
        ),
      ],
      sections: [
        _ReportPreviewSection(
          title: 'Overview',
          lines: [
            'Total maintenance records: ${entries.length}',
            if (latestTask != null) 'Latest task: ${latestTask.title}',
            if (latestTask != null) 'Latest date: ${latestTask.date}',
            if (latestTask == null)
              'No maintenance tasks have been recorded yet.',
          ],
        ),
        _ReportPreviewSection(
          title: 'Recent Tasks',
          lines: recentTasks.isNotEmpty
              ? recentTasks
              : ['Add maintenance records to populate this report.'],
        ),
      ],
    );

    /*
    final recentTasks = _currentMaintenanceEntries.take(5).map((entry) {
      return '${entry.date} • ${entry.title}';
    }).toList();
    final latestTask = _currentMaintenanceEntries.isNotEmpty
        ? _currentMaintenanceEntries.first
        : null;

    return _ReportPreviewData(
      title: 'Maintenance Report',
      subtitle: 'Maintenance tasks and latest service notes',
      summary:
          '${_currentMaintenanceEntries.length} maintenance record(s) saved for ${_selectedBatchItem?.name ?? _selectedBatch}.',
      sections: [
        _ReportPreviewSection(
          title: 'Overview',
          lines: [
            'Total maintenance records: ${_currentMaintenanceEntries.length}',
            if (latestTask != null) 'Latest task: ${latestTask.title}',
            if (latestTask != null) 'Latest date: ${latestTask.date}',
            if (latestTask == null) 'No maintenance tasks have been recorded yet.',
          ],
        ),
        _ReportPreviewSection(
          title: 'Recent Tasks',
          lines: recentTasks.isNotEmpty
              ? recentTasks
              : ['Add maintenance records to populate this report.'],
        ),
      ],
    );
*/
  }

  _ReportPreviewData _buildBatchSummaryReport(
    BatchTelemetry telemetry,
    _ExportRange range,
  ) {
    final batch = _selectedBatchItem;
    final logs = _logsForRange(_reportLogs(telemetry), range);
    final latestLog = logs.isNotEmpty ? logs.last : null;
    final totalBirds = BatchStore.instance.totalBirdsFor(_selectedBatch);
    final deaths = BatchStore.instance.mortalityCountFor(_selectedBatch);
    final alive = BatchStore.instance.aliveBirdsFor(_selectedBatch);
    final cycleProgress = _readCycleProgress(batch?.dayLabel ?? '');
    final remainingDays = cycleProgress.totalDays <= 0
        ? 0
        : math.max(0, cycleProgress.totalDays - cycleProgress.currentDay);

    return _ReportPreviewData(
      title: 'Batch Summary Report',
      subtitle:
          '${_exportRangeLabel(range)} cycle summary for the selected batch',
      summary:
          '${batch?.name ?? _selectedBatch} is currently ${batch?.status ?? 'ACTIVE'} for ${_exportRangeLabel(range).toLowerCase()} export.',
      stats: [
        _ReportStatData(label: 'Status', value: batch?.status ?? 'ACTIVE'),
        _ReportStatData(label: 'Total Birds', value: '$totalBirds'),
        _ReportStatData(label: 'Alive', value: '$alive'),
        _ReportStatData(label: 'Deaths', value: '$deaths'),
      ],
      charts: [
        _ReportChartData(
          title: 'Flock Snapshot',
          color: PdfColor.fromInt(0xFF2E7D32),
          entries: [
            _ReportChartEntry(
              label: 'Alive',
              value: alive.toDouble(),
              formattedValue: '$alive birds',
            ),
            _ReportChartEntry(
              label: 'Deaths',
              value: deaths.toDouble(),
              formattedValue: '$deaths birds',
            ),
          ],
        ),
        _ReportChartData(
          title: 'Cycle Progress',
          color: PdfColor.fromInt(0xFF6D28D9),
          entries: [
            _ReportChartEntry(
              label: 'Completed',
              value: cycleProgress.currentDay.toDouble(),
              formattedValue: '${cycleProgress.currentDay} day(s)',
            ),
            _ReportChartEntry(
              label: 'Remaining',
              value: remainingDays.toDouble(),
              formattedValue: '$remainingDays day(s)',
            ),
          ],
        ),
        _ReportChartData(
          title: 'Current Environment',
          color: PdfColor.fromInt(0xFF0F766E),
          entries: [
            _ReportChartEntry(
              label: 'Temp',
              value: telemetry.temperature,
              formattedValue: '${telemetry.temperature.toStringAsFixed(1)} C',
            ),
            _ReportChartEntry(
              label: 'Humidity',
              value: telemetry.humidity,
              formattedValue: '${telemetry.humidity.toStringAsFixed(0)}%',
            ),
          ],
        ),
      ],
      sections: [
        _ReportPreviewSection(
          title: 'Batch Information',
          lines: [
            'Batch: ${batch?.name ?? _selectedBatch}',
            'Status: ${batch?.status ?? 'ACTIVE'}',
            'Progress: ${batch?.dayLabel ?? 'Day 1 / 45'}',
            batch?.startedAt ?? 'Started: Not set',
          ],
        ),
        _ReportPreviewSection(
          title: 'Flock and Environment',
          lines: [
            'Total birds: $totalBirds',
            'Alive birds: $alive',
            'Mortality count: $deaths',
            'Temperature: ${(latestLog?.temperature ?? telemetry.temperature).toStringAsFixed(1)} C',
            'Humidity: ${(latestLog?.humidity ?? telemetry.humidity).toStringAsFixed(0)}%',
          ],
        ),
      ],
    );

    /*
    final batch = _selectedBatchItem;
    final totalBirds = BatchStore.instance.totalBirdsFor(_selectedBatch);
    final deaths = BatchStore.instance.mortalityCountFor(_selectedBatch);
    final alive = BatchStore.instance.aliveBirdsFor(_selectedBatch);

    return _ReportPreviewData(
      title: 'Batch Summary Report',
      subtitle: 'Cycle summary for the selected batch',
      summary:
          '${batch?.name ?? _selectedBatch} is currently ${batch?.status ?? 'ACTIVE'}.',
      sections: [
        _ReportPreviewSection(
          title: 'Batch Information',
          lines: [
            'Batch: ${batch?.name ?? _selectedBatch}',
            'Status: ${batch?.status ?? 'ACTIVE'}',
            'Progress: ${batch?.dayLabel ?? 'Day 1 / 45'}',
            batch?.startedAt ?? 'Started: Not set',
          ],
        ),
        _ReportPreviewSection(
          title: 'Flock and Environment',
          lines: [
            'Total birds: $totalBirds',
            'Alive birds: $alive',
            'Mortality count: $deaths',
            'Temperature: ${telemetry.temperature.toStringAsFixed(1)}°C',
            'Humidity: ${telemetry.humidity.toStringAsFixed(0)}%',
          ],
        ),
      ],
    );
*/
  }

  _CycleProgress _readCycleProgress(String dayLabel) {
    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(dayLabel);
    if (match == null) {
      return const _CycleProgress(currentDay: 0, totalDays: 0);
    }

    return _CycleProgress(
      currentDay: int.tryParse(match.group(1) ?? '') ?? 0,
      totalDays: int.tryParse(match.group(2) ?? '') ?? 0,
    );
  }

  Widget _buildReportCenter(BatchTelemetry telemetry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3E9E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tap any report, then export it as PDF.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          ..._reportDefinitions.map(
            (definition) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExpandableReportCard(
                definition: definition,
                expanded: definition.type == _expandedReportTemplate,
                preview: _buildReportPreview(
                  definition.type,
                  telemetry,
                  _selectedExportRange(definition.type),
                ),
                selectedRange: _selectedExportRange(definition.type),
                onTap: () => _toggleExpandedReport(definition.type),
                onRangeChanged: (range) =>
                    _setExportRange(definition.type, range),
                onExport: () => _exportReport(definition.type, telemetry),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MonitoringStore.instance,
      builder: (context, _) {
        if (_hasBatchSelection && !_batches.contains(_selectedBatch)) {
          _selectedBatch = _batches.first;
        }

        final telemetry = _currentTelemetry;

        return Scaffold(
          extendBody: true,
          backgroundColor: const Color(0xFFF4F7F3),
          body: SplashBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
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
                                  'Reports',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Logs & records',
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
                                initials:
                                    AuthStore.instance.currentUserInitials,
                                profilePhotoBase64:
                                    AuthStore
                                        .instance
                                        .currentUser
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
                  const SizedBox(height: 18),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadBatchData,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedBatch.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF58705A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE3E9E4),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _batches.contains(_selectedBatch)
                                        ? _selectedBatch
                                        : null,
                                    focusColor: const Color(
                                      0xFF0BB13F,
                                    ).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                    ),
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
                                        _changeSelectedBatch(value);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE3E9E4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                _SegmentButton(
                                  label: 'Report Center',
                                  selected:
                                      _selectedTab == _ReportsTab.reportCenter,
                                  onTap: () =>
                                      _setTab(_ReportsTab.reportCenter),
                                ),
                                SizedBox(width: 8),
                                _SegmentButton(
                                  label: 'Events',
                                  selected: _selectedTab == _ReportsTab.events,
                                  onTap: () => _setTab(_ReportsTab.events),
                                ),
                                SizedBox(width: 8),
                                _SegmentButton(
                                  label: 'Maintenance',
                                  selected:
                                      _selectedTab == _ReportsTab.maintenance,
                                  onTap: () => _setTab(_ReportsTab.maintenance),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_selectedTab != _ReportsTab.reportCenter) ...[
                            Text(
                              _tabHeaderTitle,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF172033),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  _sectionTitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF58705A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                _ActionButton(
                                  label: _selectedTab == _ReportsTab.events
                                      ? 'Add Event'
                                      : 'Add Maintenance',
                                  color: _selectedTab == _ReportsTab.events
                                      ? const Color(0xFFE53935)
                                      : const Color(0xFFFF8A00),
                                  onTap: () => _toggleComposer(
                                    _selectedTab == _ReportsTab.events
                                        ? _ComposerMode.event
                                        : _ComposerMode.maintenance,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_batchLoadError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildMessageCard(
                                _batchLoadError!,
                                icon: Icons.cloud_off_outlined,
                                iconColor: const Color(0xFFB45309),
                              ),
                            ),
                          if (_selectedTab == _ReportsTab.reportCenter)
                            _buildReportCenter(telemetry),
                          if (_selectedTab == _ReportsTab.events &&
                              _composerMode == _ComposerMode.event)
                            _ComposerCard(
                              title: 'Add New Event',
                              accentColor: const Color(0xFFE53935),
                              titleController: _titleController,
                              dateController: _dateController,
                              descriptionController: _descriptionController,
                              titleHint: 'Event Name / Title',
                              saveLabel: 'Save Event',
                              onCancel: () =>
                                  _toggleComposer(_ComposerMode.event),
                              onPickDate: _pickDate,
                              onSave: () {
                                _saveComposer();
                              },
                            ),
                          if (_selectedTab == _ReportsTab.maintenance &&
                              _composerMode == _ComposerMode.maintenance)
                            _ComposerCard(
                              title: 'Add Maintenance',
                              accentColor: const Color(0xFFFF8A00),
                              titleController: _titleController,
                              dateController: _dateController,
                              descriptionController: _descriptionController,
                              titleHint: 'Task Name',
                              saveLabel: 'Save Maintenance',
                              onCancel: () =>
                                  _toggleComposer(_ComposerMode.maintenance),
                              onPickDate: _pickDate,
                              onSave: () {
                                _saveComposer();
                              },
                            ),
                          if (_selectedTab == _ReportsTab.events) ...[
                            if (_isLoadingBatchData)
                              _buildMessageCard(
                                'Loading event records...',
                                icon: Icons.hourglass_top_rounded,
                                iconColor: const Color(0xFF3D7BFF),
                              ),
                            if (_currentEvents.isNotEmpty)
                              ..._buildEntries(
                                _currentEvents,
                                mode: _ComposerMode.event,
                              ),
                            if (_currentEvents.isEmpty &&
                                !_isLoadingBatchData &&
                                _composerMode != _ComposerMode.event)
                              _buildEmptyState('Events'),
                          ],
                          if (_selectedTab == _ReportsTab.maintenance) ...[
                            if (_isLoadingBatchData)
                              _buildMessageCard(
                                'Loading maintenance records...',
                                icon: Icons.hourglass_top_rounded,
                                iconColor: const Color(0xFF3D7BFF),
                              ),
                            if (_currentMaintenanceEntries.isNotEmpty)
                              ..._buildEntries(
                                _currentMaintenanceEntries,
                                mode: _ComposerMode.maintenance,
                              ),
                            if (_currentMaintenanceEntries.isEmpty &&
                                !_isLoadingBatchData &&
                                _composerMode != _ComposerMode.maintenance)
                              _buildEmptyState('Maintenance'),
                          ],
                          const SizedBox(height: 120),
                        ],
                      ),
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
                    selected: false,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _BottomNavItem(
                    icon: Icons.show_chart_rounded,
                    label: 'Analytics',
                    selected: false,
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => AnalyticsScreen(
                            initialBatchName: _selectedBatch,
                          ),
                        ),
                      );
                    },
                  ),
                  _BottomNavItem(
                    icon: Icons.description_outlined,
                    label: 'Reports',
                    selected: true,
                    onTap: _openReports,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageCard(
    String message, {
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E9E4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF5B6475),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEntries(
    List<_ReportEntry> entries, {
    required _ComposerMode mode,
  }) {
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ReportEntryCard(
          entry: value,
          accentLabel: mode == _ComposerMode.event ? 'Events' : 'Maintenance',
          onEdit: () => _startEditing(mode, index, value),
          onDelete: () => _deleteEntry(mode, index),
        ),
      );
    }).toList();
  }

  Widget _buildEmptyState(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE4DCC8),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFFD2D8E4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No records found for $label',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8F9AB3),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportEntry {
  final String id;
  final String title;
  final String date;
  final String description;
  final DateTime updatedAt;

  const _ReportEntry({
    required this.id,
    required this.title,
    required this.date,
    required this.description,
    required this.updatedAt,
  });

  factory _ReportEntry.fromRecord(ReportRecord record) {
    return _ReportEntry(
      id: record.id,
      title: record.title,
      date: record.date,
      description: record.description,
      updatedAt: record.updatedAt,
    );
  }
}

class _ReportDefinition {
  final _ReportTemplate type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ReportDefinition({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _ReportPreviewData {
  final String title;
  final String subtitle;
  final String summary;
  final List<_ReportStatData> stats;
  final List<_ReportChartData> charts;
  final List<_ReportPreviewSection> sections;

  const _ReportPreviewData({
    required this.title,
    required this.subtitle,
    required this.summary,
    this.stats = const [],
    this.charts = const [],
    required this.sections,
  });
}

class _ReportStatData {
  final String label;
  final String value;

  const _ReportStatData({required this.label, required this.value});
}

class _ReportChartData {
  final String title;
  final PdfColor color;
  final List<_ReportChartEntry> entries;
  final double? maxValueOverride;

  const _ReportChartData({
    required this.title,
    required this.color,
    required this.entries,
    this.maxValueOverride,
  });
}

class _ReportChartEntry {
  final String label;
  final double value;
  final String formattedValue;

  const _ReportChartEntry({
    required this.label,
    required this.value,
    required this.formattedValue,
  });
}

class _ReportPreviewSection {
  final String title;
  final List<String> lines;

  const _ReportPreviewSection({required this.title, required this.lines});
}

class _ReportDeviceUsageItem {
  final String category;
  final String name;
  final String id;
  final String description;
  final bool enabled;
  final int scheduleCount;

  const _ReportDeviceUsageItem({
    required this.category,
    required this.name,
    required this.id,
    required this.description,
    required this.enabled,
    required this.scheduleCount,
  });
}

class _CycleProgress {
  final int currentDay;
  final int totalDays;

  const _CycleProgress({required this.currentDay, required this.totalDays});
}

class _ExpandableReportCard extends StatelessWidget {
  final _ReportDefinition definition;
  final bool expanded;
  final _ReportPreviewData preview;
  final _ExportRange selectedRange;
  final VoidCallback onTap;
  final ValueChanged<_ExportRange> onRangeChanged;
  final VoidCallback onExport;

  const _ExpandableReportCard({
    required this.definition,
    required this.expanded,
    required this.preview,
    required this.selectedRange,
    required this.onTap,
    required this.onRangeChanged,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: definition.color.withOpacity(0.16),
        highlightColor: definition.color.withOpacity(0.10),
        hoverColor: definition.color.withOpacity(0.08),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: expanded
                ? definition.color.withOpacity(0.08)
                : const Color(0xFFF8FBF7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: expanded
                  ? definition.color.withOpacity(0.28)
                  : const Color(0xFFE3E9E4),
              width: expanded ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: definition.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      definition.icon,
                      color: definition.color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          definition.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          definition.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: expanded
                        ? definition.color
                        : const Color(0xFFB6BFCD),
                    size: 22,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5EAD9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview.title,
                              style: TextStyle(
                                fontSize: 13,
                                color: definition.color,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _ExportRangeDropdown(
                            value: selectedRange,
                            color: definition.color,
                            onChanged: onRangeChanged,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: onExport,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text(
                            'Export PDF',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportEntryCard extends StatelessWidget {
  final _ReportEntry entry;
  final String accentLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReportEntryCard({
    required this.entry,
    required this.accentLabel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAD9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF7EF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              accentLabel == 'Events'
                  ? Icons.event_note_rounded
                  : Icons.build_circle_outlined,
              color: accentLabel == 'Events'
                  ? const Color(0xFFE53935)
                  : const Color(0xFFFF8A00),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8F9AB3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              _MiniActionButton(
                icon: Icons.edit_outlined,
                color: const Color(0xFF3D7BFF),
                onTap: onEdit,
              ),
              const SizedBox(height: 8),
              _MiniActionButton(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFE53935),
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportRangeDropdown extends StatelessWidget {
  final _ExportRange value;
  final Color color;
  final ValueChanged<_ExportRange> onChanged;

  const _ExportRangeDropdown({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_ExportRange>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: color),
          borderRadius: BorderRadius.circular(12),
          focusColor: color.withOpacity(0.08),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          dropdownColor: Colors.white,
          items: const [
            DropdownMenuItem(value: _ExportRange.day, child: Text('Per Day')),
            DropdownMenuItem(value: _ExportRange.week, child: Text('Per Week')),
          ],
          onChanged: (nextValue) {
            if (nextValue != null) {
              onChanged(nextValue);
            }
          },
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: color.withOpacity(0.16),
        highlightColor: color.withOpacity(0.10),
        hoverColor: color.withOpacity(0.08),
        child: Ink(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  final String title;
  final Color accentColor;
  final TextEditingController titleController;
  final TextEditingController dateController;
  final TextEditingController descriptionController;
  final String titleHint;
  final String saveLabel;
  final VoidCallback onCancel;
  final VoidCallback onPickDate;
  final VoidCallback onSave;

  const _ComposerCard({
    required this.title,
    required this.accentColor,
    required this.titleController,
    required this.dateController,
    required this.descriptionController,
    required this.titleHint,
    required this.saveLabel,
    required this.onCancel,
    required this.onPickDate,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    InputDecoration fieldDecoration(String hint, {Widget? suffixIcon}) {
      return InputDecoration(
        hintText: hint,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: Color(0xFFA4A8B3), fontSize: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor),
        ),
      );
    }

    return Container(
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: titleController,
            decoration: fieldDecoration(titleHint),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: dateController,
            readOnly: true,
            onTap: onPickDate,
            mouseCursor: SystemMouseCursors.click,
            decoration: fieldDecoration(
              'dd/mm/yyyy',
              suffixIcon: IconButton(
                onPressed: onPickDate,
                style: IconButton.styleFrom(
                  hoverColor: accentColor.withOpacity(0.08),
                  highlightColor: accentColor.withOpacity(0.12),
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                color: const Color(0xFF2F3748),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: fieldDecoration('Description'),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6D7BA0),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  saveLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: const Color(0xFF0BB13F).withOpacity(0.14),
          highlightColor: const Color(0xFF0BB13F).withOpacity(0.10),
          hoverColor: const Color(0xFF0BB13F).withOpacity(0.08),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF1E8E3E) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF1E8E3E)
                    : const Color(0xFFDCE6DE),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1E8E3E).withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF60718A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: color.withOpacity(0.16),
        highlightColor: color.withOpacity(0.10),
        hoverColor: color.withOpacity(0.08),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE4E0D3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w700,
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

List<T> _takeLast<T>(List<T> values, int count) {
  if (values.length <= count) {
    return List<T>.from(values);
  }
  return values.sublist(values.length - count);
}
