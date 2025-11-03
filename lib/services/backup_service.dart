// File: lib/services/backup_service.dart
// Service untuk backup dan restore data aplikasi menggunakan Hive

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class BackupService {
  // List semua box yang perlu di-backup
  static const List<String> _boxNames = [
    'dailyTasks',
    'taskBox',
    'goal_tasks',
    'notes',
    'transactions',
    'budgets',
    'financial_summary',
    'profile',
    'settings',
    'motivational_quotes',
  ];

  // ============================================================================
  // BACKUP FUNCTIONS
  // ============================================================================

  /// Create backup dari semua data
  static Future<Map<String, dynamic>> createBackup() async {
    debugPrint('📦 Starting backup process...');

    final backup = <String, dynamic>{
      'version': '1.0.0',
      'timestamp': DateTime.now().toIso8601String(),
      'boxes': <String, dynamic>{},
    };

    for (final boxName in _boxNames) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          backup['boxes'][boxName] = _boxToMap(box);
          debugPrint('✅ Backed up box: $boxName (${box.length} items)');
        } else {
          // Try to open box if not open
          try {
            final box = await Hive.openBox(boxName);
            backup['boxes'][boxName] = _boxToMap(box);
            debugPrint('✅ Backed up box: $boxName (${box.length} items)');
          } catch (e) {
            debugPrint('⚠️ Box $boxName not found, skipping...');
          }
        }
      } catch (e) {
        debugPrint('❌ Error backing up box $boxName: $e');
      }
    }

    debugPrint('📦 Backup completed with ${backup['boxes'].length} boxes');
    return backup;
  }

  /// Convert Hive box ke Map
  static Map<String, dynamic> _boxToMap(Box box) {
    final map = <String, dynamic>{};
    for (var key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        // Convert HiveObject to JSON-serializable format
        if (value is HiveObject) {
          map[key.toString()] = _hiveObjectToMap(value);
        } else if (value is List) {
          map[key.toString()] = value.map((item) {
            if (item is HiveObject) {
              return _hiveObjectToMap(item);
            }
            return item;
          }).toList();
        } else if (value is Map) {
          map[key.toString()] = Map.from(value);
        } else {
          map[key.toString()] = value;
        }
      }
    }
    return map;
  }

  /// Convert HiveObject to Map (simplified)
  static Map<String, dynamic> _hiveObjectToMap(dynamic object) {
    // This is a simplified version
    // For production, you might want to use more sophisticated serialization
    try {
      return {
        'type': object.runtimeType.toString(),
        'data': object.toString(),
      };
    } catch (e) {
      return {'error': 'Cannot serialize object'};
    }
  }

  // ============================================================================
  // SAVE BACKUP TO FILE
  // ============================================================================

  /// Save backup ke file JSON
  static Future<String?> saveBackupToFile() async {
    try {
      debugPrint('💾 Creating backup file...');

      // Create backup data
      final backupData = await createBackup();

      // Convert to JSON
      final jsonString = jsonEncode(backupData);

      // Get directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'lisku_backup_$timestamp.json';
      final filePath = '${directory.path}/$fileName';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(jsonString);

      debugPrint('✅ Backup saved to: $filePath');
      debugPrint('📊 Backup size: ${(jsonString.length / 1024).toStringAsFixed(2)} KB');

      return filePath;
    } catch (e) {
      debugPrint('❌ Error saving backup: $e');
      return null;
    }
  }

  /// Share backup file
  static Future<bool> shareBackup() async {
    try {
      final filePath = await saveBackupToFile();
      if (filePath == null) return false;

      final file = XFile(filePath);
      await Share.shareXFiles(
        [file],
        subject: 'Lisku Backup',
        text: 'Backup data aplikasi Lisku - ${DateTime.now()}',
      );

      debugPrint('✅ Backup shared successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sharing backup: $e');
      return false;
    }
  }

  // ============================================================================
  // RESTORE FUNCTIONS
  // ============================================================================

  /// Pick backup file dari device
  static Future<String?> pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return result.files.single.path;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error picking file: $e');
      return null;
    }
  }

  /// Restore backup dari file
  static Future<bool> restoreFromFile(String filePath) async {
    try {
      debugPrint('📥 Starting restore from: $filePath');

      // Read file
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ Backup file not found');
        return false;
      }

      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate backup
      if (!_validateBackup(backupData)) {
        debugPrint('❌ Invalid backup file format');
        return false;
      }

      // Restore boxes
      final boxes = backupData['boxes'] as Map<String, dynamic>;
      int restoredCount = 0;

      for (final boxName in boxes.keys) {
        try {
          await _restoreBox(boxName, boxes[boxName]);
          restoredCount++;
          debugPrint('✅ Restored box: $boxName');
        } catch (e) {
          debugPrint('❌ Error restoring box $boxName: $e');
        }
      }

      debugPrint('✅ Restore completed: $restoredCount/${ boxes.length} boxes restored');
      return restoredCount > 0;
    } catch (e) {
      debugPrint('❌ Error restoring backup: $e');
      return false;
    }
  }

  /// Validate backup format
  static bool _validateBackup(Map<String, dynamic> backup) {
    if (!backup.containsKey('version')) return false;
    if (!backup.containsKey('timestamp')) return false;
    if (!backup.containsKey('boxes')) return false;
    return true;
  }

  /// Restore single box
  static Future<void> _restoreBox(String boxName, dynamic boxData) async {
    Box box;

    // Open or get box
    if (Hive.isBoxOpen(boxName)) {
      box = Hive.box(boxName);
    } else {
      box = await Hive.openBox(boxName);
    }

    // Clear existing data
    await box.clear();

    // Restore data
    if (boxData is Map<String, dynamic>) {
      for (final entry in boxData.entries) {
        try {
          await box.put(entry.key, entry.value);
        } catch (e) {
          debugPrint('⚠️ Error restoring entry ${entry.key}: $e');
        }
      }
    }
  }

  // ============================================================================
  // UTILITY FUNCTIONS
  // ============================================================================

  /// Get backup info without loading full backup
  static Future<Map<String, dynamic>?> getBackupInfo(String filePath) async {
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      return {
        'version': backupData['version'],
        'timestamp': backupData['timestamp'],
        'boxCount': (backupData['boxes'] as Map).length,
        'fileSize': await file.length(),
      };
    } catch (e) {
      debugPrint('❌ Error getting backup info: $e');
      return null;
    }
  }

  /// Calculate total items in all boxes
  static Future<int> getTotalItems() async {
    int total = 0;
    for (final boxName in _boxNames) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          total += Hive.box(boxName).length;
        }
      } catch (e) {
        debugPrint('⚠️ Error counting box $boxName: $e');
      }
    }
    return total;
  }

  /// Get backup statistics
  static Future<Map<String, int>> getBackupStatistics() async {
    final stats = <String, int>{};

    for (final boxName in _boxNames) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          stats[boxName] = Hive.box(boxName).length;
        } else {
          stats[boxName] = 0;
        }
      } catch (e) {
        stats[boxName] = 0;
      }
    }

    return stats;
  }

  /// Delete old backup files (keep last N backups)
  static Future<void> deleteOldBackups({int keepCount = 5}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync()
          .where((file) => file.path.contains('lisku_backup_'))
          .map((file) => File(file.path))
          .toList();

      // Sort by modification time (newest first)
      files.sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync())
      );

      // Delete old files
      if (files.length > keepCount) {
        for (var i = keepCount; i < files.length; i++) {
          await files[i].delete();
          debugPrint('🗑️ Deleted old backup: ${files[i].path}');
        }
      }

      debugPrint('✅ Cleanup completed: ${files.length - keepCount} old backups deleted');
    } catch (e) {
      debugPrint('❌ Error deleting old backups: $e');
    }
  }

  /// Create auto backup (daily)
  static Future<bool> createAutoBackup() async {
    try {
      debugPrint('⏰ Creating auto backup...');

      final filePath = await saveBackupToFile();
      if (filePath == null) return false;

      // Clean old backups
      await deleteOldBackups(keepCount: 7); // Keep last 7 days

      debugPrint('✅ Auto backup completed');
      return true;
    } catch (e) {
      debugPrint('❌ Error creating auto backup: $e');
      return false;
    }
  }

  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Format date from timestamp
  static String formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}