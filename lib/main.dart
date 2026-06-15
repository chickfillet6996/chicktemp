import 'package:flutter/material.dart';

import 'models/monitoring_store.dart';
import 'screens/splash_screen.dart';
import 'widgets/chicktemp_page_transitions.dart';
 
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MonitoringStore.instance.start();
  runApp(const ChickTempApp());
}
 
class ChickTempApp extends StatelessWidget {
  const ChickTempApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChickTemp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter', // or use default; add Google Fonts if desired
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        pageTransitionsTheme: ChickTempPageTransitionsTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}
