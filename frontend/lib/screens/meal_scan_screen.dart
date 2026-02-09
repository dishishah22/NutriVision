import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spectrum_flutter/services/meal_scan_service.dart';
import 'package:spectrum_flutter/screens/nutritional_insights_screen.dart';
import 'package:spectrum_flutter/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:spectrum_flutter/providers/user_nutrition_provider.dart';

class MealScanScreen extends StatefulWidget {
  const MealScanScreen({super.key});

  @override
  State<MealScanScreen> createState() => _MealScanScreenState();
}

class _MealScanScreenState extends State<MealScanScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _analyzeFood() async {
    if (_image == null) return;

    final nutritionProvider = Provider.of<UserNutritionProvider>(context, listen: false);
    final userId = nutritionProvider.userId;
    
    if (userId == null) {
      _showError('User not identified');
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final result = await MealScanService.scanMeal(_image!, userId);
      
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });

        if (result['success'] == true) {
          final data = result['data'];
          
          // 📦 standard backend structure: "nutrition": {"calories": X, ...}
          final nutrition = data['nutrition'] ?? {};
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NutritionalInsightsScreen(
                apiResult: data['full_data'] ?? data,
              ),
            ),
          );
        } else {
          _showError(result['error'] ?? 'AI Analysis failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        _showError('Connection error: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Scan Your Meal', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Snap a photo of your food to get instant AI nutritional insights',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 32),
            
            // Image Preview Area
            _buildImageCard(),
            
            const SizedBox(height: 40),
            
            if (!_isAnalyzing) ...[
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Camera',
                      Icons.camera_alt_rounded,
                      AppColors.accent,
                      () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      'Gallery',
                      Icons.photo_library_rounded,
                      Colors.blueAccent,
                      () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              
              if (_image != null) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _analyzeFood,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('Get Insights', 
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ] else 
              _buildAnalyzingState(),
              
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: _image != null
              ? Image.file(_image!, fit: BoxFit.cover)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fastfood_rounded, size: 48, color: AppColors.accent),
                      ),
                      const SizedBox(height: 20),
                      Text('No image selected', 
                        style: GoogleFonts.outfit(color: Colors.grey[500], fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(label, 
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 3,
        ),
        const SizedBox(height: 24),
        Text('AI is analyzing your meal...', 
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[700])),
        const SizedBox(height: 8),
        Text('Calculating calories, macros and ingredients', 
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500])),
      ],
    );
  }
}
