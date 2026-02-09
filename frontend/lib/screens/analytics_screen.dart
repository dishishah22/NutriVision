import 'package:flutter/material.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:spectrum_flutter/providers/user_nutrition_provider.dart';
import 'package:spectrum_flutter/models/nutrition_models.dart';
import 'package:spectrum_flutter/services/app_config_server.dart';
import 'package:spectrum_flutter/theme/app_colors.dart';
import 'package:spectrum_flutter/screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _hoveredDay = 6; // Default to "Today" (rightmost bar)
  final _appConfig = AppConfigServer();

  // Dynamic Goal Data
  double _calorieGoal = 2000;
  double _proteinPercent = 30;
  double _carbsPercent = 50;
  double _fatsPercent = 20;
  int _stravaBurned = 0;
  
  // 🧠 AI Insights List
  final List<String> _aiInsights = [
      "Your protein intake is key to muscle recovery—keep it up!",
      "Hydration boosts performance; don’t forget to drink water today.",
      "Consistency is better than perfection. Great job logging your meals!",
      "Adding more fiber to your diet can improve digestion and satiety.",
      "A balanced meal includes protein, healthy fats, and complex carbs.",
      "Small steps every day lead to big changes over time.",
      "Remember to fuel your body before and after your workouts.",
      "Eating a rainbow of vegetables ensures you get essential micronutrients.",
      "Rest days are just as important as training days for progress.",
      "Mindful eating can help you better understand your hunger cues.",
      "Sugar crashes are real—try replacing sweets with fruit for sustained energy.",
      "Healthy fats like avocado and nuts support brain function.",
      "Tracking your meals helps you stay aware of your nutritional habits.",
      "You’re doing great! Every healthy choice counts towards your goal.",
      "Sleep is the foundation of health; aim for 7-9 hours tonight."
  ];

  @override
  void initState() {
    super.initState();
    _appConfig.addListener(_update);
    _loadDynamicData();
  }

  Future<void> _loadDynamicData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch Goals
      final goalsDoc = await FirebaseFirestore.instance.collection('goals').doc(user.uid).get();
      if (goalsDoc.exists) {
        final data = goalsDoc.data()!;
        setState(() {
          _calorieGoal = (data['calorieTarget'] ?? 2000).toDouble();
          _proteinPercent = (data['proteinPercent'] ?? 30).toDouble();
          _carbsPercent = (data['carbsPercent'] ?? 50).toDouble();
          _fatsPercent = (data['fatsPercent'] ?? 20).toDouble();
        });
      }

      // 2. Fetch Strava Stats
      final stravaDoc = await FirebaseFirestore.instance.collection('strava_stats').doc(user.uid).get();
      if (stravaDoc.exists) {
        setState(() {
          _stravaBurned = (stravaDoc.data()?['weeklyCalories'] ?? 0).toInt();
        });
      }
    } catch (e) {
      debugPrint("Error loading stats data: $e");
    }
  }

  @override
  void dispose() {
    _appConfig.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserNutritionProvider>(context);
    final randomInsight = _aiInsights[Random().nextInt(_aiInsights.length)];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<List<NutritionScanModel>>(
          stream: provider.scansStream,
          builder: (context, snapshot) {
            final scans = snapshot.data ?? [];
            
            // Aggregation for "Today"
            final now = DateTime.now();
            final startOfToday = DateTime(now.year, now.month, now.day);
            double tCal = 0, tProt = 0, tCarb = 0, tFat = 0;

            for (var scan in scans) {
              final scanDate = DateTime(scan.createdAt.year, scan.createdAt.month, scan.createdAt.day);
              if (scanDate.year == startOfToday.year && 
                  scanDate.month == startOfToday.month && 
                  scanDate.day == startOfToday.day) {
                tCal += scan.calories;
                tProt += scan.protein;
                tCarb += scan.carbs;
                tFat += scan.fat;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(),
                  const SizedBox(height: 24),
                  Text(_appConfig.translate('stats'), style: GoogleFonts.outfit(color: AppColors.black, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  // Summary Cards
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard('${tCal.toInt()}', _appConfig.translate('consumed'), Icons.local_fire_department_rounded, Colors.orange)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard('$_stravaBurned', _appConfig.translate('burned'), Icons.bolt_rounded, AppColors.accent)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          '${(tCal - _stravaBurned).toInt()}', 
                          _appConfig.translate('balance'), 
                          Icons.track_changes_rounded, 
                          Colors.redAccent, 
                          isPositive: (tCal - _stravaBurned) > 0
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildMacrosCard(tCal, tProt, tCarb, tFat),
                  const SizedBox(height: 24),
                  _buildWeeklyChart(scans),
                  const SizedBox(height: 24),
                  _buildWeeklyInsights(scans, randomInsight),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final bool isDark = _appConfig.isDarkMode;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_appConfig.translate('app_name'), style: GoogleFonts.outfit(color: AppColors.accent, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(_appConfig.translate('ai_powered_analysis'), style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 13)),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1DB98D).withValues(alpha: 0.15),
            child: Icon(Icons.person_outline_rounded, color: isDark ? Colors.white70 : const Color(0xFF1DB98D), size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String value, String label, IconData icon, Color iconColor, {bool isPositive = false}) {
    final bool isDark = _appConfig.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightGrey.withValues(alpha: isDark ? 0.1 : 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(color: isPositive ? Colors.redAccent : (isDark ? Colors.white : AppColors.black), fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMacrosCard(double cals, double protein, double carbs, double fat) {
    final bool isDark = _appConfig.isDarkMode;
    final double gProt = (_calorieGoal * _proteinPercent / 100) / 4;
    final double gCarb = (_calorieGoal * _carbsPercent / 100) / 4;
    final double gFat = (_calorieGoal * _fatsPercent / 100) / 9;
    final double pPerc = gProt > 0 ? (protein / gProt).clamp(0, 1) * 100 : 0;
    
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lightGrey.withValues(alpha: isDark ? 0.1 : 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_appConfig.translate('todays_macros'), style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${pPerc.toInt()}% Protein Goal', style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              SizedBox(
                height: 120, width: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(color: AppColors.protein, value: protein.clamp(0.1, 1000), radius: 20, showTitle: false),
                      PieChartSectionData(color: Colors.orange, value: carbs.clamp(0.1, 1000), radius: 20, showTitle: false),
                      PieChartSectionData(color: Colors.pink, value: fat.clamp(0.1, 1000), radius: 20, showTitle: false),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _buildMacroRow(_appConfig.translate('protein'), '${protein.toInt()}g / ${gProt.toInt()}g', AppColors.protein),
                    const SizedBox(height: 12),
                    _buildMacroRow(_appConfig.translate('carbs'), '${carbs.toInt()}g / ${gCarb.toInt()}g', AppColors.carbs),
                    const SizedBox(height: 12),
                    _buildMacroRow(_appConfig.translate('fats'), '${fat.toInt()}g / ${gFat.toInt()}g', AppColors.fats),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, String value, Color color) {
    final bool isDark = _appConfig.isDarkMode;
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 12), overflow: TextOverflow.ellipsis)),
              Text(value, style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(List<NutritionScanModel> scans) {
    final now = DateTime.now();
    final dateRange = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final labels = dateRange.map((d) => days[d.weekday % 7]).toList();
    final weeklyValues = List.filled(7, 0.0);
    double maxVal = 2000;

    for (var scan in scans) {
      final sDate = DateTime(scan.createdAt.year, scan.createdAt.month, scan.createdAt.day);
      for (int i = 0; i < 7; i++) {
        final targetDate = dateRange[i];
        if (sDate.year == targetDate.year && 
            sDate.month == targetDate.month && 
            sDate.day == targetDate.day) {
          weeklyValues[i] += scan.calories;
          if (weeklyValues[i] > maxVal) maxVal = weeklyValues[i];
          break;
        }
      }
    }
    
    final finalMaxY = (maxVal * 1.25).clamp(2000, 8000).toDouble();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _appConfig.isDarkMode ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lightGrey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_appConfig.translate('weekly_calories'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: finalMaxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                      '${rod.toY.toInt()} kcal',
                      GoogleFonts.outfit(color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, m) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(labels[v.toInt()], style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 10)),
                      ),
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) => BarChartGroupData(
                  x: i,
                  showingTooltipIndicators: weeklyValues[i] > 0 ? [0] : [],
                  barRods: [
                    BarChartRodData(
                      toY: weeklyValues[i],
                      color: AppColors.accent,
                      width: 22,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: finalMaxY,
                        color: AppColors.lightGrey.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyInsights(List<NutritionScanModel> scans, String randomInsight) {
    final now = DateTime.now();
    final dateRange = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
    final daysFull = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final labels = dateRange.map((d) => daysFull[d.weekday % 7]).toList();
    final weeklyValues = List.filled(7, 0.0);
    
    for (var scan in scans) {
      final sDate = DateTime(scan.createdAt.year, scan.createdAt.month, scan.createdAt.day);
      for (int i = 0; i < 7; i++) {
        final targetDate = dateRange[i];
        if (sDate.year == targetDate.year && 
            sDate.month == targetDate.month && 
            sDate.day == targetDate.day) {
          weeklyValues[i] += scan.calories;
          break;
        }
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_appConfig.translate('weekly_insights'), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildInsightCard(
          '${labels[_hoveredDay]} Analysis', 
          'Total of ${weeklyValues[_hoveredDay].toInt()} kcal. Looking good!', 
          AppColors.accent, 
          Icons.calendar_today_rounded
        ),
        _buildInsightCard(
          'AI Nutrition Insight', 
          randomInsight, 
          Colors.orange, 
          Icons.lightbulb_outline_rounded
        ),
      ],
    );
  }

  Widget _buildInsightCard(String title, String sub, Color color, IconData icon) {
    final bool isDark = _appConfig.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(sub, style: GoogleFonts.outfit(color: isDark ? Colors.white70 : AppColors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
