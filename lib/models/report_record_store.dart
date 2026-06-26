import 'auth_store.dart';
import 'firebase_database_service.dart';
import 'shared_workspace.dart';
import 'shared_workspace_migration.dart';

enum ReportRecordType { event, maintenance }

class ReportRecord {
  final String id;
  final String title;
  final String date;
  final String description;
  final DateTime updatedAt;

  const ReportRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.description,
    required this.updatedAt,
  });

  ReportRecord copyWith({
    String? id,
    String? title,
    String? date,
    String? description,
    DateTime? updatedAt,
  }) {
    return ReportRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      description: description ?? this.description,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ReportRecord.fromJson(String id, Map<String, dynamic> json) {
    return ReportRecord(
      id: id,
      title: json['title']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      updatedAt: _readDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'date': date,
      'description': description,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static DateTime _readDate(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

class ReportRecordStore {
  ReportRecordStore._();

  static final ReportRecordStore instance = ReportRecordStore._();

  final FirebaseDatabaseService _database = FirebaseDatabaseService.instance;

  Future<List<ReportRecord>> fetchEntries({
    required String batchId,
    required ReportRecordType type,
  }) async {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      return const [];
    }

    final recordPath = 'report_records/$batchId/${_typeKey(type)}.json';
    var response = await _database.get(SharedWorkspace.path(recordPath));
    if (response is! Map<String, dynamic> || response.isEmpty) {
      final legacyResponse = await _loadLegacyRecords(user.id, recordPath);
      if (legacyResponse is Map<String, dynamic> &&
          legacyResponse.isNotEmpty) {
        response = legacyResponse;
        await _database.put(
          SharedWorkspace.path(recordPath),
          Map<String, dynamic>.from(legacyResponse),
        );
      }
    }
    if (response is! Map<String, dynamic>) {
      return const [];
    }

    final entries = <ReportRecord>[];
    for (final entry in response.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        entries.add(ReportRecord.fromJson(entry.key, value));
      }
    }

    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  Future<Map<String, dynamic>?> _loadLegacyRecords(
    String currentUserId,
    String recordPath,
  ) async {
    return SharedWorkspaceMigration.instance.loadLegacyMap(
      recordPath,
      fallbackUserId: currentUserId,
    );
  }

  Future<ReportRecord> saveEntry({
    required String batchId,
    required ReportRecordType type,
    required ReportRecord entry,
  }) async {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      throw const FirebaseDatabaseException('No signed-in user found.');
    }

    final entryId = entry.id.isNotEmpty
        ? entry.id
        : 'report_${DateTime.now().millisecondsSinceEpoch}';
    final savedEntry = entry.copyWith(
      id: entryId,
      updatedAt: DateTime.now(),
    );

    await _database.put(
      SharedWorkspace.path(
        'report_records/$batchId/${_typeKey(type)}/$entryId.json',
      ),
      savedEntry.toJson(),
    );

    return savedEntry;
  }

  Future<void> deleteEntry({
    required String batchId,
    required ReportRecordType type,
    required String entryId,
  }) async {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      throw const FirebaseDatabaseException('No signed-in user found.');
    }

    await _database.delete(
      SharedWorkspace.path(
        'report_records/$batchId/${_typeKey(type)}/$entryId.json',
      ),
    );
  }

  Future<void> deleteBatchRecords({
    required String batchId,
  }) async {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      throw const FirebaseDatabaseException('No signed-in user found.');
    }

    await _database.delete(
      SharedWorkspace.path('report_records/$batchId.json'),
    );
  }

  String _typeKey(ReportRecordType type) {
    switch (type) {
      case ReportRecordType.event:
        return 'events';
      case ReportRecordType.maintenance:
        return 'maintenance';
    }
  }
}
