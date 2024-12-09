import 'package:flutter/foundation.dart';

class Metric {
  final String title;
  double value;
  String change;
  final int color;
  List<dynamic> data; // Explicitly marking as dynamic
  final DateTime? lastUpdated;
  final String? trend;

  Metric({
    required this.title,
    required this.value,
    required this.change,
    required this.color,
    required this.data,
    this.lastUpdated,
    this.trend,
  });

  Map<String, dynamic> toJson() {
    // Explicitly typed Map
    return {
      'title': title,
      'value': value,
      'change': change,
      'color': color,
      'data': data,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'trend': trend,
    };
  }

  factory Metric.fromJson(Map<String, dynamic> json) {
    try {
      // Validate required fields exist
      if (!json.containsKey('title') ||
          !json.containsKey('value') ||
          !json.containsKey('change') ||
          !json.containsKey('color') ||
          !json.containsKey('data')) {
        throw const FormatException('Missing required fields in JSON');
      }

      // Type checking and conversion with error handling
      return Metric(
        title: json['title'] as String? ?? '',
        value: (json['value'] != null)
            ? (json['value'] is int)
                ? (json['value'] as int).toDouble()
                : (json['value'] as num).toDouble()
            : 0.0,
        change: json['change'] as String? ?? '0%',
        color: json['color'] as int? ?? 0,
        data: (json['data'] != null) ? List.from(json['data']) : [],
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.tryParse(json['lastUpdated'] as String)
            : null,
        trend: json['trend'] as String?,
      );
    } catch (e) {
      // You can customize error handling here
      if (kDebugMode) {
        print('Error parsing Metric from JSON: $e');
      }
      // Return a default Metric object instead of throwing
      return Metric(
        title: '',
        value: 0.0,
        change: '0%',
        color: 0,
        data: [],
      );
    }
  }

  @override
  String toString() {
    return 'Metric{title: $title, value: $value, change: $change, color: $color, data: $data, lastUpdated: $lastUpdated, trend: $trend}';
  }
}