import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config.dart';

class HeatmapScreen extends StatefulWidget {
  final String sessionId;
  final String month;
  const HeatmapScreen({
    super.key,
    required this.sessionId,
    required this.month,
  });

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  static const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const weekdaysFull = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // Design tokens
  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF1A1A1A);
  static const _orange = Color(0xFFFF6B00);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF888888);

  @override
  void initState() {
    super.initState();
    _fetchHeatmap();
  }

  Future<void> _fetchHeatmap() async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/heatmap?session_id=${widget.sessionId}&month=${widget.month}',
        ),
      );
      if (response.statusCode == 200) {
        setState(() {
          _data = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error: ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed: $e';
        _isLoading = false;
      });
    }
  }

  Color _cellColor(double value) {
    if (value == 0) return const Color(0xFF2A2A2A);
    if (value > 0) return const Color(0xFF1A3A1A);
    // Orange intensity for spending
    final intensity = (value.abs() / 150).clamp(0.08, 1.0);
    return Color.lerp(const Color(0xFF2A1500), _orange, intensity)!;
  }

  Color _cellTextColor(double value, Color bg) {
    if (value == 0) return Colors.transparent;
    if (value > 0) return Colors.greenAccent;
    final intensity = (value.abs() / 150).clamp(0.08, 1.0);
    return intensity > 0.5 ? Colors.white : const Color(0xFFFF6B00);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Spending Heatmap',
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontFamily: 'Lato',
                ),
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final weeks = _data!.entries.toList();

    // Compute total spend for summary card
    double totalSpend = 0;
    double totalIncome = 0;
    double peakDay = 0;
    for (final week in weeks) {
      final dayValues = week.value as Map<String, dynamic>;
      for (final day in weekdaysFull) {
        final v = (dayValues[day] as num).toDouble();
        if (v < 0) totalSpend += v.abs();
        if (v > 0) totalIncome += v;
        if (v.abs() > peakDay) peakDay = v.abs();
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          _buildSummaryCard(totalSpend, totalIncome, peakDay),
          const SizedBox(height: 24),

          // Month label
          Text(
            widget.month,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // Heatmap grid
          _buildGrid(weeks),
          const SizedBox(height: 24),

          // Legend
          _buildLegend(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    double totalSpend,
    double totalIncome,
    double peakDay,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _buildSummaryMetric(
              label: 'TOTAL SPENT',
              value: '\$${totalSpend.toStringAsFixed(2)}',
              color: _orange,
            ),
          ),
          Container(width: 1, height: 48, color: const Color(0xFF2A2A2A)),
          Expanded(
            child: _buildSummaryMetric(
              label: 'INCOME',
              value: '\$${totalIncome.toStringAsFixed(2)}',
              color: Colors.greenAccent,
            ),
          ),
          Container(width: 1, height: 48, color: const Color(0xFF2A2A2A)),
          Expanded(
            child: _buildSummaryMetric(
              label: 'PEAK DAY',
              value: '\$${peakDay.toStringAsFixed(0)}',
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 9,
              color: _textSecondary,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          // FittedBox scales the value down if the column is too narrow,
          // preventing wrapping while keeping the text as large as possible
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<MapEntry<String, dynamic>> weeks) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
      ),
      child: Column(
        children: [
          // Weekday header
          Row(
            children: [
              const SizedBox(width: 48),
              ...weekdays.map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Week rows
          ...weeks.map((weekEntry) {
            final weekLabel = weekEntry.key.substring(5, 10);
            final dayValues = weekEntry.value as Map<String, dynamic>;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      weekLabel,
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 9,
                        color: _textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  ...weekdaysFull.map((day) {
                    final value = (dayValues[day] as num).toDouble();
                    final bg = _cellColor(value);
                    final textColor = _cellTextColor(value, bg);

                    return Expanded(
                      child: Container(
                        height: 42,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: value != 0
                              ? Text(
                                  value.abs() >= 10
                                      ? value.toStringAsFixed(0)
                                      : value.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontFamily: 'Lato',
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                )
                              : const SizedBox(),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _legendPill(_orange, 'High Spend'),
        _legendPill(const Color(0xFF2A1500), 'Low Spend'),
        _legendPill(const Color(0xFF1A3A1A), 'Income'),
        _legendPill(const Color(0xFF2A2A2A), 'No Activity'),
      ],
    );
  }

  Widget _legendPill(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 10,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
