import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_store.dart';
import 'firebase_database_service.dart';
import 'shared_workspace.dart';
import 'shared_workspace_migration.dart';

class BatchItem {
  final String id;
  final String name;
  final String status;
  final String startedAt;
  final String dayLabel;
  final String birdsLabel;
  final int mortalityCount;
  final int? dayAnchorDay;
  final DateTime? dayAnchorDate;

  const BatchItem({
    this.id = '',
    required this.name,
    required this.status,
    required this.startedAt,
    required this.dayLabel,
    required this.birdsLabel,
    this.mortalityCount = 0,
    this.dayAnchorDay,
    this.dayAnchorDate,
  });

  BatchItem copyWith({
    String? id,
    String? name,
    String? status,
    String? startedAt,
    String? dayLabel,
    String? birdsLabel,
    int? mortalityCount,
    int? dayAnchorDay,
    DateTime? dayAnchorDate,
    bool clearDayAnchor = false,
  }) {
    return BatchItem(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      dayLabel: dayLabel ?? this.dayLabel,
      birdsLabel: birdsLabel ?? this.birdsLabel,
      mortalityCount: mortalityCount ?? this.mortalityCount,
      dayAnchorDay: clearDayAnchor
          ? null
          : dayAnchorDay ?? this.dayAnchorDay,
      dayAnchorDate: clearDayAnchor
          ? null
          : dayAnchorDate ?? this.dayAnchorDate,
    );
  }

  factory BatchItem.fromJson(String id, Map<String, dynamic> json) {
    final dayLabel = json['day_label']?.toString() ?? 'Day 1 / 45';
    final isActive = json['is_active'] != false;
    return BatchItem(
      id: id,
      name: json['batch_name']?.toString() ?? 'Unnamed Batch',
      status: !isActive || _isCycleFinished(dayLabel) ? 'INACTIVE' : 'ACTIVE',
      startedAt: json['started_at_label']?.toString() ?? 'Started: Not set',
      dayLabel: dayLabel,
      birdsLabel: '${json['total_chickens'] ?? 0} Birds',
      mortalityCount: _readInt(json['mortality_count']),
      dayAnchorDay: _readNullableInt(json['day_anchor_day']),
      dayAnchorDate: _readDate(json['day_anchor_date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'batch_id': stableId,
      'batch_name': name,
      'started_at_label': startedAt,
      'day_label': dayLabel,
      'total_chickens': _birdsCount,
      'mortality_count': mortalityCount,
      'is_active': status.toUpperCase() == 'ACTIVE',
      if (dayAnchorDay != null) 'day_anchor_day': dayAnchorDay,
      if (dayAnchorDate != null)
        'day_anchor_date': _dateOnlyIso(dayAnchorDate!),
    };
  }

  String get stableId => id.isNotEmpty ? id : _safeKey(name);

  BatchItem withElapsedDay([DateTime? currentDate]) {
    if (status.toUpperCase() == 'INACTIVE') {
      return this;
    }

    final dayMatch = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(dayLabel);
    if (dayMatch == null) {
      return this;
    }

    final savedDay = int.tryParse(dayMatch.group(1) ?? '');
    final totalDays = int.tryParse(dayMatch.group(2) ?? '');
    if (savedDay == null || totalDays == null || totalDays <= 0) {
      return this;
    }

    final now = currentDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final anchorDate = dayAnchorDate;
    final anchorDay = dayAnchorDay;
    final calculatedDay = anchorDate != null && anchorDay != null
        ? _calculatedDayFromAnchor(
            anchorDay: anchorDay,
            anchorDate: anchorDate,
            today: today,
          )
        : _calculatedDayFromStart(
            startedAt: startedAt,
            today: today,
            savedDay: savedDay,
          );
    final nextDay = calculatedDay.clamp(1, totalDays).toInt();
    final nextLabel = 'Day $nextDay / $totalDays';
    final nextStatus = nextDay >= totalDays ? 'INACTIVE' : 'ACTIVE';

    if (nextLabel == dayLabel && nextStatus == status) {
      return this;
    }
    return copyWith(dayLabel: nextLabel, status: nextStatus);
  }

  int get _birdsCount {
    final digits = RegExp(r'\d+').firstMatch(birdsLabel)?.group(0);
    return int.tryParse(digits ?? '') ?? 0;
  }

  static String _safeKey(String value) {
    final key = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return key.isEmpty ? 'batch_${DateTime.now().millisecondsSinceEpoch}' : key;
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

  static int? _readNullableInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static DateTime? _readDate(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
    }
    return null;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _dateOnlyIso(DateTime value) {
    final date = _dateOnly(value);
    return date.toIso8601String();
  }

  static int _calculatedDayFromStart({
    required String startedAt,
    required DateTime today,
    required int savedDay,
  }) {
    final startDate = _parseStartedAt(startedAt);
    if (startDate == null) {
      return savedDay;
    }

    final firstDay = _dateOnly(startDate);
    final elapsedDay = today.difference(firstDay).inDays + 1;
    return elapsedDay > savedDay ? elapsedDay : savedDay;
  }

  static int _calculatedDayFromAnchor({
    required int anchorDay,
    required DateTime anchorDate,
    required DateTime today,
  }) {
    final calculatedDay = anchorDay + today.difference(_dateOnly(anchorDate)).inDays;
    return calculatedDay > anchorDay ? calculatedDay : anchorDay;
  }

  static int? _currentDayFromLabel(String dayLabel) {
    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(dayLabel);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  static DateTime? _parseStartedAt(String value) {
    final raw = value.replaceFirst(RegExp(r'^Started:\s*'), '').trim();
    final isoDate = DateTime.tryParse(raw);
    if (isoDate != null) {
      return isoDate;
    }

    final match = RegExp(
      r'^([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})$',
    ).firstMatch(raw);
    if (match == null) {
      return null;
    }

    const months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    final month = months[match.group(1)!.toLowerCase()];
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (month == null || day == null || year == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  static bool _isCycleFinished(String dayLabel) {
    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(dayLabel);
    if (match == null) {
      return false;
    }

    final currentDay = int.tryParse(match.group(1) ?? '');
    final totalDays = int.tryParse(match.group(2) ?? '');
    if (currentDay == null || totalDays == null || totalDays <= 0) {
      return false;
    }

    return currentDay >= totalDays;
  }
}

class BatchStore extends ChangeNotifier {
  BatchStore._() {
    _scheduleNextDayRefresh();
  }

  static final BatchStore instance = BatchStore._();

  final FirebaseDatabaseService _database = FirebaseDatabaseService.instance;
  Timer? _dayRefreshTimer;

  static const String _batchCachePrefix = 'cached_batches';

  final List<BatchItem> _batches = [
    const BatchItem(
      id: 'broiler_batch_1',
      name: 'Broiler Batch 1',
      status: 'ACTIVE',
      startedAt: 'Started: May 26, 2026',
      dayLabel: 'Day 1 / 45',
      birdsLabel: '500 Birds',
      mortalityCount: 0,
    ),
  ];

  List<BatchItem> get batches {
    _refreshElapsedDays();
    return List.unmodifiable(_batches);
  }

  BatchItem? get activeBatch {
    _refreshElapsedDays();
    for (final batch in _batches) {
      if (_isActive(batch)) {
        return batch;
      }
    }
    return null;
  }

  List<BatchItem> get activeBatches {
    _refreshElapsedDays();
    return List.unmodifiable(_batches.where(_isActive));
  }

  List<BatchItem> get historyBatches {
    _refreshElapsedDays();
    return List.unmodifiable(_batches.where((batch) => !_isActive(batch)));
  }

  bool get hasActiveBatch => activeBatch != null;

  bool get isEmpty => _batches.isEmpty;

  void add(BatchItem batch) {
    _refreshElapsedDays();
    final savedBatch = batch.copyWith(id: batch.stableId).withElapsedDay();
    if (_isActive(savedBatch) && _batches.any(_isActive)) {
      throw StateError('Finish the active batch before creating a new one.');
    }
    _batches.add(savedBatch);
    notifyListeners();
    unawaited(_saveLocalCache());
    _saveBatch(savedBatch);
  }

  void clear() {
    _batches.clear();
    notifyListeners();
  }

  void remove(BatchItem batch) {
    _batches.remove(batch);
    notifyListeners();
    unawaited(_saveLocalCache());
    _deleteBatch(batch);
  }

  void update(BatchItem previous, BatchItem updated) {
    final index = _batches.indexOf(previous);
    if (index == -1) {
      return;
    }

    final savedBatch = updated.copyWith(
      id: previous.stableId,
      clearDayAnchor: previous.startedAt != updated.startedAt,
    );
    _batches[index] = savedBatch;
    notifyListeners();
    unawaited(_saveLocalCache());
    _saveBatch(savedBatch);
  }

  BatchItem? findById(String batchId) {
    _refreshElapsedDays();
    for (final batch in _batches) {
      if (batch.stableId == batchId) {
        return batch;
      }
    }
    return null;
  }

  BatchItem? findByName(String batchName) {
    _refreshElapsedDays();
    for (final batch in _batches) {
      if (batch.name == batchName) {
        return batch;
      }
    }
    return null;
  }

  int totalBirdsFor(String batchName) {
    final batch = findByName(batchName);
    if (batch == null) {
      return 500;
    }
    final digits = RegExp(r'\d+').firstMatch(batch.birdsLabel)?.group(0);
    return int.tryParse(digits ?? '') ?? 500;
  }

  int mortalityCountFor(String batchName) {
    return findByName(batchName)?.mortalityCount ?? 0;
  }

  int aliveBirdsFor(String batchName) {
    final totalBirds = totalBirdsFor(batchName);
    final mortality = mortalityCountFor(batchName);
    return (totalBirds - mortality).clamp(0, totalBirds).toInt();
  }

  void setMortalityCount(String batchName, int mortalityCount) {
    final index = _batches.indexWhere((batch) => batch.name == batchName);
    if (index == -1) {
      return;
    }

    final next = _batches[index].copyWith(mortalityCount: mortalityCount);
    _batches[index] = next;
    notifyListeners();
    unawaited(_saveLocalCache());
    _saveBatch(next);
  }

  Future<BatchItem?> finishBatch({
    required String batchId,
  }) async {
    final index = _batches.indexWhere((batch) => batch.stableId == batchId);
    if (index == -1) {
      return null;
    }

    final previous = _batches[index];
    final finished = previous.copyWith(status: 'INACTIVE');
    _batches[index] = finished;
    notifyListeners();
    await _saveLocalCache();

    try {
      await _persistBatch(finished);
      return finished;
    } on Object {
      _batches[index] = previous;
      await _saveLocalCache();
      notifyListeners();
      rethrow;
    }
  }

  Future<BatchItem?> updateDayLabel({
    required String batchId,
    required String dayLabel,
    bool notifyListenersOnChange = true,
  }) async {
    final index = _batches.indexWhere((batch) => batch.stableId == batchId);
    if (index == -1) {
      return null;
    }

    final previous = _batches[index];
    final anchorDay = BatchItem._currentDayFromLabel(dayLabel);
    final now = DateTime.now();
    final updated = previous.copyWith(
      dayLabel: dayLabel,
      status: _statusForDayLabel(dayLabel),
      dayAnchorDay: anchorDay,
      dayAnchorDate: BatchItem._dateOnly(now),
    );
    _batches[index] = updated;
    if (notifyListenersOnChange) {
      notifyListeners();
    }
    await _saveLocalCache();

    try {
      await _persistBatch(updated);
      return updated;
    } on Object {
      _batches[index] = previous;
      await _saveLocalCache();
      if (notifyListenersOnChange) {
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> loadForCurrentUser() async {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      return;
    }

    dynamic response;
    try {
      response = await _database.get(SharedWorkspace.path('batches.json'));
      if (response is! Map<String, dynamic> || response.isEmpty) {
        final legacyResponse = await _loadLegacyBatches(user.id);
        if (legacyResponse != null && legacyResponse.isNotEmpty) {
          response = legacyResponse;
          await _database.put(
            SharedWorkspace.path('batches.json'),
            legacyResponse,
          );
        }
      }
    } on Object {
      final restored = await _loadLocalCache();
      if (restored) {
        notifyListeners();
        return;
      }
      rethrow;
    }

    _batches.clear();
    if (response is! Map<String, dynamic>) {
      await _saveLocalCache();
      notifyListeners();
      return;
    }

    for (final entry in response.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        _batches.add(BatchItem.fromJson(entry.key, value).withElapsedDay());
      }
    }
    final normalizedBatches = _normalizeSingleActiveBatch();
    await _saveLocalCache();
    _persistBatchUpdates(normalizedBatches);
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _loadLegacyBatches(String currentUserId) async {
    return SharedWorkspaceMigration.instance.loadLegacyMap(
      'batches',
      fallbackUserId: currentUserId,
    );
  }

  Future<void> saveAllForCurrentUser() async {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      return;
    }

    final batchesJson = {
      for (final batch in _batches)
        batch.stableId: batch.withElapsedDay().toJson(),
    };
    if (batchesJson.isEmpty) {
      final existing = await _database.get(SharedWorkspace.path('batches.json'));
      if (existing is Map<String, dynamic> && existing.isNotEmpty) {
        return;
      }
    }
    await _database.put(SharedWorkspace.path('batches.json'), batchesJson);
    await _saveLocalCache();
  }

  void _saveBatch(BatchItem batch) {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      return;
    }

    unawaited(_persistBatch(batch));
  }

  void _deleteBatch(BatchItem batch) {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      return;
    }

    unawaited(
      _database.delete(
        SharedWorkspace.path('batches/${batch.stableId}.json'),
      ),
    );
  }

  Future<void> _persistBatch(BatchItem batch) async {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      return;
    }

    await _database.put(
      SharedWorkspace.path('batches/${batch.stableId}.json'),
      batch.toJson(),
    );
  }

  void _refreshElapsedDays({bool notify = false}) {
    var changed = false;
    for (var index = 0; index < _batches.length; index++) {
      final refreshed = _batches[index].withElapsedDay();
      if (!identical(refreshed, _batches[index])) {
        _batches[index] = refreshed;
        changed = true;
      }
    }

    final normalizedBatches = _normalizeSingleActiveBatch();
    if (normalizedBatches.isNotEmpty) {
      changed = true;
    }

    if (!changed) {
      return;
    }
    unawaited(_saveLocalCache());
    _persistBatchUpdates(normalizedBatches);
    if (notify) {
      notifyListeners();
    }
  }

  List<BatchItem> _normalizeSingleActiveBatch() {
    final activeIndexes = <int>[];
    for (var index = 0; index < _batches.length; index++) {
      if (_isActive(_batches[index])) {
        activeIndexes.add(index);
      }
    }

    if (activeIndexes.length <= 1) {
      return const [];
    }

    final keeperIndex = activeIndexes.reduce((bestIndex, nextIndex) {
      final bestDate = BatchItem._parseStartedAt(_batches[bestIndex].startedAt);
      final nextDate = BatchItem._parseStartedAt(_batches[nextIndex].startedAt);
      if (nextDate == null && bestDate != null) {
        return bestIndex;
      }
      if (nextDate != null &&
          (bestDate == null || !nextDate.isBefore(bestDate))) {
        return nextIndex;
      }
      return bestIndex;
    });

    final changedBatches = <BatchItem>[];
    for (final index in activeIndexes) {
      if (index == keeperIndex) {
        continue;
      }
      final inactive = _batches[index].copyWith(status: 'INACTIVE');
      _batches[index] = inactive;
      changedBatches.add(inactive);
    }
    return changedBatches;
  }

  void _persistBatchUpdates(Iterable<BatchItem> batches) {
    for (final batch in batches) {
      _saveBatch(batch);
    }
  }

  void _scheduleNextDayRefresh() {
    _dayRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dayRefreshTimer = Timer(nextDay.difference(now), () {
      _refreshElapsedDays(notify: true);
      _scheduleNextDayRefresh();
    });
  }

  Future<bool> _loadLocalCache() async {
    final cacheKey = _localCacheKey;
    if (cacheKey == null) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) {
        final userId = AuthStore.instance.currentUser?.id;
        if (userId != null && userId.isNotEmpty) {
          final legacyKey = '${_batchCachePrefix}_${_safeCacheKey(userId)}';
          raw = prefs.getString(legacyKey);
          if (raw != null && raw.isNotEmpty) {
            await prefs.setString(cacheKey, raw);
          }
        }
      }
      if (raw == null || raw.isEmpty) {
        return false;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      _batches.clear();
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          _batches.add(BatchItem.fromJson(entry.key, value).withElapsedDay());
        }
      }
      _normalizeSingleActiveBatch();
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _saveLocalCache() async {
    final cacheKey = _localCacheKey;
    if (cacheKey == null) {
      return;
    }

    final payload = {
      for (final batch in _batches)
        batch.stableId: batch.withElapsedDay().toJson(),
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(payload));
    } on Object {
      // The batch remains usable even if device storage is unavailable.
    }
  }

  String? get _localCacheKey => SharedWorkspace.localKey(_batchCachePrefix);

  String _safeCacheKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  static String _statusForDayLabel(String dayLabel) {
    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(dayLabel);
    if (match == null) {
      return 'ACTIVE';
    }

    final currentDay = int.tryParse(match.group(1) ?? '');
    final totalDays = int.tryParse(match.group(2) ?? '');
    if (currentDay == null || totalDays == null || totalDays <= 0) {
      return 'ACTIVE';
    }

    return currentDay >= totalDays ? 'INACTIVE' : 'ACTIVE';
  }

  static bool _isActive(BatchItem batch) {
    return batch.status.toUpperCase() == 'ACTIVE';
  }
}
