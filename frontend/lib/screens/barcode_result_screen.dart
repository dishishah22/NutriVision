import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spectrum_flutter/services/barcode_service.dart';
import 'package:provider/provider.dart';
import 'package:spectrum_flutter/providers/user_nutrition_provider.dart';

class BarcodeResultScreen extends StatefulWidget {
  final String barcode;

  const BarcodeResultScreen({super.key, required this.barcode});

  @override
  State<BarcodeResultScreen> createState() => _BarcodeResultScreenState();
}

class _BarcodeResultScreenState extends State<BarcodeResultScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _productData;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final nutritionProvider = Provider.of<UserNutritionProvider>(context, listen: false);
      final userId = nutritionProvider.userId;
      
      if (userId == null) {
        setState(() {
          _error = "User not identified";
          _isLoading = false;
        });
        return;
      }

      final result = await ApiService.fetchProductByBarcode(widget.barcode, userId);
      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            _productData = result['data'];
            // Backend now handles the save!
          } else {
            _error = result['error'] ?? 'Unknown error occurred';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveScan(Map<String, dynamic> data) async {
    try {
      final provider = Provider.of<UserNutritionProvider>(context, listen: false);
      final nutriments = data['nutriments'] ?? {};
      
      double getVal(String key) {
         final v = nutriments[key];
         if (v is num) return v.toDouble();
         if (v is String) return double.tryParse(v) ?? 0.0;
         return 0.0;
      }

      await provider.addScan(
        scanType: 'barcode_scan',
        foodName: data['product_name'] ?? 'Scanned Product',
        calories: getVal('energy-kcal_100g'),
        protein: getVal('proteins_100g'),
        fat: getVal('fat_100g'),
        carbs: getVal('carbohydrates_100g'),
        rawApiResponse: data,
      );
    } catch (e) {
      debugPrint("Auto-save failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Product Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _error != null
              ? _buildErrorView()
              : _buildSuccessView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final data = _productData!;
    final nutriments = data['nutriments'] as Map<String, dynamic>? ?? {};

    // Check if what we got is basically an empty/error result from the backend
    bool isEmptyResult = data['ingredients']?.toString().contains("not available") ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(data),
          const SizedBox(height: 24),
          _buildSectionTitle('Ingredients'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              isEmptyResult ? "No data found for this barcode." : (data['ingredients'] ?? 'No ingredients listed'),
              style: GoogleFonts.outfit(
                fontSize: 15,
                height: 1.6,
                color: isEmptyResult ? Colors.redAccent : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Nutritional Facts (per 100g)'),
          const SizedBox(height: 12),
          _buildNutrientsGrid(nutriments),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.qr_code_rounded, 'Barcode', widget.barcode),
          const Divider(height: 24),
          _buildInfoRow(Icons.scale_rounded, 'Weight', data['weight_grams'] ?? 'N/A'),
          const Divider(height: 24),
          _buildInfoRow(Icons.restaurant_rounded, 'Serving Size', data['serving_size'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.blueAccent, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13)),
            Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildNutrientsGrid(Map<String, dynamic> nutriments) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildNutrientCard('Energy', '${_safeNutrient(nutriments, 'energy-kcal_100g')} kcal', Colors.orange),
        _buildNutrientCard('Proteins', '${_safeNutrient(nutriments, 'proteins_100g')} g', Colors.blue),
        _buildNutrientCard('Carbs', '${_safeNutrient(nutriments, 'carbohydrates_100g')} g', Colors.green),
        _buildNutrientCard('Fats', '${_safeNutrient(nutriments, 'fat_100g')} g', Colors.red),
        _buildNutrientCard('Sugars', '${_safeNutrient(nutriments, 'sugars_100g')} g', Colors.pink),
        _buildNutrientCard('Fiber', '${_safeNutrient(nutriments, 'fiber_100g')} g', Colors.teal),
        _buildNutrientCard('Salt', '${_safeNutrient(nutriments, 'salt_100g')} g', Colors.brown),
      ],
    );
  }

  String _safeNutrient(Map<String, dynamic> nutriments, String key) {
    final value = nutriments[key];
    if (value == null) return '0';
    if (value is num) return value.toStringAsFixed(1);
    return value.toString();
  }

  Widget _buildNutrientCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}
