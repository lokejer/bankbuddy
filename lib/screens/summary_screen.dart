import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config.dart';

class SummaryScreen extends StatefulWidget {
  final String sessionId;
  final String month;
  const SummaryScreen({
    super.key,
    required this.sessionId,
    required this.month,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF1A1A1A);
  static const _orange = Color(0xFFFF6B00);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF888888);

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/summary?session_id=${widget.sessionId}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
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
    final entries = _data!.entries.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, Jerome 👋',
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Here\'s your financial summary',
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 13,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: _textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Month cards
          ...entries.map((entry) => _buildMonthCard(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildMonthCard(String month, dynamic rawValues) {
    final values = rawValues as Map<String, dynamic>;
    final nett = (values['nett_cashflow'] as num).toDouble();
    final allowance = (values['allowance'] as num).toDouble();
    final reimbursements = (values['reimbursements'] as num).toDouble();
    final outgoing = (values['outgoing'] as num).toDouble();
    final isPositive = nett >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
      ),
      child: Column(
        children: [
          // Hero nett cashflow section
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      month,
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _textSecondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? const Color(0xFF1A3A1A)
                            : const Color(0xFF2A1500),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPositive
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: isPositive ? Colors.greenAccent : _orange,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPositive ? 'Saved' : 'Overspent',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isPositive ? Colors.greenAccent : _orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'NETT CASHFLOW',
                  style: const TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 9,
                    color: _textSecondary,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${nett.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: isPositive ? Colors.greenAccent : _orange,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: const Color(0xFF242424)),

          // Three metrics row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Row(
              children: [
                _metricCell('ALLOWANCE', allowance, Colors.blue.shade300),
                _verticalDivider(),
                _metricCell('REIMBURSE', reimbursements, Colors.greenAccent),
                _verticalDivider(),
                _metricCell('OUTGOING', outgoing.abs(), Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCell(String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 8,
              color: _textSecondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '\$${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontFamily: 'Lato',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF2A2A2A),
    );
  }
}
