import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/analytics_service.dart';
import '../../../models/metric.dart';
import '../../../widgets/overview_card.dart';
import '../../../widgets/metric_card.dart';

class AnalyticsReportingScreen extends StatefulWidget {
  const AnalyticsReportingScreen({super.key});

  @override
  State<AnalyticsReportingScreen> createState() => _AnalyticsReportingScreenState();
}

class _AnalyticsReportingScreenState extends State<AnalyticsReportingScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final TextEditingController _dataController = TextEditingController();
  String _selectedPeriod = 'Monthly';
  String _selectedCurrency = 'KES';
  int _selectedMetricIndex = 0;
  bool _isLoading = true;
  bool _isUpdating = false;
  List<Metric> _metrics = [];
  DateTime _lastUpdate = DateTime.now();

  final List<String> _periods = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  final List<String> _currencies = ['KES', 'USD', 'EUR', 'GBP'];

  static const Duration _refreshInterval = Duration(minutes: 5);

  // Add default metrics for initial state
  final List<Metric> _defaultMetrics = [
    Metric(
      title: 'Revenue',
      value: 0,
      change: '0%',
      data: [0, 0, 0, 0, 0],
      color: Colors.blue.value,
      lastUpdated: DateTime.now(),
      trend: 'stable',
    ),
    Metric(
      title: 'Expenses',
      value: 0,
      change: '0%',
      data: [0, 0, 0, 0, 0],
      color: Colors.red.value,
      lastUpdated: DateTime.now(),
      trend: 'stable',
    ),
    Metric(
      title: 'Profit',
      value: 0,
      change: '0%',
      data: [0, 0, 0, 0, 0],
      color: Colors.green.value,
      lastUpdated: DateTime.now(),
      trend: 'stable',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() {
        _metrics = _defaultMetrics;  // Set default metrics immediately
      });
      await Future.wait([
        _loadPreferences(),
        _loadMetrics(),
      ]);
      _setupAutoRefresh();
    } catch (e) {
      _showError('Failed to initialize: ${e.toString()}');
    }
  }

  void _setupAutoRefresh() {
    Future.delayed(_refreshInterval, () {
      if (mounted) {
        _loadMetrics();
        _setupAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    _dataController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _selectedPeriod = prefs.getString('selected_period') ?? 'Monthly';
          _selectedCurrency = prefs.getString('selected_currency') ?? 'KES';
          final lastUpdateMillis = prefs.getInt('last_update');
          if (lastUpdateMillis != null) {
            _lastUpdate = DateTime.fromMillisecondsSinceEpoch(lastUpdateMillis);
          }
        });
      }
    } catch (e) {
      _showError('Failed to load preferences: ${e.toString()}');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString('selected_period', _selectedPeriod),
        prefs.setString('selected_currency', _selectedCurrency),
        prefs.setInt('last_update', DateTime.now().millisecondsSinceEpoch),
      ]);
    } catch (e) {
      _showError('Failed to save preferences: ${e.toString()}');
    }
  }

  Future<void> _loadMetrics() async {
    if (_isUpdating) return;

    setState(() => _isLoading = true);
    try {
      final metrics = await _analyticsService.fetchMetrics(
        period: _selectedPeriod.toLowerCase(),
        currency: _selectedCurrency,
      );
      
      if (mounted) {
        setState(() {
          _metrics = metrics.isEmpty ? _defaultMetrics : metrics;  // Use defaults if no data
          _isLoading = false;
          _lastUpdate = DateTime.now();
        });
        await _savePreferences();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Keep existing metrics on error
          if (_metrics.isEmpty) {
            _metrics = _defaultMetrics;
          }
        });
        _showError('Failed to load metrics: ${e.toString()}');
      }
    }
  }

  Future<void> _updateMetricValue(double newValue) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);
    try {
      if (_selectedMetricIndex >= 0 && _selectedMetricIndex < _metrics.length) {
        final updatedMetric = _metrics[_selectedMetricIndex].copyWith(
          value: newValue,
          lastUpdated: DateTime.now(),
        );

        await _analyticsService.updateMetric(
          _selectedMetricIndex,
          updatedMetric,
        );

        if (mounted) {
          setState(() {
            _metrics[_selectedMetricIndex] = updatedMetric;
            _isUpdating = false;
          });
          _dataController.clear();
          _showSuccess('Metric updated successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        _showError('Failed to update metric: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(
      symbol: _getCurrencySymbol(_selectedCurrency),
      decimalDigits: 0,
    );
    return format.format(amount);
  }

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return 'Ksh';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Analytics & Reporting'),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _isLoading ? null : () => _loadMetrics(),
          tooltip: 'Refresh Data',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading && _metrics.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading analytics data...'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMetrics,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLastUpdateText(),
                  const SizedBox(height: 16),
                  _buildFilters(),
                  const SizedBox(height: 20),
                  _buildOverviewSection(),
                  const SizedBox(height: 20),
                  _buildMetricsSection(),
                  const SizedBox(height: 20),
                  _buildDataEntrySection(),
                  const SizedBox(height: 20),
                  _buildTrendSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdateText() {
    return Text(
      'Last updated: ${DateFormat.yMd().add_jm().format(_lastUpdate)}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCurrencySelector(),
        const SizedBox(height: 16),
        _buildPeriodSelector(),
      ],
    );
  }

  Widget _buildCurrencySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Currency:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        DropdownButton<String>(
          value: _selectedCurrency,
          onChanged: _isLoading
              ? null
              : (String? newValue) {
                  if (newValue != null && newValue != _selectedCurrency) {
                    setState(() => _selectedCurrency = newValue);
                    _savePreferences();
                    _loadMetrics();
                  }
                },
          items: _currencies.map((String currency) {
            return DropdownMenuItem<String>(
              value: currency,
              child: Text(currency),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Wrap(
      spacing: 8.0,
      children: _periods.map((period) {
        return ChoiceChip(
          label: Text(period),
          selected: _selectedPeriod == period,
          onSelected: _isLoading
              ? null
              : (selected) {
                  if (selected && _selectedPeriod != period) {
                    setState(() => _selectedPeriod = period);
                    _savePreferences();
                    _loadMetrics();
                  }
                },
        );
      }).toList(),
    );
  }

  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Overview'),
        const SizedBox(height: 16),
        _buildOverviewCard(),
      ],
    );
  }

  Widget _buildMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Performance Metrics'),
        const SizedBox(height: 16),
        _buildMetricsGrid(),
      ],
    );
  }

  Widget _buildDataEntrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Update Data'),
        const SizedBox(height: 16),
        _buildDataEntryForm(),
      ],
    );
  }

  Widget _buildTrendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Trend Analysis'),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: _buildTrendChart(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildOverviewCard() {
    if (_metrics.isEmpty) return const SizedBox.shrink();

    final totalRevenue = _metrics.firstWhere((m) => m.title == 'Revenue').value;
    final totalExpenses = _metrics.firstWhere((m) => m.title == 'Expenses').value;
    final totalProfit = _metrics.firstWhere((m) => m.title == 'Profit').value;

    return OverviewCard(
      items: [
        OverviewItem(
          title: 'Total Revenue',
          value: _formatCurrency(totalRevenue),
          change: _metrics.firstWhere((m) => m.title == 'Revenue').change,
          trend: _metrics.firstWhere((m) => m.title == 'Revenue').trend,
        ),
        OverviewItem(
          title: 'Total Expenses',
          value: _formatCurrency(totalExpenses),
          change: _metrics.firstWhere((m) => m.title == 'Expenses').change,
          trend: _metrics.firstWhere((m) => m.title == 'Expenses').trend,
        ),
        OverviewItem(
          title: 'Total Profit',
          value: _formatCurrency(totalProfit),
          change: _metrics.firstWhere((m) => m.title == 'Profit').change,
          trend: _metrics.firstWhere((m) => m.title == 'Profit').trend,
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _metrics.length,
          itemBuilder: (context, index) {
            final metric = _metrics[index];
            return MetricCard(
              title: metric.title,
              value: _formatCurrency(metric.value),
              change: metric.change,
              trend: metric.trend,
              color: Color(metric.color),
              isSelected: _selectedMetricIndex == index,
              onTap: () => setState(() => _selectedMetricIndex = index),
            );
          },
        );
      },
    );
  }

  Widget _buildDataEntryForm() {
    if (_metrics.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Metric: ${_metrics[_selectedMetricIndex].title}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _dataController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Enter new value',
            border: const OutlineInputBorder(),
            suffixText: _selectedCurrency,
            enabled: !_isUpdating,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUpdating
                ? null
                : () {
                    final value = double.tryParse(_dataController.text);
                    if (value != null) {
                      _updateMetricValue(value);
                    } else {
                      _showError('Please enter a valid number');
                    }
                  },
            child: _isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Update Metric'),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart() {
  if (_metrics.isEmpty) return const SizedBox.shrink();

  final metric = _metrics[_selectedMetricIndex];
  final List<double> data = List<double>.from(metric.data);

  if (data.isEmpty) {
    return const Center(
      child: Text('No trend data available'),
    );
  }

  return LineChart(
    LineChartData(
      gridData: const FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < data.length) {
                return Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              return Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  _formatCurrency(value),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            },
            reservedSize: 50,
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.shade300),
      ),
      minX: 0,
      maxX: (data.length - 1).toDouble(),
      minY: data.isEmpty ? 0 : data.reduce((a, b) => min(a, b)) * 0.9,
      maxY: data.isEmpty ? 100 : data.reduce((a, b) => max(a, b)) * 1.1,
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(
            data.length,
            (i) => FlSpot(i.toDouble(), data[i]),
          ),
          isCurved: true,
          barWidth: 3,
          color: Color(metric.color),
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: Color(metric.color).withOpacity(0.2),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                '$_selectedPeriod ${spot.x.toInt() + 1}\n${_formatCurrency(spot.y)}',
                const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              );
            }).toList();
          },
        ),
      ),
    ),
  );
}
}

class MetricTrend {
  final List<double> data;
  final String direction; // 'up', 'down', or 'stable'
  final double percentage;

  const MetricTrend({
    required this.data,
    required this.direction,
    required this.percentage,
  });
}

extension MetricExtension on Metric {
  Metric copyWith({
    String? title,
    double? value,
    String? change,
    List<double>? data,
    int? color,
    DateTime? lastUpdated,
    MetricTrend? trend,
  }) {
    return Metric(
      title: title ?? this.title,
      value: value ?? this.value,
      change: change ?? this.change,
      data: data ?? this.data,
      color: color ?? this.color,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      trend: trend?.toString() ?? this.trend,
    );
  }
}
