class SensorConfig {
  // Create this in Firebase Realtime Database, then paste your database URL.
  // Example: https://chicktemp-default-rtdb.asia-southeast1.firebasedatabase.app
  static const firebaseDatabaseUrl =
      'https://chicktemp-a6c7e-default-rtdb.asia-southeast1.firebasedatabase.app';

  static const firebaseSensorPath = 'sensor/latest.json';
  static const directEsp32SensorUrl = 'http://192.168.4.1/sensor';

  static String firebaseUrlFor(String path) {
    final baseUrl = firebaseDatabaseUrl.endsWith('/')
        ? firebaseDatabaseUrl.substring(0, firebaseDatabaseUrl.length - 1)
        : firebaseDatabaseUrl;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$cleanPath';
  }

  static String get firebaseSensorUrl {
    if (firebaseDatabaseUrl.contains('YOUR_DATABASE_NAME')) {
      return '';
    }

    return firebaseUrlFor(firebaseSensorPath);
  }
}
