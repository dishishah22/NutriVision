import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spectrum_flutter/screens/profile_screen.dart';
import 'package:spectrum_flutter/services/app_config_server.dart';
import 'package:spectrum_flutter/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:health/health.dart'; // Temporarily disabled due to build issues


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedGoal = 'Build Muscle';
  double _calorieTarget = 2500;
  double _proteinPercent = 35;
  double _carbsPercent = 38;
  double _fatsPercent = 27;

  // Strava Dynamic Stats
  int _stravaCalories = 0;
  double _stravaDistance = 0.0; // In km (mapped to Steps card for now or Distance)
  int _stravaActiveMin = 0;
  bool _isLoadingStrava = false;
  List<dynamic> _recentActivities = [];

  bool _isStravaConnected = false;
  bool _autoSync = true;
  bool _isSaving = false;
  final _appConfig = AppConfigServer();

  // Google Fit - Temporarily disabled
  // final Health _health = Health();
  // bool _isGoogleFitConnected = false;
  // int _googleFitSteps = 0;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _appConfig.addListener(_update);
    _loadSettings();
    _initDeepLinks();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('strava_token');
    
    if (token != null) {
        setState(() => _isStravaConnected = true);
        _fetchStravaStats(token);
    }
    
    // Load Firestore Goals from top-level 'goals' collection
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('goals').doc(user.uid).get();
        if (doc.exists) {
            final data = doc.data()!;
            setState(() {
                _selectedGoal = data['goalType'] ?? 'Build Muscle';
                _calorieTarget = (data['calorieTarget'] ?? 2500).toDouble();
                _proteinPercent = (data['proteinPercent'] ?? 35).toDouble();
                _carbsPercent = (data['carbsPercent'] ?? 38).toDouble();
                _fatsPercent = (data['fatsPercent'] ?? 27).toDouble();
            });
        }
    }
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    
    // Check initial link if app was closed
    _appLinks.getInitialLink().then((uri) {
        if (uri != null) _handleDeepLink(uri);
    });

    // Listen for new links while app is open
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'nutrivision' && uri.host == 'callback') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        print("✅ [DEBUG] Strava Token Received: $token");
        setState(() => _isStravaConnected = true);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Succesfully connected to Strava! Fetching data...')),
          );
          _fetchStravaStats(token);
        }
      }
    }
  }

  @override
  void dispose() {
    _appConfig.removeListener(_update);
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _update() => setState(() {});

  void _onGoalSelected(String goal) {
    setState(() {
      _selectedGoal = goal;
      if (goal == 'Lose Weight') {
        _calorieTarget = 1800;
        _proteinPercent = 40;
        _carbsPercent = 30;
        _fatsPercent = 30;
      } else if (goal == 'Build Muscle') {
        _calorieTarget = 2800;
        _proteinPercent = 30;
        _carbsPercent = 50;
        _fatsPercent = 20;
      } else if (goal == 'Manage Diabetes') {
        _calorieTarget = 2000;
        _proteinPercent = 25;
        _carbsPercent = 25;
        _fatsPercent = 50;
      } else {
        _calorieTarget = 2200;
        _proteinPercent = 20;
        _carbsPercent = 50;
        _fatsPercent = 30;
      }
    });
  }

  double _calculateCalories(dynamic activity) {
    double calories = 0;
    double kj = (activity['kilojoules'] ?? 0).toDouble();
    
    if (kj > 0) {
        // Use Strava's data if available
        calories = kj / 4.184;
    } else {
        // Calculate calories based on activity type, distance, and duration
        String activityType = (activity['type'] ?? 'Workout').toString().toLowerCase();
        double seconds = (activity['moving_time'] ?? 0).toDouble();
        double hours = seconds / 3600;
        
        // MET values for different activities (assuming 70kg person)
        double met = 3.5; // Default: moderate walking
        
        if (activityType.contains('run')) {
            met = 10.0; // Running ~6 mph
        } else if (activityType.contains('ride') || activityType.contains('bike') || activityType.contains('cycle')) {
            met = 6.8; // Moderate cycling
        } else if (activityType.contains('walk')) {
            met = 3.5; // Walking ~3 mph
        } else if (activityType.contains('swim')) {
            met = 8.0; // Moderate swimming
        } else if (activityType.contains('hike')) {
            met = 5.5; // Hiking
        } else if (activityType.contains('yoga')) {
            met = 2.5; // Yoga
        } else {
            met = 3.5;
        }
        
        // Calculate: Calories = MET × weight(kg) × time(hours)
        double avgWeight = 70; // Average body weight in kg
        calories = met * avgWeight * hours;
    }
    return calories;
  }

  Future<void> _fetchStravaStats(String token) async {
    setState(() => _isLoadingStrava = true);
    
    // Call backend to use Strava API
    final stravaBaseUrl = _appConfig.apiUrl;
    final url = Uri.parse('$stravaBaseUrl/api/strava/activities');
    
    try {
        final response = await http.get(
            url, 
            headers: {'Authorization': token}
        );

        if (response.statusCode == 200) {
            // Save token for persistence
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('strava_token', token);

            final List<dynamic> activities = jsonDecode(response.body);
            print("🚴 [DEBUG] Strava Activities Fetched: ${activities.length}");
            
            setState(() {
                _recentActivities = activities.take(2).toList();
            });
            
            double totalCals = 0;
            double totalDist = 0;
            double totalTime = 0;
            
            final now = DateTime.now();
            final sevenDaysAgo = now.subtract(const Duration(days: 7));

            for (var activity in activities) {
                // Check if activity is within last 7 days
                String dateStr = activity['start_date_local'] ?? '';
                if (dateStr.isNotEmpty) {
                    try {
                        DateTime activityDate = DateTime.parse(dateStr);
                        if (activityDate.isAfter(sevenDaysAgo)) {
                            // Activity is within last 7 days
                            
                            // Calories - Use helper
                            double calories = _calculateCalories(activity);
                            totalCals += calories;
                            
                            // Distance (meters to km)
                            double meters = (activity['distance'] ?? 0).toDouble();
                            totalDist += (meters / 1000);
                            
                            // Moving Time (seconds to min)
                            double seconds = (activity['moving_time'] ?? 0).toDouble();
                            totalTime += (seconds / 60);
                        }
                    } catch (e) {
                        print("⚠️ [DEBUG] Error parsing date: $dateStr");
                    }
                }
            }

            setState(() {
                _stravaCalories = totalCals.toInt();
                _stravaDistance = totalDist;
                _stravaActiveMin = totalTime.toInt();
                _isLoadingStrava = false;
            });
            
            // Save to SharedPreferences for Home screen
            await prefs.setInt('strava_weekly_calories', _stravaCalories);
            print("💾 [DEBUG] Saved to SharedPreferences: $_stravaCalories kcal");
            
            // Save to Firestore 'strava_stats' collection
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
                print("💾 [DEBUG] Saving Strava to Firestore: user=${user.uid}, cals=$_stravaCalories");
                await FirebaseFirestore.instance.collection('strava_stats').doc(user.uid).set({
                    'weeklyCalories': _stravaCalories,
                    'weeklyDistance': _stravaDistance,
                    'weeklyActiveMin': _stravaActiveMin,
                    'lastSynced': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                print("✅ [DEBUG] Strava stats saved to Firestore!");
            } else {
                print("❌ [DEBUG] Cannot save Strava stats - no user logged in!");
            }
            
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Synced: $_stravaActiveMin min active this week!'), backgroundColor: Colors.green),
            );

        } else {
             throw "Server error: ${response.statusCode}";
        }
    } catch (e) {
        print("❌ [DEBUG] Strava Fetch Error: $e");
        setState(() => _isLoadingStrava = false);
        
        String errorMsg = "Connection Error";
        if (e.toString().contains("SocketException") || e.toString().contains("Connection refused")) {
             errorMsg = "Ensure Laptop & Phone are on SAME WiFi & Firewall is OFF (Port 8000)";
        } else if (e.toString().contains("ClientException")) {
             errorMsg = "Server not reachable. Check Python script.";
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(errorMsg), 
                backgroundColor: Colors.red, 
                duration: const Duration(seconds: 5)
            ),
        );
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    
    try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
            throw 'No user logged in!';
        }

        print("💾 [DEBUG] Saving goals for user: ${user.uid}");
        print("💾 [DEBUG] Goal: $_selectedGoal, Calories: $_calorieTarget");

        // Save to top-level 'goals' collection
        await FirebaseFirestore.instance.collection('goals').doc(user.uid).set({
            'goalType': _selectedGoal,
            'calorieTarget': _calorieTarget,
            'proteinPercent': _proteinPercent,
            'carbsPercent': _carbsPercent,
            'fatsPercent': _fatsPercent,
            'lastUpdated': FieldValue.serverTimestamp(),
            'stravaConnected': _isStravaConnected,
        }, SetOptions(merge: true));

        print("✅ [DEBUG] Goals saved successfully!");

        await Future.delayed(const Duration(seconds: 1)); // UX delay
        if (!mounted) return;
        setState(() => _isSaving = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goals & Settings saved to Database!', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
        print("❌ [DEBUG] Error saving goals: $e");
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  /* Google Fit - Temporarily disabled due to build issues
  Future<void> _connectGoogleFit() async {
    // Define the types to get
    final types = [
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.HEART_RATE,
    ];

    // Request authorization
    bool requested = await _health.requestAuthorization(types);

    if (requested) {
        setState(() => _isGoogleFitConnected = true);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Fit connected successfully! 🎉')),
        );
        _fetchGoogleFitStats();
    } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Fit authorization failed. ⚠️')),
        );
    }
  }

  Future<void> _fetchGoogleFitStats() async {
    if (!_isGoogleFitConnected) return;

    try {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);
        
        int? steps = await _health.getTotalStepsInInterval(midnight, now);
        
        if (steps != null) {
            setState(() {
                _googleFitSteps = steps;
            });
            print("👣 [DEBUG] Google Fit Steps: $_googleFitSteps");
        }
    } catch (e) {
        print("❌ [DEBUG] Google Fit Fetch Error: $e");
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    final bool isDark = _appConfig.isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 24),
              Text(_appConfig.translate('settings'), style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              // Your Goal Section
              _buildSectionTitle(_appConfig.translate('your_goal'), _appConfig.translate('goal_desc')),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85, // Taller cards to fit large text
                children: [
                  _buildGoalCard(_appConfig.translate('weight_loss'), _appConfig.translate('calorie_deficit'), Icons.scale_outlined),
                  _buildGoalCard(_appConfig.translate('muscle_build'), _appConfig.translate('high_protein'), Icons.fitness_center_outlined),
                  _buildGoalCard(_appConfig.translate('maintain_weight'), _appConfig.translate('balanced_nutrition_lifestyle'), Icons.track_changes_outlined),
                  _buildGoalCard(_appConfig.translate('manage_diabetes'), _appConfig.translate('low_carb_balanced'), Icons.favorite_border_rounded),
                ],
              ),

              const SizedBox(height: 32),

              // Daily Calorie Target
              _buildSectionTitle(_appConfig.translate('daily_target'), null),
              const SizedBox(height: 16),
              _buildCalorieSlider(),

              const SizedBox(height: 32),

              // Macro Distribution
              _buildSectionTitle(_appConfig.translate('macro_distribution'), _appConfig.translate('macro_desc')),
              const SizedBox(height: 16),
              _buildMacroDistribution(),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_appConfig.translate('save_goals'), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 48),

              // Fitness Integration
              Text(_appConfig.translate('fitness_sync'), style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildFitnessIntegration(),

              const SizedBox(height: 32),

              // This Week's Activity
              _buildSectionTitle("This Week's Activity", null),
              const SizedBox(height: 16),
              _buildActivityStats(),

              const SizedBox(height: 32),

              // Recent Workouts
              _buildSectionTitle(_appConfig.translate('recent_workouts'), null),
              const SizedBox(height: 16),
              if (_recentActivities.isEmpty) 
                Center(child: Text(_isStravaConnected ? "No recent workouts found." : "Connect Strava to see workouts", style: GoogleFonts.outfit(color: AppColors.grey))),
              
              ..._recentActivities.map((activity) {
                  int cals = _calculateCalories(activity).toInt();
                  double seconds = (activity['moving_time'] ?? 0).toDouble();
                  int mins = (seconds / 60).toInt();
                  String type = activity['type'] ?? 'Workout';
                  String name = activity['name'] ?? 'Activity';
                  
                  return _buildWorkoutItem(
                    name, 
                    '$mins min • $cals kcal', 
                    type == 'Run' ? Icons.directions_run_rounded : (type == 'Ride' ? Icons.directions_bike_rounded : Icons.fitness_center_rounded)
                  );
              }).toList(),

              const SizedBox(height: 32),

              // Info Box
              _buildInfoBox(),

              const SizedBox(height: 120),
            ],
          ),
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
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1DB98D).withValues(alpha: 0.15),
                child: Icon(Icons.person_outline_rounded, color: isDark ? Colors.white70 : const Color(0xFF1DB98D), size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String? subtitle) {
    final bool isDark = _appConfig.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildGoalCard(String title, String subtitle, IconData icon) {
    final bool isDark = _appConfig.isDarkMode;
    bool isSelected = _selectedGoal == title;
    return GestureDetector(
      onTap: () => _onGoalSelected(title),
      child: Container(
        // height: 180, // Removed fixed height to prevent GridView overflow
        padding: const EdgeInsets.all(16), // Adjusted padding
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.lightGrey.withAlpha(isDark ? 20 : 128), width: 2),
          boxShadow: [
            if (isSelected) BoxShadow(color: AppColors.accent.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: isDark ? Colors.black26 : AppColors.background, shape: BoxShape.circle),
                  child: Icon(icon, color: isSelected ? AppColors.accent : AppColors.grey, size: 28), // Large but balanced
                ),
                if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 24),
              ],
            ),
            const SizedBox(height: 12),
            Expanded( // Use Expanded to handle long titles
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    title, 
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white : AppColors.black, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 17, // Neat and readable
                      height: 1.1
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle, 
                    style: GoogleFonts.outfit(
                      color: AppColors.grey, 
                      fontSize: 12, 
                      height: 1.2
                    ), 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieSlider() {
    final bool isDark = _appConfig.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lightGrey.withAlpha(isDark ? 20 : 128)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${_calorieTarget.toInt()}', style: GoogleFonts.outfit(color: AppColors.accent, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(_appConfig.translate('kcal_per_day'), style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: Colors.orange.withAlpha(77),
              thumbColor: Colors.white,
              overlayColor: AppColors.accent.withAlpha(26),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
            ),
            child: Slider(
              value: _calorieTarget,
              min: 1200,
              max: 4000,
              onChanged: (val) => setState(() => _calorieTarget = val),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1,200', style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 10)),
              Text('4,000', style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroDistribution() {
    final bool isDark = _appConfig.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lightGrey.withAlpha(isDark ? 20 : 128)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(flex: _proteinPercent.toInt(), child: Container(height: 12, color: AppColors.protein)),
                Expanded(flex: _carbsPercent.toInt(), child: Container(height: 12, color: Colors.orange)),
                Expanded(flex: _fatsPercent.toInt(), child: Container(height: 12, color: Colors.pink)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildMacroSlider(_appConfig.translate('protein'), _proteinPercent, AppColors.protein, '219g ${_appConfig.translate('per_day')}', (v) => setState(() => _proteinPercent = v)),
          const SizedBox(height: 20),
          _buildMacroSlider(_appConfig.translate('carbs'), _carbsPercent, Colors.orange, '238g ${_appConfig.translate('per_day')}', (v) => setState(() => _carbsPercent = v)),
          const SizedBox(height: 20),
          _buildMacroSlider(_appConfig.translate('fats'), _fatsPercent, Colors.pink, '75g ${_appConfig.translate('per_day')}', (v) => setState(() => _fatsPercent = v)),
        ],
      ),
    );
  }

  Widget _buildMacroSlider(String label, double val, Color color, String sub, Function(double) onChanged) {
    final bool isDark = _appConfig.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label, style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            Text('${val.toInt()}%', style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: Colors.orange.withAlpha(51),
            thumbColor: Colors.white,
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(value: val, min: 0, max: 100, onChanged: onChanged),
        ),
        Text(sub, style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildFitnessIntegration() {
    final bool isDark = _appConfig.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent.withAlpha(isDark ? 51 : 128), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_rounded, color: AppColors.grey, size: 16),
                  const SizedBox(width: 8),
                  Text('Fitness Sync', style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(_appConfig.translate('connected'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_appConfig.translate('sync_workouts'), style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 10)),
          const SizedBox(height: 20),
          _buildIntegrationItem('Strava', _isStravaConnected ? 'Synced with Strava' : _appConfig.translate('not_connected'), _isStravaConnected ? _appConfig.translate('disconnect') : _appConfig.translate('connect'), () async {
            if (!_isStravaConnected) {
              // 🚀 Initiate Strava OAuth via Backend
              final stravaBaseUrl = _appConfig.apiUrl;
              final loginUrl = Uri.parse('$stravaBaseUrl/api/strava/login');
              
              print("🔗 [DEBUG] Attempting to launch Strava Login: $loginUrl");
              
              try {
                // Try launching with default mode first for maximum compatibility
                bool launched = await launchUrl(
                  loginUrl,
                  mode: LaunchMode.platformDefault,
                );
                
                if (launched) {
                  print("✅ [DEBUG] Browser opened successfully");
                  // We don't set _isStravaConnected = true yet, 
                  // it should only happen once they come back
                } else {
                  print("⚠️ [DEBUG] launchUrl returned false, trying externalApplication...");
                  launched = await launchUrl(
                    loginUrl,
                    mode: LaunchMode.externalApplication,
                  );
                }

                if (!launched) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open browser. Try typing the URL manually in your mobile browser.')),
                  );
                }
              } catch (e) {
                print("❌ [DEBUG] Strava Launch Exception: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Launch Error: $e. Check if backend is running at :5000'), 
                    backgroundColor: Colors.redAccent
                  ),
                );
              }
            } else {
              // Disconnect
              setState(() => _isStravaConnected = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Strava disconnected.', style: GoogleFonts.outfit())),
              );
            }
          }),
          
          /* Google Fit - Temporarily disabled
          const SizedBox(height: 12),
          
          // Google Fit Item
          _buildIntegrationItem('Google Fit', _isGoogleFitConnected ? 'Tracking steps ($_googleFitSteps)' : _appConfig.translate('not_connected'), _isGoogleFitConnected ? _appConfig.translate('disconnect') : _appConfig.translate('connect'), () {
             if (!_isGoogleFitConnected) {
                 _connectGoogleFit();
             } else {
                 setState(() => _isGoogleFitConnected = false);
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Google Fit disconnected.')),
                 );
             }
          }),
          */
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_appConfig.translate('auto_sync'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.black)),
              Switch(value: _autoSync, onChanged: (v) => setState(() => _autoSync = v), activeColor: AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationItem(String title, String sub, String btnText, VoidCallback onTap) {
    final bool isDark = _appConfig.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.black26 : AppColors.background.withAlpha(128), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: isDark ? Colors.white12 : Colors.white, child: Icon(Icons.directions_run_rounded, size: 16, color: title == 'Strava' ? Colors.orange : AppColors.accent)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : AppColors.black)),
                Text(sub, style: const TextStyle(color: AppColors.grey, fontSize: 10)),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: Text(btnText, style: TextStyle(color: btnText == 'Disconnect' ? Colors.redAccent.withAlpha(178) : AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildActivityStats() {
    return Row(
      children: [
        Expanded(child: _buildActivityCard(
            _isStravaConnected ? '$_stravaCalories' : '0', 
            _appConfig.translate('burned'), 
            Icons.bolt_rounded, 
            Colors.orange
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildActivityCard(
            _isStravaConnected ? '${_stravaDistance.toStringAsFixed(1)} km' : '0 km', 
            'Distance', // Changed from Steps to Distance for Strava accuracy
            Icons.map_rounded, 
            Colors.redAccent
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildActivityCard(
            _isStravaConnected ? '$_stravaActiveMin' : '0', 
            _appConfig.translate('active_min'), 
            Icons.timer_rounded, 
            AppColors.accent
        )),
      ],
    );
  }

  Widget _buildActivityCard(String val, String label, IconData icon, Color color) {
    final bool isDark = _appConfig.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1F2937) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.lightGrey.withAlpha(isDark ? 20 : 128))),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(val, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : AppColors.black)),
          Text(label, style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildWorkoutItem(String title, String sub, IconData icon) {
    final bool isDark = _appConfig.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1F2937) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lightGrey.withAlpha(isDark ? 20 : 128))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.accent.withAlpha(26), shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppColors.black)),
                Text(sub, style: const TextStyle(color: AppColors.grey, fontSize: 11)),
              ],
            ),
          ),
          Text(_appConfig.translate('synced'), style: const TextStyle(color: AppColors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildInfoBox() {
    final bool isDark = _appConfig.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.withAlpha(13), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withAlpha(51))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withAlpha(26), shape: BoxShape.circle), child: const Icon(Icons.bolt_rounded, color: Colors.orange, size: 16)),
          const SizedBox(width: 16),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.outfit(color: isDark ? Colors.white70 : AppColors.grey, fontSize: 11, height: 1.4),
                children: [
                  TextSpan(text: '${_appConfig.translate('calorie_budget_adjusted')}\n', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  TextSpan(text: _appConfig.translate('based_on_burned')),
                  const TextSpan(text: '341 kcal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  TextSpan(text: ' ${_appConfig.translate('meet_goals')}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
