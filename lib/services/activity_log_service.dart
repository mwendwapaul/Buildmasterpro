import 'dart:convert';

import 'package:build_masterpro/models/activity_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityLogService {
  static const String _logsKey = 'activity_logs';

  Future<void> logActivity({
    required String userId,
    required String userName,
    required String action,
    required String description,
    String? targetId,
    String? targetType,
  }) async {
    final log = ActivityLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      userName: userName,
      action: action,
      description: description,
      timestamp: DateTime.now(),
      targetId: targetId,
      targetType: targetType,
    );

    final logs = await getLogs();
    logs.insert(0, log);

    // Keep only the last 1000 logs
    if (logs.length > 1000) {
      logs.removeRange(1000, logs.length);
    }

    final prefs = await SharedPreferences.getInstance();
    final logsJson = logs.map((log) => jsonEncode(log.toJson())).toList();
    await prefs.setStringList(_logsKey, logsJson);
  }

  Future<List<ActivityLog>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getStringList(_logsKey);
    if (logsJson == null) return [];

    return logsJson
        .map((logStr) => ActivityLog.fromJson(jsonDecode(logStr)))
        .toList();
  }
}
