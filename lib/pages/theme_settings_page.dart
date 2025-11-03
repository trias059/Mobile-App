import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lisku/services/theme_service.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          body: Container(
            decoration: themeService.getBackgroundDecoration(),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(context, themeService),
                    const SizedBox(height: 30),

                    // Current Theme Display
                    _buildCurrentThemeCard(themeService),
                    const SizedBox(height: 20),

                    // Theme Options
                    _buildThemeOptions(themeService),
                    const SizedBox(height: 30),

                    // Time-based Preview
                    _buildTimePreview(themeService),
                    const SizedBox(height: 20),

                    // Theme Info
                    _buildThemeInfo(themeService),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeService themeService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengaturan Tema',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Mode: ${themeService.currentModeDisplayName}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: themeService.toggleTheme,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentThemeCard(ThemeService themeService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _getThemeIcon(themeService),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tema Aktif',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      themeService.currentModeDisplayName,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (themeService.currentMode == AppThemeMode.auto) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getTimeColor(themeService.currentTimeOfDay).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _getTimeIcon(themeService.currentTimeOfDay),
                    color: _getTimeColor(themeService.currentTimeOfDay),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getTimeDescription(themeService.currentTimeOfDay),
                    style: TextStyle(
                      color: _getTimeColor(themeService.currentTimeOfDay),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemeOptions(ThemeService themeService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Mode Tema',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          _buildThemeOption(
            themeService,
            AppThemeMode.auto,
            Icons.brightness_auto,
            'Otomatis',
            'Berubah sesuai waktu hari',
            Colors.blue,
          ),
          const SizedBox(height: 10),
          _buildThemeOption(
            themeService,
            AppThemeMode.light,
            Icons.brightness_7,
            'Terang',
            'Selalu menggunakan tema terang',
            Colors.orange,
          ),
          const SizedBox(height: 10),
          _buildThemeOption(
            themeService,
            AppThemeMode.dark,
            Icons.brightness_3,
            'Gelap',
            'Selalu menggunakan tema gelap',
            Colors.indigo,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
      ThemeService themeService,
      AppThemeMode mode,
      IconData icon,
      String title,
      String description,
      Color color,
      ) {
    final isSelected = themeService.currentMode == mode;

    return InkWell(
      onTap: () => themeService.setThemeMode(mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePreview(ThemeService themeService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview Tema Berdasarkan Waktu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _buildTimePreviewCard(AppTimeOfDay.morning, '06:00-11:59')),
              const SizedBox(width: 8),
              Expanded(child: _buildTimePreviewCard(AppTimeOfDay.afternoon, '12:00-16:59')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTimePreviewCard(AppTimeOfDay.evening, '17:00-19:59')),
              const SizedBox(width: 8),
              Expanded(child: _buildTimePreviewCard(AppTimeOfDay.night, '20:00-05:59')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePreviewCard(AppTimeOfDay timeOfDay, String timeRange) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getPreviewGradient(timeOfDay),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getTimeIcon(timeOfDay),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            _getTimeDisplayName(timeOfDay),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            timeRange,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeInfo(ThemeService themeService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Informasi Tema',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Mode Otomatis mengubah tema berdasarkan waktu hari\n'
                '• Background wallpaper berubah otomatis untuk pengalaman visual yang menyenangkan\n'
                '• Tema akan update otomatis saat perpindahan waktu\n'
                '• Pengaturan tersimpan dan aktif saat aplikasi restart',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getThemeIcon(ThemeService themeService) {
    IconData icon;
    Color color;

    switch (themeService.currentMode) {
      case AppThemeMode.auto:
        icon = _getTimeIcon(themeService.currentTimeOfDay);
        color = _getTimeColor(themeService.currentTimeOfDay);
        break;
      case AppThemeMode.light:
        icon = Icons.brightness_7;
        color = Colors.orange;
        break;
      case AppThemeMode.dark:
        icon = Icons.brightness_3;
        color = Colors.indigo;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  IconData _getTimeIcon(AppTimeOfDay timeOfDay) {
    switch (timeOfDay) {
      case AppTimeOfDay.morning:
        return Icons.wb_sunny;
      case AppTimeOfDay.afternoon:
        return Icons.wb_sunny_outlined;
      case AppTimeOfDay.evening:
        return Icons.wb_twilight;
      case AppTimeOfDay.night:
        return Icons.nights_stay;
    }
  }

  Color _getTimeColor(AppTimeOfDay timeOfDay) {
    switch (timeOfDay) {
      case AppTimeOfDay.morning:
        return Colors.green;
      case AppTimeOfDay.afternoon:
        return Colors.blue;
      case AppTimeOfDay.evening:
        return Colors.orange;
      case AppTimeOfDay.night:
        return Colors.indigo;
    }
  }

  String _getTimeDescription(AppTimeOfDay timeOfDay) {
    switch (timeOfDay) {
      case AppTimeOfDay.morning:
        return 'Tema Pagi - Fresh & Energik';
      case AppTimeOfDay.afternoon:
        return 'Tema Siang - Bright & Clean';
      case AppTimeOfDay.evening:
        return 'Tema Sore - Warm & Cozy';
      case AppTimeOfDay.night:
        return 'Tema Malam - Dark & Calm';
    }
  }

  String _getTimeDisplayName(AppTimeOfDay timeOfDay) {
    switch (timeOfDay) {
      case AppTimeOfDay.morning:
        return 'Pagi';
      case AppTimeOfDay.afternoon:
        return 'Siang';
      case AppTimeOfDay.evening:
        return 'Sore';
      case AppTimeOfDay.night:
        return 'Malam';
    }
  }

  List<Color> _getPreviewGradient(AppTimeOfDay timeOfDay) {
    switch (timeOfDay) {
      case AppTimeOfDay.morning:
        return [const Color(0xFF4CAF50), const Color(0xFF81C784)];
      case AppTimeOfDay.afternoon:
        return [const Color(0xFF2196F3), const Color(0xFF64B5F6)];
      case AppTimeOfDay.evening:
        return [const Color(0xFFFF9800), const Color(0xFFFFB74D)];
      case AppTimeOfDay.night:
        return [const Color(0xFF3F51B5), const Color(0xFF533483)];
    }
  }
}