import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart'; // Import logging package
import '../models/metric.dart';

class AnalyticsService {
  static const String baseUrl = 'YOUR_API_BASE_URL';
  static const String metricsKey = 'analytics_metrics';

  // Set up the logger
  final Logger _logger = Logger('AnalyticsService');

  Future<List<Metric>> fetchMetrics({required String period, required String currency}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/metrics'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final metrics = data.map((d) => Metric.fromJson(d)).toList();
        await _saveMetricsLocally(metrics);
        return metrics;
      }
    } catch (e) {
      _logger
          .severe('Error fetching from API: $e'); // Log error instead of print
    }

    return await getLocalMetrics();
  }

  Future<List<Metric>> getLocalMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    final String? metricsJson = prefs.getString(metricsKey);
    if (metricsJson != null) {
      final List<dynamic> data = json.decode(metricsJson);
      return data.map((d) => Metric.fromJson(d)).toList();
    }
    return _getDefaultMetrics();
  }

  Future<void> _saveMetricsLocally(List<Metric> metrics) async {
    final prefs = await SharedPreferences.getInstance();
    final metricsJson = metrics.map((m) => m.toJson()).toList();
    await prefs.setString(metricsKey, json.encode(metricsJson));
  }

  Future<void> updateMetric(int index, Metric updatedMetric) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/metrics/$index'),
        body: json.encode(updatedMetric.toJson()),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update metric on server');
      }
    } catch (e) {
      _logger.severe(
          'Error updating metric on API: $e'); // Log error instead of print
    }

    final metrics = await getLocalMetrics();
    if (index >= 0 && index < metrics.length) {
      metrics[index] = updatedMetric;
      await _saveMetricsLocally(metrics);
    }
  }

  List<Metric> _getDefaultMetrics() {
    return [
      Metric(
        title: 'Revenue',
        value: 250000.0,
        change: '+12.5%',
        color: Colors.blue.value,
        data: [150000.0, 180000.0, 220000.0, 250000.0, 230000.0, 260000.0], lastUpdated: null, trend: null,
      ),
      Metric(
        title: 'Expenses',
        value: 150000.0,
        change: '+8.3%',
        color: Colors.red.value,
        data: [90000.0, 110000.0, 130000.0, 150000.0, 140000.0, 155000.0], lastUpdated: null, trend: null,
      ),
      Metric(
        title: 'Profit',
        value: 100000.0,
        change: '+15.2%',
        color: Colors.green.value,
        data: [60000.0, 70000.0, 90000.0, 100000.0, 90000.0, 105000.0], lastUpdated: null, trend: null,
      ),
      Metric(
        title: 'Active Users',
        value: 1200.0,
        change: '+5.8%',
        color: Colors.orange.value,
        data: [800.0, 900.0, 1000.0, 1200.0, 1150.0, 1250.0], lastUpdated: null, trend: null,
      ),
    ];
  }
}
