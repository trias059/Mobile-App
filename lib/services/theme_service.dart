// File: lib/services/theme_service.dart
// Fixed version - No setState during build

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AppThemeMode { light, dark, auto }

enum AppTimeOfDay { morning, afternoon, evening, night }

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  late Box _settingsBox;

  AppThemeMode _currentMode = AppThemeMode.auto;
  ThemeData _currentTheme = _getMorningTheme();
  bool _isInitialized = false;

  ThemeService() {
    _init();
  }

  Future<void> _init() async {
    try {
      _settingsBox = await Hive.openBox('settings');
      _loadThemeMode();
      _updateTheme();
      _isInitialized = true;

      // Use post frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      print('Error initializing theme service: $e');
    }
  }

  void _loadThemeMode() {
    final savedMode = _settingsBox.get(_themeKey, defaultValue: 'auto');
    switch (savedMode) {
      case 'light':
        _currentMode = AppThemeMode.light;
        break;
      case 'dark':
        _currentMode = AppThemeMode.dark;
        break;
      default:
        _currentMode = AppThemeMode.auto;
    }
  }

  void _saveThemeMode() {
    if (_isInitialized) {
      _settingsBox.put(_themeKey, _currentMode.toString().split('.').last);
    }
  }

  AppTimeOfDay _getCurrentTimeOfDay() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 6 && hour < 12) {
      return AppTimeOfDay.morning;
    } else if (hour >= 12 && hour < 17) {
      return AppTimeOfDay.afternoon;
    } else if (hour >= 17 && hour < 20) {
      return AppTimeOfDay.evening;
    } else {
      return AppTimeOfDay.night;
    }
  }

  void _updateTheme() {
    switch (_currentMode) {
      case AppThemeMode.light:
        _currentTheme = _getLightTheme();
        break;
      case AppThemeMode.dark:
        _currentTheme = _getDarkTheme();
        break;
      case AppThemeMode.auto:
        _currentTheme = _getTimeBasedTheme();
        break;
    }
  }

  ThemeData _getTimeBasedTheme() {
    switch (_getCurrentTimeOfDay()) {
      case AppTimeOfDay.morning:
        return _getMorningTheme();
      case AppTimeOfDay.afternoon:
        return _getAfternoonTheme();
      case AppTimeOfDay.evening:
        return _getEveningTheme();
      case AppTimeOfDay.night:
        return _getNightTheme();
    }
  }

  // Getters
  AppThemeMode get currentMode => _currentMode;
  ThemeData get currentTheme => _currentTheme;
  AppTimeOfDay get currentTimeOfDay => _getCurrentTimeOfDay();
  bool get isInitialized => _isInitialized;

  String get currentModeDisplayName {
    switch (_currentMode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.auto:
        return 'Auto (${_getTimeDisplayName()})';
    }
  }

  String _getTimeDisplayName() {
    switch (_getCurrentTimeOfDay()) {
      case AppTimeOfDay.morning:
        return 'Morning';
      case AppTimeOfDay.afternoon:
        return 'Afternoon';
      case AppTimeOfDay.evening:
        return 'Evening';
      case AppTimeOfDay.night:
        return 'Night';
    }
  }

  // Theme setters
  void setThemeMode(AppThemeMode mode) {
    _currentMode = mode;
    _updateTheme();
    _saveThemeMode();

    // Use post frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void toggleTheme() {
    switch (_currentMode) {
      case AppThemeMode.light:
        setThemeMode(AppThemeMode.dark);
        break;
      case AppThemeMode.dark:
        setThemeMode(AppThemeMode.auto);
        break;
      case AppThemeMode.auto:
        setThemeMode(AppThemeMode.light);
        break;
    }
  }

  // Background gradients for different times with fallback
  Decoration getBackgroundDecoration() {
    try {
      switch (_currentMode == AppThemeMode.auto ? _getCurrentTimeOfDay() : null) {
        case AppTimeOfDay.morning:
          return _getMorningBackground();
        case AppTimeOfDay.afternoon:
          return _getAfternoonBackground();
        case AppTimeOfDay.evening:
          return _getEveningBackground();
        case AppTimeOfDay.night:
          return _getNightBackground();
        default:
          return _currentMode == AppThemeMode.dark
              ? _getNightBackground()
              : _getAfternoonBackground();
      }
    } catch (e) {
      // Fallback background jika ada error
      return _getDefaultBackground();
    }
  }

  // Default background sebagai fallback
  Decoration _getDefaultBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE3F2FD), // Light blue
          Color(0xFFBBDEFB), // Sky blue
          Color(0xFF90CAF9), // Bright blue
          Color(0xFF64B5F6), // Afternoon blue
        ],
        stops: [0.0, 0.3, 0.6, 1.0],
      ),
    );
  }

  // Theme Definitions
  static ThemeData _getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
    );
  }

  static ThemeData _getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData _getMorningTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4CAF50), // Fresh green
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF2E7D32),
      ),
    );
  }

  static ThemeData _getAfternoonTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3), // Bright blue
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1565C0),
      ),
    );
  }

  static ThemeData _getEveningTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF9800), // Warm orange
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFE65100),
      ),
    );
  }

  static ThemeData _getNightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3F51B5), // Deep purple
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFBBDEFB),
      ),
    );
  }

  // Background Decorations
  Decoration _getMorningBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE8F5E8), // Light mint
          Color(0xFFC8E6C9), // Soft green
          Color(0xFFA5D6A7), // Fresh green
          Color(0xFF81C784), // Morning green
        ],
        stops: [0.0, 0.3, 0.6, 1.0],
      ),
    );
  }

  Decoration _getAfternoonBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE3F2FD), // Light blue
          Color(0xFFBBDEFB), // Sky blue
          Color(0xFF90CAF9), // Bright blue
          Color(0xFF64B5F6), // Afternoon blue
        ],
        stops: [0.0, 0.3, 0.6, 1.0],
      ),
    );
  }

  Decoration _getEveningBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF3E0), // Warm cream
          Color(0xFFFFE0B2), // Sunset orange
          Color(0xFFFFCC80), // Golden hour
          Color(0xFFFFB74D), // Evening glow
        ],
        stops: [0.0, 0.3, 0.6, 1.0],
      ),
    );
  }

  Decoration _getNightBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1A1A2E), // Deep night
          Color(0xFF16213E), // Midnight blue
          Color(0xFF0F3460), // Dark blue
          Color(0xFF533483), // Purple night
        ],
        stops: [0.0, 0.3, 0.6, 1.0],
      ),
    );
  }

  // Helper method untuk update otomatis berdasarkan waktu
  void checkTimeUpdate() {
    if (_currentMode == AppThemeMode.auto && _isInitialized) {
      final newTheme = _getTimeBasedTheme();
      if (newTheme != _currentTheme) {
        _currentTheme = newTheme;

        // Use post frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    }
  }
}