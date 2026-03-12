import 'package:flutter/material.dart';
import 'summary_screen.dart';
import 'candlestick_screen.dart';
import 'heatmap_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String sessionId;
  final String month;
  const DashboardScreen({
    super.key,
    required this.sessionId,
    required this.month,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF1A1A1A);
  static const _orange = Color(0xFFFF6B00);
  static const _textSecondary = Color(0xFF888888);
  static const _textPrimary = Color(0xFFFFFFFF);

  // Nav bar geometry — keep in sync with the Container height/padding
  static const _navBarHeight = 64.0;
  static const _pillWidth = 90.0;
  static const _pillHeight = 46.0;

  static const _tabs = [
    (icon: Icons.grid_view_rounded, label: 'Summary'),
    (icon: Icons.candlestick_chart_rounded, label: 'Balance'),
    (icon: Icons.grid_on_rounded, label: 'Heatmap'),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      SummaryScreen(sessionId: widget.sessionId, month: widget.month),
      CandlestickScreen(sessionId: widget.sessionId, month: widget.month),
      HeatmapScreen(sessionId: widget.sessionId, month: widget.month),
    ];

    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Container(
          height: _navBarHeight,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / _tabs.length;

              // Pill left offset: centre the pill within the current tab slot
              final pillLeft =
                  _selectedIndex * tabWidth + (tabWidth - _pillWidth) / 2;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Sliding orange background pill
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    left: pillLeft,
                    top: (_navBarHeight - _pillHeight) / 2,
                    child: Container(
                      width: _pillWidth,
                      height: _pillHeight,
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),

                  // Tab items sit on top of the pill
                  Row(
                    children: List.generate(_tabs.length, (i) {
                      final isSelected = _selectedIndex == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedIndex = i),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            height: _navBarHeight,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    _tabs[i].icon,
                                    key: ValueKey(isSelected),
                                    color: isSelected
                                        ? _orange
                                        : _textSecondary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontFamily: 'Lato',
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? _orange
                                        : _textSecondary,
                                    letterSpacing: 0.3,
                                  ),
                                  child: Text(_tabs[i].label),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
