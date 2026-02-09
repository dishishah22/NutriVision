import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spectrum_flutter/models/nutrition_models.dart';
import 'package:spectrum_flutter/providers/user_nutrition_provider.dart';
import 'package:spectrum_flutter/theme/app_colors.dart';

class NutritionHistoryScreen extends StatelessWidget {
  const NutritionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserNutritionProvider>(context);

    if (provider.userId == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text("History")),
        body: const Center(child: Text("Please log in to view history")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Nutrition History',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              final uid = provider.userId;
              if (uid != null) provider.setUserId(uid);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // DEBUG INFO
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: provider.userId ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account ID copied!")));
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    SelectableText("Account ID: ${provider.userId}", 
                      style: GoogleFonts.outfit(fontSize: 10, color: Colors.black54), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    const Text("Tap to copy for DB verification", style: TextStyle(fontSize: 8, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Summary Card
            StreamBuilder<NutritionSummaryModel>(
              stream: provider.summaryStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final summary = snapshot.data!;
                return _buildSummaryCard(summary);
              },
            ),
            const SizedBox(height: 24),
            
            // History Table Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Recent Scans",
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            
            // Dynamic History List
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(provider.userId)
                  .collection('scans')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(50.0),
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  );
                }
                
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final scan = NutritionScanModel.fromMap(data);
                    return _buildHistoryItem(scan);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 32),
          const SizedBox(height: 12),
          Text("Sync Error", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(error, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.history_rounded, size: 80, color: AppColors.lightGrey.withValues(alpha: 0.3)),
          const SizedBox(height: 20),
          Text("Your nutrition journey is empty.", style: GoogleFonts.outfit(color: AppColors.black, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text("Scan meals on the home screen to see your progress here.", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(NutritionScanModel scan) {
    final bool isBarcode = scan.scanType == 'barcode_scan';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightGrey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isBarcode ? Colors.blue : AppColors.accent).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(isBarcode ? Icons.qr_code_scanner_rounded : Icons.restaurant_rounded, 
              color: isBarcode ? Colors.blue : AppColors.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scan.foodName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(DateFormat('EEEE, MMM d • hh:mm a').format(scan.createdAt), 
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${scan.calories.toInt()} kcal', 
                style: GoogleFonts.outfit(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildMiniMacro('P', '${scan.protein.toInt()}g', Colors.orange),
                  const SizedBox(width: 4),
                  _buildMiniMacro('F', '${scan.fat.toInt()}g', Colors.redAccent),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMacro(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text("$label $value", style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSummaryCard(NutritionSummaryModel summary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text("Lifetime Summary",
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Calories", "${summary.totalCalories.toInt()}", Icons.local_fire_department, Colors.orange),
              _buildStatItem("Protein", "${summary.totalProtein.toInt()}g", Icons.fitness_center, Colors.blue),
              _buildStatItem("Fat", "${summary.totalFat.toInt()}g", Icons.opacity, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}
