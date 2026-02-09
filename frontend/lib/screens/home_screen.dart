import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spectrum_flutter/screens/meal_scan_screen.dart';
import 'package:spectrum_flutter/services/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spectrum_flutter/theme/app_colors.dart';
import 'package:spectrum_flutter/screens/nutrition_history_screen.dart';
import 'package:spectrum_flutter/screens/profile_screen.dart';
import 'package:spectrum_flutter/screens/ai_assistant_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Goals from Settings
  double _calorieGoal = 2000;
  double _proteinPercent = 30;
  double _carbsPercent = 50;
  double _fatsPercent = 20;
  String _selectedGoal = 'Maintain Weight';

  // Strava Weekly Stats
  int _stravaCaloriesBurned = 0;
  
  // Consumed today (mock for now, will come from meal scans)
  int _caloriesConsumed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGoalsAndActivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print("🔄 [DEBUG] App resumed - reloading goals and stats");
      _loadGoalsAndActivity();
    }
  }

  Future<void> _loadGoalsAndActivity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("⚠️ [DEBUG] No user logged in");
      return;
    }

    try {
      print("🔄 [DEBUG] Loading goals for user: ${user.uid}");
      
      // Load saved goals from top-level 'goals' collection
      final goalsDoc = await FirebaseFirestore.instance
          .collection('goals')
          .doc(user.uid)
          .get();

      if (goalsDoc.exists) {
        final data = goalsDoc.data()!;
        print("📊 [DEBUG] Goals found: ${data['goalType']}, ${data['calorieTarget']} kcal");
        setState(() {
          _calorieGoal = (data['calorieTarget'] ?? 2000).toDouble();
          _proteinPercent = (data['proteinPercent'] ?? 30).toDouble();
          _carbsPercent = (data['carbsPercent'] ?? 50).toDouble();
          _fatsPercent = (data['fatsPercent'] ?? 20).toDouble();
          _selectedGoal = data['goalType'] ?? 'Maintain Weight';
        });
      } else {
        print("⚠️ [DEBUG] No goals found in database. Using defaults.");
      }

      // Load Strava stats from top-level 'strava_stats' collection
      final stravaDoc = await FirebaseFirestore.instance
          .collection('strava_stats')
          .doc(user.uid)
          .get();
          
      if (stravaDoc.exists) {
        final data = stravaDoc.data()!;
        setState(() {
          _stravaCaloriesBurned = (data['weeklyCalories'] ?? 0).toInt();
        });
        print("🔥 [DEBUG] Strava stats found: $_stravaCaloriesBurned kcal burned");
      }

      // Load Consumed Calories from user's 'nutrition_summary'
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      if (userDoc.exists) {
        final data = userDoc.data()!;
        if (data.containsKey('nutrition_summary')) {
          final summary = data['nutrition_summary'] as Map<String, dynamic>;
          setState(() {
            _caloriesConsumed = (summary['totalCalories'] ?? 0).toInt();
          });
          print("🍎 [DEBUG] Nutrition summary found: $_caloriesConsumed kcal eaten");
        }
      }

      print("✅ [DEBUG] Loaded - Goal: $_calorieGoal kcal, Burned: $_stravaCaloriesBurned kcal, Eaten: $_caloriesConsumed kcal");
    } catch (e) {
      print("❌ [DEBUG] Error loading goals/activity: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    String nameToDisplay = 'User';
    
    if (user != null) {
      String rawName = '';
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        rawName = user.displayName!;
      } else if (user.email != null && user.email!.isNotEmpty) {
        rawName = user.email!.split('@')[0];
      }

      if (rawName.isNotEmpty) {
        String noDigits = rawName.replaceAll(RegExp(r'[0-9]'), '');
        List<String> parts = noDigits.split(RegExp(r'[ ._-]'));
        
        for (String part in parts) {
          if (part.isNotEmpty) {
             if (part.toLowerCase().contains('shah') && part.length > 4 && !part.toLowerCase().startsWith('shah')) {
                int index = part.toLowerCase().indexOf('shah');
                part = part.substring(0, index);
             }

            if (part.isNotEmpty) {
                 nameToDisplay = part[0].toUpperCase() + part.substring(1).toLowerCase();
                 break;
            }
          }
        }
      }
    }

    // Calculate progress
    int netCalories = _caloriesConsumed - _stravaCaloriesBurned;
    double progress = netCalories / _calorieGoal;
    
    // Remaining calories to reach goal
    int remainingCalories = _calorieGoal.toInt() - netCalories;
    
    // Calculate macro targets in grams
    int proteinTarget = ((_calorieGoal * _proteinPercent / 100) / 4).toInt(); // 4 kcal/g
    int carbsTarget = ((_calorieGoal * _carbsPercent / 100) / 4).toInt(); // 4 kcal/g
    int fatsTarget = ((_calorieGoal * _fatsPercent / 100) / 9).toInt(); // 9 kcal/g

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'NutriVision',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: const Color(0xFF1DB98D),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1DB98D).withValues(alpha: 0.15),
                child: Text(
                  user?.displayName?.substring(0, 1).toUpperCase() ?? 
                  user?.email?.substring(0, 1).toUpperCase() ?? 
                  'U',
                  style: const TextStyle(
                    color: Color(0xFF1DB98D),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGoalsAndActivity,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with profile and history
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                      child: Text(
                        user?.displayName?.substring(0, 1).toUpperCase() ?? 
                        user?.email?.substring(0, 1).toUpperCase() ?? 
                        'U',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello,',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          user?.displayName ?? user?.email?.split('@')[0] ?? 'User',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.history, color: AppColors.accent),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NutritionHistoryScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Goal: $_selectedGoal • ${_calorieGoal.toInt()} kcal/day',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            
            // 🆕 Live Updates Box (Dynamic Database Data)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('scans')
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                String subTitle = 'Your meals & Strava activity are updating in real-time from the cloud.';
                bool hasData = false;
                
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final latestDoc = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  final foodName = latestDoc['foodName'] ?? 'Unknown Meal';
                  final cal = (latestDoc['calories'] ?? 0).toInt();
                  subTitle = 'Latest: $foodName ($cal kcal) synced from your history.';
                  hasData = true;
                } else if (_stravaCaloriesBurned > 0) {
                  subTitle = 'Latest: $_stravaCaloriesBurned kcal synced from Strava activity.';
                  hasData = true;
                }

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasData ? Icons.check_circle_rounded : Icons.sync_rounded, 
                            color: AppColors.accent, 
                            size: 24
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasData ? 'Live Update Sync' : 'Live Sync Active',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.accent, // Green
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subTitle,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.accent.withOpacity(0.8), // Green
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
              const SizedBox(height: 32),
              
              // Summary Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient, // Green Gradient
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Today\'s Progress',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Goal: ${_calorieGoal.toInt()}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🍽️ Eaten',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                            ),
                            Text(
                              '$_caloriesConsumed',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🔥 Burned',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                            ),
                            Text(
                              '$_stravaCaloriesBurned',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📊 Net',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                            ),
                            Text(
                              '$netCalories',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.black.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMacroSummary('Protein', '${proteinTarget}g', 0.0),
                        _buildMacroSummary('Carbs', '${carbsTarget}g', 0.0),
                        _buildMacroSummary('Fat', '${fatsTarget}g', 0.0),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Quick Actions
              Text(
                'Quick Actions',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      title: 'Scan Food',
                      icon: FontAwesomeIcons.camera,
                      color: AppColors.accent, // Green
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MealScanScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      title: 'AI Assistant',
                      icon: Icons.psychology_outlined,
                      color: AppColors.accent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AiAssistantChatScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
               // Recent Meals
              Text(
                'Recent Meals',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              // Load real meals from Firestore
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .collection('scans')
                    .orderBy('createdAt', descending: true)
                    .limit(3)
                    .snapshots(),
                builder: (context, snapshot) {  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(color: AppColors.accent),
                      ),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error loading meals',
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.restaurant_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No meals scanned yet',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Scan Food" to add your first meal!',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final meals = snapshot.data!.docs;
                  
                  return Column(
                    children: meals.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final foodName = data['foodName'] ?? 'Unknown Food';
                      final calories = data['calories'] ?? 0;
                      final timestamp = (data['createdAt'] as Timestamp?)?.toDate();
                      final timeStr = timestamp != null 
                          ? '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}' 
                          : 'N/A';
        final mealType = data['scanType'] == 'barcode_scan' ? 'Barcode' : 'Meal Scan';
                    
                      return _buildMealItem(
                        mealType,
                        foodName,
                        '${calories.toInt()} kcal',
                        timeStr,
                      );
                    }).toList(),
                  );
              },
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMacroSummary(String label, String value, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealItem(String type, String name, String calories, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1), // Green light background
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              type == 'Breakfast'
                  ? Icons.wb_sunny_outlined
                  : type == 'Lunch'
                      ? Icons.restaurant
                      : Icons.nightlight_outlined,
              color: AppColors.accent, // Green Icon
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  type,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                calories,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent, // Green Text
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
