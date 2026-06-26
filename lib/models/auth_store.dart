import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_database_service.dart';

class AppUser {
  final String id;
  final String fullName;
  final String emailAddress;
  final String phoneNumber;
  final String role;
  final String profilePhotoBase64;
  final bool startsWithEmptyControls;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.emailAddress,
    required this.phoneNumber,
    required this.role,
    required this.profilePhotoBase64,
    required this.startsWithEmptyControls,
  });

  factory AppUser.fromJson(String id, Map<String, dynamic> json) {
    return AppUser(
      id: id,
      fullName: json['full_name']?.toString() ?? '',
      emailAddress: json['email_address']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      role: json['role']?.toString() ?? 'manager',
      profilePhotoBase64: json['profile_photo_base64']?.toString() ?? '',
      startsWithEmptyControls: json['starts_with_empty_controls'] == true,
    );
  }

  String get initials => AuthStore.buildInitials(fullName);
  bool get hasProfilePhoto => profilePhotoBase64.trim().isNotEmpty;
}

class AuthResult {
  final bool success;
  final String message;
  final AppUser? user;

  const AuthResult._({
    required this.success,
    required this.message,
    this.user,
  });

  factory AuthResult.success(AppUser user) {
    return AuthResult._(
      success: true,
      message: 'Signed in',
      user: user,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(
      success: false,
      message: message,
    );
  }
}

class AuthStore {
  AuthStore._();

  static const String _cachedUsersKey = 'cached_auth_users';
  static const String rememberMeKey = 'remember_me';
  static const String rememberedEmailKey = 'remembered_email';
  static const String _rememberedUserIdKey = 'remembered_user_id';
  static const String gmailAddressMessage =
      'Enter a valid Gmail address ending in @gmail.com.';
  static final RegExp _gmailAddressPattern = RegExp(
    r'^[A-Z0-9._%+-]+@gmail\.com$',
    caseSensitive: false,
  );

  static final AuthStore instance = AuthStore._();

  final FirebaseDatabaseService _database = FirebaseDatabaseService.instance;

  AppUser? currentUser;

  String get currentUserInitials => buildInitials(currentUser?.fullName);

  static bool isValidGmailAddress(String email) {
    return _gmailAddressPattern.hasMatch(email.trim());
  }

  Future<({bool enabled, String email})> loadRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      enabled: prefs.getBool(rememberMeKey) ?? false,
      email: prefs.getString(rememberedEmailKey) ?? '',
    );
  }

  Future<void> saveRememberedLogin({
    required bool enabled,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(rememberMeKey, enabled);
    if (enabled) {
      await prefs.setString(rememberedEmailKey, email.trim().toLowerCase());
      final userId = currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        await prefs.setString(_rememberedUserIdKey, userId);
      }
      return;
    }

    await prefs.remove(rememberedEmailKey);
    await prefs.remove(_rememberedUserIdKey);
  }

  Future<bool> restoreRememberedSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(rememberMeKey) ?? false)) {
      return false;
    }

    final userId = prefs.getString(_rememberedUserIdKey);
    if (userId == null || userId.isEmpty) {
      return false;
    }

    final record = await _loadCachedUserRecord(userId);
    if (record == null) {
      return false;
    }

    currentUser = AppUser.fromJson(userId, record);
    return true;
  }

  Future<void> signOut() async {
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedUserIdKey);
  }

  Future<AuthResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!isValidGmailAddress(normalizedEmail)) {
      return AuthResult.failure(gmailAddressMessage);
    }

    final existingUserId = await _findUserIdByEmail(normalizedEmail);
    if (existingUserId != null) {
      return AuthResult.failure('An account already exists for this email.');
    }

    final emailKey = _emailKey(normalizedEmail);
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final userJson = {
      'user_id': userId,
      'full_name': fullName.trim(),
      'email_address': normalizedEmail,
      'password_hash': _passwordHash(password),
      'phone_number': '',
      'role': 'manager',
      'profile_photo_base64': '',
      'starts_with_empty_controls': false,
    };

    await _database.put('users/$userId.json', userJson);
    await _database.put('users_by_email/$emailKey.json', {'user_id': userId});
    await _cacheUserRecord(userId, userJson);

    final user = AppUser.fromJson(userId, userJson);
    currentUser = user;
    return AuthResult.success(user);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!isValidGmailAddress(normalizedEmail)) {
      return AuthResult.failure(gmailAddressMessage);
    }

    try {
      final userId = await _findUserIdByEmail(normalizedEmail);
      if (userId == null || userId.isEmpty) {
        return AuthResult.failure('No account found for this email.');
      }

      final userRecord = await _database.get('users/$userId.json');
      if (userRecord is! Map<String, dynamic>) {
        return AuthResult.failure('No account found for this email.');
      }

      if (userRecord['password_hash'] != _passwordHash(password)) {
        return AuthResult.failure('Incorrect password.');
      }

      await _cacheUserRecord(userId, userRecord);
      final user = AppUser.fromJson(userId, userRecord);
      currentUser = user;
      return AuthResult.success(user);
    } on Object catch (error) {
      final cachedResult = await _loginFromCache(
        email: normalizedEmail,
        password: password,
      );
      if (cachedResult != null) {
        return cachedResult;
      }
      if (error is FirebaseDatabaseException) {
        return AuthResult.failure(error.message);
      }
      return AuthResult.failure(
        'Unable to sign in right now. Check your connection and try again.',
      );
    }
  }

  Future<AuthResult> updateProfile({
    required String fullName,
    required String email,
    required String phoneNumber,
    String? profilePhotoBase64,
  }) async {
    final user = currentUser;
    if (user == null) {
      return AuthResult.failure('No user is signed in.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (!isValidGmailAddress(normalizedEmail)) {
      return AuthResult.failure(gmailAddressMessage);
    }

    final isEmailChanged = normalizedEmail != user.emailAddress.toLowerCase();
    final previousEmailKey = _emailKey(user.emailAddress.toLowerCase());
    final nextEmailKey = _emailKey(normalizedEmail);

    if (!isEmailChanged) {
      final cachedRecord = await _loadCachedUserRecord(user.id);
      final nextRecord = _updatedProfileRecord(
        user: user,
        sourceRecord: cachedRecord,
        fullName: fullName,
        normalizedEmail: normalizedEmail,
        phoneNumber: phoneNumber,
        profilePhotoBase64: profilePhotoBase64,
      );
      await _cacheUserRecord(user.id, nextRecord);

      final updatedUser = AppUser.fromJson(user.id, nextRecord);
      currentUser = updatedUser;
      unawaited(_syncProfileRecord(user: updatedUser, record: nextRecord));
      return AuthResult._(
        success: true,
        message: 'Profile updated',
        user: updatedUser,
      );
    }

    try {
      final existingUserId = await _findUserIdByEmail(normalizedEmail);
      if (existingUserId != null && existingUserId != user.id) {
        return AuthResult.failure(
          'That email is already used by another account.',
        );
      }

      final userRecord = await _database.get('users/${user.id}.json');
      final nextRecord = _updatedProfileRecord(
        user: user,
        sourceRecord: userRecord,
        fullName: fullName,
        normalizedEmail: normalizedEmail,
        phoneNumber: phoneNumber,
        profilePhotoBase64: profilePhotoBase64,
      );

      await _database.put('users/${user.id}.json', nextRecord);
      if (previousEmailKey != nextEmailKey) {
        await _database.delete('users_by_email/$previousEmailKey.json');
      }
      await _database.put('users_by_email/$nextEmailKey.json', {
        'user_id': user.id,
      });
      await _cacheUserRecord(user.id, nextRecord);

      final updatedUser = AppUser.fromJson(user.id, nextRecord);
      currentUser = updatedUser;
      return AuthResult.success(updatedUser);
    } on FirebaseDatabaseException catch (error) {
      if (isEmailChanged) {
        return AuthResult.failure(
          '${error.message} Connect to the internet before changing your email address.',
        );
      }

      final cachedRecord = await _loadCachedUserRecord(user.id);
      final nextRecord = _updatedProfileRecord(
        user: user,
        sourceRecord: cachedRecord,
        fullName: fullName,
        normalizedEmail: normalizedEmail,
        phoneNumber: phoneNumber,
        profilePhotoBase64: profilePhotoBase64,
      );
      await _cacheUserRecord(user.id, nextRecord);

      final updatedUser = AppUser.fromJson(user.id, nextRecord);
      currentUser = updatedUser;
      return AuthResult._(
        success: true,
        message:
            'Profile saved on this device. Save again when online to sync it to Firebase.',
        user: updatedUser,
      );
    }
  }

  Future<AuthResult> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return AuthResult.failure('Enter your email address.');
    }
    if (!isValidGmailAddress(normalizedEmail)) {
      return AuthResult.failure(gmailAddressMessage);
    }
    if (newPassword.length < 6) {
      return AuthResult.failure('Password must be at least 6 characters.');
    }

    final userId = await _findUserIdByEmail(normalizedEmail);
    if (userId == null || userId.isEmpty) {
      return AuthResult.failure('No account found for this email.');
    }

    final userRecord = await _database.get('users/$userId.json');
    if (userRecord is! Map<String, dynamic>) {
      return AuthResult.failure('No account found for this email.');
    }

    final nextRecord = <String, dynamic>{
      ...userRecord,
      'email_address': normalizedEmail,
      'password_hash': _passwordHash(newPassword),
    };

    await _database.put('users/$userId.json', nextRecord);
    await _cacheUserRecord(userId, nextRecord);

    if (currentUser?.id == userId) {
      currentUser = AppUser.fromJson(userId, nextRecord);
    }

    return AuthResult.success(AppUser.fromJson(userId, nextRecord));
  }

  Future<String?> _findUserIdByEmail(String email) async {
    final emailKey = _emailKey(email);
    final emailRecord = await _database.get('users_by_email/$emailKey.json');
    if (emailRecord is Map<String, dynamic>) {
      final userId = emailRecord['user_id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        return userId;
      }
    }
    if (emailRecord is String && emailRecord.isNotEmpty) {
      return emailRecord;
    }

    final users = await _database.get('users.json');
    if (users is Map<String, dynamic>) {
      for (final entry in users.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic> &&
            value['email_address']?.toString().toLowerCase() == email) {
          return entry.key;
        }
      }
    }

    return null;
  }

  String _emailKey(String email) {
    return base64Url.encode(utf8.encode(email)).replaceAll('=', '');
  }

  Future<AuthResult?> _loginFromCache({
    required String email,
    required String password,
  }) async {
    final cachedUsers = await _loadCachedUsers();
    for (final entry in cachedUsers.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) {
        continue;
      }

      final cachedEmail = value['email_address']?.toString().toLowerCase();
      if (cachedEmail != email) {
        continue;
      }

      if (value['password_hash'] != _passwordHash(password)) {
        return AuthResult.failure('Incorrect password.');
      }

      final user = AppUser.fromJson(entry.key, value);
      currentUser = user;
      return AuthResult.success(user);
    }

    return null;
  }

  Future<void> _cacheUserRecord(
    String userId,
    Map<String, dynamic> record,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedUsers = await _loadCachedUsers();
    cachedUsers[userId] = Map<String, dynamic>.from(record);
    await prefs.setString(_cachedUsersKey, jsonEncode(cachedUsers));
  }

  Future<Map<String, dynamic>> _loadCachedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedUsersKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> _loadCachedUserRecord(String userId) async {
    final cachedUsers = await _loadCachedUsers();
    final record = cachedUsers[userId];
    if (record is Map<String, dynamic>) {
      return Map<String, dynamic>.from(record);
    }
    return null;
  }

  Future<void> _syncProfileRecord({
    required AppUser user,
    required Map<String, dynamic> record,
  }) async {
    try {
      await _database.put('users/${user.id}.json', record);
      await _database.put('users_by_email/${_emailKey(user.emailAddress)}.json', {
        'user_id': user.id,
      });
    } on Object {
      // Keep the locally cached profile even if background sync fails.
    }
  }

  Map<String, dynamic> _updatedProfileRecord({
    required AppUser user,
    required Object? sourceRecord,
    required String fullName,
    required String normalizedEmail,
    required String phoneNumber,
    required String? profilePhotoBase64,
  }) {
    final record = sourceRecord is Map<String, dynamic>
        ? Map<String, dynamic>.from(sourceRecord)
        : <String, dynamic>{};
    return <String, dynamic>{
      ...record,
      'user_id': user.id,
      'full_name': fullName.trim(),
      'email_address': normalizedEmail,
      'phone_number': phoneNumber.trim(),
      'role': user.role,
      'starts_with_empty_controls':
          record['starts_with_empty_controls'] ?? user.startsWithEmptyControls,
      'profile_photo_base64':
          profilePhotoBase64 ??
          record['profile_photo_base64']?.toString() ??
          user.profilePhotoBase64,
    };
  }

  static String buildInitials(String? name, {String fallback = 'FM'}) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return fallback;
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _passwordHash(String password) {
    // Prototype-only hash to avoid storing plain text in the demo database.
    // Use Firebase Auth before putting this app into production.
    var hash = 0x811c9dc5;
    for (final codeUnit in password.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
