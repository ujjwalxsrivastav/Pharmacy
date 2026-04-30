import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SalesChart extends StatelessWidget {
  final List<double> weeklyData;

  const SalesChart({super.key, required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final calculatedMax = weeklyData.isEmpty ? 100.0 : (weeklyData.reduce((a, b) => a > b ? a : b) * 1.3);
    final maxY = calculatedMax > 0 ? calculatedMax : 100.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 18, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: AppColors.primaryGradient))),
              const SizedBox(width: 10),
              Text('Weekly Sales', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text('This Week', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barGroups: _buildBarGroups(),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(color: colors.surfaceLight, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(days[value.toInt()], style: GoogleFonts.inter(fontSize: 10, color: colors.textHint, fontWeight: FontWeight.w500)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem('₹${rod.toY.toStringAsFixed(0)}', GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white));
                    },
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(weeklyData.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: weeklyData[index],
            width: 20,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
            gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: AppColors.primaryGradient),
          ),
        ],
      );
    });
  }
}
