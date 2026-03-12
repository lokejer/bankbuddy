import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config.dart';
import '../config.dart';

// --- Chart scale helper ---
class ChartScale {
  final double min;
  final double max;
  final double range;

  ChartScale(double minVal, double maxVal)
    : min = minVal - (maxVal - minVal) * 0.05,
      max = maxVal + (maxVal - minVal) * 0.05,
      range =
          (maxVal + (maxVal - minVal) * 0.05) -
          (minVal - (maxVal - minVal) * 0.05);

  double toY(double price, double chartHeight) =>
      chartHeight - ((price - min) / range) * chartHeight;
}

class CandlestickScreen extends StatefulWidget {
  final String sessionId;
  final String month;
  const CandlestickScreen({
    super.key,
    required this.sessionId,
    required this.month,
  });

  @override
  State<CandlestickScreen> createState() => _CandlestickScreenState();
}

class _CandlestickScreenState extends State<CandlestickScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  int? _hoveredIndex;
  bool _isInteracting = false;

  // Design tokens
  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF1A1A1A);
  static const _border = Color(0xFF2A2A2A);
  static const _orange = Color(0xFFFF6B00);
  static const _candleUp = Color(0xFF00C076);
  static const _candleDown = Color(0xFFFF3B3B);
  static const _neutral = Color(0xFF3A3A3A);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF888888);
  static const _gridLine = Color(0xFF1F1F1F);

  // --- Helpers ---

  void _endInteraction() {
    setState(() {
      _isInteracting = false;
      _hoveredIndex = null;
    });
  }

  static double numVal(Map<String, dynamic> v, String key) =>
      (v[key] as num).toDouble();

  @override
  void initState() {
    super.initState();
    _fetchCandlestick();
  }

  Future<void> _fetchCandlestick() async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/candlestick?session_id=${widget.sessionId}&months=${widget.month}',
        ),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _data = decoded[widget.month] as Map<String, dynamic>;
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
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Balance Chart',
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
    final entries = _data!.entries.toList();

    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    for (final e in entries) {
      final v = e.value as Map<String, dynamic>;
      if (numVal(v, 'low') < minVal) minVal = numVal(v, 'low');
      if (numVal(v, 'high') > maxVal) maxVal = numVal(v, 'high');
    }

    final latestClose = numVal(
      entries.last.value as Map<String, dynamic>,
      'close',
    );
    final firstOpen = numVal(
      entries.first.value as Map<String, dynamic>,
      'open',
    );
    final monthChange = latestClose - firstOpen;
    final isPositiveMonth = monthChange >= 0;

    final scale = ChartScale(minVal, maxVal);

    return SingleChildScrollView(
      physics: _isInteracting
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(latestClose, monthChange, isPositiveMonth),
          const SizedBox(height: 24),
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
          const SizedBox(height: 12),
          _buildChartWithTooltip(entries, scale),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entries.first.key.substring(5),
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 11,
                  color: _textSecondary,
                ),
              ),
              Text(
                entries.last.key.substring(5),
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 11,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _buildLegend(),
          const SizedBox(height: 32),
          _buildStatsRow(entries, minVal, maxVal),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(double close, double change, bool isPositive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Balance',
            style: TextStyle(
              fontFamily: 'Lato',
              fontSize: 12,
              color: _textSecondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${close.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFF1A3A1A)
                      : const Color(0xFF3A1A1A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isPositive ? Colors.greenAccent : Colors.redAccent,
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '\$${change.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPositive
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Month-to-date change',
            style: TextStyle(
              fontFamily: 'Lato',
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartWithTooltip(
    List<MapEntry<String, dynamic>> entries,
    ChartScale scale,
  ) {
    const chartHeight = 240.0;
    const yAxisWidth = 60.0;
    const containerPadding = 16.0;
    const tooltipWidth = 130.0;
    const tooltipHeight = 112.0;
    const tooltipMarginAboveWick = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final chartAreaWidth = totalWidth - yAxisWidth - (containerPadding * 2);
        final candleWidth = chartAreaWidth / entries.length;

        double tooltipLeft = 0;
        double tooltipTop = 0;
        Color accentColor = _candleUp;
        Map<String, dynamic>? hoveredValues;

        if (_hoveredIndex != null) {
          final v = entries[_hoveredIndex!].value as Map<String, dynamic>;
          final high = numVal(v, 'high');
          final close = numVal(v, 'close');
          final open = numVal(v, 'open');
          accentColor = close >= open ? _candleUp : _candleDown;
          hoveredValues = v;

          final wickTopY = scale.toY(high, chartHeight) + containerPadding;
          tooltipTop = (wickTopY - tooltipHeight - tooltipMarginAboveWick)
              .clamp(-tooltipHeight, double.infinity);

          final candleCenterX =
              yAxisWidth +
              containerPadding +
              _hoveredIndex! * candleWidth +
              candleWidth / 2;

          final flipLeft =
              candleCenterX + tooltipWidth + 8 > totalWidth - containerPadding;
          tooltipLeft = flipLeft
              ? (candleCenterX - tooltipWidth - 8).clamp(0.0, double.infinity)
              : candleCenterX + 8;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildChartInner(entries, scale, chartHeight, yAxisWidth),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              left: tooltipLeft,
              top: tooltipTop,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _hoveredIndex != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: hoveredValues == null
                      ? const SizedBox.shrink()
                      : _buildTooltipBox(
                          entries[_hoveredIndex!].key,
                          hoveredValues,
                          accentColor,
                          tooltipWidth,
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTooltipBox(
    String dateKey,
    Map<String, dynamic> v,
    Color accentColor,
    double tooltipWidth,
  ) {
    return Container(
      width: tooltipWidth,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dateKey.substring(5),
            style: TextStyle(
              fontFamily: 'Lato',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          _tooltipRow('O', numVal(v, 'open')),
          _tooltipRow('C', numVal(v, 'close')),
          _tooltipRow('H', numVal(v, 'high')),
          _tooltipRow('L', numVal(v, 'low')),
        ],
      ),
    );
  }

  Widget _buildChartInner(
    List<MapEntry<String, dynamic>> entries,
    ChartScale scale,
    double chartHeight,
    double yAxisWidth,
  ) {
    final gridLevels = List.generate(
      4,
      (i) => scale.min + (scale.range / 3) * (3 - i),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1),
      ),
      child: SizedBox(
        height: chartHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Y-axis labels
            SizedBox(
              width: yAxisWidth,
              child: Stack(
                children: gridLevels.map((level) {
                  return Positioned(
                    top: scale.toY(level, chartHeight) - 8,
                    child: Text(
                      '\$${(level / 1000).toStringAsFixed(1)}k',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 9,
                        color: _textSecondary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Interactive chart area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final candleWidth = totalWidth / entries.length;

                  int xToIndex(double x) =>
                      (x / candleWidth).floor().clamp(0, entries.length - 1);

                  return GestureDetector(
                    onPanStart: (d) {
                      setState(() {
                        _isInteracting = true;
                        _hoveredIndex = xToIndex(d.localPosition.dx);
                      });
                    },
                    onPanUpdate: (d) {
                      final newIndex = xToIndex(d.localPosition.dx);
                      if (newIndex != _hoveredIndex) {
                        setState(() => _hoveredIndex = newIndex);
                      }
                    },
                    onPanEnd: (_) => _endInteraction(),
                    onPanCancel: _endInteraction,
                    onTapDown: (d) {
                      setState(() {
                        _isInteracting = true;
                        _hoveredIndex = xToIndex(d.localPosition.dx);
                      });
                    },
                    onTapUp: (_) => _endInteraction(),
                    child: RepaintBoundary(
                      child: Stack(
                        children: [
                          // Grid lines
                          ...gridLevels.map(
                            (level) => Positioned(
                              top: scale.toY(level, chartHeight),
                              left: 0,
                              right: 0,
                              child: Container(height: 1, color: _gridLine),
                            ),
                          ),

                          // Candles
                          ...entries.asMap().entries.map((indexedEntry) {
                            final idx = indexedEntry.key;
                            final v =
                                indexedEntry.value.value
                                    as Map<String, dynamic>;
                            final open = numVal(v, 'open');
                            final close = numVal(v, 'close');
                            final high = numVal(v, 'high');
                            final low = numVal(v, 'low');
                            final hasTransactions =
                                v['has_transactions'] as bool;

                            final isUp = close >= open;
                            final bodyColor = !hasTransactions
                                ? _neutral
                                : (isUp ? _candleUp : _candleDown);

                            final isHovered = _hoveredIndex == idx;
                            final dimmed = _hoveredIndex != null && !isHovered;

                            final bodyTop = scale.toY(
                              isUp ? close : open,
                              chartHeight,
                            );
                            final bodyBottom = scale.toY(
                              isUp ? open : close,
                              chartHeight,
                            );
                            final wickTop = scale.toY(high, chartHeight);
                            final wickBottom = scale.toY(low, chartHeight);
                            final bodyHeight = (bodyBottom - bodyTop).clamp(
                              1.5,
                              chartHeight,
                            );

                            return Positioned(
                              left: idx * candleWidth,
                              width: candleWidth,
                              top: 0,
                              bottom: 0,
                              child: AnimatedOpacity(
                                opacity: dimmed ? 0.3 : 1.0,
                                duration: const Duration(milliseconds: 150),
                                child: Stack(
                                  children: [
                                    // Wick
                                    Positioned(
                                      left: candleWidth / 2 - 0.5,
                                      top: wickTop,
                                      child: Container(
                                        width: 1,
                                        height: (wickBottom - wickTop).clamp(
                                          0,
                                          chartHeight,
                                        ),
                                        color: bodyColor.withOpacity(
                                          !hasTransactions ? 0.4 : 0.8,
                                        ),
                                      ),
                                    ),
                                    // Body
                                    Positioned(
                                      left: candleWidth * 0.2,
                                      top: bodyTop,
                                      child: Container(
                                        width: candleWidth * 0.6,
                                        height: bodyHeight,
                                        decoration: BoxDecoration(
                                          color: bodyColor,
                                          borderRadius: BorderRadius.circular(
                                            1.5,
                                          ),
                                          boxShadow: isHovered
                                              ? [
                                                  BoxShadow(
                                                    color: bodyColor
                                                        .withOpacity(0.5),
                                                    blurRadius: 6,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          // Vertical crosshair
                          if (_hoveredIndex != null)
                            Positioned(
                              left:
                                  _hoveredIndex! * candleWidth +
                                  candleWidth / 2 -
                                  0.5,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 1,
                                color: _orange.withOpacity(0.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tooltipRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 10,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(0)}',
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 10,
              color: _textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendPill(_candleUp, 'Balance Up'),
        const SizedBox(width: 10),
        _legendPill(_candleDown, 'Balance Down'),
        const SizedBox(width: 10),
        _legendPill(_neutral, 'No Activity'),
      ],
    );
  }

  Widget _legendPill(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
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
              fontSize: 11,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    List<MapEntry<String, dynamic>> entries,
    double minVal,
    double maxVal,
  ) {
    final txnDays = entries
        .where((e) => e.value['has_transactions'] == true)
        .length;

    return Row(
      children: [
        _statCard('HIGH', '\$${maxVal.toStringAsFixed(0)}', Colors.greenAccent),
        const SizedBox(width: 12),
        _statCard('LOW', '\$${minVal.toStringAsFixed(0)}', Colors.redAccent),
        const SizedBox(width: 12),
        _statCard('ACTIVE DAYS', '$txnDays', _orange),
      ],
    );
  }

  Widget _statCard(String label, String value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Lato',
                fontSize: 9,
                color: _textSecondary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
