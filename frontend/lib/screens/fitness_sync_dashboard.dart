import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spectrum_flutter/screens/meal_scan_screen.dart';
import 'package:spectrum_flutter/theme/app_colors.dart';
import 'package:spectrum_flutter/screens/analytics_screen.dart';
import 'package:spectrum_flutter/screens/profile_screen.dart';
import 'package:spectrum_flutter/screens/settings_screen.dart';
import 'package:spectrum_flutter/services/app_config_server.dart';
import 'package:spectrum_flutter/screens/barcode_scan_screen.dart';
import 'package:spectrum_flutter/screens/nutrition_history_screen.dart';
import 'package:provider/provider.dart';
import 'package:spectrum_flutter/providers/user_nutrition_provider.dart';
import 'package:spectrum_flutter/models/nutrition_models.dart';
import 'package:spectrum_flutter/screens/home_screen.dart';

class FitnessSyncDashboard extends StatefulWidget {
  const FitnessSyncDashboard({super.key});

  @override
  State<FitnessSyncDashboard> createState() => _FitnessSyncDashboardState();
}

class _FitnessSyncDashboardState extends State<FitnessSyncDashboard> {
  int _selectedIndex = 0;
  final _appConfig = AppConfigServer();
  int _homeScreenRebuildKey = 0; // Changes to force HomeScreen rebuild

  @override
  void initState() {
    super.initState();
    _appConfig.addListener(_update);
  }

  @override
  void dispose() {
    _appConfig.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});
  
  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Force HomeScreen to rebuild when switching to home tab
      if (index == 0) {
        _homeScreenRebuildKey++;
        print("🏠 [DEBUG] Switched to Home tab - forcing rebuild with key: $_homeScreenRebuildKey");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _appConfig.isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : AppColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(key: ValueKey(_homeScreenRebuildKey)),
          const BarcodeScanScreen(),
          const AnalyticsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final bool isDark = _appConfig.isDarkMode;
    return SizedBox(
      height: 110, // Increased height to prevent FAB clipping
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none, // Allow FAB to overflow
        children: [
          Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.lightGrey.withAlpha(isDark ? 20 : 128)),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 0 : 5), blurRadius: 20)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_outlined, AppConfigServer().translate('home'), 0),
                _buildNavItem(Icons.qr_code_scanner_rounded, _appConfig.translate('stats') == "आँकड़े" ? "बारकोड" : "Barcode", 1),
                const SizedBox(width: 60), // Space for FAB
                _buildNavItem(Icons.bar_chart_rounded, AppConfigServer().translate('stats'), 2),
                _buildNavItem(Icons.settings_outlined, AppConfigServer().translate('settings'), 3),
              ],
            ),
          ),
          Positioned(
            bottom: 25, // Centered properly relative to the white bar
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MealScanScreen())),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x661DB98D), blurRadius: 15, offset: Offset(0, 5))],
                ),
                child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.transparent, // Better tap target
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? AppColors.accent : AppColors.grey, size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.outfit(color: isActive ? AppColors.accent : AppColors.grey, fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final bool isDark = _appConfig.isDarkMode;
    final user = FirebaseAuth.instance.currentUser;
    final String displayName = user?.displayName ?? 'User';
    final String initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, $displayName', 
                style: GoogleFonts.outfit(color: AppColors.accent, fontSize: 24, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(AppConfigServer().translate('ai_powered_analysis'), 
                style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1DB98D).withValues(alpha: 0.15),
                backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                child: user?.photoURL == null 
                  ? Text(initial, style: const TextStyle(color: Color(0xFF1DB98D), fontWeight: FontWeight.bold))
                  : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyTip(bool isDark) {
    int tipIndex = (DateTime.now().day % 3) + 1;
    String tipKey = 'tip_$tipIndex';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_appConfig.translate('daily_tip'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_appConfig.translate(tipKey), style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeDashboard(BuildContext context) {
    final bool isDark = _appConfig.isDarkMode;
    final provider = Provider.of<UserNutritionProvider>(context);
    const double goalCalories = 2000;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildDailyTip(isDark),

            const SizedBox(height: 24),

            // Today's Progress Card (DYNAMIC)
            StreamBuilder<NutritionSummaryModel>(
              stream: provider.summaryStream,
              builder: (context, AsyncSnapshot<NutritionSummaryModel> snapshot) {
                final summary = snapshot.data ?? NutritionSummaryModel.empty();
                
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_appConfig.translate('progress_title'), style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('${summary.totalCalories.toInt()} / ${goalCalories.toInt()} kcal', 
                                style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                            child: Text('${((summary.totalCalories/goalCalories)*100).toInt()}%', style: GoogleFonts.outfit(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (summary.totalCalories / goalCalories).clamp(0, 1),
                          minHeight: 12,
                          backgroundColor: isDark ? Colors.white10 : AppColors.lightGrey,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 16),
                          const SizedBox(width: 8),
                          Text('${(goalCalories - summary.totalCalories).clamp(0, goalCalories).toInt()} ${_appConfig.translate('kcal_remaining')}', 
                            style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Scan Actions
            _buildScanAction(context, isDark, true),
            const SizedBox(height: 16),
            _buildScanAction(context, isDark, false),

            const SizedBox(height: 32),

            // Today's Meals Section (DYNAMIC)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_appConfig.translate('todays_meals'), style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NutritionHistoryScreen())),
                  child: Text("View History", style: GoogleFonts.outfit(color: AppColors.accent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            StreamBuilder<List<NutritionScanModel>>(
              stream: provider.scansStream,
              builder: (context, AsyncSnapshot<List<NutritionScanModel>> snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyMeals(isDark);
                }
                
                final now = DateTime.now();
                final todayScans = snapshot.data!.where((s) => 
                  s.createdAt.year == now.year && 
                  s.createdAt.month == now.month && 
                  s.createdAt.day == now.day
                ).toList();

                if (todayScans.isEmpty) return _buildEmptyMeals(isDark);

                return Column(
                  children: todayScans.map<Widget>((scan) => _buildMealListItem(
                    context, 
                    scan.foodName, 
                    "${scan.createdAt.hour}:${scan.createdAt.minute.toString().padLeft(2, '0')}", 
                    '${scan.calories.toInt()} kcal', 
                    0.5, // Ad-hoc progress
                    scan.scanType == 'meal_scan' ? Icons.camera_alt_rounded : Icons.qr_code_scanner_rounded,
                    scan.scanType == 'meal_scan' ? AppColors.accent : Colors.blueAccent,
                  )).toList(),
                );
              },
            ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMeals(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightGrey.withAlpha(isDark ? 20 : 128)),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu_rounded, color: AppColors.grey.withAlpha(100), size: 48),
          const SizedBox(height: 16),
          Text("No meals logged today", style: GoogleFonts.outfit(color: AppColors.grey)),
        ],
      ),
    );
  }

  Widget _buildScanAction(BuildContext context, bool isDark, bool isAI) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => isAI ? const MealScanScreen() : const BarcodeScanScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.lightGrey.withAlpha(isDark ? 20 : 128)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isAI ? AppColors.accent : Colors.blueAccent, borderRadius: BorderRadius.circular(16)),
              child: Icon(isAI ? Icons.camera_alt_rounded : Icons.qr_code_scanner_rounded, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(isAI ? _appConfig.translate('scan_meal') : "Scan Barcode", style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (isAI) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.withAlpha(26), borderRadius: BorderRadius.circular(4)),
                          child: const Text('✨ AI', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(isAI ? _appConfig.translate('scan_desc') : "Get instant facts from barcodes", style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealListItem(BuildContext context, String title, String time, String kcal, double progress, IconData icon, Color iconColor) {
    final bool isDark = _appConfig.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightGrey.withAlpha(isDark ? 20 : 128)),
      ),
      child: Column(
        children: [
          Row(
            children: [
               CircleAvatar(radius: 20, backgroundColor: AppColors.background, child: Icon(icon, color: iconColor, size: 20)),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      Row(
                        children: [
                          Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : AppColors.black)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange.withAlpha(26), borderRadius: BorderRadius.circular(4)),
                            child: Text(_appConfig.translate('moderate'), style: const TextStyle(color: Colors.orange, fontSize: 10)),
                          ),
                        ],
                      ),
                      Text('$time  •  $kcal', style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 12)),
                   ],
                 ),
               ),
               const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.lightGrey,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
